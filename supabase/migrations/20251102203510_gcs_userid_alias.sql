DROP FUNCTION IF EXISTS public.get_crew_members(integer);

CREATE FUNCTION public.get_crew_members(
  p_crew_id integer
) RETURNS TABLE (
  rank integer,
  user_id integer,
  user_name text,
  is_leader boolean,
  weekly_score integer,
  total_score integer
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM set_config('search_path', 'public', true);
  RETURN QUERY
  WITH members AS (
    SELECT
      u.user_id AS user_id_val,
      u.name AS user_name_val,
      u.weekly_score AS weekly_score_val,
      u.total_score AS total_score_val,
      (u.user_id = c.leader_user_id) AS is_leader_val
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
    weekly_score_val::int AS weekly_score,
    total_score_val::int AS total_score
  FROM ranked
  ORDER BY CASE WHEN is_leader_val THEN 0 ELSE 1 END, rank;
END;
$$;
