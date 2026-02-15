
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE maps ENABLE ROW LEVEL SECURITY;
ALTER TABLE cabins ENABLE ROW LEVEL SECURITY;
ALTER TABLE presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Any Member of Organization can view organization details.
CREATE POLICY "org_select_members"
ON organizations
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organizations.id
      AND m.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM organization_invitations i
    WHERE i.organization_id = organizations.id
      AND LOWER(i.email) = LOWER(auth.email())
  )
);

-- No one can insert directly into the organizations table, only through the create_organization() function which handles creating the default map, cabin and membership. 
CREATE POLICY "org_insert_deny_direct"
ON organizations
FOR INSERT
WITH CHECK (false);  -- Only create_organization() can insert (bypasses RLS)

-- Only users with OWNER or ADMIN role can update organization details.
CREATE POLICY "org_update_admin_owner"
ON organizations
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organizations.id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER', 'ADMIN')
  )
);

-- Only users with OWNER role can delete an organization.
CREATE POLICY "org_delete_owner_only"
ON organizations
FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organizations.id
      AND m.user_id = auth.uid()
      AND m.role = 'OWNER'
  )
);


-- Users can view their own user record or records of users in the same organization.
CREATE POLICY "users_select_self_or_same_org"
ON users
FOR SELECT
USING (
  id = auth.uid()
  OR
  EXISTS (
    SELECT 1
    FROM organization_members m1
    JOIN organization_members m2
      ON m1.organization_id = m2.organization_id
    WHERE m1.user_id = auth.uid()
      AND m2.user_id = users.id
  )
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

-- Only users with OWNER or ADMIN role can view or delete organization invitations.
CREATE POLICY "invitations_admin_owner_read_delete"
ON organization_invitations
FOR SELECT, DELETE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organization_invitations.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER','ADMIN')
  )
);

-- Users can view, delete their own invitations to join organizations.
CREATE POLICY "invitations_select_own"
ON organization_invitations
FOR SELECT, DELETE
USING (
  LOWER(email) = LOWER(auth.email())
);

-- Only users with OWNER or ADMIN role can create organization invitations.
CREATE POLICY "invitations_admin_owner_insert"
ON organization_invitations
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organization_invitations.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER','ADMIN')
  )
);

-- No one can update organization invitations, only delete (by OWNER/ADMIN) or insert (by OWNER/ADMIN).
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
    JOIN users u ON u.id = om.user_id
    JOIN auth.users au ON au.id = u.id
    WHERE om.organization_id = NEW.organization_id
      AND LOWER(au.email) = LOWER(NEW.email)
  ) THEN
    RAISE EXCEPTION 'User is already a member of this organization';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_prevent_existing_member_invitation
BEFORE INSERT ON organization_invitations
FOR EACH ROW
EXECUTE FUNCTION prevent_existing_member_invitation();

-- users can view maps only if they are a member of the organization.
CREATE POLICY "maps_select_members"
ON maps
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = maps.organization_id
      AND m.user_id = auth.uid()
  )
);

-- Only users with OWNER or ADMIN role can create maps for their organization.
CREATE POLICY "maps_insert_admin_owner"
ON maps
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = maps.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER','ADMIN')
  )
);

-- Only users with OWNER or ADMIN role can update maps in their organization.
CREATE POLICY "maps_update_admin_owner"
ON maps
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = maps.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER','ADMIN')
  )
);

-- Only users with OWNER role can delete maps in their organization.
CREATE POLICY "maps_delete_owner_only"
ON maps
FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = maps.organization_id
      AND m.user_id = auth.uid()
      AND m.role = 'OWNER'
  )
);

-- Any Member of Organization can view cabins in their organization.
CREATE POLICY "cabins_select_members"
ON cabins
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = cabins.organization_id
      AND m.user_id = auth.uid()
  )
);

-- Only users with OWNER or ADMIN role can create cabins for their organization.
CREATE POLICY "cabins_insert_admin_owner"
ON cabins
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = cabins.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER','ADMIN')
  )
);

-- Any Member Can Target Row, enforce column level permissions in the function
CREATE POLICY "cabins_update_members"
ON cabins
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = cabins.organization_id
      AND m.user_id = auth.uid()
      AND (
        m.role IN ('OWNER', 'ADMIN')
        OR m.default_cabin_id = cabins.id
      )
  )
);

-- Only users with OWNER or ADMIN role can delete cabins in their organization.
CREATE POLICY "cabins_delete_admin_owner"
ON cabins
FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = cabins.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER','ADMIN')
  )
);

-- Trigger to enforce column level permissions for cabin updates. Members can only update the name, cabin_url and link_url of their default cabin. They cannot change the layout or move cabins around. Admins and Owners can update all fields.
CREATE OR REPLACE FUNCTION enforce_cabin_update_permissions()
RETURNS trigger AS $$
DECLARE
  user_role text;
  user_default_cabin uuid;
BEGIN
  -- Defense-in-depth: immutable fields (also covered by separate triggers)
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
    RAISE EXCEPTION 'organization_id cannot be modified';
  END IF;
  IF NEW.map_id IS DISTINCT FROM OLD.map_id THEN
    RAISE EXCEPTION 'map_id cannot be modified';
  END IF;

  -- Get role and default cabin in one query
  SELECT role, default_cabin_id
  INTO user_role, user_default_cabin
  FROM organization_members
  WHERE organization_id = OLD.organization_id
    AND user_id = auth.uid();

  IF user_role IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- OWNER / ADMIN can update anything
  IF user_role IN ('OWNER','ADMIN') THEN
    RETURN NEW;
  END IF;

  -- MEMBER: must be their default cabin
  IF user_default_cabin IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Members can only update their own cabin';
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_cabin_update_permissions
BEFORE UPDATE ON cabins
FOR EACH ROW
EXECUTE FUNCTION enforce_cabin_update_permissions();


