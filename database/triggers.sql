

-- Organization cannot be updated on any of the tables to prevent complications with row level security and data integrity. This trigger function is used by multiple tables, so we create it once and reuse it for each table.
CREATE OR REPLACE FUNCTION prevent_org_id_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
    RAISE EXCEPTION 'organization_id cannot be modified';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_no_org_change_cabins
BEFORE UPDATE ON cabins
FOR EACH ROW
EXECUTE FUNCTION prevent_org_id_update();

CREATE TRIGGER trg_no_org_change_maps
BEFORE UPDATE ON maps
FOR EACH ROW
EXECUTE FUNCTION prevent_org_id_update();

CREATE TRIGGER trg_no_org_change_members
BEFORE UPDATE ON organization_members
FOR EACH ROW
EXECUTE FUNCTION prevent_org_id_update();

-- Not needed because UPDATE is disabled for invitations, but we add it for defense in depth in case that ever changes in the future.
CREATE TRIGGER trg_no_org_change_invitations
BEFORE UPDATE ON organization_invitations
FOR EACH ROW
EXECUTE FUNCTION prevent_org_id_update();

CREATE TRIGGER trg_no_org_change_presence
BEFORE UPDATE ON presence
FOR EACH ROW
EXECUTE FUNCTION prevent_org_id_update();

------------------------------------------------------------------------------------------------------------------------------------------------

-- Primary key id cannot be updated on any table. This trigger function is used by multiple tables, so we create it once and reuse it for each table.
CREATE OR REPLACE FUNCTION prevent_id_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Primary key id cannot be modified';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_id_change_organizations
BEFORE UPDATE ON organizations
FOR EACH ROW
EXECUTE FUNCTION prevent_id_update();

CREATE TRIGGER trg_no_id_change_maps
BEFORE UPDATE ON maps
FOR EACH ROW
EXECUTE FUNCTION prevent_id_update();

CREATE TRIGGER trg_no_id_change_cabins
BEFORE UPDATE ON cabins
FOR EACH ROW
EXECUTE FUNCTION prevent_id_update();

CREATE TRIGGER trg_no_id_change_users
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION prevent_id_update();

------------------------------------------------------------------------------------------------------------------------------------------------

-- created_at cannot be updated on any table to preserve data integrity. This trigger function is used by multiple tables, so we create it once and reuse it for each table.
CREATE OR REPLACE FUNCTION prevent_created_at_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'created_at cannot be modified';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_created_at_change_organizations
BEFORE UPDATE ON organizations
FOR EACH ROW
EXECUTE FUNCTION prevent_created_at_update();

CREATE TRIGGER trg_no_created_at_change_maps
BEFORE UPDATE ON maps
FOR EACH ROW
EXECUTE FUNCTION prevent_created_at_update();

CREATE TRIGGER trg_no_created_at_change_cabins
BEFORE UPDATE ON cabins
FOR EACH ROW
EXECUTE FUNCTION prevent_created_at_update();

CREATE TRIGGER trg_no_created_at_change_users
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION prevent_created_at_update();

CREATE TRIGGER trg_no_created_at_change_members
BEFORE UPDATE ON organization_members
FOR EACH ROW
EXECUTE FUNCTION prevent_created_at_update();

------------------------------------------------------------------------------------------------------------------------------------------------

-- user_id in organization_members and presence cannot be updated to prevent complications with row level security and data integrity. This trigger function is used by both tables.
CREATE OR REPLACE FUNCTION prevent_user_id_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    RAISE EXCEPTION 'user_id cannot be modified';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_user_id_change_members
BEFORE UPDATE ON organization_members
FOR EACH ROW
EXECUTE FUNCTION prevent_user_id_update();

CREATE TRIGGER trg_no_user_id_change_presence
BEFORE UPDATE ON presence
FOR EACH ROW
EXECUTE FUNCTION prevent_user_id_update();

------------------------------------------------------------------------------------------------------------------------------------------------

-- map_id in cabins cannot be updated to prevent complications with row level security and data integrity. This trigger function is used by cabins.
CREATE OR REPLACE FUNCTION prevent_map_id_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.map_id IS DISTINCT FROM OLD.map_id THEN
    RAISE EXCEPTION 'map_id cannot be modified';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_map_id_change_cabins
BEFORE UPDATE ON cabins
FOR EACH ROW
EXECUTE FUNCTION prevent_map_id_update();

------------------------------------------------------------------------------------------------------------------------------------------------

