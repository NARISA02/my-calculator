-- Realtime calculator rooms: owners edit, joined viewers read.

create schema if not exists private;
revoke all on schema private from public;

create table if not exists public.rooms (
  id bigint generated always as identity primary key,
  room_code text not null unique,
  owner_id uuid not null references auth.users (id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  version bigint not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '12 hours'),
  constraint rooms_code_format_check
    check (room_code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  constraint rooms_state_object_check
    check (jsonb_typeof(state) = 'object'),
  constraint rooms_state_size_check
    check (pg_column_size(state) <= 262144),
  constraint rooms_version_positive_check
    check (version > 0),
  constraint rooms_expiry_check
    check (expires_at > created_at)
);

create table if not exists public.room_members (
  room_id bigint not null references public.rooms (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  member_role text not null default 'viewer',
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id),
  constraint room_members_role_check
    check (member_role in ('viewer'))
);

create index if not exists room_members_user_room_idx
  on public.room_members (user_id, room_id);

create index if not exists rooms_owner_updated_idx
  on public.rooms (owner_id, updated_at desc);

create index if not exists rooms_active_expiry_idx
  on public.rooms (expires_at)
  where is_active = true;

create or replace function private.touch_room()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  new.version := old.version + 1;
  return new;
end;
$$;

drop trigger if exists rooms_touch_before_update on public.rooms;
create trigger rooms_touch_before_update
before update of state on public.rooms
for each row execute function private.touch_room();

create or replace function private.join_room_by_code(p_room_code text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  matched_room_id bigint;
begin
  if caller_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select room.id
    into matched_room_id
  from public.rooms as room
  where room.room_code = upper(trim(p_room_code))
    and room.is_active = true
    and room.expires_at > now()
  limit 1;

  if matched_room_id is null then
    raise exception using errcode = 'P0001', message = 'ROOM_NOT_FOUND';
  end if;

  insert into public.room_members (room_id, user_id, member_role)
  values (matched_room_id, caller_id, 'viewer')
  on conflict (room_id, user_id) do nothing;

  return matched_room_id;
end;
$$;

create or replace function public.join_room(p_room_code text)
returns bigint
language sql
security invoker
set search_path = ''
as $$
  select private.join_room_by_code(p_room_code);
$$;

alter table public.rooms enable row level security;
alter table public.room_members enable row level security;

drop policy if exists rooms_read_joined_or_owned on public.rooms;
create policy rooms_read_joined_or_owned
on public.rooms
for select
to authenticated
using (
  owner_id = (select auth.uid())
  or exists (
    select 1
    from public.room_members as member
    where member.room_id = rooms.id
      and member.user_id = (select auth.uid())
  )
);

drop policy if exists rooms_create_as_owner on public.rooms;
create policy rooms_create_as_owner
on public.rooms
for insert
to authenticated
with check (owner_id = (select auth.uid()));

drop policy if exists rooms_owner_updates_state on public.rooms;
create policy rooms_owner_updates_state
on public.rooms
for update
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

drop policy if exists room_members_read_self on public.room_members;
create policy room_members_read_self
on public.room_members
for select
to authenticated
using (user_id = (select auth.uid()));

revoke all on table public.rooms from public, anon, authenticated;
revoke all on table public.room_members from public, anon, authenticated;
revoke all on sequence public.rooms_id_seq from public, anon, authenticated;

grant select on table public.rooms to authenticated;
grant insert (room_code, owner_id, state) on table public.rooms to authenticated;
grant update (state) on table public.rooms to authenticated;
grant select on table public.room_members to authenticated;
grant usage, select on sequence public.rooms_id_seq to authenticated;

revoke all on function private.touch_room() from public, anon, authenticated;
revoke all on function private.join_room_by_code(text) from public, anon, authenticated;
revoke all on function public.join_room(text) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.join_room_by_code(text) to authenticated;
grant execute on function public.join_room(text) to authenticated;

-- The dashboard's automatic-RLS event trigger does not need to be callable
-- through the Data API. Keep the trigger working while removing RPC access.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rooms'
  ) then
    alter publication supabase_realtime add table public.rooms;
  end if;
end;
$$;
