DROP FUNCTION IF EXISTS public.get_weekly_crew_rankings_by_area(text,text,int,int);
DROP FUNCTION IF EXISTS public.get_total_crew_rankings_by_area(text,text,int,int);

CREATE FUNCTION public.get_weekly_crew_rankings_by_area(
  p_area_name text,
  target_week text DEFAULT NULL,
  fetch_limit integer DEFAULT 100,
  fetch_offset integer DEFAULT 0
) RETURNS TABLE (
  rank integer,
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  weekly_score numeric,
  total_score numeric
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
  WITH filtered AS (
    SELECT
      u.crew_id AS crew_id_col,
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
    WHERE (v_area IS NULL OR rr.start_area_name = v_area)
      AND u.crew_id IS NOT NULL
  ), weekly AS (
    SELECT crew_id_col, SUM(points_col) AS weekly_points
    FROM filtered
    WHERE week_id_col = v_week_id
    GROUP BY crew_id_col
  ), total AS (
    SELECT crew_id_col, SUM(points_col) AS total_points
    FROM filtered
    GROUP BY crew_id_col
  ), area_crews AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url
    FROM public."crew" c
  ), base AS (
    SELECT
      ac.crew_id AS crew_id_val,
      ac.crew_name AS crew_name_val,
      ac.logo_url AS logo_url_val,
      (SELECT COUNT(*) FROM public."user" mu WHERE mu.crew_id = ac.crew_id) AS member_count_val,
      COALESCE(w.weekly_points, 0)::numeric AS weekly_score_val,
      COALESCE(t.total_points, 0)::numeric AS total_score_val
    FROM area_crews ac
    LEFT JOIN weekly w ON w.crew_id_col = ac.crew_id
    LEFT JOIN total t ON t.crew_id_col = ac.crew_id
  ), ranked AS (
    SELECT
      base.*,
      ROW_NUMBER() OVER (
        ORDER BY weekly_score_val DESC, total_score_val DESC, crew_name_val
      ) AS rn
    FROM base
  )
  SELECT
    ranked.rn::int AS rank,
    ranked.crew_id_val::int AS crew_id,
    ranked.crew_name_val::text AS crew_name,
    ranked.logo_url_val::text AS logo_url,
    ranked.member_count_val::int AS member_count,
    ranked.weekly_score_val AS weekly_score,
    ranked.total_score_val AS total_score
  FROM ranked
  ORDER BY ranked.rn
  LIMIT COALESCE(fetch_limit, 100)
  OFFSET COALESCE(fetch_offset, 0);
END;
$$;

CREATE FUNCTION public.get_total_crew_rankings_by_area(
  p_area_name text,
  target_week text DEFAULT NULL,
  fetch_limit integer DEFAULT 100,
  fetch_offset integer DEFAULT 0
) RETURNS TABLE (
  rank integer,
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  weekly_score numeric,
  total_score numeric
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
  WITH filtered AS (
    SELECT
      u.crew_id AS crew_id_col,
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
    WHERE (v_area IS NULL OR rr.start_area_name = v_area)
      AND u.crew_id IS NOT NULL
  ), weekly AS (
    SELECT crew_id_col, SUM(points_col) AS weekly_points
    FROM filtered
    WHERE week_id_col = v_week_id
    GROUP BY crew_id_col
  ), total AS (
    SELECT crew_id_col, SUM(points_col) AS total_points
    FROM filtered
    GROUP BY crew_id_col
  ), area_crews AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url
    FROM public."crew" c
  ), base AS (
    SELECT
      ac.crew_id AS crew_id_val,
      ac.crew_name AS crew_name_val,
      ac.logo_url AS logo_url_val,
      (SELECT COUNT(*) FROM public."user" mu WHERE mu.crew_id = ac.crew_id) AS member_count_val,
      COALESCE(w.weekly_points, 0)::numeric AS weekly_score_val,
      COALESCE(t.total_points, 0)::numeric AS total_score_val
    FROM area_crews ac
    LEFT JOIN weekly w ON w.crew_id_col = ac.crew_id
    LEFT JOIN total t ON t.crew_id_col = ac.crew_id
  ), ranked AS (
    SELECT
      base.*,
      ROW_NUMBER() OVER (
        ORDER BY total_score_val DESC, weekly_score_val DESC, crew_name_val
      ) AS rn
    FROM base
  )
  SELECT
    ranked.rn::int AS rank,
    ranked.crew_id_val::int AS crew_id,
    ranked.crew_name_val::text AS crew_name,
    ranked.logo_url_val::text AS logo_url,
    ranked.member_count_val::int AS member_count,
    ranked.weekly_score_val AS weekly_score,
    ranked.total_score_val AS total_score
  FROM ranked
  ORDER BY ranked.rn
  LIMIT COALESCE(fetch_limit, 100)
  OFFSET COALESCE(fetch_offset, 0);
END;
$$;
