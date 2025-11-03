drop function if exists public.create_crew(
  uuid,
  text,
  text,
  integer[],
  text
);

create or replace function public.create_crew(
  p_auth_user_id uuid,
  p_crew_name text,
  p_logo_url text,
  p_area_ids integer[],
  p_introduction text default null
)
returns table (
  crew_id integer,
  crew_name text,
  logo_url text,
  member_count integer,
  max_member integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user record;
  v_crew_id integer;
  v_area_id integer;
  v_limit integer;
  i integer;
begin
  perform set_config('search_path', 'public', true);

  select u.user_id, u.name, u.crew_id
  into v_user
  from public."user" u
  where u.auth_user_id = p_auth_user_id;

  if v_user.user_id is null then
    raise exception 'User not found';
  end if;

  if v_user.crew_id is not null then
    raise exception '이미 크루에 소속되어 있습니다.';
  end if;

  insert into public."crew" (
    crew_name,
    leader_name,
    leader_user_id,
    max_member,
    logo_url,
    introduction
  )
  values (
    p_crew_name,
    v_user.name,
    v_user.user_id,
    20,
    p_logo_url,
    p_introduction
  )
  returning public."crew".crew_id
  into v_crew_id;

  if p_area_ids is not null and array_length(p_area_ids, 1) >= 1 then
    update public."crew"
    set area_id = p_area_ids[1]
    where public."crew".crew_id = v_crew_id;
  end if;

  if p_area_ids is not null then
    v_limit := least(array_length(p_area_ids, 1), 3);
    if v_limit is not null then
      for i in 1..v_limit loop
        v_area_id := p_area_ids[i];
        if v_area_id is not null then
          insert into public.crew_area_map (crew_id, area_id)
          values (v_crew_id, v_area_id)
          on conflict on constraint crew_area_map_pkey do nothing;
        end if;
      end loop;
    end if;
  end if;

  update public."user"
  set crew_id = v_crew_id
  where public."user".user_id = v_user.user_id;

  return query
  select
    c.crew_id,
    c.crew_name,
    c.logo_url,
    (
      select count(*)
      from public."user" u
      where u.crew_id = c.crew_id
    ) as member_count,
    coalesce(c.max_member, 20) as max_member
  from public."crew" c
  where c.crew_id = v_crew_id;
end;
$$;
