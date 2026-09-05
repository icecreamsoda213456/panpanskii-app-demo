-- Panpanskii Photo Booth LiveKit backend.
-- Safe one-time migration for Supabase SQL Editor.
-- Existing completed sessions, photos, and legacy signaling rows are preserved.
-- Any duplicate active photo metadata is archived before it is deduplicated.

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Tables, columns, defaults, constraints, and indexes.
-- ---------------------------------------------------------------------------

create table if not exists public.photobooth_sessions (
  id uuid primary key default gen_random_uuid(),
  room_name text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  status text not null default 'lobby'
    check (status in ('lobby', 'countdown', 'capturing', 'complete', 'cancelled')),
  current_round integer not null default 0 check (current_round between 0 and 4),
  total_rounds integer not null default 5 check (total_rounds = 5),
  capture_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.photobooth_participants (
  session_id uuid not null references public.photobooth_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  frame_style text not null default 'vintage'
    check (frame_style in ('vintage', 'sakura', 'midnight')),
  is_ready boolean not null default false,
  joined_at timestamptz not null default clock_timestamp(),
  primary key (session_id, user_id)
);

create table if not exists public.photobooth_photos (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.photobooth_sessions(id) on delete cascade,
  round_index integer not null check (round_index between 0 and 4),
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  storage_path text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (session_id, round_index, user_id)
);

-- Add the LiveKit columns when this script is applied to an older Photo Booth
-- schema. No completed rows or photo rows are deleted.
alter table public.photobooth_sessions
  add column if not exists room_name text;
alter table public.photobooth_sessions
  add column if not exists created_by uuid references auth.users(id) on delete cascade;
alter table public.photobooth_sessions
  add column if not exists status text;
alter table public.photobooth_sessions
  add column if not exists current_round integer;
alter table public.photobooth_sessions
  add column if not exists total_rounds integer;
alter table public.photobooth_sessions
  add column if not exists capture_at timestamptz;
alter table public.photobooth_sessions
  add column if not exists created_at timestamptz;
alter table public.photobooth_sessions
  add column if not exists updated_at timestamptz;

alter table public.photobooth_participants
  add column if not exists frame_style text;
alter table public.photobooth_participants
  add column if not exists is_ready boolean;
alter table public.photobooth_participants
  add column if not exists joined_at timestamptz;

alter table public.photobooth_photos
  add column if not exists round_index integer;
alter table public.photobooth_photos
  add column if not exists username text;
alter table public.photobooth_photos
  add column if not exists mascot text;
alter table public.photobooth_photos
  add column if not exists storage_path text;
alter table public.photobooth_photos
  add column if not exists created_at timestamptz;

-- Remove every legacy Photo Booth policy before changing the legacy columns.
-- Policies are permissive and combine with OR, so keeping even one old policy
-- would bypass the participant-only policies created later in this script.
do $$
declare
  policy_record record;
begin
  if to_regclass('public.photobooth_sessions') is not null then
    execute 'drop policy if exists "Authenticated users can read photobooth sessions" on public.photobooth_sessions';
    execute 'drop policy if exists "Users can create photobooth sessions" on public.photobooth_sessions';
    execute 'drop policy if exists "Authenticated users can update photobooth sessions" on public.photobooth_sessions';
  end if;

  if to_regclass('public.photobooth_photos') is not null then
    execute 'drop policy if exists "Authenticated users can read photobooth photos" on public.photobooth_photos';
    execute 'drop policy if exists "Users can upload their photobooth photos" on public.photobooth_photos';
  end if;

  if to_regclass('public.photobooth_signals') is not null then
    execute 'drop policy if exists "Authenticated users can read photobooth signals" on public.photobooth_signals';
    execute 'drop policy if exists "Users can send photobooth signals" on public.photobooth_signals';
    execute 'alter table public.photobooth_signals enable row level security';
    execute 'revoke all on table public.photobooth_signals from anon, authenticated';
  end if;

  for policy_record in
    select schemaname, tablename, policyname
    from pg_policies
    where (schemaname = 'public' and tablename in (
      'photobooth_sessions',
      'photobooth_participants',
      'photobooth_photos',
      'photobooth_signals'
    ))
      or (schemaname = 'storage' and tablename = 'objects'
        and policyname ilike '%photobooth%')
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      policy_record.policyname,
      policy_record.schemaname,
      policy_record.tablename
    );
  end loop;
end;
$$;

