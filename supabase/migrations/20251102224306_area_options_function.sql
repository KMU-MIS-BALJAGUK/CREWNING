-- Create function to expose area options regardless of RLS
create or replace function public.get_area_options()
returns table (
  area_id integer,
  name text
)
language sql
security definer
set search_path = public
as $$
  select a.area_id, a.name
  from public.area as a
  order by a.name;
$$;

grant execute on function public.get_area_options() to authenticated, anon;
