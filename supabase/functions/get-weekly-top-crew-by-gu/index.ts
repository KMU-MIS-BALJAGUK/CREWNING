import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.48.0';
import { corsHeaders } from '../_shared/cors.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 },
    );
  }

  try {
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: areas, error: areasError } = await adminClient
      .from('area')
      .select('area_id, name')
      .order('area_id');

    if (areasError) throw areasError;

    const results: Array<Record<string, unknown>> = [];

    for (const area of areas ?? []) {
      const { data: ranking, error: rankingError } = await adminClient.rpc(
        'get_weekly_crew_rankings_by_area',
        {
          p_area_name: area.name,
          fetch_limit: 1,
          fetch_offset: 0,
        },
      );

      if (rankingError) throw rankingError;

      const top = Array.isArray(ranking) && ranking.length > 0 ? ranking[0] : null;
      if (top && Number(top.weekly_score ?? 0) > 0) {
        results.push({
          area_id: Number(area.area_id ?? 0),
          gu_name: area.name,
          crew_id: Number(top.crew_id ?? 0),
          crew_name: top.crew_name ?? null,
          logo_url: top.logo_url ?? null,
          member_count: Number(top.member_count ?? 0),
          weekly_score: Number(top.weekly_score ?? 0),
          total_score: Number(top.total_score ?? 0),
          rank: Number(top.rank ?? 1),
        });
      }
    }
    results.sort((a, b) => (String(a.area_name ?? '')).localeCompare(String(b.area_name ?? '')));

    return new Response(JSON.stringify(results), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
