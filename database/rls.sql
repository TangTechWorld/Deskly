-- RLS on all tables, with policies to restrict access based on organization membership and roles. Triggers to enforce additional constraints and cascading behavior.
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE maps ENABLE ROW LEVEL SECURITY;
ALTER TABLE cabins ENABLE ROW LEVEL SECURITY;
ALTER TABLE presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Blanket REVOKE: Prevent all authenticated and public access to all functions
-- Functions should be given access individually
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;

----------------------------------------------------------------------------------------------------------------

-- Helper function to get current authenticated user's email safely
-- without requiring direct table access in RLS policy expressions.
CREATE OR REPLACE FUNCTION get_auth_email()
RETURNS text AS $$
DECLARE
  current_email text;
BEGIN
  SELECT au.email INTO current_email
  FROM auth.users au
  WHERE au.id = auth.uid();

  RETURN current_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper function to get a user's auth email by user id.
CREATE OR REPLACE FUNCTION get_user_email(p_user_id uuid)
RETURNS text AS $$
DECLARE
  current_email text;
BEGIN
  SELECT au.email INTO current_email
  FROM auth.users au
  WHERE au.id = p_user_id;

  RETURN current_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper function to check if user is a member of an organization (bypasses RLS)
CREATE OR REPLACE FUNCTION is_member_of(org_id uuid)
RETURNS boolean AS $$
DECLARE
  is_member boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM organization_members
    WHERE organization_id = org_id AND user_id = auth.uid()
  ) INTO is_member;
  RETURN is_member;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper function to get user's role in an organization (bypasses RLS)
CREATE OR REPLACE FUNCTION get_user_role(org_id uuid)
RETURNS text AS $$
DECLARE
  user_role text;
BEGIN
  SELECT role INTO user_role FROM organization_members
  WHERE organization_id = org_id AND user_id = auth.uid();
  RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper function to check if user has OWNER or ADMIN role (bypasses RLS)
