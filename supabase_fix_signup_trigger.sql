-- ============================================================
-- Fix: sign-up trigger was violating profiles_username_fmt
-- Run this in: Supabase Dashboard → SQL Editor → New Query
--
-- Root cause: handle_new_user() derived the username straight from the
-- email's local part (e.g. "John.Doe+test" from John.Doe+test@gmail.com),
-- but profiles_username_fmt (added in supabase_hardening.sql) requires
-- usernames to match ^[a-z0-9_]{3,20}$. Any email with a dot, plus sign,
-- uppercase letter, or a local part shorter than 3 / longer than 20 chars
-- failed silently as a generic "Database error saving new user" (500) on
-- signup — which blocked sign-up (and therefore sign-in) for most real
-- email addresses.
-- ============================================================

create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
declare
  base_username text;
  final_username text;
  suffix int := 0;
begin
  base_username := lower(regexp_replace(
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    '[^a-z0-9_]', '_', 'g'
  ));

  if char_length(base_username) < 3 then
    base_username := rpad(base_username, 3, '0');
  end if;
  base_username := left(base_username, 20);

  final_username := base_username;
  while exists (select 1 from profiles where username = final_username) loop
    suffix := suffix + 1;
    final_username := left(base_username, 20 - length(suffix::text) - 1) || '_' || suffix;
  end loop;

  insert into profiles (id, username, display_name)
  values (
    new.id,
    final_username,
    left(coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)), 60)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Trigger definition is unchanged, but re-create it defensively in case this
-- is being run standalone without supabase_schema.sql.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();
