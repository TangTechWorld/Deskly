
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pgtap;

-- This schema defines the database structure for a virtual office application. It includes tables for organizations, users, maps, cabins, memberships, and presence tracking. 
-- This supports multiple organizations, each with its own set of users, maps, and cabins. Users can have different roles (OWNER, ADMIN, MEMBER) within an organization that determine their permissions for viewing and updating data.
-- Row level security policies are implemented to ensure that users can only access data relevant to their organization and role. Deletion rules are set to maintain data integrity and prevent orphaned records.
-- No soft deletes are used, all deletions are hard deletes. This simplifies the data model and ensures that deleted records do not affect application logic or performance.

-- Each organization can have maps and users.
-- Can be viewed by users in the organization or users with pending invitations. Only Organization record is exposed to non-members, maps, cabins etc are restricted.
-- Can be updated by users with OWNER or ADMIN role. Only name can be updated.
-- Deleting an organization will delete all associated maps, cabins, and memberships.
CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CHECK (TRIM(name) <> '' AND char_length(name) <= 100)
);

-- Each user can be a member of multiple organizations. Image is the user image, if null the default user image will be used.
-- Can be viewed by users in the same organization.
-- Can be updated by users themselves.
-- Deleting a user will delete all their memberships and presence. If the user is owner of any organization, delete is restricted. This is to prevent orphaned organizations without owners.
CREATE TABLE users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  image_url text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CHECK (TRIM(name) <> '' AND char_length(name) <= 100),
  CHECK (image_url IS NULL OR (image_url ~ '^https://' AND char_length(image_url) <= 500))
);

-- Invitations for users to join an organization. Invitations are deleted after user joins the organization. They dont expire.
-- Only visible to admins of the organization.
-- No updates allowed, only insert and delete by the admins or owners
-- Deleting an invitation does nothing.
CREATE TABLE organization_invitations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email text NOT NULL,
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),

  CHECK (TRIM(message) <> '' AND char_length(message) <= 500),
  CHECK (email ~* '^[^@]+@[^@]+\.[^@]+$')
);

CREATE UNIQUE INDEX idx_invitations_org_email ON organization_invitations(organization_id, LOWER(email));
CREATE INDEX idx_invitations_org ON organization_invitations(organization_id);
CREATE INDEX idx_invitations_email ON organization_invitations(LOWER(email));

-- Each map belongs to an organization and has a background image and a cabin image. 
-- Can be viewed by users in the same organization.
-- Can be updated by users with OWNER or ADMIN role of the organization. Only background and cabin can be updated.
-- Deleting a map will delete all associated cabins.
CREATE TABLE maps (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  background_url text NULL,
  cabin_url text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CHECK (background_url IS NULL OR (background_url ~ '^https://' AND char_length(background_url) <= 500)),
  CHECK (cabin_url IS NULL OR (cabin_url ~ '^https://' AND char_length(cabin_url) <= 500)),
  UNIQUE (id, organization_id)
);
CREATE INDEX idx_maps_org ON maps(organization_id);

-- Each cabin belongs to a map and organization, has a name, position (x,y), size (width, height), and an optional link URL.
-- Can be viewed by users in the same organization.
-- All fields can be updated by users with OWNER or ADMIN role of the organization. Member can update the cabin_url, name and link_url.
-- is_locked can be updated by any user, but only if they are present inside the cabin. link_url can only be updated by members if the cabin type is not 'desk'
-- Deleting a cabin will remove it from any user's presence. Cabin cannot be deleted if it's set as a cabin for any organization member.
CREATE TABLE cabins (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  map_id uuid NOT NULL,
  cabin_url text NULL,
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('desk','room','focus')),
  link_url text NULL,
  x integer NOT NULL,
  y integer NOT NULL,
  width integer NOT NULL,
  height integer NOT NULL,
  is_locked boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  bounds box GENERATED ALWAYS AS (box(point(x, y), point(x + width, y + height))) STORED,

  UNIQUE (id, organization_id),

  FOREIGN KEY (map_id, organization_id)
    REFERENCES maps (id, organization_id)
    ON DELETE CASCADE,

  CHECK (TRIM(name) <> '' AND char_length(name) <= 100),
  CHECK (cabin_url IS NULL OR (cabin_url ~ '^https://' AND char_length(cabin_url) <= 500)),
  CHECK (link_url IS NULL OR (link_url ~ '^https://' AND char_length(link_url) <= 500)),
  CHECK (width > 0 AND width <= 2000 AND height > 0 AND height <= 2000),
  CHECK (x >= 0 AND x <= 10000 AND y >= 0 AND y <= 10000)
);

