-- ============================================================
-- Brew App — Wishlist ("Want to Try") table
-- Run in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

create table if not exists wishlist (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  shop_id     uuid,
  title       text not null check (char_length(title) between 1 and 120),
  note        text not null default '' check (char_length(note) <= 500),
  created_at  timestamptz not null default now()
);

alter table wishlist enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Users manage own wishlist (select)') then
    create policy "Users manage own wishlist (select)"
      on wishlist for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Users manage own wishlist (insert)') then
    create policy "Users manage own wishlist (insert)"
      on wishlist for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Users manage own wishlist (delete)') then
    create policy "Users manage own wishlist (delete)"
      on wishlist for delete using (auth.uid() = user_id);
  end if;
end $$;

create index if not exists wishlist_user_id_idx on wishlist(user_id);
