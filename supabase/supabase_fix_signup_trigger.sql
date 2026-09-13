-- ============================================================
-- FIX v2: signup HTTP 500 "Database error saving new user"
-- Run this in: Supabase Dashboard → SQL Editor → New Query → Run
--
-- Live-tested diagnosis: EVERY signup fails (clean emails too), not just
-- dotted/uppercase ones. Root cause: handle_new_user() is SECURITY DEFINER
-- but never pins search_path. GoTrue's database connection uses a search
-- path that does not include "public", so the unqualified
-- `insert into profiles` can't find the table -> error inside the signup
-- transaction -> HTTP 500 for every account ever attempted.
--
-- This version:
--   1. pins `set search_path = public` and schema-qualifies every table
--   2. keeps the username sanitizer (lowercase -> strip -> 3..20 chars)
--   3. adds an exception fallback that writes a guaranteed-valid generated
--      handle, so a profile hiccup can never block signup again
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_username text;
  final_username text;
  suffix int := 0;
begin
  -- Lowercase FIRST, then strip disallowed chars: "John.Doe" -> "johndoe".
  base_username := regexp_replace(
    lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))),
    '[^a-z0-9_]', '', 'g'
  );

  if char_length(base_username) < 3 then
    base_username := rpad(coalesce(nullif(base_username, ''), 'brew'), 3, '0');
  end if;
  base_username := left(base_username, 20);

  final_username := base_username;
  while exists (select 1 from public.profiles where username = final_username) and suffix < 500 loop
    suffix := suffix + 1;
    final_username := left(base_username, 20 - length(suffix::text) - 1) || '_' || suffix;
  end loop;

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    final_username,
    left(coalesce(
      nullif(new.raw_user_meta_data->>'full_name', ''),
      nullif(split_part(new.email, '@', 1), ''),
      'Brew Fan'
    ), 60)
  )
  on conflict (id) do nothing;
  return new;

exception when others then
  -- Last-resort fallback: never let a profile problem block signup.
  -- 'brew_' + 12 hex chars = 17 chars, always matches ^[a-z0-9_]{3,20}$.
  insert into public.profiles (id, username, display_name)
  values (new.id, 'brew_' || substr(md5(new.id::text), 1, 12), 'Brew Fan')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