CREATE OR REPLACE FUNCTION is_admin_or_owner(org_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN COALESCE(get_user_role(org_id), '') IN ('OWNER', 'ADMIN');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper function to check if user is OWNER (bypasses RLS)
CREATE OR REPLACE FUNCTION is_owner(org_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN get_user_role(org_id) = 'OWNER';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper function to check if user is member or invited (bypasses RLS)
CREATE OR REPLACE FUNCTION is_member_or_invited(org_id uuid)
RETURNS boolean AS $$
DECLARE
  is_member_or_invited boolean;
BEGIN
  SELECT COALESCE((
    SELECT EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_id = org_id AND user_id = auth.uid()
    )
  ), false) OR COALESCE((
    SELECT EXISTS (
      SELECT 1 FROM organization_invitations i
      WHERE i.organization_id = org_id
        AND LOWER(i.email) = LOWER(get_auth_email())
    )
  ), false) INTO is_member_or_invited;
  RETURN is_member_or_invited;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper function to check if two users are in same organization (bypasses RLS)
CREATE OR REPLACE FUNCTION are_in_same_org(other_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM organization_members m1
    JOIN organization_members m2 ON m1.organization_id = m2.organization_id
    WHERE m1.user_id = auth.uid() AND m2.user_id = other_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper function to allow privileged DB sessions (e.g. postgres) to run
-- maintenance queries without JWT claims while keeping authenticated users
-- on normal RLS + role-based behavior.
CREATE OR REPLACE FUNCTION is_privileged_db_role()
RETURNS boolean AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = current_user
      AND rolbypassrls = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

----------------------------------------------------------------------------------------------------------------

-- Any Member of Organization can view organization details.
CREATE POLICY "org_select_members"
ON organizations
FOR SELECT
USING (is_member_or_invited(organizations.id));

-- No one can insert directly into the organizations table, only through the create_organization() function which handles creating the map, cabin and membership. 
CREATE POLICY "org_insert_deny_direct"
ON organizations
FOR INSERT
WITH CHECK (false);  -- Only create_organization() can insert (bypasses RLS)

-- Only users with OWNER or ADMIN role can update organization details.
CREATE POLICY "org_update_admin_owner"
ON organizations
FOR UPDATE
USING (is_admin_or_owner(organizations.id));

-- Only users with OWNER role can delete an organization.
CREATE POLICY "org_delete_owner_only"
ON organizations
FOR DELETE
USING (is_owner(organizations.id));

----------------------------------------------------------------------------------------------------------------

-- Users can view their own user record or records of users in the same organization.
CREATE POLICY "users_select_self_or_same_org"
ON users
FOR SELECT
USING (
  id = auth.uid() OR are_in_same_org(users.id)
);

-- Users can only insert their own user record.
CREATE POLICY "users_insert_self"
ON users
FOR INSERT
WITH CHECK (
  id = auth.uid()
);

-- Users can only update their own user record.
CREATE POLICY "users_update_self"
ON users
FOR UPDATE
USING (
  id = auth.uid()
);

-- Users can only delete their own user record.
CREATE POLICY "users_delete_self"
ON users
FOR DELETE
USING (
  id = auth.uid()
);

-- Prevent deleting a user who is the sole owner of an organization.
CREATE OR REPLACE FUNCTION prevent_last_owner_user_delete()
RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.user_id = OLD.id
      AND m.role = 'OWNER'
      AND NOT EXISTS (
        SELECT 1 FROM organization_members m2
        WHERE m2.organization_id = m.organization_id
          AND m2.role = 'OWNER'
          AND m2.user_id <> OLD.id
      )
  ) THEN
    RAISE EXCEPTION 'Cannot delete user who is the sole owner of an organization. Transfer ownership first.';
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_last_owner_user_delete
BEFORE DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION prevent_last_owner_user_delete();

----------------------------------------------------------------------------------------------------------------

-- Only users with OWNER or ADMIN role can view organization invitations.
CREATE POLICY "invitations_admin_owner_select"
ON organization_invitations
FOR SELECT
USING (is_admin_or_owner(organization_invitations.organization_id));

-- Only users with OWNER or ADMIN role can delete organization invitations.
CREATE POLICY "invitations_admin_owner_delete"
ON organization_invitations
FOR DELETE
USING (is_admin_or_owner(organization_invitations.organization_id));

-- Users can view their own invitations to join organizations.
CREATE POLICY "invitations_select_own"
ON organization_invitations
FOR SELECT
USING (
  LOWER(get_auth_email()) = LOWER(organization_invitations.email)
);

-- Users can delete their own invitations to join organizations.
CREATE POLICY "invitations_delete_own"
ON organization_invitations
FOR DELETE
USING (
  LOWER(get_auth_email()) = LOWER(organization_invitations.email)
);

-- Only users with OWNER or ADMIN role can create organization invitations.
CREATE POLICY "invitations_admin_owner_insert"
ON organization_invitations
FOR INSERT
WITH CHECK (is_admin_or_owner(organization_invitations.organization_id));

-- No one can update organization invitations, only delete (by OWNER/ADMIN/User) or insert (by OWNER/ADMIN).
CREATE POLICY "invitations_update_denied"
ON organization_invitations
FOR UPDATE
USING (false);

-- Prevent creating invitations for users who are already members of the organization.
CREATE OR REPLACE FUNCTION prevent_existing_member_invitation()
RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM organization_members om
    WHERE om.organization_id = NEW.organization_id
      AND LOWER(get_user_email(om.user_id)) = LOWER(NEW.email)
  ) THEN
    RAISE EXCEPTION 'Cannot send invitation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_prevent_existing_member_invitation
BEFORE INSERT ON organization_invitations
FOR EACH ROW
EXECUTE FUNCTION prevent_existing_member_invitation();

----------------------------------------------------------------------------------------------------------------

-- users can view maps only if they are a member of the organization.
CREATE POLICY "maps_select_members"
ON maps
FOR SELECT
USING (is_member_of(maps.organization_id));

-- Only users with OWNER or ADMIN role can create maps for their organization.
CREATE POLICY "maps_insert_admin_owner"
ON maps
FOR INSERT
WITH CHECK (is_admin_or_owner(maps.organization_id));

-- Only users with OWNER or ADMIN role can update maps in their organization.
CREATE POLICY "maps_update_admin_owner"
ON maps
FOR UPDATE
USING (is_admin_or_owner(maps.organization_id));

-- Only users with OWNER role can delete maps in their organization.
CREATE POLICY "maps_delete_owner_only"
ON maps
FOR DELETE
USING (is_owner(maps.organization_id));

