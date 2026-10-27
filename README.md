# CodeJam Workshop Backend

A ready-made Supabase backend so you can focus on the frontend. It has four tables full of sample data:

| Table      | What's in it                                                                      |
| ---------- | --------------------------------------------------------------------------------- |
| `profiles` | Users: `username`, `display_name`, `avatar_url`, `bio`                            |
| `posts`    | Social feed: `author_id`, `body`, `image_url`, `likes`                            |
| `comments` | Comments on posts: `post_id`, `author_id`, `body`                                 |
| `products` | Shop items: `name`, `description`, `category`, `price_cents`, `image_url`, `rating`, `stock` |

Every row also has `id`, `created_at`, and `is_seed`. You don't need to log in. Anyone can **read everything** and **create, edit, or delete** rows. The sample data (`is_seed: true`) is read-only so nobody can wipe it.

---

## For attendees

You need two values from the organizer:

```js
const URL = "https://<project>.supabase.co";  // the project URL
const KEY = "<publishable / anon key>";       // safe to put in frontend code
```

### Option A: plain `fetch`

```js
const api = (path, opts = {}) =>
  fetch(`${URL}/rest/v1/${path}`, {
    ...opts,
    headers: {
      apikey: KEY,
      "Content-Type": "application/json",
      Prefer: "return=representation", // send back the created/updated row
      ...opts.headers,
    },
  }).then((r) => r.json());

// Read
const products = await api("products?select=*&order=price_cents.asc");

// Feed with each post's author and comments in one request
const feed = await api(
  "posts?select=*,author:profiles(*),comments(*,author:profiles(username,avatar_url))&order=created_at.desc&limit=20"
);

// Create
const [me] = await api("profiles", {
  method: "POST",
  body: JSON.stringify({ username: "your_name", display_name: "Your Name" }),
});
await api("posts", {
  method: "POST",
  body: JSON.stringify({ author_id: me.id, body: "Hello CodeJam!" }),
});

// Update / delete (only works on rows you created, not the sample data)
await api(`posts?id=eq.42`, { method: "PATCH", body: JSON.stringify({ body: "edited" }) });
await api(`posts?id=eq.42`, { method: "DELETE" });

// Like any post, including sample posts. Returns the new like count.
await api("rpc/like_post", { method: "POST", body: JSON.stringify({ post_id: 1 }) });
```

### Option B: `supabase-js`

```js
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabase = createClient(URL, KEY);

const { data } = await supabase.from("products").select("*").eq("category", "tech");
await supabase.from("posts").insert({ author_id: me.id, body: "hi" });
await supabase.rpc("like_post", { post_id: 1 });

// Live updates: run code whenever someone creates a post
supabase
  .channel("feed")
  .on("postgres_changes", { event: "INSERT", schema: "public", table: "posts" }, (msg) =>
    console.log("new post!", msg.new)
  )
  .subscribe();
```

### Query cheat sheet (URL params)

| Want                    | Add to the URL                                  |
| ----------------------- | ----------------------------------------------- |
| Only some columns       | `select=id,name,price_cents`                    |
| Equals                  | `category=eq.tech`                              |
| Greater / less than     | `price_cents=lt.2000`, `rating=gte.4.5`         |
| Text search             | `name=ilike.*key*`                              |
| Sort                    | `order=created_at.desc`                         |
| Paginate                | `limit=10&offset=20`                            |
| Join related rows       | `select=*,author:profiles(*),comments(*)`       |
| Total count             | header `Prefer: count=exact` (returned in `Content-Range`) |

More: <https://postgrest.org/en/stable/references/api/tables_views.html>

### Gotchas

- Prices are in **cents**, so `12999` is $129.99.
- `username` must be 2–32 lowercase letters, digits, or `_`, and must be unique.
- Length limits: post body ≤ 1000 chars, comment ≤ 500, bio ≤ 280.
- Editing or deleting sample data quietly does nothing: you get back `[]`, not an error.
- There is no login, so anyone can edit or delete anyone else's rows. Be nice.
- There's a profanity filter. Swear words in posts, comments, bios and products are saved as `****`. Usernames containing one are rejected with a 400 error.
- Images: avatars come from `i.pravatar.cc` and everything else from `picsum.photos`. To add your own, use any image URL.

---

## For the organizer

### Deploy

See **[SETUP.md](SETUP.md)** for the full walkthrough: creating the project in the CodeJam Supabase org, pushing the schema, and proxying `codejam.mcgilleus.ca/workshop/api` to it via Netlify.

The short version:

```sh
npx supabase login
npx supabase link --project-ref <your-project-ref>
npx supabase db push --include-seed
```

If you'd rather not use the CLI, paste the files in `supabase/migrations/` (in order), then `supabase/seed.sql`, into the dashboard's **SQL Editor** and run them. Hand out the URL and the **publishable** key only.

### Reset after (or during) the workshop

Paste `supabase/reset.sql` into the SQL Editor. It deletes every row attendees created and restores the sample like counts.

### Profanity filter

The banned-word list is `private.banned_words`, which the API doesn't expose. To edit it, use Studio (Table Editor → schema `private`) or SQL:

```sql
insert into private.banned_words (word, match_prefix) values ('frick', true);
```

Matching is whole-word and ignores case. `match_prefix = true` also catches suffixed forms (`fuck` → `fucking`); leave it `false` for words that begin innocent ones (`ass` → `assignment`). Changes only apply to new writes. Leetspeak like `sh1t` isn't caught.

### Run locally (needs Docker)

```sh
npx supabase start      # API at http://127.0.0.1:54321, prints the keys
npx supabase db reset   # re-run the migration and seed from scratch
npx supabase stop
```
