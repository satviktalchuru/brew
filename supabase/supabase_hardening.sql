-- ============================================================
-- Brew App — Security Hardening (run AFTER supabase_schema.sql)
-- Supabase Dashboard → SQL Editor → New Query → Run
-- Closes the "client can write garbage / abusive values" hole.
-- Safe to re-run (guards with IF NOT EXISTS / DO blocks).
-- ============================================================

-- ---- drink_logs: bound scores and cap text lengths ----
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'drink_logs_elo_bounds') then
    alter table drink_logs add constraint drink_logs_elo_bounds
      check (elo_score >= 0 and elo_score <= 10000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'drink_logs_name_len') then
    alter table drink_logs add constraint drink_logs_name_len
      check (char_length(drink_name) between 1 and 120);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'drink_logs_notes_len') then
    alter table drink_logs add constraint drink_logs_notes_len
      check (char_length(notes) <= 2000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'drink_logs_method_len') then
    alter table drink_logs add constraint drink_logs_method_len
      check (char_length(brew_method) <= 32);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'drink_logs_roast_len') then
    alter table drink_logs add constraint drink_logs_roast_len
      check (char_length(roast) <= 32);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'drink_logs_would_order_len') then
    alter table drink_logs add constraint drink_logs_would_order_len
      check (char_length(would_order) <= 16);
  end if;
end $$;

-- ---- profiles: enforce sane username / display name ----
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_username_fmt') then
    alter table profiles add constraint profiles_username_fmt
      check (username ~ '^[a-z0-9_]{3,20}$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_display_len') then
    alter table profiles add constraint profiles_display_len
      check (char_length(display_name) between 1 and 60);
  end if;
end $$;

-- ---- likes: one like per user per log (idempotent guard) ----
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'likes_user_id_log_id_key') then
    alter table likes add constraint likes_user_id_log_id_key unique (user_id, log_id);
  end if;
end $$;

-- ---- friendships / chat_requests: can't befriend/chat yourself ----
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'chat_requests_distinct') then
    alter table chat_requests add constraint chat_requests_distinct
      check (requester_id <> addressee_id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'friendships_distinct') then
    alter table friendships add constraint friendships_distinct
      check (requester_id <> addressee_id);
  end if;
end $$;

-- ============================================================
-- NOTE — two more hardening steps are done in the Dashboard, not SQL:
--
-- 1. Auth rate limiting:
--    Authentication → Rate Limits → lower the sign-in / sign-up / OTP
--    limits from the defaults to throttle credential-stuffing.
--
-- 2. Leaked-password protection:
--    Authentication → Policies → enable "Check against HaveIBeenPwned".
-- ============================================================
