-- Magnetic Hearts Duo
-- Paste this entire file into Supabase Dashboard -> SQL Editor -> New query.
-- This migration only creates the new Magnetic Hearts backend objects.

begin;

create extension if not exists pgcrypto with schema extensions;

do $$
begin
  if to_regprocedure('public.is_panpanskii_approved_user()') is null then
    raise exception
      'Run the existing Panpanskii two-user security migration before Magnetic Hearts.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. Persistent rooms and two fixed player memberships
-- ---------------------------------------------------------------------------

create table if not exists public.magnetic_heart_rooms (
  id uuid primary key default gen_random_uuid(),
  topic text not null,
  room_code text not null,
  host_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'waiting',
  reveal_message text,
  reveal_image_url text,
  created_at timestamptz not null default clock_timestamp(),
  started_at timestamptz,
  play_at timestamptz,
  completed_at timestamptz,
  expires_at timestamptz not null default (clock_timestamp() + interval '2 hours'),
  updated_at timestamptz not null default clock_timestamp()
);

alter table public.magnetic_heart_rooms
  add column if not exists topic text,
  add column if not exists room_code text,
  add column if not exists host_user_id uuid references auth.users(id) on delete cascade,
  add column if not exists status text default 'waiting',
  add column if not exists reveal_message text,
  add column if not exists reveal_image_url text,
  add column if not exists created_at timestamptz default clock_timestamp(),
  add column if not exists started_at timestamptz,
  add column if not exists play_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists expires_at timestamptz default (clock_timestamp() + interval '2 hours'),
  add column if not exists updated_at timestamptz default clock_timestamp();

alter table public.magnetic_heart_rooms
  alter column topic set not null,
  alter column room_code set not null,
  alter column host_user_id set not null,
  alter column status set not null,
  alter column created_at set not null,
  alter column expires_at set not null,
  alter column updated_at set not null;

alter table public.magnetic_heart_rooms
  drop constraint if exists magnetic_heart_rooms_status_check;
alter table public.magnetic_heart_rooms
  add constraint magnetic_heart_rooms_status_check check (
    status in ('waiting', 'ready', 'countdown', 'playing', 'completed', 'abandoned')
  );

alter table public.magnetic_heart_rooms
  drop constraint if exists magnetic_heart_rooms_room_code_check;
alter table public.magnetic_heart_rooms
  add constraint magnetic_heart_rooms_room_code_check check (
    room_code ~ '^[A-Z0-9]{6}$'
  );

alter table public.magnetic_heart_rooms
  drop constraint if exists magnetic_heart_rooms_topic_check;
alter table public.magnetic_heart_rooms
  add constraint magnetic_heart_rooms_topic_check check (
    topic = 'magnetic-heart:' || id::text
  );

alter table public.magnetic_heart_rooms
  drop constraint if exists magnetic_heart_rooms_reveal_message_check;
alter table public.magnetic_heart_rooms
  add constraint magnetic_heart_rooms_reveal_message_check check (
    reveal_message is null or char_length(reveal_message) <= 280
  );

create unique index if not exists magnetic_heart_rooms_topic_uidx
  on public.magnetic_heart_rooms(topic);
create unique index if not exists magnetic_heart_rooms_code_uidx
  on public.magnetic_heart_rooms(room_code);
create index if not exists magnetic_heart_rooms_active_idx
  on public.magnetic_heart_rooms(status, expires_at, updated_at desc);
create index if not exists magnetic_heart_rooms_host_idx
  on public.magnetic_heart_rooms(host_user_id, updated_at desc);

create table if not exists public.magnetic_heart_room_members (
  room_id uuid not null references public.magnetic_heart_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null default 'panpanskii',
  mascot text not null default 'panda',
  role text not null,
  node_color text not null,
  is_ready boolean not null default false,
  joined_at timestamptz not null default clock_timestamp(),
  last_seen_at timestamptz not null default clock_timestamp(),
  node_x double precision not null default 0.5,
  node_y double precision not null default 0.58,
  is_dragging boolean not null default false,
  last_sequence bigint not null default 0,
  primary key (room_id, user_id)
);

