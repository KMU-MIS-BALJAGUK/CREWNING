-- Add leader-management functions and enhance get_crew_members to include is_myself

DROP FUNCTION IF EXISTS public.get_crew_members(integer, uuid);

CREATE FUNCTION public.get_crew_members(
  p_crew_id integer,
  p_auth_user_id uuid DEFAULT NULL
) RETURNS TABLE (
  rank integer,
  user_id integer,
  user_name text,
  is_leader boolean,
  is_myself boolean,
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
END;
$$;

-- Kick member (leader only)
DROP FUNCTION IF EXISTS public.kick_member(integer, integer, uuid);
CREATE FUNCTION public.kick_member(
  p_crew_id integer,
  p_target_user_id integer,
  p_auth_user_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_user_id integer;
  v_leader_user_id integer;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  SELECT user_id INTO v_caller_user_id FROM public."user" WHERE auth_user_id = p_auth_user_id;
  SELECT leader_user_id INTO v_leader_user_id FROM public."crew" WHERE crew_id = p_crew_id;

  IF v_caller_user_id IS NULL OR v_leader_user_id IS NULL OR v_caller_user_id <> v_leader_user_id THEN
    RAISE EXCEPTION '권한이 없습니다.';
  END IF;

  IF p_target_user_id = v_leader_user_id THEN
    RAISE EXCEPTION '리더는 방출할 수 없습니다.';
  END IF;

  UPDATE public."user"
  SET crew_id = NULL
  WHERE user_id = p_target_user_id
    AND crew_id = p_crew_id;
END;
$$;

-- Delegate leadership to another member (leader only)
DROP FUNCTION IF EXISTS public.delegate_leader(integer, integer, uuid);
CREATE FUNCTION public.delegate_leader(
  p_crew_id integer,
  p_new_leader_user_id integer,
  p_auth_user_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_user_id integer;
  v_current_leader integer;
  v_exists integer;
BEGIN
  PERFORM set_config('search_path', 'public', true);
  SELECT user_id INTO v_caller_user_id FROM public."user" WHERE auth_user_id = p_auth_user_id;
  SELECT leader_user_id INTO v_current_leader FROM public."crew" WHERE crew_id = p_crew_id;

  IF v_caller_user_id IS NULL OR v_current_leader IS NULL OR v_caller_user_id <> v_current_leader THEN
    RAISE EXCEPTION '권한이 없습니다.';
  END IF;

  SELECT 1 INTO v_exists FROM public."user" WHERE user_id = p_new_leader_user_id AND crew_id = p_crew_id;
  IF v_exists IS NULL THEN
    RAISE EXCEPTION '해당 사용자는 크루 멤버가 아닙니다.';
  END IF;

  UPDATE public."crew"
  SET leader_user_id = p_new_leader_user_id
  WHERE crew_id = p_crew_id;
END;
$$;
