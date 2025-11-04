DROP FUNCTION IF EXISTS public.get_crew_overview(integer, text);
DROP FUNCTION IF EXISTS public.get_crew_overview(integer, text, text);

CREATE FUNCTION public.get_crew_overview(
  p_crew_id integer,
  target_week text DEFAULT NULL,
  p_area_name text DEFAULT NULL
) RETURNS TABLE (
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  max_member integer,
  weekly_score numeric,
  weekly_rank integer,
  total_score numeric,
  total_rank integer,
  introduction text
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_area text;
  v_week_id text;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  v_area := NULLIF(trim(p_area_name), '');
  v_week_id := COALESCE(
    target_week,
    to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW')
  );

  IF v_area IS NULL THEN
    RETURN QUERY
    WITH aggregated AS (
      SELECT
        c.crew_id AS crew_id_val,
        c.crew_name AS crew_name_val,
        c.logo_url AS logo_url_val,
        COALESCE(c.max_member, 20)::int AS max_member_val,
        COALESCE(c.introduction, '') AS introduction_val,
        COUNT(u.user_id) AS member_count_val,
        COALESCE(SUM(u.weekly_score), 0)::numeric AS weekly_sum,
        COALESCE(SUM(u.total_score), 0)::numeric AS total_sum
      FROM public."crew" c
      LEFT JOIN public."user" u ON u.crew_id = c.crew_id
      GROUP BY c.crew_id, c.crew_name, c.logo_url, c.max_member, c.introduction
    ), weekly_ranked AS (
      SELECT
        aggregated.*,
        ROW_NUMBER() OVER (
          ORDER BY weekly_sum DESC, total_sum DESC, crew_name_val
        ) AS weekly_rank
      FROM aggregated
    ), total_ranked AS (
      SELECT
        crew_id_val AS crew_id_tr,
        ROW_NUMBER() OVER (
          ORDER BY total_sum DESC, weekly_sum DESC, crew_name_val
        ) AS total_rank
      FROM aggregated
    )
    SELECT
      wr.crew_id_val::int,
      wr.crew_name_val::text,
      wr.logo_url_val::text,
      wr.member_count_val::int,
      wr.max_member_val::int,
      wr.weekly_sum,
      wr.weekly_rank::int,
      wr.total_sum,
      tr.total_rank::int,
      wr.introduction_val::text
    FROM weekly_ranked wr
    JOIN total_ranked tr ON tr.crew_id_tr = wr.crew_id_val
    WHERE wr.crew_id_val = p_crew_id;
    RETURN;
  END IF;

  RETURN QUERY
  WITH runs AS (
    SELECT
      rr.user_id,
      to_char(
        (COALESCE(rr.start_time, rr.end_time, now()) AT TIME ZONE 'Asia/Seoul')::date,
        'IYYY-IW'
      ) AS week_id_col,
      COALESCE(
        NULLIF(rr.score, 0),
        CASE
          WHEN COALESCE(rr.distance, 0)::numeric > 0
            THEN GREATEST(floor(COALESCE(rr.distance, 0)::numeric * 10), 1)
          ELSE 0::numeric
        END
      ) AS points_col
    FROM public.running_record rr
    WHERE rr.start_area_name = v_area
  ), weekly AS (
    SELECT user_id, SUM(points_col) AS weekly_points
    FROM runs
    WHERE week_id_col = v_week_id
    GROUP BY user_id
  ), total AS (
    SELECT user_id, SUM(points_col) AS total_points
    FROM runs
    GROUP BY user_id
  ), base AS (
    SELECT
      c.crew_id AS crew_id_val,
      c.crew_name AS crew_name_val,
      c.logo_url AS logo_url_val,
      COALESCE(c.max_member, 20)::int AS max_member_val,
      COALESCE(c.introduction, '') AS introduction_val,
      (SELECT COUNT(*) FROM public."user" mu WHERE mu.crew_id = c.crew_id) AS member_count,
      COALESCE((
        SELECT SUM(COALESCE(w.weekly_points, 0))
        FROM public."user" u
        LEFT JOIN weekly w ON w.user_id = u.user_id
        WHERE u.crew_id = c.crew_id
      ), 0)::numeric AS weekly_sum,
      COALESCE((
        SELECT SUM(COALESCE(t.total_points, 0))
        FROM public."user" u
        LEFT JOIN total t ON t.user_id = u.user_id
        WHERE u.crew_id = c.crew_id
      ), 0)::numeric AS total_sum
    FROM public."crew" c
  ), ranked AS (
    SELECT
      base.*,
      ROW_NUMBER() OVER (
        ORDER BY weekly_sum DESC, total_sum DESC, crew_name_val
      ) AS weekly_rank,
      ROW_NUMBER() OVER (
        ORDER BY total_sum DESC, weekly_sum DESC, crew_name_val
      ) AS total_rank
    FROM base
  )
  SELECT
    ranked.crew_id_val::int,
    ranked.crew_name_val::text,
    ranked.logo_url_val::text,
    ranked.member_count::int,
    ranked.max_member_val::int,
    ranked.weekly_sum,
    ranked.weekly_rank::int,
    ranked.total_sum,
    ranked.total_rank::int,
    ranked.introduction_val::text
  FROM ranked
  WHERE ranked.crew_id_val = p_crew_id;
END;
$$;

DROP FUNCTION IF EXISTS public.get_crew_members(integer, uuid);
DROP FUNCTION IF EXISTS public.get_crew_members(integer, uuid, text);

CREATE FUNCTION public.get_crew_members(
  p_crew_id integer,
  p_auth_user_id uuid DEFAULT NULL,
  p_area_name text DEFAULT NULL
) RETURNS TABLE (
  rank integer,
  user_id integer,
  user_name text,
  is_leader boolean,
  is_myself boolean,
  weekly_score integer,
  total_score integer
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_area text;
  v_week_id text;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  v_area := NULLIF(trim(p_area_name), '');
  v_week_id := to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW');

  IF v_area IS NULL THEN
    RETURN QUERY
    WITH members AS (
      SELECT
        u.user_id AS user_id_val,
        u.name AS user_name_val,
        u.weekly_score AS weekly_score_val,
        u.total_score AS total_score_val,
        (u.user_id = c.leader_user_id) AS is_leader_val,
        (u.auth_user_id = p_auth_user_id) AS is_myself_val
      FROM public."user" u
      JOIN public."crew" c ON c.crew_id = p_crew_id
      WHERE u.crew_id = p_crew_id
    ), ranked AS (
      SELECT
        user_id_val,
        user_name_val,
        weekly_score_val,
        total_score_val,
        is_leader_val,
        is_myself_val,
        ROW_NUMBER() OVER (
          PARTITION BY NOT is_leader_val
          ORDER BY total_score_val DESC, user_name_val
        ) AS pos
      FROM members
    )
    SELECT
      (CASE WHEN is_leader_val THEN 1 ELSE pos + 1 END)::int AS rank,
      user_id_val::int AS user_id,
      user_name_val::text AS user_name,
      is_leader_val AS is_leader,
      is_myself_val AS is_myself,
      weekly_score_val::int AS weekly_score,
      total_score_val::int AS total_score
    FROM ranked
    ORDER BY CASE WHEN is_leader_val THEN 0 ELSE 1 END, rank;
    RETURN;
  END IF;

  RETURN QUERY
  WITH members AS (
    SELECT
      u.user_id AS user_id_val,
      u.name AS user_name_val,
      (u.user_id = c.leader_user_id) AS is_leader_val,
      (u.auth_user_id = p_auth_user_id) AS is_myself_val
    FROM public."user" u
    JOIN public."crew" c ON c.crew_id = p_crew_id
    WHERE u.crew_id = p_crew_id
  ), area_runs AS (
    SELECT
      rr.user_id,
      to_char(
        (COALESCE(rr.start_time, rr.end_time, now()) AT TIME ZONE 'Asia/Seoul')::date,
        'IYYY-IW'
      ) AS week_id_col,
      COALESCE(
        NULLIF(rr.score, 0),
        CASE
          WHEN COALESCE(rr.distance, 0)::numeric > 0
            THEN GREATEST(floor(COALESCE(rr.distance, 0)::numeric * 10), 1)
          ELSE 0::numeric
        END
      ) AS points_col
    FROM public.running_record rr
    WHERE rr.start_area_name = v_area
  ), area_scores AS (
    SELECT
      ar.user_id,
      COALESCE(SUM(COALESCE(ar.points_col, 0)), 0)::numeric AS total_points,
      COALESCE(SUM(COALESCE(ar.points_col, 0)) FILTER (WHERE ar.week_id_col = v_week_id), 0)::numeric AS weekly_points
    FROM area_runs ar
    JOIN members m ON m.user_id_val = ar.user_id
    GROUP BY ar.user_id
  ), decorated AS (
    SELECT
      m.user_id_val,
      m.user_name_val,
      m.is_leader_val,
      m.is_myself_val,
      COALESCE(ascr.weekly_points, 0)::int AS weekly_score_val,
      COALESCE(ascr.total_points, 0)::int AS total_score_val
    FROM members m
    LEFT JOIN area_scores ascr ON ascr.user_id = m.user_id_val
  ), ranked AS (
    SELECT
      decorated.*,
      ROW_NUMBER() OVER (
        PARTITION BY NOT decorated.is_leader_val
        ORDER BY decorated.total_score_val DESC, decorated.user_name_val
      ) AS pos
    FROM decorated
  )
  SELECT
    (CASE WHEN is_leader_val THEN 1 ELSE pos + 1 END)::int AS rank,
    user_id_val::int AS user_id,
    user_name_val::text AS user_name,
    is_leader_val AS is_leader,
    is_myself_val AS is_myself,
    weekly_score_val,
    total_score_val
  FROM ranked
  ORDER BY CASE WHEN is_leader_val THEN 0 ELSE 1 END, rank;
END;
$$;