-- Trigger to reassign presence to default cabin when a cabin is deleted. This ensures that users are not left with a reference to a deleted cabin in their presence. The trigger will move any users in the deleted cabin to their default cabin. 
-- If the deleted cabin is set as a default cabin for any user, the delete will be restricted by the foreign key constraint.
-- These bypass the RLS policies, because presence should be overridden on cabin delete by the admin
CREATE OR REPLACE FUNCTION reassign_presence_on_cabin_delete()
RETURNS trigger AS $$
BEGIN
  -- Move all users in this cabin to their default cabin
  UPDATE presence p
  SET current_cabin_id = m.default_cabin_id, status = CASE 
      WHEN p.status = 'IN_ROOM' THEN 'ACTIVE' 
      ELSE p.status 
    END
  FROM organization_members m
  WHERE p.current_cabin_id = OLD.id
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


-- Add trigger to enforce desk-only default cabins
CREATE OR REPLACE FUNCTION enforce_default_cabin_is_desk()
RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cabins 
    WHERE id = NEW.default_cabin_id 
      AND type = 'desk'
  ) THEN
    RAISE EXCEPTION 'Default cabin must be a desk';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_default_cabin_is_desk
BEFORE INSERT OR UPDATE OF default_cabin_id ON organization_members
FOR EACH ROW
EXECUTE FUNCTION enforce_default_cabin_is_desk();


-- Any Member of Organization can view organization members in their organization.
CREATE POLICY "members_select_same_org"
ON organization_members
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organization_members.organization_id
      AND m.user_id = auth.uid()
  )
);

-- Only users with OWNER or ADMIN role can create organization members.
CREATE POLICY "members_insert_admin_owner"
ON organization_members
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organization_members.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER','ADMIN')
  )
);

-- Only users with OWNER or ADMIN role can update organization members.
CREATE POLICY "members_update_admin_owner"
ON organization_members
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organization_members.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER','ADMIN')
  )
);

-- Only users with OWNER or ADMIN role can delete organization members. Or users can delete themselves.
CREATE POLICY "members_delete_admin_owner"
ON organization_members
FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = organization_members.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER', 'ADMIN')
  )
  OR organization_members.user_id = auth.uid()
);

-- Trigger to enforce mutation rules for organization members. This includes preventing ADMIN from creating or promoting OWNER, preventing deleting or demoting the last OWNER, and ensuring that only users with appropriate roles can make changes to memberships.
-- Owners can create/delete/update owners, admins or members. Admin can create/delete/update admins and members but not owners. Members cannot create any memberships.
-- The trigger also ensures that the first member of an organization must be an OWNER and is directly allowed
CREATE OR REPLACE FUNCTION enforce_member_mutation_rules()
RETURNS trigger AS $$
DECLARE
  acting_role text;
  owner_count integer;
BEGIN
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

    IF owner_count <= 1 THEN
      RAISE EXCEPTION 'Cannot remove the last OWNER. Transfer ownership or delete the organization first.';
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

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

-- Any Member of Organization can view presence in their organization.
CREATE POLICY "presence_select_same_org"
ON presence
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = presence.organization_id
      AND m.user_id = auth.uid()
  )
);

-- Users can only insert their own presence.
CREATE POLICY "presence_insert_self"
ON presence
FOR INSERT
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM organization_members m
    WHERE m.organization_id = presence.organization_id
      AND m.user_id = auth.uid()
  )
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

-- Trigger to validate that the cabin assigned in presence belongs to the same organization.
CREATE OR REPLACE FUNCTION validate_presence_cabin()
RETURNS trigger AS $$
BEGIN
  -- Verify the cabin belongs to this organization
  IF NOT EXISTS (
    SELECT 1 FROM cabins c
    WHERE c.id = NEW.current_cabin_id
      AND c.organization_id = NEW.organization_id
  ) THEN
    RAISE EXCEPTION 'Cabin does not belong to this organization';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_presence_cabin ON presence;
CREATE TRIGGER trg_validate_presence_cabin
BEFORE INSERT OR UPDATE ON presence
FOR EACH ROW
EXECUTE FUNCTION validate_presence_cabin();


-- Only OWNER/ADMIN can view audit logs
CREATE POLICY "audit_select_admin_owner"
ON audit_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.organization_id = audit_logs.organization_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER', 'ADMIN')
  )
);

-- No direct inserts/updates/deletes - only via triggers
CREATE POLICY "audit_no_direct_insert" ON audit_logs FOR INSERT WITH CHECK (false);
CREATE POLICY "audit_no_update" ON audit_logs FOR UPDATE USING (false);
CREATE POLICY "audit_no_delete" ON audit_logs FOR DELETE USING (false);


-- Users can see events sent TO them
CREATE POLICY "events_select_recipient"
ON events FOR SELECT
USING (to_user_id = auth.uid());

-- Users can send events to members in same org
CREATE POLICY "events_insert_member"
ON events FOR INSERT
WITH CHECK (
  from_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 
    FROM organization_members m1
    JOIN organization_members m2 ON m1.organization_id = m2.organization_id
    WHERE m1.user_id = auth.uid()
      AND m2.user_id = events.to_user_id
      AND m1.organization_id = events.organization_id
  )
);

-- No updates
CREATE POLICY "events_no_update"
ON events FOR UPDATE
USING (false);

-- Users can delete events sent to them (dismiss)
CREATE POLICY "events_delete_recipient"
ON events FOR DELETE
USING (to_user_id = auth.uid());