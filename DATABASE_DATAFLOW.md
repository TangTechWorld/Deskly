# Deskly Database Data Flow & Permissions

Multi-tenant SaaS with organizations containing maps/cabins, users, memberships, and real-time presence. All data isolation via `organization_id` + Row Level Security. No soft deletes.

## Entity Permissions at a Glance

| Entity                       | View                     | Insert                            | Update                                 | Delete                       |
| ---------------------------- | ------------------------ | --------------------------------- | -------------------------------------- | ---------------------------- |
| **organizations**            | Members or invited       | `create_organization()` fn only   | OWNER/ADMIN (name)                     | OWNER                        |
| **users**                    | Self or same-org members | Self only                         | Self only                              | Self (if not sole org OWNER) |
| **organization_members**     | Members in org           | `accept_invitation()` fn only     | OWNER/ADMIN (role, cabin_id)           | OWNER/ADMIN or self          |
| **organization_invitations** | OWNER/ADMIN or self      | OWNER/ADMIN (prevents duplicates) | Never                                  | OWNER/ADMIN or self          |
| **maps**                     | Members                  | OWNER/ADMIN                       | OWNER/ADMIN (bg, cabin URLs)           | OWNER                        |
| **cabins**                   | Members                  | OWNER/ADMIN                       | Members (own cabin); OWNER/ADMIN (all) | OWNER/ADMIN                  |
| **presence**                 | Members                  | Self only                         | Self only (throttled 30s)              | Self                         |
| **events**                   | Sender or receiver       | Sender (rate limited 10/min)      | Never                                  | Recipient only               |
| **audit_logs**               | OWNER/ADMIN via fn       | System only                       | Never                                  | Never                        |

**Immutable fields** (all): `id`, `created_at`, `organization_id`, `user_id` (members/presence), `map_id` (cabins)

---

## Limits & Rate Limits

- **Maps:** 1 per org (soft limit via trigger)
- **Cabins:** 50 per org (soft limit via trigger)
- **Pending invitations:** 30 per org (soft limit via trigger)
- **Events:** 10 per sender per minute (rate limit via trigger)
- **Presence updates:** Once per 30 seconds (throttled; older than 30 min considered stale)

## Auto-Cleanup (pg_cron)

- Stale presence (no update > 30 min): every 5 min
- Stale invitations (> 30 days old): daily 3am
- Old events (> 7 days): daily 3am
- Old audit logs (> 90 days): daily 3am

## Storage Buckets

- **avatars/{user_id}/avatar.png** — User-only read/write (2MB, PNG/JPEG/WebP)
- **org-assets/{org_id}/background.png** — OWNER/ADMIN only (2MB, PNG/JPEG/WebP)
- **org-assets/{org_id}/cabins/{cabin_id}.png** — Member can upload for own cabin (2MB, PNG/JPEG/WebP)

---

## Data Flow: Complete User Journey

### Organizations & Memberships

```
1. User signs up → auth.users + users table INSERT

2. Create organization → create_organization(name):
   - organizations INSERT
   - maps INSERT (1 per org)
   - cabins INSERT (1 owner desk)
   - organization_members INSERT (user as OWNER)
   - Audit: org.created, map.created, member.added

3. OWNER invites members → organization_invitations INSERT
   - RLS: OWNER/ADMIN only
   - Trigger: prevents duplicate email per org, checks no existing member
   - Audit: invitation.sent (email masked)

4. Invitee accepts → accept_invitation(id):
   - organization_members INSERT (auto-assigns available desk cabin as MEMBER)
   - organization_invitations DELETE (auto-deletes invitation)
   - Audit: member.added, invitation.deleted

5. Invitee rejects → organization_invitations DELETE
   - User deletes their own invitation
   - No membership created
   - Audit: invitation.deleted

6. Member leaves organization → organization_members DELETE (self or OWNER/ADMIN):
   - Presence CASCADE deleted
   - Audit: member.removed
   - User can delete their own membership or be removed by OWNER/ADMIN

7. OWNER removes member → organization_members DELETE (by OWNER/ADMIN):
   - Presence CASCADE deleted
   - Audit: member.removed

8. OWNER/ADMIN transfers ownership/changes roles → organization_members UPDATE:
   - organization_members.role UPDATE (OWNER/ADMIN/MEMBER)
   - Audit: member.role_changed

9. Delete organization → organizations DELETE (OWNER only):
   - Cascades: all maps, cabins, members, presence, events, invitations
   - Audit: member.removed (per member), org.deleted
```

