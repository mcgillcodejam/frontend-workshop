-- Profanity filter: masks banned words with **** in free-text columns before they're saved,
-- and rejects usernames containing them. Applies to every write path (REST, supabase-js, SQL).
--
-- The word list lives in the `private` schema, which the REST API doesn't expose, so attendees
-- can't read or edit it. Add words from Studio (Table Editor -> schema "private") or SQL:
--   insert into private.banned_words (word, match_prefix) values ('frick', true);
-- Matching is whole-word and case-insensitive. match_prefix = true also catches suffixed forms
-- (fuck -> fucking, fucker); leave it false for words that start innocent ones (ass -> assignment).
-- New words only affect future writes, not rows already saved.

create schema if not exists private;

create table private.banned_words (
  word         text primary key check (word = lower(word) and word ~ '^[[:alpha:][:digit:] ]+$'),
  match_prefix boolean not null default false
);

insert into private.banned_words (word, match_prefix) values
  -- English
  ('fuck', true), ('motherfuck', true), ('shit', true), ('bullshit', true), ('bitch', true),
  ('cunt', true), ('asshole', true), ('dickhead', true), ('wank', true), ('twat', true),
  ('slut', true), ('whore', true), ('piss', true), ('douche', true),
  ('ass', false), ('arse', false), ('dick', false), ('dicks', false), ('cock', false),
  ('cocks', false), ('pussy', false), ('pussies', false), ('bastard', false), ('bastards', false),
  ('bollocks', false), ('jackass', false), ('dumbass', false), ('tits', false), ('titty', false),
  -- Slurs
  ('nigger', true), ('nigga', true), ('fag', true), ('retard', true), ('tranny', true),
  ('chink', false), ('chinks', false), ('spic', false), ('spics', false), ('kike', false),
  ('kikes', false), ('dyke', false), ('dykes', false), ('coon', false), ('coons', false),
  ('wetback', true),
  -- French / Québécois
  ('tabarnak', true), ('tabarnac', true), ('tabarnaque', true), ('câlisse', true),
  ('calisse', true), ('criss', false), ('crisse', false), ('osti', false), ('ostie', false),
  ('esti', false), ('merde', false), ('putain', true), ('connard', true), ('connasse', true),
  ('salope', true), ('enculé', true), ('encule', true);

-- Replace each banned word in `input` with ****.
create function private.censor(input text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  w      record;
  result text := input;
begin
  if input is null then
    return null;
  end if;

  for w in select word, match_prefix from private.banned_words loop
    result := regexp_replace(
      result,
      '\m' || w.word || case when w.match_prefix then '\w*' else '' end || '\M',
      '****',
      'gi'
    );
  end loop;

  return result;
end
$$;

-- Trigger: censor the columns passed as trigger arguments.
create function private.censor_columns()
returns trigger
language plpgsql
security definer -- callers (anon) can't access the private schema
set search_path = ''
as $$
declare
  col     text;
  patched jsonb := '{}';
begin
  foreach col in array tg_argv loop
    patched := patched || jsonb_build_object(col, private.censor(to_jsonb(new) ->> col));
  end loop;

  return jsonb_populate_record(new, patched);
end
$$;

-- Trigger: reject usernames containing a banned word (underscores count as word breaks).
create function private.check_username()
returns trigger
language plpgsql
security definer -- callers (anon) can't access the private schema
set search_path = ''
as $$
begin
  if private.censor(replace(new.username, '_', ' ')) <> replace(new.username, '_', ' ') then
    raise exception 'username "%" is not allowed', new.username
      using errcode = 'check_violation';
  end if;

  return new;
end
$$;

create trigger check_username
  before insert or update of username on public.profiles
  for each row execute function private.check_username();

create trigger censor_text
  before insert or update of display_name, bio on public.profiles
  for each row execute function private.censor_columns('display_name', 'bio');

create trigger censor_text
  before insert or update of body on public.posts
  for each row execute function private.censor_columns('body');

create trigger censor_text
  before insert or update of body on public.comments
  for each row execute function private.censor_columns('body');

create trigger censor_text
  before insert or update of name, description, category on public.products
  for each row execute function private.censor_columns('name', 'description', 'category');
