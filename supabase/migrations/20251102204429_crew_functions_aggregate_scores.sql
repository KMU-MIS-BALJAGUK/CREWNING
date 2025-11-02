DROP FUNCTION IF EXISTS public.get_weekly_crew_rankings(text,int,int);
DROP FUNCTION IF EXISTS public.get_total_crew_rankings(int,int);
DROP FUNCTION IF EXISTS public.get_my_crew_summary(uuid,text);
DROP FUNCTION IF EXISTS public.get_crew_overview(integer,text);

CREATE FUNCTION public.get_weekly_crew_rankings(
  target_week text DEFAULT NULL,
  fetch_limit integer DEFAULT 100,
  fetch_offset integer DEFAULT 0
) RETURNS TABLE (
  rank integer,
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  weekly_score double precision,
  total_score double precision
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH aggregated AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COUNT(u.user_id) AS member_count,
      COALESCE(SUM(u.weekly_score), 0)::double precision AS weekly_sum,
      COALESCE(SUM(u.total_score), 0)::double precision AS total_sum
    FROM public."crew" c
    LEFT JOIN public."user" u ON u.crew_id = c.crew_id
    GROUP BY c.crew_id, c.crew_name, c.logo_url
  ), ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY weekly_sum DESC, total_sum DESC, crew_name) AS rank_val
    FROM aggregated
  )
  SELECT
    rank_val::int,
    crew_id::int,
    crew_name::text,
    logo_url::text,
    member_count::int,
    weekly_sum,
    total_sum
  FROM ranked
  ORDER BY rank_val
  LIMIT COALESCE(fetch_limit, 100)
  OFFSET COALESCE(fetch_offset, 0);
$$;

CREATE FUNCTION public.get_total_crew_rankings(
  fetch_limit integer DEFAULT 100,
  fetch_offset integer DEFAULT 0
) RETURNS TABLE (
  rank integer,
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  total_score double precision
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH aggregated AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COUNT(u.user_id) AS member_count,
      COALESCE(SUM(u.total_score), 0)::double precision AS total_sum
    FROM public."crew" c
    LEFT JOIN public."user" u ON u.crew_id = c.crew_id
    GROUP BY c.crew_id, c.crew_name, c.logo_url
  ), ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY total_sum DESC, crew_name) AS rank_val
    FROM aggregated
  )
  SELECT
    rank_val::int,
    crew_id::int,
    crew_name::text,
    logo_url::text,
    member_count::int,
    total_sum
  FROM ranked
  ORDER BY rank_val
  LIMIT COALESCE(fetch_limit, 100)
  OFFSET COALESCE(fetch_offset, 0);
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
  total_score double precision,
  total_rank integer
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH me AS (
    SELECT crew_id FROM public."user" WHERE auth_user_id = p_auth_user_id
  ), aggregated AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COUNT(u.user_id) AS member_count,
      COALESCE(SUM(u.weekly_score), 0)::double precision AS weekly_sum,
      COALESCE(SUM(u.total_score), 0)::double precision AS total_sum
    FROM public."crew" c
    LEFT JOIN public."user" u ON u.crew_id = c.crew_id
    GROUP BY c.crew_id, c.crew_name, c.logo_url
  ), weekly_ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY weekly_sum DESC, total_sum DESC, crew_name) AS weekly_rank
    FROM aggregated
  ), total_ranked AS (
    SELECT crew_id AS crew_id_tr, ROW_NUMBER() OVER (ORDER BY total_sum DESC, crew_name) AS total_rank
    FROM aggregated
  )
  SELECT
    wr.crew_id::int,
    wr.crew_name::text,
    wr.logo_url::text,
    wr.member_count::int,
    wr.weekly_sum,
    wr.weekly_rank::int,
    wr.total_sum,
    tr.total_rank::int
  FROM weekly_ranked wr
  JOIN total_ranked tr ON tr.crew_id_tr = wr.crew_id
  JOIN me ON me.crew_id = wr.crew_id;
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
  total_score double precision,
  total_rank integer,
  introduction text
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH aggregated AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COALESCE(c.max_member, 20)::int AS max_member,
      COALESCE(c.introduction, '') AS introduction,
      COUNT(u.user_id) AS member_count,
      COALESCE(SUM(u.weekly_score), 0)::double precision AS weekly_sum,
      COALESCE(SUM(u.total_score), 0)::double precision AS total_sum
    FROM public."crew" c
    LEFT JOIN public."user" u ON u.crew_id = c.crew_id
    GROUP BY c.crew_id, c.crew_name, c.logo_url, c.max_member, c.introduction
  ), weekly_ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY weekly_sum DESC, total_sum DESC, crew_name) AS weekly_rank
    FROM aggregated
  ), total_ranked AS (
    SELECT crew_id AS crew_id_tr, ROW_NUMBER() OVER (ORDER BY total_sum DESC, crew_name) AS total_rank
    FROM aggregated
  )
  SELECT
    wr.crew_id::int,
    wr.crew_name::text,
    wr.logo_url::text,
    wr.member_count::int,
    wr.max_member::int,
    wr.weekly_sum,
    wr.weekly_rank::int,
    wr.total_sum,
    tr.total_rank::int,
    wr.introduction::text
  FROM weekly_ranked wr
  JOIN total_ranked tr ON tr.crew_id_tr = wr.crew_id
  WHERE wr.crew_id = p_crew_id;
$$;