-- updated_at is automatically set to now() on any update to keep track of when records were last modified. This trigger function is used by multiple tables, so we create it once and reuse it for each table.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER z_trg_set_updated_at_organizations
BEFORE UPDATE OR INSERT ON organizations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER z_trg_set_updated_at_maps
BEFORE UPDATE OR INSERT ON maps
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER z_trg_set_updated_at_cabins
BEFORE UPDATE OR INSERT ON cabins
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER z_trg_set_updated_at_users
BEFORE UPDATE OR INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER z_trg_set_updated_at_members
BEFORE UPDATE OR INSERT ON organization_members
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER z_trg_set_updated_at_presence
BEFORE UPDATE OR INSERT ON presence
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

------------------------------------------------------------------------------------------------------------------------------------------------

-- Logs audit records. Can only be triggered by other functions in this schema, not directly by users.
CREATE OR REPLACE FUNCTION audit_log(
  p_org_id uuid,
  p_action text,
  p_target_type text DEFAULT NULL,
  p_target_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'
) RETURNS void AS $$
BEGIN
  INSERT INTO public.audit_logs (organization_id, actor_id, action, target_type, target_id, metadata)
  VALUES (p_org_id, auth.uid(), p_action, p_target_type, p_target_id, p_metadata);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION audit_log FROM PUBLIC;
REVOKE ALL ON FUNCTION audit_log FROM authenticated;


