// Basic Supabase Edge Function used for connectivity tests.
Deno.serve((_req) =>
  new Response(
    JSON.stringify({ message: 'Hello from Supabase Edge Function!' }),
    {
      headers: {
        'Content-Type': 'application/json',
      },
    },
  ),
);
