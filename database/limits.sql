
-- Trigger to throttle presence updates to once every 30 seconds per user.
CREATE OR REPLACE FUNCTION throttle_presence_update()
RETURNS trigger AS $$
BEGIN
  -- Throttle updates to once per 30 seconds
  IF OLD.updated_at > now() - interval '30 seconds' 
     AND NEW.status = OLD.status 
     AND NEW.current_cabin_id = OLD.current_cabin_id THEN
    -- Same state, too soon — skip the update silently
    RETURN NULL;  -- NULL cancels the update
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_throttle_presence_update
BEFORE UPDATE ON presence
FOR EACH ROW
EXECUTE FUNCTION throttle_presence_update();


-- Trigger to enforce membership limits: max 50 members per organization and max 10 organizations per user. This trigger runs before inserting a new organization_member record and checks the current counts to ensure limits are not exceeded.
CREATE OR REPLACE FUNCTION enforce_membership_limits()
RETURNS trigger AS $$
DECLARE
  member_count integer;
  org_count integer;
  member_limit integer := 50;
  org_limit integer := 10;
BEGIN
  -- Members per org
  SELECT COUNT(*) INTO member_count
  FROM organization_members
  WHERE organization_id = NEW.organization_id;

  IF member_count >= member_limit THEN
    RAISE EXCEPTION 'Organization member limit (%) reached', member_limit;
  END IF;

  -- Orgs per user
  SELECT COUNT(*) INTO org_count
  FROM organization_members
  WHERE user_id = NEW.user_id;

  IF org_count >= org_limit THEN
    RAISE EXCEPTION 'User organization limit (%) reached', org_limit;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_membership_limits
BEFORE INSERT ON organization_members
FOR EACH ROW
EXECUTE FUNCTION enforce_membership_limits();


-- Maps count limit per organization. This trigger runs before inserting a new map and checks the current count of maps for the organization to ensure it does not exceed the limit.
CREATE OR REPLACE FUNCTION enforce_map_limit()
RETURNS trigger AS $$
DECLARE
  map_count integer;
  map_limit integer := 1;       -- only one map per organization for simplicity
BEGIN
  SELECT COUNT(*) INTO map_count
  FROM maps
  WHERE organization_id = NEW.organization_id;

  IF map_count >= map_limit THEN
    RAISE EXCEPTION 'Map limit (%) reached', map_limit;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_map_limit
BEFORE INSERT ON maps
FOR EACH ROW
EXECUTE FUNCTION enforce_map_limit();


-- Cabin count limit per organization. This trigger runs before inserting a new cabin and checks the current count of cabins for the organization to ensure it does not exceed the limit.
CREATE OR REPLACE FUNCTION enforce_cabin_limit()
RETURNS trigger AS $$
DECLARE
  cabin_count integer;
  cabin_limit integer := 50;       -- more than enough for 20 members
BEGIN
  SELECT COUNT(*) INTO cabin_count
  FROM cabins
  WHERE organization_id = NEW.organization_id;

  IF cabin_count >= cabin_limit THEN
    RAISE EXCEPTION 'Cabin limit (%) reached', cabin_limit;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_cabin_limit
BEFORE INSERT ON cabins
FOR EACH ROW
EXECUTE FUNCTION enforce_cabin_limit();


-- Invitation limit per organization. This trigger runs before inserting a new organization invitation and checks the current count of pending invitations for the organization to ensure it does not exceed the limit.
CREATE OR REPLACE FUNCTION enforce_invitation_limit()
RETURNS trigger AS $$
DECLARE
  invite_count integer;
  invite_limit integer := 30;      -- pending, not accepted
BEGIN
  SELECT COUNT(*) INTO invite_count
  FROM organization_invitations
  WHERE organization_id = NEW.organization_id;

  IF invite_count >= invite_limit THEN
    RAISE EXCEPTION 'Pending invitation limit (%) reached', invite_limit;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_invitation_limit
BEFORE INSERT ON organization_invitations
FOR EACH ROW
EXECUTE FUNCTION enforce_invitation_limit();

-- Event rate limit: This trigger runs before inserting a new event and checks how many events the same user has sent to the same recipient in the last minute. If it exceeds the defined limit, it raises an exception to prevent spamming.
CREATE OR REPLACE FUNCTION enforce_event_rate_limit()
RETURNS trigger AS $$
DECLARE
  recent_count integer;
  rate_limit integer := 10;           -- max events
  rate_window interval := '1 minute'; -- per window
BEGIN
  SELECT COUNT(*) INTO recent_count
  FROM events
  WHERE from_user_id = NEW.from_user_id
    AND to_user_id = NEW.to_user_id
    AND created_at > now() - rate_window;

  IF recent_count >= rate_limit THEN
    RAISE EXCEPTION 'Rate limit exceeded. Try again later.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_event_rate_limit
BEFORE INSERT ON events
FOR EACH ROW
EXECUTE FUNCTION enforce_event_rate_limit();