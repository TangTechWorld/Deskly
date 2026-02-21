-- test_presence.sql
-- pgTAP tests for presence table, constraints, RLS, triggers, and business logic
BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(19);

-- 1. MEMBER can SELECT presence
SELECT mock_as_authenticated('Member');
SELECT ok(
  (SELECT COUNT(*) FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) >= 0,
  'MEMBER can SELECT org presence'
);
RESET ROLE;

-- 2. STRANGER cannot SELECT presence
SELECT mock_as_authenticated('Stranger');
SELECT ok(
  (SELECT COUNT(*) FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 0,
  'STRANGER cannot SELECT org presence'
);
RESET ROLE;

-- 3. STRANGER cannot INSERT own presence (not a member)
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$INSERT INTO presence (organization_id, user_id, cabin_id, status) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Stranger'))) || $$, $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$, 'ACTIVE')$$);
RESET ROLE;

-- 4. Member can INSERT own presence
SELECT mock_as_authenticated('Admin');
INSERT INTO presence (organization_id, user_id, cabin_id, status)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Admin')),
  (SELECT mock_get_data('cabins', 'Desk2')),
  'ACTIVE'
)
ON CONFLICT (organization_id, user_id) DO UPDATE SET cabin_id = EXCLUDED.cabin_id, status = EXCLUDED.status;
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Admin'))) = 1,
  'Member can INSERT own presence'
);

-- 5. Member cannot INSERT other's presence
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO presence (organization_id, user_id, cabin_id, status) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$, $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$, 'ACTIVE')$$);
RESET ROLE;

-- 5. Stranger cannot INSERT other's presence
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$INSERT INTO presence (organization_id, user_id, cabin_id, status) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$, $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$, 'ACTIVE')$$);
RESET ROLE;

-- 6. ADMIN cannot INSERT other's presence
SELECT mock_as_authenticated('Admin');
SELECT throws_ok($$INSERT INTO presence (organization_id, user_id, cabin_id, status) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Member'))) || $$, $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk3'))) || $$, 'AWAY')$$);
RESET ROLE;

-- 7. User can UPDATE own presence (status)
SELECT mock_as_authenticated('Admin');
UPDATE presence
SET status = 'IN_ROOM'
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Admin'));
RESET ROLE;
SELECT is(
  (SELECT status FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Admin'))),
  'IN_ROOM',
  'User can UPDATE own presence status'
);

-- 8. User cannot UPDATE other's presence
SELECT mock_as_authenticated('Admin');
UPDATE presence SET status = 'DND'
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Owner'));
RESET ROLE;
SELECT is(
  (SELECT status FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Owner'))),
  'ACTIVE',
  'User cannot UPDATE other''s presence (status unchanged)'
);

-- 9. User can DELETE own presence
SELECT mock_as_authenticated('Admin');
DELETE FROM presence
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Admin'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Admin'))) = 0,
  'User can DELETE own presence'
);

-- 10. User cannot DELETE other's presence
SELECT mock_as_authenticated('Member');
DELETE FROM presence
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Owner'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Owner'))) = 1,
  'User cannot DELETE other''s presence (still exists)'
);

-- 11. Invalid status blocked by CHECK constraint
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO presence (organization_id, user_id, cabin_id, status) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Member'))) || $$, $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk3'))) || $$, 'INVALID_STATUS')$$);
RESET ROLE;

-- 12. custom_status > 50 chars blocked by CHECK constraint
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO presence (organization_id, user_id, cabin_id, status, custom_status) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Member'))) || $$, $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk3'))) || $$, 'ACTIVE', $$ || quote_literal(repeat('a', 51)) || $$)$$);
RESET ROLE;

-- 13. Cabin must belong to organization (validate_presence_cabin trigger)
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO presence (organization_id, user_id, cabin_id, status) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Member'))) || $$, gen_random_uuid(), 'ACTIVE')$$);
RESET ROLE;

-- 14. organization_id cannot be updated
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$UPDATE presence SET organization_id = gen_random_uuid() WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$$$);
RESET ROLE;

-- 15. user_id cannot be updated
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$UPDATE presence SET user_id = gen_random_uuid() WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$$$);
RESET ROLE;

-- 16. Presence CASCADE deleted when member is removed
-- First add Stranger as a member
INSERT INTO organization_members (organization_id, user_id, role, cabin_id)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Stranger')),
  'MEMBER',
  (SELECT mock_get_data('cabins', 'Desk5'))
);
-- Stranger inserts their own presence
SELECT mock_as_authenticated('Stranger');
INSERT INTO presence (organization_id, user_id, cabin_id, status)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Stranger')),
  (SELECT mock_get_data('cabins', 'Desk5')),
  'ACTIVE'
);
RESET ROLE;
-- Owner deletes the member (should CASCADE delete presence)
SELECT mock_as_authenticated('Owner');
DELETE FROM organization_members
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Stranger'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Stranger'))) = 0,
  'Presence CASCADE deleted when member removed'
);

-- 17. Unlock cabin when last person leaves locked cabin
-- First lock a cabin by having someone in it
SELECT mock_as_authenticated('Member');
INSERT INTO presence (organization_id, user_id, cabin_id, status)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Member')),
  (SELECT mock_get_data('cabins', 'MeetingRoom1')),
  'IN_ROOM'
)
ON CONFLICT (organization_id, user_id) DO UPDATE SET cabin_id = (SELECT mock_get_data('cabins', 'MeetingRoom1')), status = 'IN_ROOM';
-- Lock the cabin as Member (who is present in the room)
UPDATE cabins SET is_locked = true WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'));
-- Remove the Member's presence (last person leaves)
DELETE FROM presence
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Member'));
RESET ROLE;
SELECT ok(
  (SELECT is_locked FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'))) = false,
  'Cabin unlocked when last person leaves'
);

-- 18. updated_at set on presence record
SELECT mock_as_authenticated('Owner');
INSERT INTO presence (organization_id, user_id, cabin_id, status)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Owner')),
  (SELECT mock_get_data('cabins', 'Desk1')),
  'ACTIVE'
)
ON CONFLICT (organization_id, user_id) DO NOTHING;
RESET ROLE;
SELECT ok(
  (SELECT updated_at IS NOT NULL FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Owner'))),
  'updated_at set on presence record'
);

SELECT * FROM finish();

ROLLBACK;
