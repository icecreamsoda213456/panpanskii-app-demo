-- Demo-only content for the portfolio preview.
-- Run after the chat and cozy garden schema scripts.

do $$
declare
  first_user uuid;
  second_user uuid;
  first_name text;
  second_name text;
  first_mascot text;
  second_mascot text;
  demo_day text;
begin
  select u.id,
         coalesce(p.username, 'Panda'),
         coalesce(p.avatar, 'panda')
    into first_user, first_name, first_mascot
    from auth.users u
    left join public.profiles p on p.id = u.id
   order by u.created_at
   limit 1;

  select u.id,
         coalesce(p.username, 'Koala'),
         coalesce(p.avatar, 'koala')
    into second_user, second_name, second_mascot
    from auth.users u
    left join public.profiles p on p.id = u.id
   where u.id <> first_user
   order by u.created_at
   limit 1;

  if first_user is null then
    raise notice 'No authenticated accounts found; demo data was not inserted.';
    return;
  end if;

  second_user := coalesce(second_user, first_user);
  second_name := coalesce(second_name, first_name);
  second_mascot := case when second_user = first_user then first_mascot else second_mascot end;
  demo_day := to_char(
    (now() at time zone 'Asia/Manila' - interval '6 hours')::date,
    'YYYY-MM-DD'
  );

  insert into public.private_chat_messages
    (room_id, user_id, username, mascot, message, created_at)
  select 'main', first_user, first_name, first_mascot,
         'Good morning, my favorite person. I left coffee and a little hug here.',
         now() - interval '42 minutes'
   where not exists (
     select 1 from public.private_chat_messages
      where room_id = 'main'
        and message = 'Good morning, my favorite person. I left coffee and a little hug here.'
   );

  insert into public.private_chat_messages
    (room_id, user_id, username, mascot, message, created_at)
  select 'main', second_user, second_name, second_mascot,
         'I found it! Adding it to our tiny list of cozy wins for today.',
         now() - interval '35 minutes'
   where not exists (
     select 1 from public.private_chat_messages
      where room_id = 'main'
        and message = 'I found it! Adding it to our tiny list of cozy wins for today.'
   );

  insert into public.private_chat_messages
    (room_id, user_id, username, mascot, message, created_at)
  select 'main', first_user, first_name, first_mascot,
         'Tonight: garden check, one photo, and a tiny celebration?',
         now() - interval '18 minutes'
   where not exists (
     select 1 from public.private_chat_messages
      where room_id = 'main'
        and message = 'Tonight: garden check, one photo, and a tiny celebration?'
   );

  insert into public.cozy_garden_state
    (id, plant_type, growth, current_streak, longest_streak, total_harvests)
  values ('main', 'sunflower', 72, 4, 9, 2)
  on conflict (id) do update set
    growth = greatest(public.cozy_garden_state.growth, excluded.growth),
    current_streak = greatest(public.cozy_garden_state.current_streak, excluded.current_streak),
    longest_streak = greatest(public.cozy_garden_state.longest_streak, excluded.longest_streak),
    total_harvests = greatest(public.cozy_garden_state.total_harvests, excluded.total_harvests),
    updated_at = now();

  insert into public.cozy_garden_actions
    (day_key, user_id, username, mascot, action)
  values
    (demo_day, first_user, first_name, first_mascot, 'water'),
    (demo_day, second_user, second_name, second_mascot, 'water')
  on conflict (day_key, user_id) do nothing;
end $$;