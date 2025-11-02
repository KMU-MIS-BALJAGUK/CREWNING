import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.42.2';

const supabaseUrl = Deno.env.get('EDGE_SUPABASE_URL');
const serviceRoleKey = Deno.env.get('EDGE_SERVICE_ROLE_KEY');

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error('Missing EDGE_SUPABASE_URL or EDGE_SERVICE_ROLE_KEY env vars');
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

export default async function handler(_: Request): Promise<Response> {
  const { data, error } = await supabase
    .from('user')
    .update({ weekly_score: 0 })
    .neq('weekly_score', 0)
    .select('user_id');

  if (error) {
    console.error('reset-weekly: failed', error);
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(
    JSON.stringify({ success: true, affected_users: data?.length ?? 0 }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
}
