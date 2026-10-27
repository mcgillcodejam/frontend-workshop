-- Starter data. Everything here is is_seed = true, so attendees can read it but not edit or delete it.
-- Images come from pravatar.cc (avatars) and picsum.photos (everything else); no uploads needed.

insert into public.profiles (username, display_name, avatar_url, bio, is_seed, created_at) values
  ('maya_codes',   'Maya Chen',         'https://i.pravatar.cc/300?u=maya_codes',   'Frontend dev. Tailwind evangelist. Coffee-powered.',          true, now() - interval '60 days'),
  ('leo_builds',   'Leo Tremblay',      'https://i.pravatar.cc/300?u=leo_builds',   'Shipping side projects faster than I finish them.',           true, now() - interval '58 days'),
  ('priya_ux',     'Priya Sharma',      'https://i.pravatar.cc/300?u=priya_ux',     'UX designer. I will fight you about border radius.',          true, now() - interval '55 days'),
  ('sam_ships',    'Sam Okafor',        'https://i.pravatar.cc/300?u=sam_ships',    'Full stack, half asleep.',                                    true, now() - interval '50 days'),
  ('ines_pixels',  'Inès Gagnon',       'https://i.pravatar.cc/300?u=ines_pixels',  'Illustrator turned developer. Montreal.',                     true, now() - interval '47 days'),
  ('noah_dev',     'Noah Kim',          'https://i.pravatar.cc/300?u=noah_dev',     'CS @ McGill. Hackathon regular.',                             true, now() - interval '40 days'),
  ('zara_designs', 'Zara Ahmed',        'https://i.pravatar.cc/300?u=zara_designs', 'Typography nerd. Variable fonts are my love language.',       true, now() - interval '33 days'),
  ('felix_js',     'Félix Roy',         'https://i.pravatar.cc/300?u=felix_js',     'I mass-rewrite things in the framework of the week.',         true, now() - interval '25 days'),
  ('amara_ml',     'Amara Diallo',      'https://i.pravatar.cc/300?u=amara_ml',     'ML by day, CSS art by night.',                                true, now() - interval '18 days'),
  ('owen_hacks',   'Owen MacDonald',    'https://i.pravatar.cc/300?u=owen_hacks',   'Building things nobody asked for. Loving it.',                true, now() - interval '10 days');

-- 36 posts spread across the authors, newest first, every third one with an image.
with bodies as (
  select array[
    'Just shipped my first project with Supabase. Way faster than rolling my own backend.',
    'Hot take: dark mode should be the default for every dev tool.',
    'Spent three hours centering a div. Turns out I forgot display: flex.',
    'Anyone else at CodeJam this weekend? Looking for a team!',
    'New portfolio site is live. Feedback welcome, be gentle.',
    'Reminder: your users do not care about your tech stack. They care that it works.',
    'Finally understood CSS grid. Life changing.',
    'The best design system is the one your team actually uses.',
    'Coffee count today: 4. Bugs fixed: 1. Bugs created: 3.',
    'Prototyped the whole flow in Figma before writing a line of code. 10/10 would recommend.',
    'Animations should be fast. 200ms is plenty. Fight me.',
    'Rewrote the landing page for the third time this month. It is finally good.',
    'Accessibility is not a feature, it is a baseline.',
    'Learned more from one hackathon than a whole semester of lectures.',
    'Late night debugging session. The bug was a typo. It is always a typo.',
    'Hover states are underrated. Make your buttons feel alive.',
    'Today I learned about container queries and I have so many ideas.',
    'Shoutout to everyone who writes good error messages.',
    'Pair programming with a friend > solo grinding.',
    'Our demo crashed live on stage and the judges still loved it.',
    'Whitespace is a design element. Use more of it.',
    'Just discovered that Montreal bagels are objectively superior. Not tech related.',
    'Building a habit tracker to track my habit of building habit trackers.',
    'Skeleton loaders make everything feel faster. Psychology is wild.',
    'Picked a color palette from a photo of my plant. Looks amazing.',
    'Mobile first. Always. Your future self will thank you.',
    'If your app needs a tutorial, the design probably needs work.',
    'Deployed on a Friday. Living dangerously.',
    'Hackathon tip: build the demo, not the product.',
    'Empty states deserve love too. Give them an illustration and a call to action.',
    'Ported a side project to a new framework just to see what the hype is about.',
    'Started a design journal. Screenshotting every UI I like.',
    'Font pairing is 80% of good design and nobody can change my mind.',
    'Made my first open source contribution today!',
    'Snow in Montreal already? Time to code indoors all winter.',
    'Our team just hit 100 commits on our hackathon project. Mostly fixing merge conflicts.'
  ] as b
),
authors as (
  select id, row_number() over (order by created_at) - 1 as n from public.profiles where is_seed
)
insert into public.posts (author_id, body, image_url, likes, is_seed, created_at)
select
  a.id,
  bodies.b[i],
  case when i % 3 = 0 then 'https://picsum.photos/seed/post' || i || '/800/600' end,
  (i * 37) % 180,
  true,
  now() - (i * interval '7 hours')
from generate_series(1, 36) as i
cross join bodies
join authors a on a.n = (i * 7) % 10
order by i; -- keeps post id = i, which reset.sql relies on