----------------------------------------------------------------------------------------------------------------

-- Any Member of Organization can view cabins in their organization.
CREATE POLICY "cabins_select_members"
ON cabins
FOR SELECT
USING (is_member_of(cabins.organization_id));

-- Only users with OWNER or ADMIN role can create cabins for their organization.
CREATE POLICY "cabins_insert_admin_owner"
ON cabins
FOR INSERT
WITH CHECK (is_admin_or_owner(cabins.organization_id));

-- Any member of the organization can attempt to update a cabin; column-level restrictions are enforced by the trigger
CREATE POLICY "cabins_update_members"
ON cabins
FOR UPDATE
USING (is_member_of(cabins.organization_id));

-- Only users with OWNER or ADMIN role can delete cabins in their organization.
CREATE POLICY "cabins_delete_admin_owner"
ON cabins
FOR DELETE
USING (is_admin_or_owner(cabins.organization_id));

-- Trigger to enforce column level permissions for cabin updates. Members can only update the name, cabin_url and link_url of their cabin. They cannot change the layout or move cabins around. Admins and Owners can update all fields.
CREATE OR REPLACE FUNCTION enforce_cabin_update_permissions()
RETURNS trigger AS $$
DECLARE
  user_role text;
  user_cabin uuid;
  is_member_present boolean;
BEGIN
  -- Defense-in-depth: immutable fields (also covered by separate triggers)
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
    RAISE EXCEPTION 'organization_id cannot be modified';
  END IF;
  IF NEW.map_id IS DISTINCT FROM OLD.map_id THEN
    RAISE EXCEPTION 'map_id cannot be modified';
  END IF;

  -- Allow direct maintenance queries from privileged DB roles (e.g. postgres)
  -- that bypass RLS and do not carry JWT auth claims.
  IF is_privileged_db_role() THEN
    RETURN NEW;
  END IF;

  -- Get role and cabin in one query
  SELECT role, cabin_id
  INTO user_role, user_cabin
  FROM organization_members
  WHERE organization_id = OLD.organization_id
    AND user_id = auth.uid();

  IF user_role IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Check if member is present in this cabin (for locking logic)
  SELECT EXISTS(
    SELECT 1 FROM presence
    WHERE organization_id = OLD.organization_id
      AND cabin_id = OLD.id
      AND user_id = auth.uid()
  ) INTO is_member_present;

  -- Only locking requires presence; unlocking requires NO presence
  IF NEW.is_locked IS DISTINCT FROM OLD.is_locked THEN
    IF NEW.is_locked = true THEN
      -- Locking: user must be present
      IF NOT is_member_present THEN
        RAISE EXCEPTION 'You must be present in a cabin to lock it';
      END IF;
    ELSIF NEW.is_locked = false THEN
      -- Unlocking: no one can be present
      IF EXISTS(
        SELECT 1 FROM presence
        WHERE organization_id = OLD.organization_id
          AND cabin_id = OLD.id
      ) THEN
        RAISE EXCEPTION 'Cannot unlock cabin while someone is present';
      END IF;
    END IF;
  END IF;

  -- OWNER / ADMIN can update anything
  IF user_role IN ('OWNER','ADMIN') THEN
    RETURN NEW;
  END IF;

  IF user_cabin IS DISTINCT FROM OLD.id THEN
    -- Not the assigned member: allow is_locked and link_url for non-desk, but no other changes
    IF NEW.type IS DISTINCT FROM OLD.type OR NEW.x IS DISTINCT FROM OLD.x OR NEW.y IS DISTINCT FROM OLD.y 
        OR NEW.width IS DISTINCT FROM OLD.width OR NEW.height IS DISTINCT FROM OLD.height
        OR NEW.name IS DISTINCT FROM OLD.name OR NEW.cabin_url IS DISTINCT FROM OLD.cabin_url THEN
      RAISE EXCEPTION 'Only the assigned member can update cabin details; others may only change is_locked, or link_url for non-desk cabins.';
    END IF;
    -- Allow link_url changes only for non-desk cabins
    IF NEW.link_url IS DISTINCT FROM OLD.link_url AND OLD.type = 'desk' THEN
      RAISE EXCEPTION 'Desk cabins cannot have their link_url changed';
    END IF;
    RETURN NEW;
  END IF;

  -- MEMBER: restrict structural changes
  IF NEW.type <> OLD.type OR
      NEW.x <> OLD.x OR
      NEW.y <> OLD.y OR
      NEW.width <> OLD.width OR
      NEW.height <> OLD.height THEN
    RAISE EXCEPTION 'Members cannot modify layout or structural fields';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_enforce_cabin_update_permissions
