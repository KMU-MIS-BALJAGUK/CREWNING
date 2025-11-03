import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars');
}

const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false }});

serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
    }

    const authHeader = req.headers.get('authorization') || '';
    const token = authHeader.replace(/^Bearer\s+/i, '');
    if (!token) return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 });

    // Verify token -> get auth user
    const { data: userData, error: userErr } = await sb.auth.getUser(token);
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 });
    }
    const authUser = userData.user;

    const body = await req.json();
    const crewId = body?.crew_id;
    const introduction = body?.introduction ?? body?.message ?? null;
    if (!crewId) return new Response(JSON.stringify({ error: 'crew_id required' }), { status: 400 });

    // lookup local user mapping
    const { data: mapped, error: mapErr } = await sb.from('user').select('user_id,email').eq('auth_user_id', authUser.id).maybeSingle();

    let localUserId: number | null = null;

    if (mapErr) {
      return new Response(JSON.stringify({ error: 'db error', details: mapErr.message }), { status: 500 });
    }

    if (mapped && (mapped as any).user_id != null) {
      localUserId = (mapped as any).user_id as number;
    } else {
      // create local user mapping using next user_id
      const { data: lastRow } = await sb.from('user').select('user_id').order('user_id', { ascending: false }).limit(1).maybeSingle();
      const nextId = lastRow && (lastRow as any).user_id ? (lastRow as any).user_id + 1 : 1;
      const email = (authUser.email) ? authUser.email : `${authUser.id}@noemail.invalid`;
      const name = email.split('@')[0] || 'Guest';
      const { data: inserted, error: insErr } = await sb.from('user').insert({ user_id: nextId, name, email, auth_user_id: authUser.id }).select().maybeSingle();
      if (insErr) {
        return new Response(JSON.stringify({ error: 'failed to create local user', details: insErr.message }), { status: 500 });
      }
      localUserId = (inserted as any).user_id as number;
    }

    // check duplicate pending
    const { data: existing } = await sb.from('register').select('register_id').eq('user_id', localUserId).eq('status', 'pending').limit(1);
    if (existing && Array.isArray(existing) && existing.length > 0) {
      return new Response(JSON.stringify({ error: 'ALREADY_PENDING' }), { status: 409 });
    }

    // insert into register
    const insertRecord: any = { crew_id: crewId, user_id: localUserId, status: 'pending' };
    if (introduction) insertRecord.introduction = introduction;

    const { data: reg, error: regErr } = await sb.from('register').insert(insertRecord).select().maybeSingle();
    if (regErr) {
      return new Response(JSON.stringify({ error: 'insert failed', details: regErr.message }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true, register: reg }), { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: 'internal', details: (e as Error).message }), { status: 500 });
  }
});
