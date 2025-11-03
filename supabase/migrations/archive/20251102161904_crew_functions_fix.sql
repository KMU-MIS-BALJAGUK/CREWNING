-- Fix ambiguous week_id references by renaming local variables
CREATE OR REPLACE FUNCTION public.get_weekly_crew_rankings(
  target_week text DEFAULT NULL,
  fetch_limit int DEFAULT 100,
  fetch_offset int DEFAULT 0
) RETURNS TABLE (
  rank integer,
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  weekly_score numeric,
  total_score integer
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _week_id text;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  _week_id := COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'));
  RETURN QUERY
  WITH base AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COALESCE(c.max_member, 20) AS max_member,
      COALESCE(c.total_score, 0) AS total_score,
      COALESCE(cws.score, 0) AS weekly_score,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count
    FROM public."crew" c
    LEFT JOIN public.crew_weekly_scores cws
      ON cws.crew_id = c.crew_id AND cws.week_id = _week_id
  ), ranked AS (
    SELECT
      crew_id,
      crew_name,
      logo_url,
      member_count,
      weekly_score,
      total_score,
      ROW_NUMBER() OVER (ORDER BY weekly_score DESC, total_score DESC, crew_name) AS rnk
    FROM base
  )
  SELECT
    rnk, crew_id, crew_name, logo_url, member_count,
    weekly_score, total_score
  FROM ranked
  ORDER BY rnk
  LIMIT COALESCE(fetch_limit, 100)
  OFFSET COALESCE(fetch_offset, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_crew_summary(
  p_auth_user_id uuid,
  target_week text DEFAULT NULL
) RETURNS TABLE (
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  weekly_score numeric,
  weekly_rank integer,
  total_score integer,
  total_rank integer
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _week_id text;
  v_user_id integer;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  SELECT user_id INTO v_user_id FROM public."user" WHERE auth_user_id = p_auth_user_id;
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;
  _week_id := COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'));

  RETURN QUERY
  WITH crew_base AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COALESCE(c.total_score, 0) AS total_score,
      COALESCE(cws.score, 0) AS weekly_score,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count
    FROM public."crew" c
    LEFT JOIN public.crew_weekly_scores cws
      ON cws.crew_id = c.crew_id AND cws.week_id = _week_id
  ), weekly_ranked AS (
    SELECT
      cb.*, ROW_NUMBER() OVER (ORDER BY cb.weekly_score DESC, cb.total_score DESC, cb.crew_name) AS weekly_rank
    FROM crew_base cb
  ), total_ranked AS (
    SELECT
      cb.*, ROW_NUMBER() OVER (ORDER BY cb.total_score DESC, cb.crew_name) AS total_rank
    FROM crew_base cb
  )
  SELECT
    wr.crew_id,
    wr.crew_name,
    wr.logo_url,
    wr.member_count,
    wr.weekly_score,
    wr.weekly_rank,
    tr.total_score,
    tr.total_rank
  FROM weekly_ranked wr
  JOIN total_ranked tr USING (crew_id, crew_name, logo_url, member_count, weekly_score, total_score)
  WHERE wr.crew_id = (SELECT crew_id FROM public."user" WHERE user_id = v_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_crew_overview(
  p_crew_id integer,
  target_week text DEFAULT NULL
) RETURNS TABLE (
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  max_member integer,
  weekly_score numeric,
  weekly_rank integer,
  total_score integer,
  total_rank integer,
  introduction text
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _week_id text;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  _week_id := COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'));
  RETURN QUERY
  WITH crew_base AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COALESCE(c.total_score, 0) AS total_score,
      COALESCE(cws.score, 0) AS weekly_score,
      COALESCE(c.max_member, 20) AS max_member,
      COALESCE(c.introduction, '') AS introduction,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count
    FROM public."crew" c
    LEFT JOIN public.crew_weekly_scores cws
      ON cws.crew_id = c.crew_id AND cws.week_id = _week_id
  ), weekly_ranked AS (
    SELECT cb.*, ROW_NUMBER() OVER (ORDER BY cb.weekly_score DESC, cb.total_score DESC, cb.crew_name) AS weekly_rank
    FROM crew_base cb
  ), total_ranked AS (
    SELECT cb.*, ROW_NUMBER() OVER (ORDER BY cb.total_score DESC, cb.crew_name) AS total_rank
    FROM crew_base cb
  )
  SELECT
    wr.crew_id,
    wr.crew_name,
    wr.logo_url,
    wr.member_count,
    wr.max_member,
    wr.weekly_score,
    wr.weekly_rank,
    tr.total_score,
    tr.total_rank,
    wr.introduction
  FROM weekly_ranked wr
  JOIN total_ranked tr USING (crew_id, crew_name, logo_url, member_count, weekly_score, total_score, max_member, introduction)
  WHERE wr.crew_id = p_crew_id;
END;
$$;
