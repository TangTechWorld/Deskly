# Spatial Presence SaaS ? Deskly

Open spatial presence layer for link-based collaboration.
The system provides:

- Spatial map (desks + rooms)
- Real-time presence
- Vendor-neutral meeting links
- Lightweight join/leave lifecycle
- Multi-tenant SaaS-ready architecture

Mainly contains

- organizations (name)
- users (name, avatar_url)
- organization_invitations (email, message)
- maps (per organization, for now only one) (image_url)
- cabins (per map) (cabin_url, name, type (desk, room, focus), link_url, positioning)
- organization_members (user assigned to a cabin of type desk and will have owner, admin and member access on org)
- presence (user at org and cabin with status active, in_room, away, dnd and custom message)
- events (events at org from user, to user and type (ring, knock, invite_to_room))

UI thoughts

- Main page with login via google/github links and general website content
- after login, organization selection screen.
  - can connect to only one org at a time. so they should feel that they switched over completely rather than being in both.
  - Org screen shows orgs they have access to and invited to, it will generally be very small.
  - Allows new org creation, accept/decline invitations. accessible orgs will have active member count displayed
  - If they are connected to org and access revoked, they will be kicked out to this view
- on org selection, Main map screen
  - shows map with cabins around (will be a svg based render). should allow map zoom (with fit to screen).
  - cabin will have avatars displayed with status
  - cabin show the name, current occupants.
  - person click would show ring, knock etc events.
  - move to cabin option. and in cabin, join meeting option and leave meeting option
  - if person at self desk, can edit name, image and url for it
- admins will have edit map access
  - allows map background change
  - allows cabin edits - name, image, url
  - add new cabin adds based on type and drag to location
