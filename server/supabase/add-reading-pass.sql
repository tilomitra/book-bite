-- Reading pass: 5 free full books per account, 5 more for each side of an invite.
-- Apply in the Supabase SQL editor. Only the server (service key) reads or writes these tables.

-- One invite code per user, made on first use
create table if not exists referral_codes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  created_at timestamptz not null default now()
);

-- A friend who joined with a code. Each account can use one code, once.
-- Deleting either account removes the row, so a deleted-and-recreated account can't farm credit.
create table if not exists referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references auth.users(id) on delete cascade,
  referred_id uuid not null unique references auth.users(id) on delete cascade,
  code text not null,
  created_at timestamptz not null default now(),
  check (referrer_id <> referred_id)
);
create index if not exists referrals_referrer_idx on referrals(referrer_id);

-- Books a user opened in full. An unlocked book stays unlocked.
create table if not exists book_unlocks (
  user_id uuid not null references auth.users(id) on delete cascade,
  book_id uuid not null references books(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, book_id)
);

alter table referral_codes enable row level security;
alter table referrals enable row level security;
alter table book_unlocks enable row level security;

-- Unlocks books in order while the user has books left; returns every requested book that is now
-- unlocked (new or earlier). The advisory lock stops two requests from both taking the last book.
create or replace function unlock_books(p_user_id uuid, p_book_ids uuid[], p_limit int)
returns setof uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  used int;
  b uuid;
begin
  perform pg_advisory_xact_lock(hashtext('book_unlocks:' || p_user_id::text));
  select count(*) into used from book_unlocks where user_id = p_user_id;
  foreach b in array p_book_ids loop
    if exists (select 1 from book_unlocks where user_id = p_user_id and book_id = b) then
      return next b;
    elsif used < p_limit and exists (select 1 from books where id = b) then
      insert into book_unlocks (user_id, book_id) values (p_user_id, b);
      used := used + 1;
      return next b;
    end if;
  end loop;
end;
$$;

revoke execute on function unlock_books(uuid, uuid[], int) from public, anon, authenticated;
