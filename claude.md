# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Deskly is a spatial presence layer for link-based collaboration — real-time office maps showing who's where, with vendor-neutral meeting links. Multi-tenant SaaS built with a "no server" architecture where business logic lives in the database (RLS, functions, triggers) rather than API routes.

## Commands

- **Dev server:** `bun dev` (runs at http://localhost:3000)
- **Build:** `bun run build` (runs lint then next build)
- **Lint:** `bun run lint` (always run this command after any changes)
- use bun commands always - like bun install

## Architecture

### Tech Stack

Next.js 16 (App Router) + React 19 + TypeScript (strict) + Supabase (auth, Postgres, realtime, storage) + Tailwind CSS 4 + ShadCN/Radix UI. Deployed on Vercel.

### Key Architectural Decisions

- **No API routes or middleware.** All data access goes directly from client → Supabase. Security is enforced entirely by Postgres RLS policies and security-definer functions.
- **Multi-tenant isolation at the database level.** Every table has `organization_id`. RLS helper functions (`is_member_of()`, `get_user_role()`, `is_admin_or_owner()`) gate all access.
- **Hard deletes only** — no soft delete patterns anywhere.
- **OAuth only** — Google and GitHub via Supabase Auth. No password auth.
- **Realtime** via Supabase WebSocket subscriptions on `maps`, `cabins`, `organization_members`, `presence` tables.

### Source Layout

- `src/app/` — Next.js App Router pages. Root layout hides Header/Footer on `/orgs/*` routes.
- `src/components/ui/` — ShadCN components using `cn()` utility (clsx + tailwind-merge).
- `src/utils/config.ts` — Zod-validated environment config for `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY`.
- `src/utils/supabase.ts` — Single shared Supabase client instance.
- `database/` — SQL schema split into `tables.sql`, `rls.sql`, `functions.sql`, `triggers.sql`, `limits.sql`, `storage.sql`, `cleanup.sql`. Tests in `database/tests/`.

### UI

- Main page with login via google/github links and general website content
- Organizations page. Will be here after login. If new user, confirm name.
  - Org screen shows orgs they have access to and invited to.
  - Allows new org creation, accept/decline invitations. accessible orgs will have active member count displayed
  - If they are connected to org and access revoked, they will be kicked out to this view
- Main Map screen, on Org selection
  - Shows map with cabins around (will be a svg based render). should allow map zoom (with fit to screen).
  - Cabin will have avatars displayed with status
  - Cabin show the name, current occupants.
  - Person click would show ring, knock etc events.
  - Move to cabin option. and in cabin, join meeting option and leave meeting option
  - If person at self desk, can edit name, image and url for it
- Admins will have edit map access
  - Allows map background change
  - Allows cabin edits - name, image, url
  - Add new cabin adds based on type and drag to location

### Database Schema (core tables)

organizations → maps (1:1) → cabins (many per map)
organizations → organization_members → users (linked to auth.users)
organizations → presence (per-user status: ACTIVE/IN_ROOM/AWAY/DND)
organizations → events (ring/knock/invite interactions)
organizations → audit_logs (immutable history)
organizations → organization_invitations (email-based)

Triggers enforce: no org_id updates, throttled presence updates (30s), membership limits (50 members/org, 10 orgs/user).

## Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY=
```

## Code Conventions

- **TypeScript is extremely strict:** `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`, no `any` (ESLint enforced), exhaustive switch checks.
- **Path alias:** `@/*` maps to `./src/*`.
- **ESLint rules of note:** no floating promises, no unsafe operations, no console (warn level), require-await, strict equality only.
- **React:** Server components by default; `"use client"` only when needed. Functional components with TypeScript interfaces.
- **Styling:** Tailwind utility classes with `cn()` for conditional merging. Component variants via `class-variance-authority`.
