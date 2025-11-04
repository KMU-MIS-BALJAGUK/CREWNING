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

  RETURN QUERY
  WITH crew_runs AS (
    SELECT
      u.crew_id AS crew_id_col,
      rr.user_id AS user_id_col,
      to_char(
        (COALESCE(rr.start_time, rr.end_time, now()) AT TIME ZONE 'Asia/Seoul')::date,
        'IYYY-IW'
      ) AS week_id_col,
      COALESCE(
        rr.score,
        CASE
          WHEN COALESCE(rr.distance, 0)::numeric > 0
            THEN GREATEST(floor(COALESCE(rr.distance, 0)::numeric * 10), 1)
          ELSE 0::numeric
        END
      ) AS points_col
    FROM public.running_record rr
    JOIN public."user" u ON u.user_id = rr.user_id
    WHERE u.crew_id IS NOT NULL
      AND (v_area IS NULL OR rr.start_area_name = v_area)
  ), weekly AS (
    SELECT crew_id_col, SUM(points_col) AS weekly_points
    FROM crew_runs
    WHERE week_id_col = v_week_id
    GROUP BY crew_id_col
  ), total AS (
    SELECT crew_id_col, SUM(points_col) AS total_points
    FROM crew_runs
    GROUP BY crew_id_col
  ), base AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      (SELECT COUNT(*) FROM public."user" mu WHERE mu.crew_id = c.crew_id) AS member_count,
      COALESCE(c.max_member, 20)::int AS max_member,
      COALESCE(c.introduction, '') AS introduction,
      COALESCE(w.weekly_points, 0)::numeric AS weekly_score,
      COALESCE(t.total_points, 0)::numeric AS total_score
    FROM public."crew" c
    LEFT JOIN weekly w ON w.crew_id_col = c.crew_id
    LEFT JOIN total t ON t.crew_id_col = c.crew_id
  )
  SELECT
    base.crew_id::int,
    base.crew_name::text,
    base.logo_url::text,
    base.member_count::int,
    base.max_member::int,
    base.weekly_score,
    ROW_NUMBER() OVER (
      ORDER BY base.weekly_score DESC, base.total_score DESC, base.crew_name
    )::int AS weekly_rank,
    base.total_score,
    ROW_NUMBER() OVER (
      ORDER BY base.total_score DESC, base.weekly_score DESC, base.crew_name
    )::int AS total_rank,
    base.introduction::text
  FROM base
  WHERE base.crew_id = p_crew_id;
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
  ), runs AS (
    SELECT
      rr.user_id AS user_id_col,
      to_char(
        (COALESCE(rr.start_time, rr.end_time, now()) AT TIME ZONE 'Asia/Seoul')::date,
        'IYYY-IW'
      ) AS week_id_col,
      COALESCE(
        rr.score,
        CASE
          WHEN COALESCE(rr.distance, 0)::numeric > 0
            THEN GREATEST(floor(COALESCE(rr.distance, 0)::numeric * 10), 1)
          ELSE 0::numeric
        END
      ) AS points_col
    FROM public.running_record rr
    WHERE (v_area IS NULL OR rr.start_area_name = v_area)
      AND rr.user_id IN (SELECT user_id_val FROM members)
  ), aggregated AS (
    SELECT
      m.user_id_val,
      COALESCE(SUM(r.points_col) FILTER (WHERE r.week_id_col = v_week_id), 0)::int AS weekly_points,
      COALESCE(SUM(r.points_col), 0)::int AS total_points
    FROM members m
    LEFT JOIN runs r ON r.user_id_col = m.user_id_val
    GROUP BY m.user_id_val
  ), ranked AS (
    SELECT
      m.user_id_val,
      m.user_name_val,
      m.is_leader_val,
      m.is_myself_val,
      COALESCE(a.weekly_points, 0) AS weekly_score_val,
      COALESCE(a.total_points, 0) AS total_score_val,
      ROW_NUMBER() OVER (
        PARTITION BY NOT m.is_leader_val
        ORDER BY COALESCE(a.total_points, 0) DESC, m.user_name_val
      ) AS pos
    FROM members m
    LEFT JOIN aggregated a ON a.user_id_val = m.user_id_val
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