-- ~3 comments per post, from authors other than the post's author.
with lines as (
  select array[
    'This is so real.',
    'Love this!',
    'Great point, never thought about it that way.',
    'Saving this for later.',
    'Okay but where can I see it?',
    'Hard agree.',
    'Respectfully, I disagree. But I see where you are coming from.',
    'Following for updates!',
    'Can you share the link?',
    'Same thing happened to me last week lol',
    'This made my day.',
    'Big if true.',
    'Teach me your ways.',
    'Congrats!! 🎉',
    'Underrated take.',
    'Bookmarked.',
    'How long did this take you?',
    'Need this energy today.',
    'Absolutely beautiful work.',
    'Sending this to my whole team.'
  ] as l
),
authors as (
  select id, row_number() over (order by created_at) - 1 as n from public.profiles where is_seed
),
p as (
  select id, author_id, created_at, row_number() over (order by id) as pn from public.posts where is_seed
)
insert into public.comments (post_id, author_id, body, is_seed, created_at)
select
  p.id,
  a.id,
  lines.l[1 + ((p.pn * 3 + k * 7) % 20)],
  true,
  p.created_at + (k * interval '25 minutes')
from p
cross join generate_series(1, 3) as k
cross join lines
join authors a on a.n = (p.pn + k * 3) % 10
where a.id <> p.author_id
  and (p.pn + k) % 4 <> 0; -- vary comment counts a bit

insert into public.products (name, description, category, price_cents, image_url, rating, stock, is_seed) values
  ('Mechanical Keyboard',    'Hot-swappable 75% board with tactile switches and PBT keycaps.',  'tech',        12999, 'https://picsum.photos/seed/keyboard/800/600',   4.7, 24, true),
  ('Wireless Mouse',         'Ergonomic, silent clicks, 70-day battery life.',                    'tech',         4999, 'https://picsum.photos/seed/mouse/800/600',      4.3, 58, true),
  ('USB-C Hub',              '7-in-1: HDMI, SD card, 3x USB-A, ethernet, pass-through charging.', 'tech',         3999, 'https://picsum.photos/seed/usbhub/800/600',     4.1, 0,  true),
  ('Noise-Cancelling Headphones', 'Over-ear, 30h battery, perfect for library grind sessions.',   'tech',        24999, 'https://picsum.photos/seed/headphones/800/600', 4.8, 12, true),
  ('Laptop Stand',           'Aluminum, adjustable height, folds flat.',                          'workspace',    3499, 'https://picsum.photos/seed/laptopstand/800/600',4.5, 40, true),
  ('Desk Mat',               'Extra large felt desk mat. Charcoal grey.',                         'workspace',    2499, 'https://picsum.photos/seed/deskmat/800/600',    4.4, 75, true),
  ('Monitor Light Bar',      'Glare-free lighting that clips on top of your monitor.',            'workspace',    5999, 'https://picsum.photos/seed/lightbar/800/600',   4.6, 18, true),
  ('Desk Plant',             'Low-maintenance pothos in a ceramic pot. Hard to kill.',            'workspace',    1899, 'https://picsum.photos/seed/plant/800/600',      4.9, 33, true),
  ('Dot Grid Notebook',      'A5, 160 pages, lays flat. For sketching wireframes.',               'stationery',   1599, 'https://picsum.photos/seed/notebook/800/600',   4.6, 120, true),
  ('Fineliner Set',          '12 colors, 0.4mm tips. Great for UI sketches.',                     'stationery',   1299, 'https://picsum.photos/seed/pens/800/600',       4.2, 90, true),
  ('Sticky Notes Mega Pack', '24 pads in pastel colors. Fuel for your next design sprint.',       'stationery',    999, 'https://picsum.photos/seed/sticky/800/600',     4.0, 200, true),
  ('Hackathon Hoodie',       'Heavyweight cotton hoodie. Survives 36-hour coding sessions.',      'apparel',      5499, 'https://picsum.photos/seed/hoodie/800/600',     4.8, 15, true),
  ('Dev Tee',                'Soft tee with a tiny semicolon on the chest.',                      'apparel',      2499, 'https://picsum.photos/seed/tee/800/600',        4.3, 60, true),
  ('Beanie',                 'Warm knit beanie for Montreal winters.',                            'apparel',      1999, 'https://picsum.photos/seed/beanie/800/600',     4.5, 0,  true),
  ('Sticker Pack',           '20 vinyl laptop stickers. Frameworks, memes, and cats.',            'accessories',   799, 'https://picsum.photos/seed/stickers/800/600',   4.7, 300, true),
  ('Insulated Water Bottle', 'Keeps drinks cold for 24h. Fits in a backpack side pocket.',        'accessories',  2999, 'https://picsum.photos/seed/bottle/800/600',     4.6, 45, true),
  ('Laptop Sleeve',          'Padded 14" sleeve with an accessory pocket.',                       'accessories',  3299, 'https://picsum.photos/seed/sleeve/800/600',     4.4, 27, true),
  ('Cold Brew Coffee Kit',   'Make a week of cold brew at home. Fuel not included.',              'accessories',  3999, 'https://picsum.photos/seed/coldbrew/800/600',   3.9, 9,  true),
  ('Rubber Duck',            'For debugging. Listens without judgment.',                          'accessories',   499, 'https://picsum.photos/seed/duck/800/600',       5.0, 500, true),
  ('Pixel Art Poster',       '18x24 print of a retro city skyline.',                              'decor',        2199, 'https://picsum.photos/seed/poster/800/600',     4.5, 22, true);
