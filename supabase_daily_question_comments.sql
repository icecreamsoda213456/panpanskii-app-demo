begin;

-- Shared answer thread for each Daily Question day.
create table if not exists public.daily_question_comments (
  id uuid primary key default gen_random_uuid(),
  day_key text not null
    check (day_key ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null check (char_length(trim(username)) between 1 and 80),
  mascot text not null check (mascot in ('panda', 'koala')),
  message text not null
    check (char_length(trim(message)) between 1 and 600),
  created_at timestamptz not null default clock_timestamp()
);

create index if not exists daily_question_comments_day_created_idx
  on public.daily_question_comments (day_key, created_at);

alter table public.daily_question_comments enable row level security;
alter table public.daily_question_comments replica identity full;

drop policy if exists "Authenticated users can read daily question comments"
  on public.daily_question_comments;
drop policy if exists "Users can create their own daily question comments"
  on public.daily_question_comments;
drop policy if exists "Users can delete their own daily question comments"
  on public.daily_question_comments;

create policy "Authenticated users can read daily question comments"
  on public.daily_question_comments
  for select
  to authenticated
  using (true);

create policy "Users can create their own daily question comments"
  on public.daily_question_comments
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can delete their own daily question comments"
  on public.daily_question_comments
  for delete
  to authenticated
  using (auth.uid() = user_id);

revoke all on table public.daily_question_comments from anon;
grant select, insert, delete on table public.daily_question_comments
  to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'daily_question_comments'
  ) then
    alter publication supabase_realtime
      add table public.daily_question_comments;
  end if;
end
$$;

commit;
