-- Workshop backend: open read/write tables for frontend practice.
-- Anyone with the anon key can read everything and create/edit/delete their own rows.
-- Rows marked is_seed = true (the starter data) are read-only so nobody can wipe the demo content.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id           uuid primary key default gen_random_uuid(),
  username     text not null unique check (username ~ '^[a-z0-9_]{2,32}$'),
  display_name text not null check (char_length(display_name) between 1 and 64),
  avatar_url   text check (char_length(avatar_url) <= 500),
  bio          text check (char_length(bio) <= 280),
  is_seed      boolean not null default false,
  created_at   timestamptz not null default now()
);

create table public.posts (
  id         bigint generated always as identity primary key,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 1000),
  image_url  text check (char_length(image_url) <= 500),
  likes      integer not null default 0 check (likes >= 0),
  is_seed    boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.comments (
  id         bigint generated always as identity primary key,
  post_id    bigint not null references public.posts (id) on delete cascade,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 500),
  is_seed    boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.products (
  id          bigint generated always as identity primary key,
  name        text not null check (char_length(name) between 1 and 100),
  description text check (char_length(description) <= 1000),
  category    text not null default 'misc' check (char_length(category) between 1 and 40),
  price_cents integer not null check (price_cents >= 0),
  image_url   text check (char_length(image_url) <= 500),
  rating      numeric(2, 1) check (rating between 0 and 5),
  stock       integer not null default 0 check (stock >= 0),
  is_seed     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index posts_author_id_idx    on public.posts (author_id);
create index posts_created_at_idx   on public.posts (created_at desc);
create index comments_post_id_idx   on public.comments (post_id);
create index comments_author_id_idx on public.comments (author_id);
create index products_category_idx  on public.products (category);

-- ---------------------------------------------------------------------------
-- Access: explicit grants (newer Supabase projects don't auto-expose tables)
-- ---------------------------------------------------------------------------

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete
  on public.profiles, public.posts, public.comments, public.products
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Row level security: read all, write anything that isn't seed data
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array['profiles', 'posts', 'comments', 'products'] loop
    execute format('alter table public.%I enable row level security', t);

    execute format(
      'create policy "anyone can read" on public.%I for select to anon, authenticated using (true)', t);
    execute format(
      'create policy "anyone can create" on public.%I for insert to anon, authenticated with check (not is_seed)', t);
    execute format(
      'create policy "anyone can edit non-seed rows" on public.%I for update to anon, authenticated using (not is_seed) with check (not is_seed)', t);
    execute format(
      'create policy "anyone can delete non-seed rows" on public.%I for delete to anon, authenticated using (not is_seed)', t);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- RPC: POST /rest/v1/rpc/like_post  {"post_id": 1}  -> new like count
-- Works on seed posts too, since likes are the one thing everyone should be able to bump.
-- ---------------------------------------------------------------------------

create function public.like_post(post_id bigint)
returns integer
language sql
security definer
set search_path = ''
as $$
  update public.posts
     set likes = likes + 1
   where id = like_post.post_id
  returning likes;
$$;

revoke execute on function public.like_post(bigint) from public;
grant execute on function public.like_post(bigint) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: let frontends subscribe to live inserts/updates
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.posts, public.comments, public.products;
  end if;
end
$$;
