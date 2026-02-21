# Deskly

Spatial presence layer for link-based collaboration.
The system provides:

- Spatial map (desks + rooms)
- Real-time presence
- Vendor-neutral meeting links
- Lightweight join/leave lifecycle
- Multi-tenant SaaS-ready architecture

## Tech Stack

- React
  - with ShadCN
- NextJS
- Supabase
- Vercel

## Development

- Package manager is `bun`. Run `bun dev` for dev website on http://localhost:3000/
- `.env.local` should be created with below keys

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY= SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET=
```

- App doesnt have server. All logic is written in UI or as Row Level Security in Supabase.
- This command will run test cases for the database
  `psql "postgresql://postgres.scpbirtmmxkfbuuythdt:[pwd]@aws-1-ap-southeast-2.pooler.supabase.com:6543/postgres?sslmode=require" -f run_all_tests.sql 2>&1 | tee test_results.log`
