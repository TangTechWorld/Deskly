-- test_limits_cleanup.sql
-- pgTAP tests for 6 limit enforcement functions and 4 cleanup functions
-- Tests cover: presence throttle, map/cabin/invitation limits, org limit per user, event rate limit, and cleanup
-- Membership limits not tested directly since cabin limits (max 50 per org) effectively constrain members

BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(14);

-- ======== LIMIT ENFORCEMENT TESTS ========

-- 1. Presence update throttle: updates within 30 seconds with no state change are throttled
SELECT mock_as_authenticated('Member');
DELETE FROM presence WHERE user_id = (SELECT mock_get_data('users', 'Member'));
INSERT INTO presence (organization_id, user_id, cabin_id, status, updated_at)
VALUES ((SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('users', 'Member')), (SELECT mock_get_data('cabins', 'Desk3')), 'ACTIVE', now());
SELECT throws_ok($$UPDATE presence SET updated_at = now() WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$ AND user_id = $$ || quote_literal((SELECT mock_get_data('users', 'Member'))) || $$$$);
RESET ROLE;

-- 2. Map limit: only 1 map per organization enforced by trigger
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$INSERT INTO maps (organization_id) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$)$$);
RESET ROLE;

-- 3. Cabin limit: max 50 cabins per organization
SELECT mock_as_authenticated('Owner');
DO $$
DECLARE
  v_org_id uuid := (SELECT mock_get_data('organizations', 'Org1'));
  v_map_id uuid := (SELECT id FROM maps WHERE organization_id = v_org_id LIMIT 1);
  i integer;
  cabin_count integer;
BEGIN
  -- Org1 already has 8 cabins, add 42 more to reach 50
  FOR i IN 1..42 LOOP
    INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height)
    VALUES (v_org_id, v_map_id, 'Cabin ' || i, 'desk', i * 100, 100, 100, 100);
  END LOOP;
  cabin_count := (SELECT COUNT(*)::int FROM cabins WHERE organization_id = v_org_id);
END
$$;
SELECT is((SELECT COUNT(*)::int FROM cabins WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))), 50, '50 cabins total in Org1');
SELECT throws_ok($$INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT id FROM maps WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) LIMIT 1)) || $$, 'Cabin Over Limit', 'desk', 999, 0, 100, 100)$$);
RESET ROLE;

-- 4. Invitation limit: max 30 pending invitations per organization
SELECT mock_as_authenticated('Owner');
DO $$
DECLARE
  v_org_id uuid := (SELECT mock_get_data('organizations', 'Org1'));
  i integer;
BEGIN
  -- First delete existing invitations
  DELETE FROM organization_invitations WHERE organization_id = v_org_id;
  FOR i IN 1..30 LOOP
    INSERT INTO organization_invitations (organization_id, email, message)
    VALUES (v_org_id, 'invite' || i || '@test.com', 'Join');
  END LOOP;
END
$$;
SELECT is((SELECT COUNT(*)::int FROM organization_invitations WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))), 30, '30 invitations inserted');
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, 'invite-over-limit@example.com', 'Join')$$);
RESET ROLE;

-- 5. Organization limit per user: max 10 orgs per user
SELECT mock_as_authenticated('Owner');
DO $$
DECLARE
  i integer;
BEGIN
  -- Owner has 2 orgs already (Org1 + Org To Delete), create 8 more to hit limit of 10
  FOR i IN 1..8 LOOP
    PERFORM create_organization('Owner Org Limit Test ' || i);
  END LOOP;
END
$$;
SELECT is((SELECT COUNT(*)::int FROM organization_members WHERE user_id = (SELECT auth.uid())), 10, 'User has 10 organizations');
SELECT throws_ok($$SELECT create_organization('Owner Over Org Limit')$$);
RESET ROLE;

-- 6. Event rate limit: max 10 events per minute between two users
SELECT mock_as_authenticated('Member');
DO $$
DECLARE
  v_org_id uuid;
  v_from_user uuid := (SELECT mock_get_data('users', 'Member'));
  v_to_user uuid := (SELECT mock_get_data('users', 'Admin'));
  i integer;
