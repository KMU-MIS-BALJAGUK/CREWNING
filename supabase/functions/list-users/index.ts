// Edge Function to fetch every user record from the Supabase table `user`.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.48.0';

const supabaseUrl = De2no.env.get('SUPABASE_URL');
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

const headers = {
  'Content-Type': 'application/json',
};

if (!supabaseUrl || !supabaseServiceRoleKey) {
  console.error(
    'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables.',
  );

  throw new Error(
    'Edge Function requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY to be configured.',
  );
}

Deno.serve(async () => {
  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
    },
  });

  const { data, error } = await supabase.from('user').select('*');

  if (error) {
    console.error('Failed to fetch users:', error);

    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers,
    });
  }

  return new Response(JSON.stringify({ users: data ?? [] }), {
    status: 200,
    headers,
  });
});