-- The legacy status CHECK accepts `waiting`, while LiveKit uses `lobby`.
-- Drop the old constraint before changing old values to the new vocabulary.
alter table public.photobooth_sessions
  drop constraint if exists photobooth_sessions_status_check;
alter table public.photobooth_sessions
  alter column capture_at drop not null;
alter table public.photobooth_sessions
  drop constraint if exists photobooth_sessions_current_round_check;
alter table public.photobooth_sessions
  drop constraint if exists photobooth_sessions_total_rounds_check;
alter table public.photobooth_participants
  drop constraint if exists photobooth_participants_frame_style_check;
alter table public.photobooth_photos
  drop constraint if exists photobooth_photos_round_index_check;
alter table public.photobooth_photos
  drop constraint if exists photobooth_photos_mascot_check;

-- Preserve old records while normalizing values required by the LiveKit flow.
update public.photobooth_sessions
set status = case lower(coalesce(status, ''))
  when 'waiting' then 'lobby'
  when 'lobby' then 'lobby'
  when 'countdown' then 'countdown'
  when 'capturing' then 'capturing'
  when 'complete' then 'complete'
  when 'cancelled' then 'cancelled'
  else 'cancelled'
end;

update public.photobooth_sessions
set capture_at = null
where status in ('lobby', 'complete', 'cancelled');

update public.photobooth_sessions
set current_round = greatest(0, least(coalesce(current_round, 0), 4));

update public.photobooth_sessions
set total_rounds = 5
where total_rounds is distinct from 5;

update public.photobooth_sessions
set room_name = 'photobooth-' || id::text
where room_name is null or btrim(room_name) = '';

with duplicate_rooms as (
  select room_name
  from public.photobooth_sessions
  group by room_name
  having count(*) > 1
)
update public.photobooth_sessions session
set room_name = 'photobooth-' || session.id::text
from duplicate_rooms duplicate_room
where session.room_name = duplicate_room.room_name;

update public.photobooth_sessions
set created_at = coalesce(created_at, clock_timestamp()),
    updated_at = coalesce(updated_at, created_at, clock_timestamp());

-- Copy each legacy frame_index to the matching LiveKit round before deduping.
-- The dynamic branch keeps this script compatible with a fresh installation.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'photobooth_photos'
      and column_name = 'frame_index'
  ) then
    execute $legacy_frame_index$
      update public.photobooth_photos
      set round_index = greatest(0, least(coalesce(round_index, frame_index, 0), 4))
    $legacy_frame_index$;
  else
    update public.photobooth_photos
    set round_index = greatest(0, least(coalesce(round_index, 0), 4));
  end if;
end;
$$;

update public.photobooth_photos
set username = coalesce(nullif(username, ''), 'panpanskii'),
    mascot = case when mascot in ('panda', 'koala') then mascot else 'panda' end,
    storage_path = coalesce(
      nullif(storage_path, ''),
      user_id::text || '/' || session_id::text || '/round-' ||
        round_index::text || '.png'
    ),
    created_at = coalesce(created_at, clock_timestamp());

-- Historical booths predate photobooth_participants. Create a membership row
-- for every distinct photo owner and use the old session frame as its fallback.
do $$
declare
  has_legacy_session_frame_style boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'photobooth_sessions'
      and column_name = 'frame_style'
  ) into has_legacy_session_frame_style;

  if has_legacy_session_frame_style then
    execute $legacy_participants$
      insert into public.photobooth_participants (
        session_id,
        user_id,
        frame_style,
        is_ready,
        joined_at
      )
      select distinct on (photo.session_id, photo.user_id)
        photo.session_id,
        photo.user_id,
        case
          when session.frame_style in ('vintage', 'sakura', 'midnight')
            then session.frame_style
          else 'vintage'
        end,
        false,
        coalesce(photo.created_at, clock_timestamp())
      from public.photobooth_photos photo
      join public.photobooth_sessions session on session.id = photo.session_id
      where photo.user_id is not null
        and not exists (
          select 1
          from public.photobooth_participants participant
          where participant.session_id = photo.session_id
            and participant.user_id = photo.user_id
        )
      order by photo.session_id, photo.user_id, photo.created_at asc nulls last, photo.id
    $legacy_participants$;
  else
    insert into public.photobooth_participants (
      session_id,
      user_id,
      frame_style,
      is_ready,
      joined_at
    )
    select distinct on (photo.session_id, photo.user_id)
      photo.session_id,
      photo.user_id,
      'vintage',
      false,
      coalesce(photo.created_at, clock_timestamp())
    from public.photobooth_photos photo
    where photo.user_id is not null
      and not exists (
        select 1
        from public.photobooth_participants participant
        where participant.session_id = photo.session_id
          and participant.user_id = photo.user_id
      )
    order by photo.session_id, photo.user_id, photo.created_at asc nulls last, photo.id;
  end if;
