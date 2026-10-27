# Organizer Setup

How to get the workshop backend live on the CodeJam Supabase org and reachable from `codejam.mcgilleus.ca`.

**End result:** attendees use `https://codejam.mcgilleus.ca/workshop/api` as their Supabase URL, and `https://codejam.mcgilleus.ca/workshop` sends them to the README.

---

## 1. Create a separate Supabase project

Use a **new project**, not the website's existing one. The workshop tables are open for anyone to write to, so they shouldn't share a database with registrations or anything else real.

1. Go to <https://supabase.com/dashboard> and open the CodeJam org.
2. **Check the plan first.** The Free plan allows 2 active free projects, and the org already seems to have two (the website's and the functions API). If you hit the limit, pick one of:
   - Pause a project you don't need right now (*Project Settings → General → Pause project*).
   - Upgrade the org to Pro. Each extra project's compute is billed hourly, so a project that only exists for the workshop week costs a few dollars.
   - Create the project in a separate personal org.
3. **New project:**
   - **Name:** `frontend-workshop`
   - **Database password:** use *Generate*, then put it in the team password manager. You need it once for `link`, and it's a pain to reset.
   - **Region:** *Canada (Central)*, which is Montréal and gives the lowest latency in the room.
   - Leave the security options at their defaults. The migration grants API access explicitly, so it works either way.
4. Wait about 2 minutes for it to finish provisioning.
5. Note the **project ref**, the `abcd…` part of `https://abcd….supabase.co`. It's on the project's home page and under *Project Settings → General*.

> Free projects pause after 7 days of no traffic. Create it within a week of the workshop or keep it warm, and check it's awake the morning of.

## 2. Push the schema and sample data

Whoever does this needs to be a member of the org with the Owner, Administrator or Developer role.

```sh
git clone https://github.com/mcgillcodejam/frontend-workshop.git
cd frontend-workshop

npx supabase login                              # opens the browser
npx supabase link --project-ref <project-ref>   # asks for the DB password from step 1
npx supabase db push --include-seed             # creates tables, filter, sample data
```

Check that it worked. Get the **publishable key** (`sb_publishable_…`) from *Project Settings → API Keys*, then run:

```sh
curl "https://<project-ref>.supabase.co/rest/v1/products?select=name&limit=3" \
  -H "apikey: <publishable-key>"
```

You should get three product names. You can also browse the data in the dashboard's **Table Editor**.

The publishable key is safe to hand out. It's designed to live in frontend code, and the database policies control what it can do. **Never** share the secret key (`sb_secret_…`), the legacy `service_role` key, or the DB password.

## 3. Point the CodeJam website at it (Netlify)

The website is on Netlify, which can **proxy** a path to another server. This rewrite has to be a proxy (status `200`), **not** a redirect (`301`/`302`). Browsers send a CORS preflight before API calls, and a preflight can't follow a redirect. Redirects also turn `POST`s into `GET`s. A proxy keeps the codejam URL and passes the request through to Supabase unchanged.

In the **`codejam13-website`** repo, edit `public/_redirects`. The new rules must go **above** the existing SPA fallback, because Netlify uses the first rule that matches:

```
# Frontend workshop: API proxy to Supabase, and a short link to the attendee guide
/workshop/api/*  https://<project-ref>.supabase.co/:splat  200
/workshop        https://github.com/mcgillcodejam/frontend-workshop#for-attendees  302

/* /index.html 200
```

Ship it to `prod` the way you normally would. Every PR also gets a Netlify deploy preview, which is a good place to test it first.

**Test it** (swap in the preview URL to test before merging):

```sh
curl "https://codejam.mcgilleus.ca/workshop/api/rest/v1/products?select=name&limit=3" \
  -H "apikey: <publishable-key>"
```

Attendees then use:

```js
const URL = "https://codejam.mcgilleus.ca/workshop/api";
const KEY = "<publishable-key>";
```

This works with both the plain `fetch` examples and `supabase-js` from the README.

**One catch: realtime.** Netlify can't proxy WebSockets, so live subscriptions (`supabase.channel(...)`) only work against the direct `https://<project-ref>.supabase.co` URL. Anyone using realtime should create their client with that URL instead.

### Alternative: a real custom domain

Supabase can serve a project directly from a domain like `api.codejam.mcgilleus.ca`, realtime included. It costs more and takes more setup:
- It needs a paid org (Pro) plus the Custom Domain add-on, about $10/month.
- It needs a CNAME and TXT record on `mcgilleus.ca`, which EUS controls.
- It's set up in *Project Settings → Custom Domains*.

That's overkill for a one-day workshop, so the Netlify proxy is the recommended route.

## 4. Before the workshop

- [ ] Fill the real URL and publishable key into the README's *For attendees* section, so people can copy-paste.
- [ ] Hit `/workshop/api/rest/v1/posts?limit=1` the morning of to wake the project.
- [ ] Have the dashboard open on *SQL Editor* with `supabase/reset.sql` ready, in case things get messy mid-session.

## 5. After the workshop

- Run `supabase/reset.sql` to clear attendee data, or pause or delete the project if it won't be reused.
- Remove the two `/workshop` lines from `_redirects` if the project goes away. Otherwise the URL returns errors.