BEFORE UPDATE ON cabins
FOR EACH ROW
EXECUTE FUNCTION enforce_cabin_update_permissions();

-- Trigger to reassign presence to own cabin when a cabin is deleted. This ensures that users are not left with a reference to a deleted cabin in their presence. The trigger will move any users in the deleted cabin to their own cabin. 
-- If the deleted cabin is set as a own cabin for any user, the delete will be restricted by the foreign key constraint.
-- These bypass the RLS policies, because presence should be overridden on cabin delete by the admin
CREATE OR REPLACE FUNCTION reassign_presence_on_cabin_delete()
RETURNS trigger AS $$
BEGIN
  -- Move all users in this cabin to their own cabin
  UPDATE presence p
  SET cabin_id = m.cabin_id, status = CASE 
      WHEN p.status = 'IN_ROOM' THEN 'ACTIVE' 
      ELSE p.status 
    END
  FROM organization_members m
  WHERE p.cabin_id = OLD.id
    AND p.organization_id = OLD.organization_id
    AND p.user_id = m.user_id
    AND p.organization_id = m.organization_id;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_reassign_presence_on_cabin_delete
BEFORE DELETE ON cabins
FOR EACH ROW
EXECUTE FUNCTION reassign_presence_on_cabin_delete();

-- Trigger to prevent actual cabin overlaps while allowing touching/adjacent cabins
-- Two rectangles overlap if: x1 < x2+width2 AND x1+width1 > x2 AND y1 < y2+height2 AND y1+height1 > y2
-- We prevent this by requiring: x1 >= x2+width2 OR x1+width1 <= x2 OR y1 >= y2+height2 OR y1+height1 <= y2
CREATE OR REPLACE FUNCTION prevent_cabin_overlap()
RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM cabins c
    WHERE c.map_id = NEW.map_id
      AND c.id <> NEW.id
      AND NOT (
        -- Rectangles are separated (no overlap, touching allowed)
        NEW.x >= c.x + c.width OR
        NEW.x + NEW.width <= c.x OR
        NEW.y >= c.y + c.height OR
        NEW.y + NEW.height <= c.y
      )
  ) THEN
    RAISE EXCEPTION 'Cabin overlaps with another cabin on this map';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_cabin_overlap
BEFORE INSERT OR UPDATE ON cabins
FOR EACH ROW
EXECUTE FUNCTION prevent_cabin_overlap();

----------------------------------------------------------------------------------------------------------------

-- Any Member of Organization can view organization members in their organization.
CREATE POLICY "members_select_same_org"
ON organization_members
FOR SELECT
USING (is_member_of(organization_members.organization_id));

-- Only create_organization() and accept_invitation() can insert (bypass RLS)
CREATE POLICY "members_insert_deny_direct"
ON organization_members
FOR INSERT
WITH CHECK (false);

-- Only users with OWNER or ADMIN role can update organization members.
CREATE POLICY "members_update_admin_owner"
ON organization_members
FOR UPDATE
USING (
  is_admin_or_owner(organization_members.organization_id)
);

-- Only users with OWNER or ADMIN role can delete organization members. Or users can delete themselves.
CREATE POLICY "members_delete_admin_owner"
ON organization_members
FOR DELETE
USING (
  is_admin_or_owner(organization_members.organization_id)
  OR organization_members.user_id = auth.uid()
);

-- Add trigger to enforce desk-only cabins
CREATE OR REPLACE FUNCTION enforce_cabin_is_desk()
RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cabins 
    WHERE id = NEW.cabin_id 
      AND type = 'desk'
  ) THEN
    RAISE EXCEPTION 'Assigned cabin must be a desk';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_cabin_is_desk
BEFORE INSERT OR UPDATE OF cabin_id ON organization_members
FOR EACH ROW
EXECUTE FUNCTION enforce_cabin_is_desk();