end;
$$;

update public.photobooth_participants
set frame_style = 'vintage'
where frame_style is null
  or frame_style not in ('vintage', 'sakura', 'midnight');

update public.photobooth_participants
set is_ready = coalesce(is_ready, false),
    joined_at = coalesce(joined_at, clock_timestamp());

update public.photobooth_sessions session
set created_by = participant.user_id
from (
  select distinct on (session_id) session_id, user_id
  from public.photobooth_participants
  order by session_id, joined_at, user_id
) participant
where session.created_by is null
  and participant.session_id = session.id;

-- Remove every constraint/index that depends on the retired legacy column,
-- then drop the column only after its values have been migrated above.
do $$
declare
  legacy_constraint record;
  legacy_index record;
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'photobooth_photos'
      and column_name = 'frame_index'
  ) then
    for legacy_constraint in
      select conname
      from pg_constraint
      where conrelid = 'public.photobooth_photos'::regclass
        and pg_get_constraintdef(oid) ilike '%frame_index%'
    loop
      execute format(
        'alter table public.photobooth_photos drop constraint if exists %I',
        legacy_constraint.conname
      );
    end loop;

    for legacy_index in
      select indexrelid::regclass as index_name
      from pg_index index_definition
      where indrelid = 'public.photobooth_photos'::regclass
        and pg_get_indexdef(indexrelid) ilike '%frame_index%'
        and not exists (
          select 1
          from pg_constraint constraint_definition
          where constraint_definition.conindid = index_definition.indexrelid
        )
    loop
      execute format('drop index if exists %s', legacy_index.index_name);
    end loop;

    execute 'alter table public.photobooth_photos drop column if exists frame_index';
  end if;
end;
$$;

alter table public.photobooth_sessions
  alter column status set default 'lobby';
alter table public.photobooth_sessions
  alter column current_round set default 0;
alter table public.photobooth_sessions
  alter column total_rounds set default 5;
alter table public.photobooth_sessions
  alter column created_at set default clock_timestamp();
alter table public.photobooth_sessions
  alter column updated_at set default clock_timestamp();
alter table public.photobooth_participants
  alter column frame_style set default 'vintage';
alter table public.photobooth_participants
  alter column is_ready set default false;
alter table public.photobooth_participants
  alter column joined_at set default clock_timestamp();
alter table public.photobooth_photos
  alter column created_at set default clock_timestamp();

alter table public.photobooth_sessions
  alter column status set not null;
alter table public.photobooth_sessions
  alter column current_round set not null;
alter table public.photobooth_sessions
  alter column total_rounds set not null;
alter table public.photobooth_sessions
  alter column room_name set not null;
alter table public.photobooth_sessions
  alter column created_at set not null;
alter table public.photobooth_sessions
  alter column updated_at set not null;
alter table public.photobooth_participants
  alter column frame_style set not null;
alter table public.photobooth_participants
  alter column is_ready set not null;
alter table public.photobooth_participants
  alter column joined_at set not null;
alter table public.photobooth_photos
  alter column round_index set not null;
alter table public.photobooth_photos
  alter column username set not null;
alter table public.photobooth_photos
  alter column mascot set not null;
alter table public.photobooth_photos
  alter column storage_path set not null;
alter table public.photobooth_photos
  alter column created_at set not null;

-- Always replace the legacy status check. Merely checking its name leaves the
-- old `(waiting, capturing, complete, cancelled)` definition in place.
alter table public.photobooth_sessions
  add constraint photobooth_sessions_status_check
  check (status in ('lobby', 'countdown', 'capturing', 'complete', 'cancelled'));
alter table public.photobooth_sessions
  add constraint photobooth_sessions_current_round_check
  check (current_round between 0 and 4);
alter table public.photobooth_sessions
  add constraint photobooth_sessions_total_rounds_check
  check (total_rounds = 5);
alter table public.photobooth_participants
  add constraint photobooth_participants_frame_style_check
  check (frame_style in ('vintage', 'sakura', 'midnight'));
