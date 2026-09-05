alter table public.private_chat_messages replica identity full;
alter table public.send_love_letters replica identity full;
alter table public.thought_posts replica identity full;
alter table public.shared_journal_entries replica identity full;
alter table public.mood_statuses replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'private_chat_messages'
  ) then
    alter publication supabase_realtime
      add table public.private_chat_messages;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'send_love_letters'
  ) then
    alter publication supabase_realtime
      add table public.send_love_letters;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'thought_posts'
  ) then
    alter publication supabase_realtime
      add table public.thought_posts;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'shared_journal_entries'
  ) then
    alter publication supabase_realtime
      add table public.shared_journal_entries;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'mood_statuses'
  ) then
    alter publication supabase_realtime
      add table public.mood_statuses;
  end if;
end $$;