-- Trigger to enforce mutation rules for organization members. This includes preventing ADMIN from creating or promoting OWNER, preventing deleting or demoting the last OWNER, and ensuring that only users with appropriate roles can make changes to memberships.
-- Owners can create/delete/update owners, admins or members. Admin can create/delete/update admins and members but not owners. Members cannot create any memberships.
-- The trigger also ensures that the first member of an organization must be an OWNER and is directly allowed
CREATE OR REPLACE FUNCTION enforce_member_mutation_rules()
RETURNS trigger AS $$
DECLARE
  acting_role text;
  owner_count integer;
  org_count integer;
BEGIN
  -- Disable RLS to prevent infinite recursion when querying organization_members

  -- Allow direct maintenance queries from privileged DB roles (e.g. postgres)
  -- that bypass RLS and do not carry JWT auth claims.
  IF is_privileged_db_role() THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- For first insert, if there are no existing members in the organization, the new member must be an OWNER.
  IF TG_OP = 'INSERT' THEN
    IF NOT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = NEW.organization_id
    ) THEN
        -- first member must be OWNER
        IF NEW.role <> 'OWNER' THEN
        RAISE EXCEPTION 'First member must be OWNER';
        END IF;
        RETURN NEW;
    END IF;
    
    -- Allow user to add themselves (e.g., via accept_invitation function)
    IF NEW.user_id = auth.uid() THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Get role of the acting user
  SELECT role INTO acting_role
  FROM organization_members
  WHERE organization_id = COALESCE(OLD.organization_id, NEW.organization_id)
    AND user_id = auth.uid();

  IF acting_role IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF acting_role = 'MEMBER' THEN
    -- Members can only delete themselves
    IF TG_OP = 'DELETE' AND OLD.user_id = auth.uid() THEN
      -- Allow, fall through to last-OWNER check
      NULL;
    ELSE
      RAISE EXCEPTION 'MEMBER cannot manage memberships';
    END IF;
  END IF;

-- Allow self-removal for any role (last-OWNER check still applies below)
  IF TG_OP = 'DELETE' AND OLD.user_id = auth.uid() THEN
    -- Skip role-based restrictions, fall through to last-OWNER check
    NULL;
  -- Prevent ADMIN from creating or promoting OWNER
  ELSIF acting_role = 'ADMIN' THEN
    IF TG_OP = 'INSERT' AND NEW.role = 'OWNER' THEN
      RAISE EXCEPTION 'ADMIN cannot create OWNER';
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.role = 'OWNER' THEN
      RAISE EXCEPTION 'ADMIN cannot promote to OWNER';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.role = 'OWNER' THEN
      RAISE EXCEPTION 'ADMIN cannot modify OWNER';
    END IF;

    IF TG_OP = 'DELETE' AND OLD.role = 'OWNER' THEN
      RAISE EXCEPTION 'ADMIN cannot delete OWNER';
    END IF;
  END IF;

  -- Prevent deleting or demoting last OWNER
  IF TG_OP IN ('DELETE','UPDATE') AND OLD.role = 'OWNER' THEN
    SELECT count(*) INTO owner_count
    FROM organization_members
    WHERE organization_id = OLD.organization_id
      AND role = 'OWNER';
    
    -- Allow deletion if the organization doesn't exist (cascade cleanup)      
    SELECT count(*) INTO org_count
    FROM organizations o
    WHERE o.id = OLD.organization_id;

    IF owner_count <= 1 AND org_count > 0 THEN
      RAISE EXCEPTION 'Cannot remove the last OWNER. Transfer ownership or delete the organization first.';
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET row_security = OFF SET search_path = public, pg_temp;

CREATE TRIGGER trg_enforce_member_mutation_rules
BEFORE INSERT OR UPDATE OR DELETE
ON organization_members
FOR EACH ROW
EXECUTE FUNCTION enforce_member_mutation_rules();

-- Trigger to delete presence when a member is removed from the organization. Supabase Realtime may not emit events for cascade deletes, so we use a trigger to ensure that presence records are cleaned up when a member is removed.
-- These bypass the RLS policies, because presence should be overridden on member delete by the admin or the user themselves
CREATE OR REPLACE FUNCTION delete_presence_on_member_remove()
RETURNS trigger AS $$
BEGIN
  DELETE FROM public.presence
  WHERE organization_id = OLD.organization_id
    AND user_id = OLD.user_id;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_delete_presence_on_member_remove
