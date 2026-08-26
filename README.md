# BCBX — Boston College Business Exchange

BCBX is a privacy-conscious learner recognition system. Its public **Millionaires Club — Live Rich List** and authenticated staff investment terminal are a static React application. Supabase provides Postgres, authentication and the application API; no traditional server is required.

The application intentionally stores only each learner's internal UUID, display name (for example `Jessica T.`), active state and creation timestamp. There are no notes, IDs, contact details, courses, photographs or sensitive learner fields.

## What is included

- Responsive public Rich List, genuine activity ticker, monthly rankings and milestones
- Passwordless staff sign-in with approved-account enforcement
- Fixed £50K investment terminal; staff identity is derived from `auth.uid()` in SQL
- Personal staff history and administrator tools for learners, staff and corrections
- Public database functions that return ticker and display-name data only—never staff email or auth IDs
- Database-enforced £50K amount and one learner/staff/value per investment
- Minimal immutable correction audit when an administrator removes an error
- GitHub Pages-compatible hash navigation and automated deployment

When environment variables are absent, the public page shows clearly labelled preview data. Authentication and writes remain disabled.

## 1. Create and configure Supabase

1. Create a project at [Supabase](https://supabase.com/dashboard). Save the database password somewhere secure.
2. Open **SQL Editor → New query**, paste all of [`supabase/migrations/202608260001_bcbx_v1.sql`](supabase/migrations/202608260001_bcbx_v1.sql), and run it once.
3. For a demo only, run [`supabase/seed.sql`](supabase/seed.sql). It uses deliberately invalid staff emails and is clearly separated so it can be omitted in production.
4. In **Authentication → Providers → Email**, leave Email enabled. For passwordless magic links, disable **Confirm email** only if your organisation's policy permits it; otherwise keep confirmation enabled. Custom SMTP is strongly recommended before a real launch.
5. In **Project Settings → API**, copy the Project URL and publishable key (older projects call this the `anon` key). The browser key is designed to be public; RLS and the restricted SQL functions enforce access. Never use the service-role key in this app or GitHub.

### Authentication URL configuration (exact values)

In **Authentication → URL Configuration**, for a repository named `bcbx` hosted by user `username`, set:

- **Site URL:** `https://username.github.io/bcbx/`
- **Redirect URLs:**
  - `http://localhost:5173/`
  - `https://username.github.io/bcbx/`

Replace `username` and `bcbx` with the actual GitHub account and repository name. Preserve the trailing slash. If Vite starts on another local port, add that exact origin with its trailing slash as another Redirect URL.

The application uses Supabase's PKCE flow. Authentication returns to the base URL using `?code=...`; the app exchanges it, removes the query string, and opens `#/staff`. The hash route works on GitHub Pages without server rewrites or a `404.html` workaround.

For local-first setup, the Site URL may temporarily be `http://localhost:5173/`, but change it to the production URL before launch. Both entries must remain in Redirect URLs.

### Create the initial administrator

The first administrator is bootstrapped once in SQL because there is not yet an administrator who can use the UI:

1. In **Authentication → Users → Add user**, create/invite the staff member with their exact work email.
2. Copy their user UUID.
3. Run this in SQL Editor, replacing all sample values:

```sql
insert into public.staff (auth_user_id, email, display_name, ticker, role)
values ('AUTH-USER-UUID', 'admin@boston.ac.uk', 'Administrator Name', 'SCAP', 'admin');
```

Thereafter the administrator can add approved staff in the app. If an approved staff row is added before their first login, the database trigger links their auth account by exact, case-insensitive email when it is created. The UI does not create Auth users; invite them in **Authentication → Users** or let them request their first magic link after the approved staff row exists.

## 2. Run locally

Requirements: Node.js 20 or newer (Node 22 recommended).

```bash
npm install
cp .env.example .env.local
npm run dev
```

On PowerShell, copy the environment file with:

```powershell
Copy-Item .env.example .env.local
```

Edit `.env.local`:

```dotenv
VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
VITE_BASE_PATH=/
```

Then open `http://localhost:5173/`. Before committing, run:

```bash
npm run lint
npm run build
```

## 3. Deploy to GitHub Pages

The workflow at [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml) builds and deploys every push to `main`.

1. Push this project to a GitHub repository (for example `bcbx`) on the `main` branch.
2. Open **Repository Settings → Pages** and set **Source** to **GitHub Actions**.
3. Open **Settings → Secrets and variables → Actions**:
   - Under **Variables**, create `VITE_SUPABASE_URL` with the Supabase project URL.
   - Under **Secrets**, create `VITE_SUPABASE_ANON_KEY` with the publishable/anon key.
4. Push to `main`, or run **Actions → Deploy BCBX to GitHub Pages → Run workflow**.

The workflow automatically sets `VITE_BASE_PATH` to `/<repository-name>/`, so JS/CSS assets load correctly from a project Pages URL. Do not put the service-role key in GitHub.

For a custom domain or a user-site repository named `username.github.io`, change the workflow's `VITE_BASE_PATH` to `/` and update the two production Supabase URLs to the custom origin.

## Security model

RLS is enabled on every application table and direct API table privileges are revoked. Public roles can execute only `public_leaderboard()` and `public_recent_activity()`. These return learner display names, calculated totals, Business Value names and staff tickers; neither function returns email or `auth_user_id`.

Authenticated users are not automatically staff. All staff operations verify an active row linked to `auth.uid()`. `create_investment()` accepts only learner and Business Value IDs; it gets the staff ID and ticker inside the database, so a caller cannot impersonate a colleague. Administrator functions separately require the `admin` role.

Portfolio and monthly values are calculated from transactions. They are not duplicated. The leaderboard tie-break is the earliest timestamp at which the current total was achieved (equivalent to the latest transaction timestamp for a fixed current credit count), followed by display name for a stable ordering.

## Production checklist

- Do not run `seed.sql`, or remove all demo investments, learners and invalid-email staff before launch.
- Use display names only in the required `Forename I.` form.
- Configure custom SMTP and review Supabase email rate limits.
- Confirm Site URL and both Redirect URLs exactly match the deployment.
- Create the initial administrator, then add/invite only approved staff.
- Test with an anonymous browser, a normal staff account and an administrator account.
- Keep formal praise narrative exclusively in ProMonitor.
