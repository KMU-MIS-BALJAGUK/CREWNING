-- Migration: approve/reject applicant RPCs
-- Creates two SECURITY DEFINER functions: approve_application and reject_application
-- They verify the caller is the crew leader (by auth_user_id) and then update register/user accordingly.

DROP FUNCTION IF EXISTS public.approve_application(integer, uuid);
DROP FUNCTION IF EXISTS public.reject_application(integer, uuid);

CREATE FUNCTION public.approve_application(
  p_register_id integer,
  p_auth_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  r RECORD;
  leader_user_id integer;
  caller_user_id integer;
BEGIN
  -- Lock the register row
  SELECT * INTO r FROM public.register WHERE register_id = p_register_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Register % not found', p_register_id;
  END IF;

  -- Find crew leader
  SELECT c.leader_user_id INTO leader_user_id FROM public.crew c WHERE c.crew_id = r.crew_id;
  IF leader_user_id IS NULL THEN
    RAISE EXCEPTION 'Crew % has no leader', r.crew_id;
  END IF;

  -- Map caller auth uid -> user_id
  SELECT user_id INTO caller_user_id FROM public."user" WHERE auth_user_id::text = p_auth_user_id::text;
  IF caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Caller not mapped to internal user';
  END IF;

  -- Authorization: must be leader
  IF caller_user_id <> leader_user_id THEN
    RAISE EXCEPTION '권한 없음: 리더만 승인 가능';
  END IF;

  -- Only allow approving PENDING
  IF r.status IS DISTINCT FROM 'PENDING' THEN
    RAISE EXCEPTION 'Register % 상태가 % 여서 승인할 수 없습니다', p_register_id, r.status;
  END IF;

  -- Set user's crew_id
  UPDATE public."user" SET crew_id = r.crew_id WHERE user_id = r.user_id;

  -- Update register status
  UPDATE public.register SET status = 'APPROVED' WHERE register_id = p_register_id;

  RETURN jsonb_build_object('ok', true, 'register_id', p_register_id, 'user_id', r.user_id, 'crew_id', r.crew_id);
END;
$$;

CREATE FUNCTION public.reject_application(
  p_register_id integer,
  p_auth_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  r RECORD;
  leader_user_id integer;
  caller_user_id integer;
BEGIN
  SELECT * INTO r FROM public.register WHERE register_id = p_register_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Register % not found', p_register_id;
  END IF;

  SELECT c.leader_user_id INTO leader_user_id FROM public.crew c WHERE c.crew_id = r.crew_id;
  IF leader_user_id IS NULL THEN
    RAISE EXCEPTION 'Crew % has no leader', r.crew_id;
  END IF;

  SELECT user_id INTO caller_user_id FROM public."user" WHERE auth_user_id::text = p_auth_user_id::text;
  IF caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Caller not mapped to internal user';
  END IF;

  IF caller_user_id <> leader_user_id THEN
    RAISE EXCEPTION '권한 없음: 리더만 거절 가능';
  END IF;

  IF r.status IS DISTINCT FROM 'PENDING' THEN
    RAISE EXCEPTION 'Register % 상태가 % 여서 거절할 수 없습니다', p_register_id, r.status;
  END IF;

  UPDATE public.register SET status = 'REJECTED' WHERE register_id = p_register_id;

  RETURN jsonb_build_object('ok', true, 'register_id', p_register_id);
END;
$$;

-- grant execute to authenticated role so clients can call it
GRANT EXECUTE ON FUNCTION public.approve_application(integer, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_application(integer, uuid) TO authenticated;