BEFORE DELETE ON organization_members
FOR EACH ROW
EXECUTE FUNCTION delete_presence_on_member_remove();

----------------------------------------------------------------------------------------------------------------

-- Any Member of Organization can view presence in their organization.
CREATE POLICY "presence_select_same_org"
ON presence
FOR SELECT
USING (is_member_of(presence.organization_id));

-- Users can only insert their own presence.
CREATE POLICY "presence_insert_self"
ON presence
FOR INSERT
WITH CHECK (
  user_id = auth.uid()
  AND is_member_of(presence.organization_id)
);

-- Users can only update their own presence.
CREATE POLICY "presence_update_self"
ON presence
FOR UPDATE
USING (
  user_id = auth.uid()
);

-- Users can only delete their own presence.
CREATE POLICY "presence_delete_self"
ON presence
FOR DELETE
USING (
  user_id = auth.uid()
);

-- Trigger to validate that the cabin assigned in presence belongs to the same organization and is unlocked.
CREATE OR REPLACE FUNCTION validate_presence_cabin()
RETURNS trigger AS $$
BEGIN
  -- Verify the cabin belongs to this organization and is unlocked
  IF NOT EXISTS (
    SELECT 1 FROM cabins c
    WHERE c.id = NEW.cabin_id
      AND c.organization_id = NEW.organization_id
      AND c.is_locked = false
  ) THEN
    RAISE EXCEPTION 'Invalid cabin assignment';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_presence_cabin ON presence;
CREATE TRIGGER trg_validate_presence_cabin
BEFORE INSERT OR UPDATE ON presence
FOR EACH ROW
EXECUTE FUNCTION validate_presence_cabin();


-- If last presence leaves a locked cabin, unlock it (bypass RLS with SECURITY DEFINER)
CREATE OR REPLACE FUNCTION unlock_cabin_if_empty()
RETURNS trigger AS $$
DECLARE
  remaining integer;
BEGIN
  -- Only check on update or delete
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    -- Only proceed if the old cabin is locked
    IF EXISTS (
      SELECT 1 FROM cabins WHERE id = OLD.cabin_id AND organization_id = OLD.organization_id AND is_locked = true
    ) THEN
      -- Count remaining presences in the old cabin (excluding this user if update)
      SELECT count(*) INTO remaining FROM presence
      WHERE organization_id = OLD.organization_id
        AND cabin_id = OLD.cabin_id
        AND user_id != OLD.user_id;
      IF remaining = 0 THEN
        UPDATE cabins SET is_locked = false WHERE id = OLD.cabin_id AND organization_id = OLD.organization_id;
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_unlock_cabin_if_empty
AFTER UPDATE OR DELETE ON presence
FOR EACH ROW
EXECUTE FUNCTION unlock_cabin_if_empty();

----------------------------------------------------------------------------------------------------------------

-- Only OWNER/ADMIN can view audit logs
CREATE POLICY "audit_select_admin_owner"
ON audit_logs
FOR SELECT
USING (is_admin_or_owner(audit_logs.organization_id));

-- No direct inserts/updates/deletes - only via triggers
CREATE POLICY "audit_no_direct_insert" ON audit_logs FOR INSERT WITH CHECK (false);
CREATE POLICY "audit_no_update" ON audit_logs FOR UPDATE USING (false);
CREATE POLICY "audit_no_delete" ON audit_logs FOR DELETE USING (false);

----------------------------------------------------------------------------------------------------------------

-- Users can see events sent TO them or FROM them
CREATE POLICY "events_select_recipient_or_sender"
ON events
FOR SELECT
USING (to_user_id = auth.uid() OR from_user_id = auth.uid());

-- Users can send events to members in same org
CREATE POLICY "events_insert_member"
ON events
FOR INSERT
WITH CHECK (
  from_user_id = auth.uid()
  AND is_member_of(events.organization_id)
  AND are_in_same_org(events.to_user_id)
);

-- No updates
CREATE POLICY "events_no_update"
ON events
FOR UPDATE
USING (false);

-- Users can delete events sent to them (dismiss)
CREATE POLICY "events_delete_recipient"
ON events
FOR DELETE
USING (to_user_id = auth.uid());