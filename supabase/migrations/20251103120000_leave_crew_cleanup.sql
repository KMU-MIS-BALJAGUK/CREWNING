-- Server-side leave_crew function
-- If the caller is the leader and other members remain, raises an exception.
-- If the caller is the leader and the only member, remove the user from crew and delete the crew (cascade will remove mappings).
-- Otherwise, simply remove the user's crew_id.

DROP FUNCTION IF EXISTS public.leave_crew(uuid);

CREATE FUNCTION public.leave_crew(
  p_auth_user_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id integer;
  v_crew_id integer;
  v_leader_user_id integer;
  v_member_count integer;
BEGIN
  PERFORM set_config('search_path', 'public', true);

  SELECT user_id, crew_id INTO v_user_id, v_crew_id
  FROM public."user"
  WHERE auth_user_id = p_auth_user_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF v_crew_id IS NULL THEN
    -- Not in a crew, nothing to do
    RETURN;
  END IF;

  SELECT leader_user_id INTO v_leader_user_id FROM public."crew" WHERE crew_id = v_crew_id;
  SELECT COUNT(*) INTO v_member_count FROM public."user" WHERE crew_id = v_crew_id;

  IF v_leader_user_id = v_user_id THEN
    IF v_member_count > 1 THEN
      RAISE EXCEPTION '리더는 멤버가 남아있을 때 탈퇴할 수 없습니다.';
    ELSE
      -- Leader is the only member: remove user and delete crew
      UPDATE public."user" SET crew_id = NULL WHERE user_id = v_user_id;
      DELETE FROM public."crew" WHERE crew_id = v_crew_id;
      RETURN;
    END IF;
  ELSE
    -- Normal member: simply remove association
    UPDATE public."user" SET crew_id = NULL WHERE user_id = v_user_id;
    RETURN;
  END IF;
END;
$$;
