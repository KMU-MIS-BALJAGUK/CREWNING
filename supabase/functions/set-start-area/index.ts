import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.48.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const KAKAO_REST_API_KEY = Deno.env.get('KAKAO_REST_API_KEY');

const headers = { 'Content-Type': 'application/json' };

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !KAKAO_REST_API_KEY) {
  console.error('Missing one of SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, KAKAO_REST_API_KEY');
  throw new Error('Environment variables SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, KAKAO_REST_API_KEY are required.');
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
  }

  let body: any;
  try {
    body = await req.json();
  } catch (e) {
    return new Response(JSON.stringify({ error: 'invalid json' }), { status: 400, headers });
  }

  const { record_id, lat, lng, caller_auth_uid } = body ?? {};
  if (!record_id || typeof lat !== 'number' || typeof lng !== 'number' || !caller_auth_uid) {
    return new Response(JSON.stringify({ error: 'missing required fields: record_id, lat (number), lng (number), caller_auth_uid' }), { status: 400, headers });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  try {
    // resolve caller -> user_id
    const uRes = await supabase.from('user').select('user_id').eq('auth_user_id', caller_auth_uid).limit(1).maybeSingle();
    if (uRes.error) throw uRes.error;
    const userRow = uRes.data as any;
    if (!userRow) {
      return new Response(JSON.stringify({ error: 'caller user not found' }), { status: 404, headers });
    }
    const user_id = userRow.user_id as number;

    // verify running_record exists and belongs to user
    const rrRes = await supabase.from('running_record').select('record_id, user_id').eq('record_id', record_id).limit(1).maybeSingle();
    if (rrRes.error) throw rrRes.error;
    const rr = rrRes.data as any;
    if (!rr) return new Response(JSON.stringify({ error: 'running_record not found' }), { status: 404, headers });
    if (rr.user_id !== user_id) return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403, headers });

    // call Kakao coord2regioncode
    const kakaoUrl = `https://dapi.kakao.com/v2/local/geo/coord2regioncode.json?x=${encodeURIComponent(lng)}&y=${encodeURIComponent(lat)}`;
    const kakaoResp = await fetch(kakaoUrl, { headers: { Authorization: `KakaoAK ${KAKAO_REST_API_KEY}` } });
    if (!kakaoResp.ok) {
      const text = await kakaoResp.text();
      console.error('kakao error', kakaoResp.status, text);
      return new Response(JSON.stringify({ error: 'kakao failed', status: kakaoResp.status, body: text }), { status: 502, headers });
    }

    const kakaoJson = await kakaoResp.json();
    const doc = Array.isArray(kakaoJson?.documents) && kakaoJson.documents.length ? kakaoJson.documents[0] : null;
    const region2Raw = typeof doc?.region_2depth_name === 'string' ? doc.region_2depth_name : '';
    const start_area_name = region2Raw.trim() || null;

    // try to find matching area by name
    let start_area_id: number | null = null;
    if (start_area_name) {
      const aRes = await supabase
        .from('area')
        .select('area_id')
        .eq('name', start_area_name)
        .limit(1)
        .maybeSingle();
      if (aRes.error) throw aRes.error;
      const aRow = aRes.data as any;
      if (aRow) start_area_id = aRow.area_id as number;
    }

    // update running_record
    const updatePayload: any = { start_area_name };
    if (start_area_id !== null) updatePayload.start_area_id = start_area_id;

    const upRes = await supabase.from('running_record').update(updatePayload).eq('record_id', record_id);
    if (upRes.error) throw upRes.error;

    return new Response(JSON.stringify({ ok: true, start_area_id, start_area_name, kakao: doc ?? null }), { status: 200, headers });
  } catch (e: any) {
    console.error('error', e);
    return new Response(JSON.stringify({ error: e?.message ?? String(e) }), { status: 500, headers });
  }
});
