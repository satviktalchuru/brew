-- ============================================================
-- Avatar storage
-- Run this in: Supabase Dashboard → SQL Editor → New Query
--
-- Profile pictures previously existed only as an in-memory UIImage on the
-- device that took the photo — never uploaded anywhere, never synced to
-- other devices or shown to friends. This adds a real storage path:
-- a public "avatars" bucket (one file per user, at {user_id}/avatar.jpg)
-- plus an avatar_url column on profiles so friends can actually see it.
-- ============================================================

alter table profiles add column if not exists avatar_url text;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Public bucket: anyone can read (avatars are meant to be visible to
-- friends/whoever views a profile), but only a user can write to their
-- own folder within the bucket.
create policy "Avatar images are publicly accessible"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can update their own avatar"
  on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can delete their own avatar"
  on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- suggested_friends() also needs to return avatar_url now that it exists,
-- so the picks shown there aren't stuck on initials either. Postgres
-- requires dropping a table-returning function before changing its
-- output columns.
drop function if exists suggested_friends(int);

create or replace function suggested_friends(limit_count int default 10)
returns table (
  id uuid,
  username text,
  display_name text,
  is_public boolean,
  appear_in_chats boolean,
  avatar_url text,
  mutual_count bigint
)
language sql
security definer
set search_path = public
stable
as $$
  with my_friends as (
    select case when requester_id = auth.uid() then addressee_id else requester_id end as friend_id
    from friendships
    where status = 'accepted' and (requester_id = auth.uid() or addressee_id = auth.uid())
  ),
  friends_of_friends as (
    select
      case when f.requester_id = mf.friend_id then f.addressee_id else f.requester_id end as candidate_id
    from friendships f
    join my_friends mf on (f.requester_id = mf.friend_id or f.addressee_id = mf.friend_id)
    where f.status = 'accepted'
  ),
  already_connected as (
    select addressee_id as other_id from friendships where requester_id = auth.uid()
    union
    select requester_id as other_id from friendships where addressee_id = auth.uid()
  ),
  blocked_either_way as (
    select blocked_id as other_id from blocked_users where blocker_id = auth.uid()
    union
    select blocker_id as other_id from blocked_users where blocked_id = auth.uid()
  )
  select p.id, p.username, p.display_name, p.is_public, p.appear_in_chats, p.avatar_url, count(*) as mutual_count
  from friends_of_friends fof
  join profiles p on p.id = fof.candidate_id
  where fof.candidate_id <> auth.uid()
    and fof.candidate_id not in (select other_id from already_connected)
    and fof.candidate_id not in (select other_id from blocked_either_way)
    and p.is_public = true
  group by p.id, p.username, p.display_name, p.is_public, p.appear_in_chats, p.avatar_url
  order by mutual_count desc, p.username asc
  limit greatest(limit_count, 0);
$$;

grant execute on function suggested_friends(int) to authenticated;
