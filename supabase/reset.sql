-- Wipe everything attendees created, keep the seed data, reset like counts.
-- Run in the Supabase SQL editor (runs as postgres, so RLS doesn't apply).

delete from public.comments where not is_seed;
delete from public.posts    where not is_seed;
delete from public.products where not is_seed;
delete from public.profiles where not is_seed;

-- Restore seed like counts (same formula as seed.sql).
with p as (select id, row_number() over (order by id) as i from public.posts where is_seed)
update public.posts set likes = (p.i * 37) % 180 from p where posts.id = p.id;