### Real-Time Presence & Interactions

```
10. Member updates presence → presence INSERT/UPDATE (self-insert first time, self-update after):
    - First time: INSERT presence record (RLS: self only)
    - Subsequent: UPDATE presence (RLS: self only, throttled 30s)
    - Status: ACTIVE, IN_ROOM, AWAY, DND
    - Cabin: where user currently is
    - Stales: auto-cleanup if no update > 30 min

11. Member moves cabin → presence UPDATE (set cabin_id):
    - Can move to any cabin in org (not restricted)
    - Realtime broadcast: organization_members, presence topics

12. Member locks/unlocks cabin → cabins UPDATE (is_locked field):
    - Lock: must be present in cabin (trigger check)
    - Unlock: no one can be present in cabin (trigger check)
    - Only member with that cabin_id or OWNER/ADMIN can lock
    - Audit: cabin.updated

13. Member sends ring → events INSERT:
    - from_user_id = current user
    - to_user_id = recipient (must be in same org)
    - type = 'ring', 'knock', or 'invite_to_room'
    - Rate limit: 10 per minute from same sender (exception if exceeded)
    - Audit: none (events not audited)
    - Auto-delete: 24 hours after creation

14. Sender/Recipient views event → events VIEW/DELETE:
    - RLS: sender or receiver can view
    - Delete: recipient only can delete (to dismiss)
    - Audit: none (no audit trigger for events)
```

### Admin Cabins & Maps

```
15. OWNER/ADMIN creates cabin → cabins INSERT:
    - Must not overlap with existing cabins (spatial check)
    - x, y, width, height with bounds validation
    - type: desk, room, focus
    - Auto-assigned: doesn't auto-assign to anyone
    - Audit: cabin.created

16. OWNER/ADMIN edits cabin → cabins UPDATE:
    - Can change: type, name, x, y, width, height, cabin_url, link_url
    - Cannot change: organization_id, map_id
    - Audit: cabin.updated

17. Member edits own cabin → cabins UPDATE (restricted):
    - Can change: name, cabin_url, link_url (if not desk type)
    - Cannot change: type, x, y, width, height
    - Audit: cabin.updated

18. Delete cabin → cabins DELETE (OWNER/ADMIN only):
    - Cannot delete if assigned to member (FK constraint)
    - Auto-reassign presence: users in cabin moved to their own cabin
    - Audit: cabin.deleted

19. Update map → maps UPDATE:
    - OWNER/ADMIN only
    - Can change: background_url, cabin_url
    - Cannot change: organization_id
    - Audit: map.updated

20. Delete map → maps DELETE:
    - OWNER only
    - Cascades: all cabins, presence (with reassign), events
    - Audit: map.deleted
```

### Audit & Cleanup

```
21. OWNER/ADMIN views audit log → get_audit_logs(org_id, limit, offset):
    - Returns: all logged events for org (actor, action, target, metadata, timestamp)
    - Email addresses masked in logs: jo***@g***.co**
    - Audit entries auto-deleted after 90 days

22. Background cleanup (pg_cron):
    - Stale presence (> 30 min no update): deleted every 5 min
    - Stale invitations (> 30 days old): deleted daily 3am
    - Old events (> 24 hours): deleted every hour
    - Old audit logs (> 90 days): deleted daily 3am
```

### Constraints & Rollbacks

```
Cannot perform (exception raised):
- Delete user if sole OWNER of any organization
- Create cabin if spatial overlap detected
- Lock cabin if user not present
- Unlock cabin if anyone present
- Accept invitation if already member
- Create invitation if user already member
- Exceed presence update throttle (30 sec)
- Exceed event rate limit (10/min per pair)
- Exceed cabin count (50/org)
- Exceed invitation count (30 pending/org)
- Update immutable fields: id, created_at, organization_id, user_id, map_id
```