alter table public.magnetic_heart_room_members
  add column if not exists username text default 'panpanskii',
  add column if not exists mascot text default 'panda',
  add column if not exists role text,
  add column if not exists node_color text,
  add column if not exists is_ready boolean default false,
  add column if not exists joined_at timestamptz default clock_timestamp(),
  add column if not exists last_seen_at timestamptz default clock_timestamp(),
  add column if not exists node_x double precision default 0.5,
  add column if not exists node_y double precision default 0.58,
  add column if not exists is_dragging boolean default false,
  add column if not exists last_sequence bigint default 0;

update public.magnetic_heart_room_members
set
  username = coalesce(nullif(btrim(username), ''), 'panpanskii'),
  mascot = case when mascot in ('panda', 'koala') then mascot else 'panda' end,
  is_ready = coalesce(is_ready, false),
  joined_at = coalesce(joined_at, clock_timestamp()),
  last_seen_at = coalesce(last_seen_at, clock_timestamp()),
  node_x = least(1.0, greatest(0.0, coalesce(node_x, 0.5))),
  node_y = least(1.0, greatest(0.0, coalesce(node_y, 0.58))),
  is_dragging = coalesce(is_dragging, false),
  last_sequence = greatest(0, coalesce(last_sequence, 0));

alter table public.magnetic_heart_room_members
  alter column username set not null,
  alter column mascot set not null,
  alter column role set not null,
  alter column node_color set not null,
  alter column is_ready set not null,
  alter column joined_at set not null,
  alter column last_seen_at set not null,
  alter column node_x set not null,
  alter column node_y set not null,
  alter column is_dragging set not null,
  alter column last_sequence set not null;

alter table public.magnetic_heart_room_members
  drop constraint if exists magnetic_heart_members_role_check;
alter table public.magnetic_heart_room_members
  add constraint magnetic_heart_members_role_check check (
    role in ('host', 'guest')
  );

alter table public.magnetic_heart_room_members
  drop constraint if exists magnetic_heart_members_node_color_check;
alter table public.magnetic_heart_room_members
  add constraint magnetic_heart_members_node_color_check check (
    node_color in ('blue', 'pink')
  );

alter table public.magnetic_heart_room_members
  drop constraint if exists magnetic_heart_members_role_node_check;
alter table public.magnetic_heart_room_members
  add constraint magnetic_heart_members_role_node_check check (
    (role = 'host' and node_color = 'blue') or
    (role = 'guest' and node_color = 'pink')
  );

alter table public.magnetic_heart_room_members
  drop constraint if exists magnetic_heart_members_mascot_check;
alter table public.magnetic_heart_room_members
  add constraint magnetic_heart_members_mascot_check check (
    mascot in ('panda', 'koala')
  );

alter table public.magnetic_heart_room_members
  drop constraint if exists magnetic_heart_members_coordinates_check;
alter table public.magnetic_heart_room_members
  add constraint magnetic_heart_members_coordinates_check check (
    node_x between 0.0 and 1.0 and node_y between 0.0 and 1.0
  );

alter table public.magnetic_heart_room_members
  drop constraint if exists magnetic_heart_members_sequence_check;
alter table public.magnetic_heart_room_members
  add constraint magnetic_heart_members_sequence_check check (
    last_sequence >= 0
  );

create unique index if not exists magnetic_heart_members_role_uidx
  on public.magnetic_heart_room_members(room_id, role);
create unique index if not exists magnetic_heart_members_node_uidx
  on public.magnetic_heart_room_members(room_id, node_color);
create index if not exists magnetic_heart_members_user_idx
  on public.magnetic_heart_room_members(user_id, joined_at desc);

-- ---------------------------------------------------------------------------
-- 2. Integrity triggers: timestamps and a hard two-person room limit
-- ---------------------------------------------------------------------------

create or replace function public.set_magnetic_heart_room_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists magnetic_heart_rooms_updated_at
  on public.magnetic_heart_rooms;
create trigger magnetic_heart_rooms_updated_at
before update on public.magnetic_heart_rooms
for each row execute function public.set_magnetic_heart_room_updated_at();

create or replace function public.enforce_magnetic_heart_member_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_host_user_id uuid;
  v_member_count integer;