BEGIN
  v_org_id := (SELECT mock_get_data('organizations', 'Org1'));
  
  -- Clear and insert exactly 10 events within same minute
  DELETE FROM events WHERE organization_id = v_org_id AND from_user_id = v_from_user AND to_user_id = v_to_user;
  FOR i IN 1..10 LOOP
    INSERT INTO events (organization_id, from_user_id, to_user_id, type)
    VALUES (v_org_id, v_from_user, v_to_user, 'ring');
  END LOOP;
END
$$;
SELECT is((SELECT COUNT(*)::int FROM events WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND from_user_id = (SELECT mock_get_data('users', 'Member')) AND to_user_id = (SELECT mock_get_data('users', 'Admin'))), 10, '10 events inserted within rate window');
SELECT throws_ok($$INSERT INTO events (organization_id, from_user_id, to_user_id, type) VALUES ((SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('users', 'Member')), (SELECT mock_get_data('users', 'Admin')), 'ring')$$);
RESET ROLE;

-- ======== CLEANUP FUNCTION TESTS ========

-- 7. cleanup_stale_presence: removes presence older than threshold
DO $$
DECLARE
  v_org_id uuid := (SELECT mock_get_data('organizations', 'Org1'));
BEGIN
  DELETE FROM presence WHERE organization_id = v_org_id;
  INSERT INTO presence (organization_id, user_id, cabin_id, status, updated_at) VALUES 
    (v_org_id, (SELECT mock_get_data('users', 'Member')), (SELECT mock_get_data('cabins', 'Desk3')), 'ACTIVE', now() - interval '31 minutes');
  PERFORM cleanup_stale_presence('30 minutes');
END
$$;
SELECT is((SELECT COUNT(*)::int FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND updated_at < now() - interval '30 minutes'), 0, 'Old presence deleted by cleanup_stale_presence');

-- 8. cleanup_stale_invitations: removes invitations older than threshold
DO $$
DECLARE
  v_invite_id uuid := gen_random_uuid();
  v_org_id uuid := (SELECT mock_get_data('organizations', 'Org1'));
BEGIN
  DELETE FROM organization_invitations WHERE organization_id = v_org_id;
  INSERT INTO organization_invitations (id, organization_id, email, message, created_at) VALUES (v_invite_id, v_org_id, 'old-inv-' || v_invite_id::text || '@example.com', 'msg', now() - interval '31 days');
  PERFORM cleanup_stale_invitations('30 days');
END
$$;
SELECT is((SELECT COUNT(*)::int FROM organization_invitations WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND created_at < now() - interval '30 days'), 0, 'Old invitation deleted by cleanup_stale_invitations');

-- 9. cleanup_old_audit_logs: removes audit logs older than threshold
DO $$
DECLARE
  v_log_id uuid := gen_random_uuid();
  v_org_id uuid := (SELECT mock_get_data('organizations', 'Org1'));
BEGIN
  INSERT INTO audit_logs (id, organization_id, action, created_at) VALUES (v_log_id, v_org_id, 'test.cleanup', now() - interval '91 days');
  PERFORM cleanup_old_audit_logs('90 days');
END
$$;
SELECT is((SELECT COUNT(*)::int FROM audit_logs WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND created_at < now() - interval '90 days'), 0, 'Old audit log deleted by cleanup_old_audit_logs');

-- 10. cleanup_old_events: removes events older than threshold
DO $$
DECLARE
  v_event_id uuid := gen_random_uuid();
  v_org_id uuid := (SELECT mock_get_data('organizations', 'Org1'));
  v_user1_id uuid := (SELECT mock_get_data('users', 'Member'));
  v_user2_id uuid := (SELECT mock_get_data('users', 'Admin'));
BEGIN
  DELETE FROM events WHERE organization_id = v_org_id;
  INSERT INTO events (id, organization_id, from_user_id, to_user_id, type, created_at) VALUES (v_event_id, v_org_id, v_user1_id, v_user2_id, 'ring', now() - interval '25 hours');
  PERFORM cleanup_old_events('24 hours');
END
$$;
SELECT is((SELECT COUNT(*)::int FROM events WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND created_at < now() - interval '24 hours'), 0, 'Old event deleted by cleanup_old_events');

SELECT * FROM finish();

ROLLBACK;
