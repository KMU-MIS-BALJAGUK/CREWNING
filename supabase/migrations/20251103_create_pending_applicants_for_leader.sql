-- Migration: create get_pending_applicants_for_leader RPC
-- Drops existing function if present, then creates a SECURITY DEFINER function

DROP FUNCTION IF EXISTS public.get_pending_applicants_for_leader(integer, uuid);

CREATE FUNCTION public.get_pending_applicants_for_leader(
  p_crew_id integer,
  p_auth_user_id uuid
)
RETURNS TABLE(
  register_id int,
  created_at timestamptz,
  introduction text,
  applicant jsonb
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT r.register_id,
         r.created_at,
         r.introduction,
         jsonb_build_object('user_id', u.user_id, 'name', u.name, 'auth_user_id', u.auth_user_id::text) AS applicant
  FROM public.register r
  JOIN public."user" u ON u.user_id = r.user_id
  WHERE r.crew_id = p_crew_id
    AND r.status = 'PENDING'
    AND EXISTS (
      SELECT 1
      FROM public.crew c
      JOIN public."user" lu ON lu.user_id = c.leader_user_id
      WHERE c.crew_id = p_crew_id
        AND lu.auth_user_id::text = p_auth_user_id::text
    );
$$;

-- Make available to authenticated role
GRANT EXECUTE ON FUNCTION public.get_pending_applicants_for_leader(integer, uuid) TO authenticated;
