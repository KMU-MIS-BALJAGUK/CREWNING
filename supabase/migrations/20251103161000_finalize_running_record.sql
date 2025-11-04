DROP FUNCTION IF EXISTS public.finalize_running_record(uuid, integer, integer, integer);
DROP FUNCTION IF EXISTS public.finalize_running_record(integer, numeric, numeric, uuid);

CREATE FUNCTION public.finalize_running_record(
  _caller_auth_uid uuid,
  _record_id integer,
  _distance_m integer DEFAULT NULL,
  _duration_s integer DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_record public.running_record%ROWTYPE;
  v_owner public."user"%ROWTYPE;
  v_distance_m integer;
  v_distance_km numeric;
  v_elapsed_s integer;
  v_points integer;
  v_base_points numeric;
  v_score numeric;
  v_new_weekly integer;
  v_new_total integer;
  v_week_id text;
  v_pace_minutes integer;
  v_pace_seconds integer;
  v_total_seconds integer;
  v_diff_seconds integer;
  v_pace_multiplier numeric;
BEGIN
  -- Lock the running record row so concurrent finalizations do not race.
  SELECT * INTO v_record
  FROM public.running_record
  WHERE record_id = _record_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'running record not found';
  END IF;

  -- Load owner information and verify the caller.
  SELECT * INTO v_owner
  FROM public."user"
  WHERE user_id = v_record.user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'runner user not found';
  END IF;

  IF v_owner.auth_user_id::text IS DISTINCT FROM _caller_auth_uid::text THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- Decide distance (meters) based on payload or stored value.
  IF _distance_m IS NOT NULL THEN
    v_distance_m := GREATEST(_distance_m, 0);
  ELSIF v_record.distance IS NOT NULL THEN
    v_distance_m := GREATEST(0, (v_record.distance * 1000)::int);
  ELSE
    v_distance_m := 0;
  END IF;
  v_distance_km := v_distance_m::numeric / 1000;

  -- Decide elapsed seconds similarly.
  IF _duration_s IS NOT NULL THEN
    v_elapsed_s := GREATEST(_duration_s, 0);
  ELSIF v_record.elapsed_seconds IS NOT NULL THEN
    v_elapsed_s := GREATEST(v_record.elapsed_seconds, 0);
  ELSE
    v_elapsed_s := 0;
  END IF;

  -- Compute score based on distance and pace.
  v_base_points := 0;
  v_score := 0;
  v_points := 0;
  v_pace_multiplier := 1;

  IF v_distance_m >= 100 THEN
    v_base_points := v_distance_m::numeric / 100;
    IF v_record.pace IS NOT NULL THEN
      v_pace_minutes := floor(v_record.pace)::int;
      v_pace_seconds := round((v_record.pace - v_pace_minutes) * 100)::int;
      v_pace_seconds := GREATEST(0, LEAST(59, v_pace_seconds));
      v_total_seconds := (v_pace_minutes * 60) + v_pace_seconds;
      v_diff_seconds := 360 - v_total_seconds;
      v_pace_multiplier := 1 + (v_diff_seconds / 10.0) * 0.1;
      IF v_pace_multiplier < 0.5 THEN
        v_pace_multiplier := 0.5;
      END IF;
    END IF;
    v_score := v_base_points * v_pace_multiplier;
  ELSE
    v_score := 0;
  END IF;

  v_points := GREATEST(floor(v_score)::int, 0);

  -- Update running_record with sanitized values.
  UPDATE public.running_record
  SET
    distance = v_distance_km::real,
    elapsed_seconds = v_elapsed_s,
    end_time = COALESCE(v_record.end_time, now()),
    score = v_score,
    pace = CASE
      WHEN v_distance_km > 0 THEN ROUND((v_elapsed_s::numeric / 60) / NULLIF(v_distance_km, 0), 2)
      ELSE v_record.pace
    END
  WHERE record_id = _record_id;

  v_new_weekly := COALESCE(v_owner.weekly_score, 0) + v_points;
  v_new_total := COALESCE(v_owner.total_score, 0) + v_points;

  UPDATE public."user"
  SET weekly_score = v_new_weekly,
      total_score = v_new_total
  WHERE user_id = v_owner.user_id;

  -- Update crew aggregate if the user belongs to a crew.
  IF v_owner.crew_id IS NOT NULL AND v_points <> 0 THEN
    v_week_id := to_char((now() AT TIME ZONE 'Asia/Seoul')::date, 'IYYY-IW');
    INSERT INTO public.crew_weekly_scores (crew_id, week_id, score)
    VALUES (v_owner.crew_id, v_week_id, v_points)
    ON CONFLICT (crew_id, week_id) DO UPDATE
    SET score = public.crew_weekly_scores.score + EXCLUDED.score;
  END IF;

  RETURN jsonb_build_object(
    'points_awarded', v_score,
    'distance_m', v_distance_m,
    'elapsed_s', v_elapsed_s,
    'weekly_score', v_new_weekly,
    'total_score', v_new_total
  );
END;
$$;