alter table public.photobooth_photos
  add constraint photobooth_photos_round_index_check
  check (round_index between 0 and 4);
alter table public.photobooth_photos
  add constraint photobooth_photos_mascot_check
  check (mascot in ('panda', 'koala'));

-- The unique upload key is required by Flutter's photo upsert. Preserve any
-- legacy duplicate metadata before removing only the extra active rows.
create table if not exists public.photobooth_photo_duplicate_backup (
  original_photo_id uuid primary key,
  retained_photo_id uuid not null,
  session_id uuid not null,
  round_index integer not null,
  user_id uuid not null,
  username text,
  mascot text,
  storage_path text,
  created_at timestamptz,
  archived_at timestamptz not null default clock_timestamp(),
  archive_reason text not null default 'duplicate session-round-user photo metadata'
);

with ranked_photos as (
  select
    photo.id,
    first_value(photo.id) over (
      partition by photo.session_id, photo.round_index, photo.user_id
      order by photo.created_at desc nulls last, photo.id desc
    ) as retained_photo_id,
    row_number() over (
      partition by photo.session_id, photo.round_index, photo.user_id
      order by photo.created_at desc nulls last, photo.id desc
    ) as duplicate_rank
  from public.photobooth_photos photo
), duplicate_photos as (
  select photo.*, ranked_photos.retained_photo_id
  from public.photobooth_photos photo
  join ranked_photos on ranked_photos.id = photo.id
  where ranked_photos.duplicate_rank > 1
)
insert into public.photobooth_photo_duplicate_backup (
  original_photo_id,
  retained_photo_id,
  session_id,
  round_index,
  user_id,
  username,
  mascot,
  storage_path,
  created_at
)
select
  id,
  retained_photo_id,
  session_id,
  round_index,
  user_id,
  username,
  mascot,
  storage_path,
  created_at
from duplicate_photos
on conflict (original_photo_id) do nothing;

with ranked_photos as (
  select
    photo.id,
    row_number() over (
      partition by photo.session_id, photo.round_index, photo.user_id
      order by photo.created_at desc nulls last, photo.id desc
    ) as duplicate_rank
  from public.photobooth_photos photo
)
delete from public.photobooth_photos photo
using ranked_photos
where photo.id = ranked_photos.id
  and ranked_photos.duplicate_rank > 1
  and exists (
    select 1
    from public.photobooth_photo_duplicate_backup backup
    where backup.original_photo_id = photo.id
  );

create unique index if not exists photobooth_sessions_room_name_key
  on public.photobooth_sessions (room_name);
create unique index if not exists photobooth_participants_session_user_key
  on public.photobooth_participants (session_id, user_id);
create unique index if not exists photobooth_photos_session_round_user_key
  on public.photobooth_photos (session_id, round_index, user_id);
create index if not exists photobooth_sessions_status_updated_idx
  on public.photobooth_sessions (status, updated_at desc);
create index if not exists photobooth_participants_user_session_idx
  on public.photobooth_participants (user_id, session_id);
create index if not exists photobooth_photos_session_round_idx
  on public.photobooth_photos (session_id, round_index, created_at);

-- ---------------------------------------------------------------------------
-- 2. Timestamp, membership, and storage helper functions.
-- ---------------------------------------------------------------------------

create or replace function public.photobooth_touch_session()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists photobooth_sessions_touch_updated_at
  on public.photobooth_sessions;
create trigger photobooth_sessions_touch_updated_at
before update on public.photobooth_sessions
for each row execute function public.photobooth_touch_session();

