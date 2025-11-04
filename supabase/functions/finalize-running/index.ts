import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.48.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

const headers = { 'Content-Type': 'application/json' };

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  throw new Error('Environment variables SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.');
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
  }

  let body: any;
  try {
    body = await req.json();
  } catch (e) {
    console.error('invalid json', e);
    return new Response(JSON.stringify({ error: 'invalid json' }), { status: 400, headers });
  }

  const { record_id, distance_m, elapsed_s, duration_s, caller_auth_uid } = body ?? {};
  if (!record_id || (distance_m == null && elapsed_s == null && duration_s == null) || !caller_auth_uid) {
    console.error('missing required fields', { record_id, distance_m, elapsed_s, duration_s, caller_auth_uid });
    return new Response(JSON.stringify({ error: 'missing required fields: record_id, caller_auth_uid, and at least one of distance_m or elapsed_s/duration_s' }), { status: 400, headers });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  try {
    console.log('finalize-running called', { record_id, distance_m, elapsed_s, duration_s, caller_auth_uid });

    // The DB finalize_running_record expects parameters named like:
    // (_caller_auth_uid, _distance_m, _duration_s, _record_id)
    // Map incoming fields accordingly. Accept either elapsed_s or duration_s from caller.
    const rpcParams: Record<string, any> = {};
    rpcParams['_caller_auth_uid'] = caller_auth_uid;
    if (distance_m != null) rpcParams['_distance_m'] = Number(distance_m);

    // prefer explicit duration_s if provided, otherwise use elapsed_s
    const dur = duration_s ?? elapsed_s;
    if (dur != null) rpcParams['_duration_s'] = Number(dur);

    // include record id last (ordering is less important when using named params, but keep for clarity)
    rpcParams['_record_id'] = Number(record_id);

    const { data, error } = await supabase.rpc('finalize_running_record', rpcParams);

    if (error) {
      console.error('rpc finalize_running_record error', error);
      return new Response(JSON.stringify({ error: error.message, details: error }), { status: 500, headers });
    }

    console.log('rpc result', data);
    return new Response(JSON.stringify({ ok: true, result: data }), { status: 200, headers });
  } catch (e: any) {
    console.error('unexpected error', e);
    return new Response(JSON.stringify({ error: e?.message ?? String(e) }), { status: 500, headers });
  }
});