begin
  perform pg_advisory_xact_lock(hashtext(new.room_id::text)::bigint);

  select host_user_id
  into v_host_user_id
  from public.magnetic_heart_rooms
  where id = new.room_id
  for update;

  if v_host_user_id is null then
    raise exception 'Magnetic Hearts room does not exist.';
  end if;

  if (new.role = 'host' and new.user_id <> v_host_user_id) or
     (new.role = 'guest' and new.user_id = v_host_user_id) then
    raise exception 'Player role does not match this room.';
  end if;

  select count(*)
  into v_member_count
  from public.magnetic_heart_room_members
  where room_id = new.room_id;

  if v_member_count >= 2 then
    raise exception 'This Magnetic Hearts room is already full.';
  end if;

  return new;
end;
$$;

drop trigger if exists magnetic_heart_member_limit
  on public.magnetic_heart_room_members;
create trigger magnetic_heart_member_limit
before insert on public.magnetic_heart_room_members
for each row execute function public.enforce_magnetic_heart_member_limit();

-- ---------------------------------------------------------------------------
-- 3. Small SECURITY DEFINER membership helpers used by table and Realtime RLS
-- ---------------------------------------------------------------------------

create or replace function public.is_magnetic_heart_room_member(
  p_room_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_panpanskii_approved_user()
    and exists (
    select 1
    from public.magnetic_heart_room_members member
    where member.room_id = p_room_id
      and member.user_id = p_user_id
  );
$$;

create or replace function public.is_magnetic_heart_topic_member(
  p_topic text,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_panpanskii_approved_user()
    and exists (
    select 1
    from public.magnetic_heart_rooms room
    join public.magnetic_heart_room_members member
      on member.room_id = room.id
    where room.topic = p_topic
      and member.user_id = p_user_id
      and room.status <> 'abandoned'
      and room.expires_at > clock_timestamp()
  );
$$;

create or replace function public.cleanup_expired_magnetic_heart_rooms()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
begin
  update public.magnetic_heart_rooms
  set
    status = 'abandoned',
    play_at = null
  where status in ('waiting', 'ready', 'countdown', 'playing')
    and expires_at <= clock_timestamp();

  get diagnostics v_count = row_count;

  update public.magnetic_heart_room_members member
  set
    is_ready = false,
    is_dragging = false,
    last_seen_at = clock_timestamp()
  from public.magnetic_heart_rooms room
  where member.room_id = room.id
    and room.status = 'abandoned'
    and room.expires_at <= clock_timestamp();

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Atomic room lifecycle RPCs
-- ---------------------------------------------------------------------------

create or replace function public.create_magnetic_heart_room(
  p_username text,
  p_mascot text,
  p_reveal_message text default null
)
returns public.magnetic_heart_rooms
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.magnetic_heart_rooms;
  v_room_id uuid;
  v_room_code text;
  v_attempt integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if not public.is_panpanskii_approved_user() then
    raise exception 'This account is not approved for Panpanskii.';
  end if;
  if coalesce(p_mascot, '') not in ('panda', 'koala') then
    raise exception 'Invalid mascot.';
  end if;

  perform public.cleanup_expired_magnetic_heart_rooms();

  select room.*
  into v_room
  from public.magnetic_heart_rooms room
  join public.magnetic_heart_room_members member
    on member.room_id = room.id
  where member.user_id = v_user_id
    and room.status in ('waiting', 'ready', 'countdown', 'playing')
    and room.expires_at > clock_timestamp()
  order by room.updated_at desc
  limit 1
  for update of room;

  if found then
    update public.magnetic_heart_room_members
    set
      username = left(coalesce(nullif(btrim(p_username), ''), username), 80),
      mascot = p_mascot,
      last_seen_at = clock_timestamp()
    where room_id = v_room.id and user_id = v_user_id;
    return v_room;
  end if;

  v_room_id := gen_random_uuid();
  for v_attempt in 1..20 loop
    v_room_code := upper(substr(md5(
      v_room_id::text || clock_timestamp()::text || random()::text || v_attempt::text
    ), 1, 6));
    begin
      insert into public.magnetic_heart_rooms (
        id,
        topic,
        room_code,
        host_user_id,
        status,
        reveal_message,
        expires_at
      ) values (
        v_room_id,
        'magnetic-heart:' || v_room_id::text,
        v_room_code,
        v_user_id,
        'waiting',
        coalesce(
          nullif(left(btrim(coalesce(p_reveal_message, '')), 280), ''),
          'Two hearts, one little universe.'
        ),
        clock_timestamp() + interval '2 hours'
      )
      returning * into v_room;
      exit;
    exception when unique_violation then
      if v_attempt = 20 then
        raise exception 'Could not generate a unique room code. Please try again.';
      end if;
    end;
  end loop;

  insert into public.magnetic_heart_room_members (
    room_id,
    user_id,
    username,
    mascot,
    role,
    node_color,
    node_x,
    node_y
  ) values (
    v_room.id,
    v_user_id,
    left(coalesce(nullif(btrim(p_username), ''), 'panpanskii'), 80),
    p_mascot,
    'host',
    'blue',
    0.22,
    0.58
  );

  return v_room;
end;
$$;

create or replace function public.join_magnetic_heart_room(
  p_room_code text,
  p_username text,
  p_mascot text
)
returns public.magnetic_heart_rooms
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text := upper(btrim(coalesce(p_room_code, '')));
  v_room public.magnetic_heart_rooms;
  v_existing_room public.magnetic_heart_rooms;
  v_member_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if not public.is_panpanskii_approved_user() then
    raise exception 'This account is not approved for Panpanskii.';
  end if;
  if v_code !~ '^[A-Z0-9]{6}$' then
    raise exception 'Enter a valid 6-character room code.';
  end if;
  if coalesce(p_mascot, '') not in ('panda', 'koala') then
    raise exception 'Invalid mascot.';
  end if;

  perform public.cleanup_expired_magnetic_heart_rooms();

  select room.*
  into v_existing_room
  from public.magnetic_heart_rooms room
  join public.magnetic_heart_room_members member
    on member.room_id = room.id
  where member.user_id = v_user_id
    and room.status in ('waiting', 'ready', 'countdown', 'playing')
    and room.expires_at > clock_timestamp()
  order by room.updated_at desc
  limit 1
  for update of room;

  if found then
    if v_existing_room.room_code <> v_code then
      raise exception 'Close your current Magnetic Hearts room before joining another.';
    end if;
    update public.magnetic_heart_room_members
    set
      username = left(coalesce(nullif(btrim(p_username), ''), username), 80),
      mascot = p_mascot,
      last_seen_at = clock_timestamp()
    where room_id = v_existing_room.id and user_id = v_user_id;
    return v_existing_room;
  end if;

  select *
  into v_room
  from public.magnetic_heart_rooms
  where room_code = v_code
  for update;

  if not found then
    raise exception 'Room not found or expired.';
  end if;
  if v_room.host_user_id = v_user_id then
    raise exception 'The room creator is already the blue player.';
  end if;
  if v_room.status not in ('waiting', 'ready') or
     v_room.expires_at <= clock_timestamp() then
    raise exception 'This room is no longer available.';
  end if;

  if public.is_magnetic_heart_room_member(v_room.id, v_user_id) then
    update public.magnetic_heart_room_members
    set
      username = left(coalesce(nullif(btrim(p_username), ''), username), 80),
      mascot = p_mascot,
      last_seen_at = clock_timestamp()
    where room_id = v_room.id and user_id = v_user_id;
    return v_room;
  end if;

  select count(*)
  into v_member_count
  from public.magnetic_heart_room_members
  where room_id = v_room.id;
  if v_member_count >= 2 then
    raise exception 'This room is already full.';
  end if;

  insert into public.magnetic_heart_room_members (
    room_id,
    user_id,
    username,
    mascot,
    role,
    node_color,
    node_x,
    node_y
  ) values (
    v_room.id,
    v_user_id,
    left(coalesce(nullif(btrim(p_username), ''), 'panpanskii'), 80),
    p_mascot,
    'guest',
    'pink',
    0.78,
    0.58
  );

  update public.magnetic_heart_rooms
  set
    status = 'ready',
    expires_at = greatest(expires_at, clock_timestamp() + interval '2 hours')
  where id = v_room.id
  returning * into v_room;

  return v_room;
end;
$$;

create or replace function public.get_current_magnetic_heart_room()
returns public.magnetic_heart_rooms
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.magnetic_heart_rooms;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if not public.is_panpanskii_approved_user() then
    raise exception 'This account is not approved for Panpanskii.';
  end if;
  perform public.cleanup_expired_magnetic_heart_rooms();

  select room.*
  into v_room
  from public.magnetic_heart_rooms room
  join public.magnetic_heart_room_members member
    on member.room_id = room.id
  where member.user_id = v_user_id
    and room.status in ('waiting', 'ready', 'countdown', 'playing')
    and room.expires_at > clock_timestamp()
  order by room.updated_at desc
  limit 1;

  if not found then
    return null;
  end if;
  return v_room;
end;
$$;

create or replace function public.set_magnetic_heart_ready(
  p_room_id uuid,
  p_ready boolean
)
returns public.magnetic_heart_rooms
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.magnetic_heart_rooms;
  v_member_count integer;
  v_ready_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  select * into v_room
  from public.magnetic_heart_rooms
  where id = p_room_id
  for update;

  if not found or not public.is_magnetic_heart_room_member(p_room_id, v_user_id) then
    raise exception 'You do not belong to this room.';
  end if;
  if v_room.status in ('countdown', 'playing') and p_ready then
    return v_room;
  end if;
  if v_room.status in ('countdown', 'playing', 'completed', 'abandoned') then
    raise exception 'Ready state can no longer be changed for this round.';
  end if;

  update public.magnetic_heart_room_members
  set
    is_ready = p_ready,
    last_seen_at = clock_timestamp()
  where room_id = p_room_id and user_id = v_user_id;

  select count(*), count(*) filter (where is_ready)
  into v_member_count, v_ready_count
  from public.magnetic_heart_room_members
  where room_id = p_room_id;

  if v_member_count = 2 and v_ready_count = 2 then
    update public.magnetic_heart_rooms
    set
      status = 'countdown',
      started_at = clock_timestamp(),
      play_at = clock_timestamp() + interval '3 seconds',
      expires_at = greatest(expires_at, clock_timestamp() + interval '2 hours')
    where id = p_room_id
      and status in ('waiting', 'ready')
    returning * into v_room;
  else
    update public.magnetic_heart_rooms
    set
      status = case when v_member_count = 2 then 'ready' else 'waiting' end,
      play_at = null
    where id = p_room_id
    returning * into v_room;
  end if;

  return v_room;
end;
$$;

create or replace function public.begin_magnetic_heart_game(p_room_id uuid)
returns public.magnetic_heart_rooms
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.magnetic_heart_rooms;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  select * into v_room
  from public.magnetic_heart_rooms
  where id = p_room_id
  for update;

  if not found or not public.is_magnetic_heart_room_member(p_room_id, v_user_id) then
    raise exception 'You do not belong to this room.';
  end if;
  if v_room.status = 'playing' then
    return v_room;
  end if;
  if v_room.status <> 'countdown' or v_room.play_at is null then
    raise exception 'The game is not in countdown.';
  end if;
  if clock_timestamp() < v_room.play_at then
    raise exception 'The countdown is still running.';
  end if;

  update public.magnetic_heart_rooms
  set
    status = 'playing',
    started_at = clock_timestamp(),
    play_at = null,
    expires_at = greatest(expires_at, clock_timestamp() + interval '2 hours')
  where id = p_room_id and status = 'countdown'
  returning * into v_room;

  return v_room;
end;
$$;

create or replace function public.persist_magnetic_heart_node_state(
  p_room_id uuid,
  p_x double precision,
  p_y double precision,
  p_is_dragging boolean,
  p_sequence bigint
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_updated boolean := false;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if not public.is_magnetic_heart_room_member(p_room_id, v_user_id) then
    raise exception 'You do not belong to this room.';
  end if;
  if p_x not between 0.0 and 1.0 or
     p_y not between 0.0 and 1.0 or
     p_sequence < 0 then
    raise exception 'Invalid node state.';
  end if;

  update public.magnetic_heart_room_members member
  set
    node_x = p_x,
    node_y = p_y,
    is_dragging = p_is_dragging,
    last_sequence = p_sequence,
    last_seen_at = clock_timestamp()
  where member.room_id = p_room_id
    and member.user_id = v_user_id
    and p_sequence > member.last_sequence;

  v_updated := found;
  return v_updated;
end;
$$;

create or replace function public.complete_magnetic_heart_game(p_room_id uuid)
returns public.magnetic_heart_rooms
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.magnetic_heart_rooms;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if not public.is_panpanskii_approved_user() then
    raise exception 'This account is not approved for Panpanskii.';
  end if;

  select * into v_room
  from public.magnetic_heart_rooms
  where id = p_room_id
  for update;

  if not found or v_room.host_user_id <> v_user_id then
    raise exception 'Only the blue host can complete this room.';
  end if;
  if v_room.status = 'completed' then
    return v_room;
  end if;
  if v_room.status <> 'playing' then
    raise exception 'This game is not currently playing.';
  end if;
  if (select count(*) from public.magnetic_heart_room_members where room_id = p_room_id) <> 2 then
    raise exception 'Both players are required.';
  end if;

  update public.magnetic_heart_rooms
  set
    status = 'completed',
    completed_at = clock_timestamp(),
    play_at = null
  where id = p_room_id and status = 'playing'
  returning * into v_room;

  update public.magnetic_heart_room_members
  set is_dragging = false, last_seen_at = clock_timestamp()
  where room_id = p_room_id;

  return v_room;
end;
$$;

create or replace function public.reset_magnetic_heart_game(p_room_id uuid)
returns public.magnetic_heart_rooms
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.magnetic_heart_rooms;
  v_member_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  select * into v_room
  from public.magnetic_heart_rooms
  where id = p_room_id
  for update;

  if not found or not public.is_magnetic_heart_room_member(p_room_id, v_user_id) then
    raise exception 'You do not belong to this room.';
  end if;
  if v_room.status not in ('completed', 'ready', 'waiting') then
    raise exception 'The current game cannot be reset yet.';
  end if;

  select count(*) into v_member_count
  from public.magnetic_heart_room_members
  where room_id = p_room_id;

  update public.magnetic_heart_room_members
  set
    is_ready = false,
    is_dragging = false,
    node_x = case when role = 'host' then 0.22 else 0.78 end,
    node_y = 0.58,
    last_sequence = 0,
    last_seen_at = clock_timestamp()
  where room_id = p_room_id;

  update public.magnetic_heart_rooms
  set
    status = case when v_member_count = 2 then 'ready' else 'waiting' end,
    started_at = null,
    play_at = null,
    completed_at = null,
    expires_at = clock_timestamp() + interval '2 hours'
  where id = p_room_id
  returning * into v_room;

  return v_room;
end;
$$;

create or replace function public.abandon_magnetic_heart_room(p_room_id uuid)
returns public.magnetic_heart_rooms
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.magnetic_heart_rooms;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  select * into v_room
  from public.magnetic_heart_rooms
  where id = p_room_id
  for update;

  if not found or not public.is_magnetic_heart_room_member(p_room_id, v_user_id) then
    raise exception 'You do not belong to this room.';
  end if;
  if v_room.status in ('completed', 'abandoned') then
    return v_room;
  end if;

  update public.magnetic_heart_rooms
  set status = 'abandoned', play_at = null
  where id = p_room_id
  returning * into v_room;

  update public.magnetic_heart_room_members
  set is_ready = false, is_dragging = false, last_seen_at = clock_timestamp()
  where room_id = p_room_id;

  return v_room;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Table RLS: only room members can read; all writes use checked RPCs
-- ---------------------------------------------------------------------------

alter table public.magnetic_heart_rooms enable row level security;
alter table public.magnetic_heart_room_members enable row level security;

drop policy if exists magnetic_heart_rooms_member_select
  on public.magnetic_heart_rooms;
create policy magnetic_heart_rooms_member_select
on public.magnetic_heart_rooms
for select
to authenticated
using (public.is_magnetic_heart_room_member(id, (select auth.uid())));

drop policy if exists magnetic_heart_members_member_select
  on public.magnetic_heart_room_members;
create policy magnetic_heart_members_member_select
on public.magnetic_heart_room_members
for select
to authenticated
using (public.is_magnetic_heart_room_member(room_id, (select auth.uid())));

drop policy if exists magnetic_heart_members_own_touch
  on public.magnetic_heart_room_members;
create policy magnetic_heart_members_own_touch
on public.magnetic_heart_room_members
for update
to authenticated
using (
  user_id = (select auth.uid())
  and public.is_panpanskii_approved_user()
)
with check (
  user_id = (select auth.uid())
  and public.is_panpanskii_approved_user()
);

revoke all on table public.magnetic_heart_rooms from anon, authenticated;
revoke all on table public.magnetic_heart_room_members from anon, authenticated;
grant select on table public.magnetic_heart_rooms to authenticated;
grant select on table public.magnetic_heart_room_members to authenticated;
grant update (last_seen_at) on table public.magnetic_heart_room_members
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Private Realtime Broadcast and Presence authorization
-- ---------------------------------------------------------------------------

drop policy if exists magnetic_hearts_realtime_receive
  on realtime.messages;
create policy magnetic_hearts_realtime_receive
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension in ('broadcast', 'presence')
  and public.is_magnetic_heart_topic_member(
    (select realtime.topic()),
    (select auth.uid())
  )
);

drop policy if exists magnetic_hearts_realtime_send
  on realtime.messages;
create policy magnetic_hearts_realtime_send
on realtime.messages
for insert
to authenticated
with check (
  realtime.messages.extension in ('broadcast', 'presence')
  and public.is_magnetic_heart_topic_member(
    (select realtime.topic()),
    (select auth.uid())
  )
);

-- Postgres-change streams keep authoritative room/member state synchronized.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'magnetic_heart_rooms'
  ) then
    alter publication supabase_realtime
      add table public.magnetic_heart_rooms;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'magnetic_heart_room_members'
  ) then
    alter publication supabase_realtime
      add table public.magnetic_heart_room_members;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Least-privilege function execution
