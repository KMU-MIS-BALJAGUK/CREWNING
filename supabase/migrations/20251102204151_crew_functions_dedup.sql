DROP FUNCTION IF EXISTS public.get_weekly_crew_rankings(text,int,int);
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
  total_score integer
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH agg AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COALESCE(c.total_score, 0)::int AS total_score,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count,
      COALESCE(
        (SELECT score FROM public.crew_weekly_scores cws
          WHERE cws.crew_id = c.crew_id
            AND cws.week_id = COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'))
          ORDER BY cws.id DESC
          LIMIT 1),
        0
      )::double precision AS weekly_score
    FROM public."crew" c
  ), ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY weekly_score DESC, total_score DESC, crew_name) AS rnk
    FROM agg
  )
  SELECT
    rnk::int,
    crew_id::int,
    crew_name::text,
    logo_url::text,
    member_count::int,
    weekly_score,
    total_score
  FROM ranked
  ORDER BY rnk
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
  total_score integer,
  total_rank integer
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH me AS (
    SELECT user_id, crew_id FROM public."user" WHERE auth_user_id = p_auth_user_id
  ), agg AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count,
      COALESCE(
        (SELECT score FROM public.crew_weekly_scores cws
          WHERE cws.crew_id = c.crew_id
            AND cws.week_id = COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'))
          ORDER BY cws.id DESC
          LIMIT 1),
        0
      )::double precision AS weekly_score,
      COALESCE(c.total_score, 0)::int AS total_score
    FROM public."crew" c
  ), weekly_ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY weekly_score DESC, total_score DESC, crew_name) AS weekly_rank
    FROM agg
  ), total_ranked AS (
    SELECT crew_id AS crew_id_tr, ROW_NUMBER() OVER (ORDER BY total_score DESC, crew_name) AS total_rank
    FROM agg
  )
  SELECT
    wr.crew_id::int,
    wr.crew_name::text,
    wr.logo_url::text,
    wr.member_count::int,
    wr.weekly_score,
    wr.weekly_rank::int,
    wr.total_score,
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
  total_score integer,
  total_rank integer,
  introduction text
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH agg AS (
    SELECT
      c.crew_id,
      c.crew_name,
      c.logo_url,
      COALESCE(c.max_member, 20)::int AS max_member,
      COALESCE(c.introduction, '') AS introduction,
      (SELECT COUNT(*) FROM public."user" u WHERE u.crew_id = c.crew_id) AS member_count,
      COALESCE(
        (SELECT score FROM public.crew_weekly_scores cws
          WHERE cws.crew_id = c.crew_id
            AND cws.week_id = COALESCE(target_week, to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW'))
          ORDER BY cws.id DESC
          LIMIT 1),
        0
      )::double precision AS weekly_score,
      COALESCE(c.total_score, 0)::int AS total_score
    FROM public."crew" c
  ), weekly_ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY weekly_score DESC, total_score DESC, crew_name) AS weekly_rank
    FROM agg
  ), total_ranked AS (
    SELECT crew_id AS crew_id_tr, ROW_NUMBER() OVER (ORDER BY total_score DESC, crew_name) AS total_rank
    FROM agg
  )
  SELECT
    wr.crew_id::int,
    wr.crew_name::text,
    wr.logo_url::text,
    wr.member_count::int,
    wr.max_member::int,
    wr.weekly_score,
    wr.weekly_rank::int,
    wr.total_score,
    tr.total_rank::int,
    wr.introduction::text
  FROM weekly_ranked wr
  JOIN total_ranked tr ON tr.crew_id_tr = wr.crew_id
  WHERE wr.crew_id = p_crew_id;
$$;
