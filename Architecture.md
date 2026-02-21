# Deskly – Technical Architecture Document

## 1. Overview

**Product Concept**

Spatial presence layer for link-based collaboration.

The system provides:

- Spatial map (maps + desks)
- Real-time presence
- Vendor-neutral meeting links
- Lightweight join/leave lifecycle
- Multi-tenant SaaS-ready architecture

---

# 2. Tech Stack

## UI

- React
- SVG-based map rendering

## Platforms

- Web App → Vercel (SPA/SSR)
- Desktop App → Electron (wrapper over same web logic)

## Backend

- Supabase
  - Auth (OAuth)
  - Postgres (data)
  - Realtime (presence via WebSocket)
  - Row-Level Security (multi-tenant isolation)
  - Storage

---

# 3. Core System Model

## Conceptual Separation

The system tracks:

1. **Spatial Location** (desk position)
2. **Participation State** (meeting status)

It does NOT manage:

- Video lifecycle
- Meeting sessions
- Participant counts inside Zoom/Meet/etc.

---

# 4. Data Model (Minimal SaaS Version)\

Every table includes `organization_id` for tenant isolation.

---

# 5. Spatial & Desk Logic

## Key Rules

- A desk is a spatial location.
- A desk has an attached link (any URL).
- Users move independently.
- No cascading presence changes.
- Meeting windows are external and not authoritative.

---

# 6. Desk Interaction Model

### A. Moving to a Desk

When user clicks a desk:

`presence.currentDeskId = targetDeskpresence.status = ACTIVE`

User is spatially at that desk.
No auto-meeting launch.

---

### B. Joining a Desk Meeting

When user clicks “Join”: `presence.status = IN_ROOM`

Meeting link is opened (platform dependent).
Spatial location does not change.

---

## C. Leaving a Desk Meeting

### If at own desk:

Before: `currentDeskId = defaultDeskstatus = IN_ROOM`

After: `currentDeskId = defaultDeskstatus = ACTIVE`

No spatial movement.

---

### If at someone else's desk:

Before: `currentDeskId = theirDeskstatus = IN_ROOM`

After:`currentDeskId = defaultDeskstatus = ACTIVE`

User returns to their own desk.

---

## D. Sitting Without Joining

Allowed state: `currentDeskId = targetDeskstatus = ACTIVE`

User is waiting but not in meeting.

---

# 7. Presence Behavior Matrix

| Action                     | Desk Change        | Status Change |
| -------------------------- | ------------------ | ------------- |
| Sit at desk                | Yes                | ACTIVE        |
| Join meeting               | No                 | IN_ROOM       |
| Leave meeting (own desk)   | No                 | ACTIVE        |
| Leave meeting (other desk) | Yes → default desk | ACTIVE        |
| Close meeting window       | Same as Leave      |               |

No cascading updates.

Each user controls only their own presence row.

---

# 8. Meeting Link Handling

Links are:

- Arbitrary HTTPS URLs
- Not platform-restricted
- Opened externally
- Not monitored for lifecycle

System does NOT:

- Detect participant count
- Detect remote exit
- Inject scripts
- Control video platform

Meeting lifecycle is inferred only from user join/leave actions.

---

# 9. Web App Logic (Vercel)

## Hosting

- React deployed on Vercel via SSR or SPA
- Environment variables:
  - `VITE_SUPABASE_URL`
  - `VITE_SUPABASE_ANON_KEY`

## Auth Flow (OAuth)

`await supabase.auth.signInWithOAuth({ provider: "google" });`

JWT:

- Stored in browser localStorage
- Auto-attached to DB & Realtime

---

## Realtime Subscription

Scoped by organization:

```ts
supabase
  .channel("presence")
  .on(
    "postgres_changes",
    {
      event: "*",
      schema: "public",
      table: "presence",
      filter: `organization_id=eq.${orgId}`,
    },
    handleUpdate,
  )
  .subscribe();
```

---

## Web Meeting Launch

```ts
window.open(link_url, "_blank");
```

Leaving meeting:

- Manual button only
- Cannot detect tab close reliably

---

# 10. Electron Logic

Electron wraps same React app.

---

## OAuth in Electron

Flow:

1. `signInWithOAuth()`
2. Opens system browser
3. Redirect to custom protocol: `myapp://auth/callback`
4. Electron `open-url` handler captures tokens
5. `supabase.auth.setSession(...)`

JWT stored in renderer storage.

---

## Electron Meeting Launch

### Option A (Recommended): Dedicated BrowserWindow

```ts
const win = newBrowserWindow({
  width: 480,
  height: 640,
  autoHideMenuBar: true,
});

win.loadURL(link_url);

win.on("closed", () => {
  // trigger LEAVE logic
});
```

On close:

```
presence.status = ACTIVE if not at defaultDesk:
    presence.currentDeskId = defaultDesk
```

This gives reliable local leave detection.

---

### Option B: shell.openExternal()

```ts
shell.openExternal(link_url);
```

No lifecycle detection.

Manual Leave required.

BrowserWindow is preferred.

---

# 11. Multi-Tenant Security

Enforced using Supabase Row-Level Security.

Example:

```sql
CREATE POLICY "Users update own presence" ON presenceFORUPDATEUSING (auth.uid()= user_id);
```

All presence queries scoped by:

```
organization_id
```

No global subscriptions.

---

# 12. Scaling Model

Safe up to:

- Hundreds of concurrent users per org
- Thousands across orgs

Conditions:

- Realtime scoped per org
- No polling
- No per-second heartbeats
- Event-driven updates only

Presence payloads are small JSON rows.

---

# 13. System Guarantees

- No auto-join on movement
- No forced cascading leave
- No host dependency
- No meeting session objects
- No vendor lock-in
- Spatial and meeting state cleanly separated

---

# 14. Final Architecture Diagram

```
React(Web or Electron)
        ↓
SupabaseAuth(OAuth → JWT)
        ↓
SupabasePostgres(RLS)
        ↓
SupabaseRealtime(WebSocket)
        ↓
Presence updates scoped per org
```

Meeting links open externally via:

- Web → new tab
- Electron → BrowserWindow

---

# 15. Core Design Principles

1. Spatial presence is authoritative.
2. Meeting link is external resource.
3. Presence updates are per-user only.
4. No cascading side effects.
5. Movement and meeting participation are separate.
6. Multi-tenant isolation from day one.

---

This architecture supports:

- Lightweight internal use
- Free SaaS deployment
- Scalable multi-tenant growth
- Electron + Web parity
- Vendor-neutral collaboration model