create or replace function public.is_photobooth_participant(
  p_session_id uuid,
  p_user_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select p_user_id is not null and exists (
    select 1
    from public.photobooth_participants participant
    where participant.session_id = p_session_id
      and participant.user_id = p_user_id
  );
$$;

create or replace function public.can_read_photobooth_storage(
  p_name text,
  p_user_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select p_user_id is not null and exists (
    select 1
    from public.photobooth_photos photo
    join public.photobooth_participants participant
      on participant.session_id = photo.session_id
    where photo.storage_path = p_name
      and participant.user_id = p_user_id
  );
$$;

create or replace function public.can_write_photobooth_storage(
  p_name text,
  p_user_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  parts text[];
begin
  if p_user_id is null then
    return false;
  end if;

  parts := string_to_array(p_name, '/');
  if array_length(parts, 1) <> 3
      or parts[1] <> p_user_id::text
      or parts[3] !~ '^round-[0-4]\.png$' then
    return false;
  end if;

  return exists (
    select 1
    from public.photobooth_participants participant
    where participant.session_id::text = parts[2]
      and participant.user_id = p_user_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Maximum two participants and atomic create-or-join with stale cleanup.
-- ---------------------------------------------------------------------------

create or replace function public.enforce_photobooth_participant_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  participant_count integer;
begin
  perform 1
  from public.photobooth_sessions
  where id = new.session_id
  for update;
  if not found then
    raise exception 'Photo Booth session not found.';
  end if;

  select count(*)
  into participant_count
  from public.photobooth_participants
  where session_id = new.session_id;

  if participant_count >= 2 then
    raise exception 'This Photo Booth already has two participants.';
  end if;
  return new;
end;
$$;

drop trigger if exists photobooth_participants_limit_two
  on public.photobooth_participants;
create trigger photobooth_participants_limit_two
before insert on public.photobooth_participants
for each row execute function public.enforce_photobooth_participant_limit();

create or replace function public.create_or_join_photobooth_session(
  p_frame_style text
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.photobooth_sessions%rowtype;
  new_session_id uuid;
  participant_count integer;
  caller_is_joined boolean;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to start the Photo Booth.';
  end if;
  if coalesce(p_frame_style, '') not in ('vintage', 'sakura', 'midnight') then
    raise exception 'The selected photo frame is not supported.';
  end if;

  perform pg_advisory_xact_lock(hashtext('photobooth-active-session'));

  -- Stale in-progress booths cannot trap future couples in an old room.
  update public.photobooth_sessions
  set status = 'cancelled',
      capture_at = null
  where status in ('lobby', 'countdown', 'capturing')
    and updated_at < clock_timestamp() - interval '30 minutes';

  select session.*
  into result
  from public.photobooth_sessions session
  where session.status in ('lobby', 'countdown', 'capturing')
  order by session.updated_at desc, session.created_at desc
  limit 1
  for update;

  if found then
    select count(*)
    into participant_count
    from public.photobooth_participants
    where session_id = result.id;

    select exists (
      select 1
      from public.photobooth_participants
      where session_id = result.id
        and user_id = auth.uid()
    )
    into caller_is_joined;

    if caller_is_joined then
      if result.status = 'lobby' then
        update public.photobooth_participants
        set frame_style = p_frame_style
        where session_id = result.id
          and user_id = auth.uid();
      end if;

      update public.photobooth_sessions
      set updated_at = clock_timestamp()
      where id = result.id
      returning * into result;
      return result;
    end if;

    if result.status <> 'lobby' or participant_count >= 2 then
      raise exception 'The active Photo Booth is already full or has started.';
    end if;

    insert into public.photobooth_participants (session_id, user_id, frame_style)
    values (result.id, auth.uid(), p_frame_style);

    update public.photobooth_sessions
    set updated_at = clock_timestamp()
    where id = result.id
    returning * into result;
    return result;
  end if;

  new_session_id := gen_random_uuid();
  insert into public.photobooth_sessions (
    id,
    room_name,
    created_by,
    status,
    current_round,
    total_rounds
  )
  values (
    new_session_id,
    'photobooth-' || new_session_id::text,
    auth.uid(),
    'lobby',
    0,
    5
  )
  returning * into result;

  insert into public.photobooth_participants (session_id, user_id, frame_style)
  values (result.id, auth.uid(), p_frame_style);

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Ready state, synchronized countdown, and camera capture RPCs.
-- ---------------------------------------------------------------------------

create or replace function public.set_photobooth_participant_ready(
  p_session_id uuid,
  p_ready boolean
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.photobooth_sessions%rowtype;
  participant_count integer;
  ready_count integer;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to update Ready.';
  end if;

  select *
  into result
  from public.photobooth_sessions
  where id = p_session_id
  for update;
  if not found then
    raise exception 'Photo Booth session not found.';
  end if;
  if not public.is_photobooth_participant(result.id, auth.uid()) then
    raise exception 'You are not a participant in this Photo Booth.';
  end if;

  -- A delayed duplicate Ready request after countdown has begun is harmless.
  if p_ready and result.status in ('countdown', 'capturing') then
    return result;
  end if;
  if result.status <> 'lobby' then
    raise exception 'Ready can only be changed while the booth is in the lobby.';
  end if;

  update public.photobooth_participants
  set is_ready = p_ready
  where session_id = result.id
    and user_id = auth.uid();

  select count(*), count(*) filter (where is_ready)
  into participant_count, ready_count
  from public.photobooth_participants
  where session_id = result.id;

  if participant_count = 2 and ready_count = 2 then
    update public.photobooth_sessions
    set status = 'countdown',
        current_round = 0,
        capture_at = clock_timestamp() + interval '5 seconds'
    where id = result.id
    returning * into result;
  else
    update public.photobooth_sessions
    set status = 'lobby',
        current_round = 0,
        capture_at = null
    where id = result.id
    returning * into result;
  end if;

  return result;
end;
$$;

create or replace function public.begin_photobooth_capture(
  p_session_id uuid,
  p_round_index integer
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.photobooth_sessions%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to capture a Photo Booth round.';
  end if;

  select *
  into result
  from public.photobooth_sessions
  where id = p_session_id
  for update;
  if not found then
    raise exception 'Photo Booth session not found.';
  end if;
  if not public.is_photobooth_participant(result.id, auth.uid()) then
    raise exception 'You are not a participant in this Photo Booth.';
  end if;
  if result.current_round <> p_round_index then
    raise exception 'This Photo Booth round is no longer active.';
  end if;
  if result.status = 'capturing' then
    return result;
  end if;
  if result.status <> 'countdown' then
    raise exception 'The Photo Booth is not counting down.';
  end if;
  if result.capture_at is null or result.capture_at > clock_timestamp() then
    raise exception 'The synchronized countdown has not finished.';
  end if;

  update public.photobooth_sessions
  set status = 'capturing'
  where id = result.id
  returning * into result;
  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Photo validation and database-owned five-round progression.
-- ---------------------------------------------------------------------------

create or replace function public.validate_photobooth_photo_upload()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.photobooth_sessions%rowtype;
begin
  if auth.uid() is null or new.user_id <> auth.uid() then
    raise exception 'A Photo Booth photo must belong to the signed-in user.';
  end if;
  if not public.is_photobooth_participant(new.session_id, auth.uid()) then
    raise exception 'You are not a participant in this Photo Booth.';
  end if;

  if tg_op = 'UPDATE' and (
    old.session_id is distinct from new.session_id or
    old.round_index is distinct from new.round_index or
    old.user_id is distinct from new.user_id
  ) then
    raise exception 'A Photo Booth photo cannot be moved to another round.';
  end if;

  if tg_op = 'UPDATE' then
    return new;
  end if;

  select *
  into session_row
  from public.photobooth_sessions
  where id = new.session_id
  for update;
  if not found then
    raise exception 'Photo Booth session not found.';
  end if;
  if session_row.status <> 'capturing'
      or session_row.current_round <> new.round_index then
    raise exception 'The uploaded Photo Booth photo is not for the active round.';
  end if;
  return new;
end;
$$;

drop trigger if exists photobooth_photos_validate_upload
  on public.photobooth_photos;
create trigger photobooth_photos_validate_upload
before insert or update on public.photobooth_photos
for each row execute function public.validate_photobooth_photo_upload();

create or replace function public.advance_photobooth_session_after_photo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.photobooth_sessions%rowtype;
  upload_count integer;
begin
  -- The row lock makes this idempotent when both devices upsert together.
  select *
  into session_row
  from public.photobooth_sessions
  where id = new.session_id
  for update;
  if not found then
    return new;
  end if;

  if session_row.status <> 'capturing'
      or session_row.current_round <> new.round_index then
    return new;
  end if;

  select count(distinct photo.user_id)
  into upload_count
  from public.photobooth_photos photo
  join public.photobooth_participants participant
    on participant.session_id = photo.session_id
   and participant.user_id = photo.user_id
  where photo.session_id = session_row.id
    and photo.round_index = session_row.current_round;

  if upload_count < 2 then
    return new;
  end if;

  if session_row.current_round >= session_row.total_rounds - 1 then
    update public.photobooth_sessions
    set status = 'complete',
        capture_at = null
    where id = session_row.id
      and status = 'capturing'
      and current_round = session_row.current_round;
  else
    update public.photobooth_sessions
    set current_round = session_row.current_round + 1,
        status = 'countdown',
        capture_at = clock_timestamp() + interval '5 seconds'
    where id = session_row.id
      and status = 'capturing'
      and current_round = session_row.current_round;
  end if;

  return new;
end;
$$;

drop trigger if exists photobooth_photos_advance_session
  on public.photobooth_photos;
create trigger photobooth_photos_advance_session
after insert or update on public.photobooth_photos
for each row execute function public.advance_photobooth_session_after_photo();

-- ---------------------------------------------------------------------------
-- 6. Cancellation, current-session lookup, and completed gallery RPCs.
-- ---------------------------------------------------------------------------

create or replace function public.cancel_photobooth_session(
  p_session_id uuid
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.photobooth_sessions%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to cancel the Photo Booth.';
  end if;

  select *
  into result
  from public.photobooth_sessions
  where id = p_session_id
  for update;
  if not found then
    raise exception 'Photo Booth session not found.';
  end if;
  if not public.is_photobooth_participant(result.id, auth.uid()) then
    raise exception 'You are not a participant in this Photo Booth.';
  end if;
  if result.status in ('complete', 'cancelled') then
    return result;
  end if;

  update public.photobooth_sessions
  set status = 'cancelled',
      capture_at = null
  where id = result.id
  returning * into result;
  return result;
end;
$$;

create or replace function public.get_current_photobooth_session()
returns setof public.photobooth_sessions
language sql
security invoker
stable
set search_path = public
as $$
  select session.*
  from public.photobooth_sessions session
  join public.photobooth_participants participant
    on participant.session_id = session.id
  where participant.user_id = auth.uid()
    and session.status in ('lobby', 'countdown', 'capturing')
  order by session.updated_at desc, session.created_at desc
  limit 1;
$$;

create or replace function public.list_completed_photobooth_sessions(
  p_frame_style text default null,
  p_start_at timestamptz default null,
  p_end_at timestamptz default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  room_name text,
  created_by uuid,
  status text,
  current_round integer,
  total_rounds integer,
  capture_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  participant_frame_style text
)
language sql
security invoker
set search_path = public
as $$
  select
    session.id,
    session.room_name,
    session.created_by,
    session.status,
    session.current_round,
    session.total_rounds,
    session.capture_at,
    session.created_at,
    session.updated_at,
    participant.frame_style as participant_frame_style
  from public.photobooth_sessions session
  join public.photobooth_participants participant
    on participant.session_id = session.id
  where participant.user_id = auth.uid()
    and session.status = 'complete'
    and (p_frame_style is null or participant.frame_style = p_frame_style)
    and (p_start_at is null or session.created_at >= p_start_at)
    and (p_end_at is null or session.created_at < p_end_at)
  order by session.created_at desc
  limit greatest(1, least(coalesce(p_limit, 20), 50))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- ---------------------------------------------------------------------------
-- 7. RLS and private photo storage.
-- ---------------------------------------------------------------------------

alter table public.photobooth_sessions enable row level security;
alter table public.photobooth_participants enable row level security;
alter table public.photobooth_photos enable row level security;
alter table public.photobooth_photo_duplicate_backup enable row level security;

revoke all on table public.photobooth_sessions from anon, authenticated;
revoke all on table public.photobooth_participants from anon, authenticated;
revoke all on table public.photobooth_photos from anon, authenticated;
revoke all on table public.photobooth_photo_duplicate_backup from anon, authenticated;
grant select on table public.photobooth_sessions to authenticated;
grant select on table public.photobooth_participants to authenticated;
grant select, insert, update on table public.photobooth_photos to authenticated;

drop policy if exists "Photo Booth participants can read sessions"
  on public.photobooth_sessions;
drop policy if exists "Photo Booth participants can read participants"
  on public.photobooth_participants;
drop policy if exists "Photo Booth participants can read photos"
  on public.photobooth_photos;
drop policy if exists "Photo Booth participants can insert own photos"
  on public.photobooth_photos;
drop policy if exists "Photo Booth participants can update own photos"
  on public.photobooth_photos;

create policy "Photo Booth participants can read sessions"
  on public.photobooth_sessions
  for select
  to authenticated
  using (public.is_photobooth_participant(id, auth.uid()));

create policy "Photo Booth participants can read participants"
  on public.photobooth_participants
  for select
  to authenticated
  using (public.is_photobooth_participant(session_id, auth.uid()));

create policy "Photo Booth participants can read photos"
  on public.photobooth_photos
  for select
  to authenticated
  using (public.is_photobooth_participant(session_id, auth.uid()));

create policy "Photo Booth participants can insert own photos"
  on public.photobooth_photos
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.is_photobooth_participant(session_id, auth.uid())
    and storage_path = auth.uid()::text || '/' || session_id::text ||
      '/round-' || round_index::text || '.png'
  );

create policy "Photo Booth participants can update own photos"
  on public.photobooth_photos
  for update
  to authenticated
  using (
    user_id = auth.uid()
    and public.is_photobooth_participant(session_id, auth.uid())
  )
  with check (
    user_id = auth.uid()
    and public.is_photobooth_participant(session_id, auth.uid())
    and storage_path = auth.uid()::text || '/' || session_id::text ||
      '/round-' || round_index::text || '.png'
  );

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'photobooth-photos',
  'photobooth-photos',
  false,
 10485760,
  array['image/png']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload photobooth files" on storage.objects;
drop policy if exists "Users can update their photobooth files" on storage.objects;
drop policy if exists "Authenticated users can read photobooth files" on storage.objects;
drop policy if exists "Photo Booth participants can read files" on storage.objects;
drop policy if exists "Photo Booth participants can upload files" on storage.objects;
drop policy if exists "Photo Booth participants can update files" on storage.objects;
drop policy if exists "Photo Booth participants can delete files" on storage.objects;

create policy "Photo Booth participants can read files"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'photobooth-photos'
    and public.can_read_photobooth_storage(name, auth.uid())
  );

create policy "Photo Booth participants can upload files"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'photobooth-photos'
    and public.can_write_photobooth_storage(name, auth.uid())
  );

create policy "Photo Booth participants can update files"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'photobooth-photos'
    and public.can_write_photobooth_storage(name, auth.uid())
  )
  with check (
    bucket_id = 'photobooth-photos'
    and public.can_write_photobooth_storage(name, auth.uid())
  );

create policy "Photo Booth participants can delete files"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'photobooth-photos'
    and public.can_write_photobooth_storage(name, auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 8. Realtime publication and RPC permissions.
-- ---------------------------------------------------------------------------

alter table public.photobooth_sessions replica identity full;
alter table public.photobooth_participants replica identity full;
alter table public.photobooth_photos replica identity full;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'photobooth_sessions'
    ) then
      alter publication supabase_realtime add table public.photobooth_sessions;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'photobooth_participants'
    ) then
      alter publication supabase_realtime add table public.photobooth_participants;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'photobooth_photos'
    ) then
      alter publication supabase_realtime add table public.photobooth_photos;
    end if;
  else
    raise notice 'supabase_realtime publication was not found.';
  end if;
end;
$$;

-- Revoke PUBLIC and anon first for every Photo Booth RPC/helper. Only the
-- required authenticated client calls are granted afterwards.
revoke execute on function public.photobooth_touch_session() from public, anon;
revoke execute on function public.is_photobooth_participant(uuid, uuid) from public, anon;
revoke execute on function public.can_read_photobooth_storage(text, uuid) from public, anon;
revoke execute on function public.can_write_photobooth_storage(text, uuid) from public, anon;
revoke execute on function public.enforce_photobooth_participant_limit() from public, anon;
revoke execute on function public.create_or_join_photobooth_session(text) from public, anon;
revoke execute on function public.set_photobooth_participant_ready(uuid, boolean) from public, anon;
revoke execute on function public.begin_photobooth_capture(uuid, integer) from public, anon;
revoke execute on function public.validate_photobooth_photo_upload() from public, anon;
revoke execute on function public.advance_photobooth_session_after_photo() from public, anon;
revoke execute on function public.cancel_photobooth_session(uuid) from public, anon;
revoke execute on function public.get_current_photobooth_session() from public, anon;
revoke execute on function public.list_completed_photobooth_sessions(
  text,
  timestamptz,
  timestamptz,
  integer,
  integer
) from public, anon;

grant execute on function public.is_photobooth_participant(uuid, uuid)
  to authenticated;
grant execute on function public.can_read_photobooth_storage(text, uuid)
  to authenticated;
grant execute on function public.can_write_photobooth_storage(text, uuid)
  to authenticated;
grant execute on function public.create_or_join_photobooth_session(text)
  to authenticated;
grant execute on function public.set_photobooth_participant_ready(uuid, boolean)
  to authenticated;
grant execute on function public.begin_photobooth_capture(uuid, integer)
  to authenticated;
grant execute on function public.cancel_photobooth_session(uuid)
  to authenticated;
grant execute on function public.get_current_photobooth_session()
  to authenticated;
grant execute on function public.list_completed_photobooth_sessions(
  text,
  timestamptz,
  timestamptz,
  integer,
  integer
) to authenticated;

commit;
