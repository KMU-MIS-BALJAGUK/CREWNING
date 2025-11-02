DROP FUNCTION IF EXISTS public.get_weekly_crew_rankings(text,int,int);
DROP FUNCTION IF EXISTS public.get_total_crew_rankings(int,int);
DROP FUNCTION IF EXISTS public.get_my_crew_summary(uuid,text);
DROP FUNCTION IF EXISTS public.get_crew_overview(integer,text);

CREATE FUNCTION public.get_weekly_crew_rankings(
  target_week text DEFAULT NULL,
  fetch_limit int DEFAULT 100,
  fetch_offset int DEFAULT 0
) RETURNS TABLE (
  rank integer,
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  weekly_score double precision,
  total_score integer
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_week_id text;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  v_week_id := COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'));

  RETURN QUERY
  WITH ranked AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY COALESCE(cws.score, 0) DESC, COALESCE(c.total_score, 0) DESC, c.crew_name) AS rank_val,
      c.crew_id AS crew_id_val,
      c.crew_name AS crew_name_val,
      c.logo_url AS logo_url_val,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count_val,
      COALESCE(cws.score, 0)::double precision AS weekly_score_val,
      COALESCE(c.total_score, 0)::int AS total_score_val
    FROM public."crew" c
    LEFT JOIN public.crew_weekly_scores cws
      ON cws.crew_id = c.crew_id AND cws.week_id = v_week_id
  )
  SELECT
    rank_val::int,
    crew_id_val::int,
    crew_name_val::text,
    logo_url_val::text,
    member_count_val::int,
    weekly_score_val,
    total_score_val
  FROM ranked
  ORDER BY rank_val
  LIMIT COALESCE(fetch_limit, 100)
  OFFSET COALESCE(fetch_offset, 0);
END;
$$;

CREATE FUNCTION public.get_total_crew_rankings(
  fetch_limit int DEFAULT 100,
  fetch_offset int DEFAULT 0
) RETURNS TABLE (
  rank integer,
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  total_score integer
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM set_config('search_path', 'public', true);

  RETURN QUERY
  WITH ranked AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY COALESCE(c.total_score, 0) DESC, c.crew_name) AS rank_val,
      c.crew_id AS crew_id_val,
      c.crew_name AS crew_name_val,
      c.logo_url AS logo_url_val,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count_val,
      COALESCE(c.total_score, 0)::int AS total_score_val
    FROM public."crew" c
  )
  SELECT
    rank_val::int,
    crew_id_val::int,
    crew_name_val::text,
    logo_url_val::text,
    member_count_val::int,
    total_score_val
  FROM ranked
  ORDER BY rank_val
  LIMIT COALESCE(fetch_limit, 100)
  OFFSET COALESCE(fetch_offset, 0);
END;
$$;

CREATE FUNCTION public.get_my_crew_summary(
  p_auth_user_id uuid,
  target_week text DEFAULT NULL
) RETURNS TABLE (
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  weekly_score double precision,
  weekly_rank integer,
  total_score integer,
  total_rank integer
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id integer;
  v_crew_id integer;
  v_week_id text;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  SELECT user_id, crew_id INTO v_user_id, v_crew_id
  FROM public."user" WHERE auth_user_id = p_auth_user_id;
  IF v_user_id IS NULL OR v_crew_id IS NULL THEN
    RETURN;
  END IF;

  v_week_id := COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'));

  RETURN QUERY
  WITH weekly AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY COALESCE(cws.score, 0) DESC, COALESCE(c.total_score, 0) DESC, c.crew_name) AS rank_val,
      c.crew_id AS crew_id_val,
      c.crew_name AS crew_name_val,
      c.logo_url AS logo_url_val,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count_val,
      COALESCE(cws.score, 0)::double precision AS weekly_score_val,
      COALESCE(c.total_score, 0)::int AS total_score_val
    FROM public."crew" c
    LEFT JOIN public.crew_weekly_scores cws
      ON cws.crew_id = c.crew_id AND cws.week_id = v_week_id
  ), total AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY COALESCE(c.total_score, 0) DESC, c.crew_name) AS rank_val,
      c.crew_id AS crew_id_val
    FROM public."crew" c
  )
  SELECT
    w.crew_id_val::int,
    w.crew_name_val::text,
    w.logo_url_val::text,
    w.member_count_val::int,
    w.weekly_score_val,
    w.rank_val::int,
    w.total_score_val,
    t.rank_val::int
  FROM weekly w
  JOIN total t ON t.crew_id_val = w.crew_id_val
  WHERE w.crew_id_val = v_crew_id;
END;
$$;

CREATE FUNCTION public.get_crew_overview(
  p_crew_id integer,
  target_week text DEFAULT NULL
) RETURNS TABLE (
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  max_member integer,
  weekly_score double precision,
  weekly_rank integer,
  total_score integer,
  total_rank integer,
  introduction text
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_week_id text;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  v_week_id := COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'));

  RETURN QUERY
  WITH weekly AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY COALESCE(cws.score, 0) DESC, COALESCE(c.total_score, 0) DESC, c.crew_name) AS rank_val,
      c.crew_id AS crew_id_val,
      c.crew_name AS crew_name_val,
      c.logo_url AS logo_url_val,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count_val,
      COALESCE(c.max_member, 20)::int AS max_member_val,
      COALESCE(cws.score, 0)::double precision AS weekly_score_val,
      COALESCE(c.total_score, 0)::int AS total_score_val,
      COALESCE(c.introduction, '') AS introduction_val
    FROM public."crew" c
    LEFT JOIN public.crew_weekly_scores cws
      ON cws.crew_id = c.crew_id AND cws.week_id = v_week_id
  ), total AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY COALESCE(c.total_score, 0) DESC, c.crew_name) AS rank_val,
      c.crew_id AS crew_id_val
    FROM public."crew" c
  )
  SELECT
    w.crew_id_val::int,
    w.crew_name_val::text,
    w.logo_url_val::text,
    w.member_count_val::int,
    w.max_member_val::int,
    w.weekly_score_val,
    w.rank_val::int,
    w.total_score_val,
    t.rank_val::int,
    w.introduction_val::text
  FROM weekly w
  JOIN total t ON t.crew_id_val = w.crew_id_val
  WHERE w.crew_id_val = p_crew_id;
END;
$$;