-- ---------------------------------------------------------------------------

revoke execute on function public.set_magnetic_heart_room_updated_at()
  from public, anon, authenticated;
revoke execute on function public.enforce_magnetic_heart_member_limit()
  from public, anon, authenticated;
revoke execute on function public.cleanup_expired_magnetic_heart_rooms()
  from public, anon, authenticated;

revoke execute on function public.is_magnetic_heart_room_member(uuid, uuid)
  from public, anon;
revoke execute on function public.is_magnetic_heart_topic_member(text, uuid)
  from public, anon;
grant execute on function public.is_magnetic_heart_room_member(uuid, uuid)
  to authenticated;
grant execute on function public.is_magnetic_heart_topic_member(text, uuid)
  to authenticated;

revoke execute on function public.create_magnetic_heart_room(text, text, text)
  from public, anon;
revoke execute on function public.join_magnetic_heart_room(text, text, text)
  from public, anon;
revoke execute on function public.get_current_magnetic_heart_room()
  from public, anon;
revoke execute on function public.set_magnetic_heart_ready(uuid, boolean)
  from public, anon;
revoke execute on function public.begin_magnetic_heart_game(uuid)
  from public, anon;
revoke execute on function public.persist_magnetic_heart_node_state(
  uuid, double precision, double precision, boolean, bigint
) from public, anon;
revoke execute on function public.complete_magnetic_heart_game(uuid)
  from public, anon;
revoke execute on function public.reset_magnetic_heart_game(uuid)
  from public, anon;
revoke execute on function public.abandon_magnetic_heart_room(uuid)
  from public, anon;

grant execute on function public.create_magnetic_heart_room(text, text, text)
  to authenticated;
grant execute on function public.join_magnetic_heart_room(text, text, text)
  to authenticated;
grant execute on function public.get_current_magnetic_heart_room()
  to authenticated;
grant execute on function public.set_magnetic_heart_ready(uuid, boolean)
  to authenticated;
grant execute on function public.begin_magnetic_heart_game(uuid)
  to authenticated;
grant execute on function public.persist_magnetic_heart_node_state(
  uuid, double precision, double precision, boolean, bigint
) to authenticated;
grant execute on function public.complete_magnetic_heart_game(uuid)
  to authenticated;
grant execute on function public.reset_magnetic_heart_game(uuid)
  to authenticated;
grant execute on function public.abandon_magnetic_heart_room(uuid)
  to authenticated;

notify pgrst, 'reload schema';

commit;