CREATE INDEX idx_cabins_org_map ON cabins (organization_id, map_id);

-- Membership table linking users to organizations with a role (OWNER, ADMIN, MEMBER) and a own cabin. Own cabin is unique across the organization to prevent conflicts.
-- User is can be only member of an organization Once. They cant have 2 cabins on different maps.
-- Can be viewed by users in the same organization.
-- Can be updated by users with OWNER or ADMIN role of the organization
-- Deleting member will remove their presence
CREATE TABLE organization_members (
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('OWNER','ADMIN','MEMBER')),
  cabin_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (organization_id, user_id),

  FOREIGN KEY (cabin_id, organization_id)
    REFERENCES cabins (id, organization_id)
    ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
  
  UNIQUE (cabin_id) -- Each cabin can only be one person's own desk
);

CREATE INDEX idx_members_user_org ON organization_members(user_id, organization_id);
CREATE INDEX idx_members_org_role_user ON organization_members(organization_id, role, user_id);
CREATE INDEX idx_members_cabin ON organization_members(organization_id, cabin_id);

-- Presence table tracking each user's current status and cabin in an organization. Status can be ACTIVE, IN_ROOM, AWAY, or DND.
-- Can be viewed by users in the same organization.
-- Users can only update/delete their own presence.
-- Deleting presence does nothing
-- heatbeat will be only every 10 mins. Presence will not be considered active if updated_at is older than 30 mins.
CREATE TABLE presence (
  organization_id uuid NOT NULL,
  user_id uuid NOT NULL,
  cabin_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('ACTIVE','IN_ROOM','AWAY','DND')),
  custom_status text NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (organization_id, user_id),

  FOREIGN KEY (organization_id, user_id)
    REFERENCES organization_members (organization_id, user_id)
    ON DELETE CASCADE,

  FOREIGN KEY (cabin_id, organization_id)
    REFERENCES cabins (id, organization_id)
    ON DELETE CASCADE,

  CHECK (custom_status IS NULL OR (TRIM(custom_status) <> '' AND char_length(custom_status) <= 50))
);

CREATE INDEX idx_presence_user ON presence(user_id);
CREATE INDEX idx_presence_org_updated ON presence(organization_id, updated_at DESC);
CREATE INDEX idx_presence_org_status ON presence(organization_id, status);


-- events table captures the ringing, knocking, and room invitations between users. This allows for a history of interactions and can be used to trigger notifications or other actions in the application.
-- Can be viewed by the receiver
-- Can be created by the sender, but only for their own user_id and organization. No updates allowed, only insert and delete by the sender or receiver.
-- Can be deleted by the receiver
CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  from_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('ring', 'knock', 'invite_to_room')),
  cabin_id uuid REFERENCES cabins(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),

  FOREIGN KEY (cabin_id, organization_id)
    REFERENCES cabins (id, organization_id)
    ON DELETE CASCADE
);

CREATE INDEX idx_events_to_user ON events(to_user_id, created_at DESC);
CREATE INDEX idx_events_org ON events(organization_id, created_at DESC);
CREATE INDEX idx_events_cleanup ON events(created_at);

-- This table captures key events for organizations, members, cabins, maps, and invitations. It is designed to be immutable (no updates/deletes) and to allow querying by organization, actor, and target.
-- Not adding cascade to maintain logs even if related records are deleted. Actor_id is nullable to allow logging system actions or actions by users that have been deleted.
CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id uuid NOT NULL,
  actor_id uuid REFERENCES users(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,  -- NULL if system action or user deleted
  action text NOT NULL,
  target_type text,           -- 'member', 'cabin', 'map', 'invitation', 'organization'
  target_id uuid,             -- ID of affected record
  metadata jsonb DEFAULT '{}', -- Additional context
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX idx_audit_org_created ON audit_logs(organization_id, created_at DESC);
CREATE INDEX idx_audit_actor ON audit_logs(actor_id, created_at DESC);
CREATE INDEX idx_audit_target ON audit_logs(target_type, target_id);


-- Enable realtime for maps (for live background changes)
ALTER PUBLICATION supabase_realtime ADD TABLE maps;

-- Enable realtime for cabins (for live layout updates)
ALTER PUBLICATION supabase_realtime ADD TABLE cabins;

-- Enable realtime for organization_members (for member join/leave notifications)
ALTER PUBLICATION supabase_realtime ADD TABLE organization_members;

-- Enable realtime for presence (for live presence updates)
ALTER PUBLICATION supabase_realtime ADD TABLE presence;

-- Enable realtime for events (for live event notifications)
ALTER PUBLICATION supabase_realtime ADD TABLE events;