-- org.created, org.updated audit events
CREATE OR REPLACE FUNCTION audit_organization_change()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM audit_log(
      NEW.id,
      'org.created',
      'organization',
      NEW.id,
      jsonb_build_object('name', NEW.name)
    );
  ELSIF TG_OP = 'UPDATE' AND OLD.name IS DISTINCT FROM NEW.name THEN
    PERFORM audit_log(
      NEW.id,
      'org.updated',
      'organization',
      NEW.id,
      jsonb_build_object('old_name', OLD.name, 'new_name', NEW.name)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_organization_change
AFTER INSERT OR UPDATE ON organizations
FOR EACH ROW
EXECUTE FUNCTION audit_organization_change();


-- member.added, member.joined audit events (via invitation)
CREATE OR REPLACE FUNCTION audit_member_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM audit_log(
    NEW.organization_id,
    'member.added',
    'member',
    NEW.user_id,
    jsonb_build_object('role', NEW.role)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_member_insert
AFTER INSERT ON organization_members
FOR EACH ROW
EXECUTE FUNCTION audit_member_insert();


-- member.role_changed audit event
CREATE OR REPLACE FUNCTION audit_member_update()
RETURNS trigger AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    PERFORM audit_log(
      NEW.organization_id,
      'member.role_changed',
      'member',
      NEW.user_id,
      jsonb_build_object('old_role', OLD.role, 'new_role', NEW.role)
    );
  END IF;
  
  IF OLD.default_cabin_id IS DISTINCT FROM NEW.default_cabin_id THEN
    PERFORM audit_log(
      NEW.organization_id,
      'member.cabin_reassigned',
      'member',
      NEW.user_id,
      jsonb_build_object('old_cabin', OLD.default_cabin_id, 'new_cabin', NEW.default_cabin_id)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_member_update
AFTER UPDATE ON organization_members
FOR EACH ROW
EXECUTE FUNCTION audit_member_update();


-- member.removed audit event
CREATE OR REPLACE FUNCTION audit_member_delete()
RETURNS trigger AS $$
BEGIN
  PERFORM audit_log(
    OLD.organization_id,
    'member.removed',
    'member',
    OLD.user_id,
    jsonb_build_object('role', OLD.role)
  );
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_member_delete
AFTER DELETE ON organization_members
FOR EACH ROW
EXECUTE FUNCTION audit_member_delete();


-- Function to mask email -> jo***@g***.co**
CREATE OR REPLACE FUNCTION mask_email(p_email text)
RETURNS text AS $$
DECLARE
  local_part text;
  domain text;
  domain_name text;
  tld text;
  visible_local integer;
  visible_domain integer;
BEGIN
  local_part := split_part(p_email, '@', 1);
  domain := split_part(p_email, '@', 2);
  domain_name := split_part(domain, '.', 1);
  tld := substring(domain from position('.' in domain));  -- e.g. ".com", ".co.uk"

  visible_local := GREATEST(1, LEAST(3, char_length(local_part) - 2));
  visible_domain := GREATEST(1, LEAST(3, char_length(domain_name) - 2));

  RETURN left(local_part, visible_local) || '***@'
      || left(domain_name, visible_domain) || '***'
      || left(tld, 3) || '**';
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- invitation.sent audit event
CREATE OR REPLACE FUNCTION audit_invitation_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM audit_log(
    NEW.organization_id,
    'invitation.sent',
    'invitation',
    NEW.id,
    jsonb_build_object('email', mask_email(NEW.email))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_invitation_insert
AFTER INSERT ON organization_invitations
FOR EACH ROW
EXECUTE FUNCTION audit_invitation_insert();


-- invitation.revoked audit event (admin deleted it)
CREATE OR REPLACE FUNCTION audit_invitation_delete()
RETURNS trigger AS $$
BEGIN
  -- Only log if deleted by admin (not by accept_invitation)
  -- We detect this by checking if the user just became a member
  IF NOT EXISTS (
    SELECT 1 FROM organization_members
    WHERE organization_id = OLD.organization_id
      AND user_id = auth.uid()
      AND created_at > now() - interval '30 seconds'
  ) THEN
    PERFORM audit_log(
      OLD.organization_id,
      'invitation.revoked',
      'invitation',
      OLD.id,
      jsonb_build_object('email', mask_email(OLD.email))
    );
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_invitation_delete
AFTER DELETE ON organization_invitations
FOR EACH ROW
EXECUTE FUNCTION audit_invitation_delete();


-- cabin.created audit event
CREATE OR REPLACE FUNCTION audit_cabin_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM audit_log(
    NEW.organization_id,
    'cabin.created',
    'cabin',
    NEW.id,
    jsonb_build_object('name', NEW.name)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_cabin_insert
AFTER INSERT ON cabins
FOR EACH ROW
EXECUTE FUNCTION audit_cabin_insert();


-- cabin.updated audit event
CREATE OR REPLACE FUNCTION audit_cabin_update()
RETURNS trigger AS $$
DECLARE
  changes jsonb := '{}';
BEGIN
  IF OLD.name IS DISTINCT FROM NEW.name THEN
    changes := changes || jsonb_build_object('name', jsonb_build_object('old', OLD.name, 'new', NEW.name));
  END IF;
  
  IF OLD.x IS DISTINCT FROM NEW.x OR OLD.y IS DISTINCT FROM NEW.y THEN
    changes := changes || jsonb_build_object('position', jsonb_build_object(
      'old', jsonb_build_object('x', OLD.x, 'y', OLD.y),
      'new', jsonb_build_object('x', NEW.x, 'y', NEW.y)
    ));
  END IF;
  
  IF OLD.width IS DISTINCT FROM NEW.width OR OLD.height IS DISTINCT FROM NEW.height THEN
    changes := changes || jsonb_build_object('size', jsonb_build_object(
      'old', jsonb_build_object('w', OLD.width, 'h', OLD.height),
      'new', jsonb_build_object('w', NEW.width, 'h', NEW.height)
    ));
  END IF;

  IF changes <> '{}' THEN
    PERFORM audit_log(
      NEW.organization_id,
      'cabin.updated',
      'cabin',
      NEW.id,
      changes
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_cabin_update
AFTER UPDATE ON cabins
FOR EACH ROW
EXECUTE FUNCTION audit_cabin_update();


-- cabin.deleted audit event
CREATE OR REPLACE FUNCTION audit_cabin_delete()
RETURNS trigger AS $$
BEGIN
  PERFORM audit_log(
    OLD.organization_id,
    'cabin.deleted',
    'cabin',
    OLD.id,
    jsonb_build_object('name', OLD.name)
  );
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_cabin_delete
AFTER DELETE ON cabins
FOR EACH ROW
EXECUTE FUNCTION audit_cabin_delete();


-- map.updated audit event
CREATE OR REPLACE FUNCTION audit_map_update()
RETURNS trigger AS $$
DECLARE
  changes jsonb := '{}';
BEGIN
  IF OLD.background_url IS DISTINCT FROM NEW.background_url THEN
    changes := changes || jsonb_build_object('background_url', 'changed');
  END IF;
  
  IF OLD.default_cabin_url IS DISTINCT FROM NEW.default_cabin_url THEN
    changes := changes || jsonb_build_object('default_cabin_url', 'changed');
  END IF;

  IF changes <> '{}' THEN
    PERFORM audit_log(
      NEW.organization_id,
      'map.updated',
      'map',
      NEW.id,
      changes
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER trg_audit_map_update
AFTER UPDATE ON maps
FOR EACH ROW
EXECUTE FUNCTION audit_map_update();