-- test_events.sql
-- pgTAP tests for events table, constraints, RLS, and business logic
BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(17);

-- 1. MEMBER (recipient) can SELECT events sent TO them
SELECT mock_as_authenticated('Owner');
INSERT INTO events (organization_id, from_user_id, to_user_id, type, cabin_id)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Owner')),
  (SELECT mock_get_data('users', 'Admin')),
  'ring',
  (SELECT mock_get_data('cabins', 'Desk1'))
);
RESET ROLE;
SELECT mock_as_authenticated('Admin');
SELECT ok(
  (SELECT COUNT(*) FROM events WHERE to_user_id = (SELECT mock_get_data('users', 'Admin'))) >= 1,
  'Recipient can SELECT events sent to them'
);
RESET ROLE;

-- 2. MEMBER can SELECT events sent FROM them (sender)
SELECT mock_as_authenticated('Owner');
SELECT ok(
  (SELECT COUNT(*) FROM events WHERE from_user_id = (SELECT mock_get_data('users', 'Owner'))) >= 1,
  'Sender can SELECT events sent from them'
);
RESET ROLE;

-- 3. STRANGER cannot SELECT events not sent to them
SELECT mock_as_authenticated('Stranger');
SELECT is(
  (SELECT COUNT(*) FROM events WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))),
  0::bigint,
  'Non-recipient cannot SELECT events'
);
RESET ROLE;

-- 4. Member can INSERT event to same org member (from self)
SELECT mock_as_authenticated('Member');
INSERT INTO events (organization_id, from_user_id, to_user_id, type, cabin_id)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Member')),
  (SELECT mock_get_data('users', 'Admin')),
  'knock',
  (SELECT mock_get_data('cabins', 'Desk2'))
);
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM events WHERE from_user_id = (SELECT mock_get_data('users', 'Member')) AND to_user_id = (SELECT mock_get_data('users', 'Admin'))) >= 1,
  'Member can INSERT event to same org member'
);

-- 5. Member cannot INSERT event from another user
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO events (organization_id, from_user_id, to_user_id, type, cabin_id) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Admin'))) || $$, 'ring', $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$)$$);
RESET ROLE;

-- 6. Member cannot INSERT event to STRANGER (not in same org)
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO events (organization_id, from_user_id, to_user_id, type) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Member'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Stranger'))) || $$, 'ring')$$);
RESET ROLE;

-- 7. STRANGER cannot INSERT event (not a member)
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$INSERT INTO events (organization_id, from_user_id, to_user_id, type) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Stranger'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$, 'ring')$$);
RESET ROLE;

-- 8. UPDATE always denied by RLS policy (0 rows affected)
SELECT mock_as_authenticated('Admin');
UPDATE events
SET type = 'ring'
WHERE to_user_id = (SELECT mock_get_data('users', 'Admin'))
  AND type = 'knock';
RESET ROLE;
SELECT is(
  (SELECT type FROM events WHERE to_user_id = (SELECT mock_get_data('users', 'Admin')) AND from_user_id = (SELECT mock_get_data('users', 'Member'))),
  'knock',
  'UPDATE denied by RLS policy (type unchanged)'
);

-- 9. Recipient can DELETE their own events
SELECT mock_as_authenticated('Admin');
DELETE FROM events
WHERE to_user_id = (SELECT mock_get_data('users', 'Admin'))
  AND from_user_id = (SELECT mock_get_data('users', 'Owner'))
  AND type = 'ring';
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM events WHERE to_user_id = (SELECT mock_get_data('users', 'Admin')) AND from_user_id = (SELECT mock_get_data('users', 'Owner')) AND type = 'ring') = 0,
  'Recipient can DELETE their own events'
);

-- 10. Sender cannot DELETE sent events (not recipient, 0 rows affected)
SELECT mock_as_authenticated('Member');
DELETE FROM events
WHERE from_user_id = (SELECT mock_get_data('users', 'Member'))
  AND to_user_id = (SELECT mock_get_data('users', 'Admin'))
  AND type = 'knock';
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM events WHERE from_user_id = (SELECT mock_get_data('users', 'Member')) AND to_user_id = (SELECT mock_get_data('users', 'Admin')) AND type = 'knock') = 1,
  'Sender cannot DELETE sent events (still exists)'
);

-- 11. Invalid type blocked by CHECK constraint
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$INSERT INTO events (organization_id, from_user_id, to_user_id, type) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Member'))) || $$, 'invalid_type')$$);
RESET ROLE;

-- 12. Valid types are allowed: 'ring', 'knock', 'invite_to_room'
SELECT mock_as_authenticated('Owner');
INSERT INTO events (organization_id, from_user_id, to_user_id, type)
VALUES 
  ((SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('users', 'Owner')), (SELECT mock_get_data('users', 'Member')), 'ring'),
  ((SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('users', 'Owner')), (SELECT mock_get_data('users', 'Member')), 'knock'),
  ((SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('users', 'Owner')), (SELECT mock_get_data('users', 'Member')), 'invite_to_room');
RESET ROLE;
SELECT ok(
  (SELECT COUNT(DISTINCT type) FROM events WHERE from_user_id = (SELECT mock_get_data('users', 'Owner')) AND to_user_id = (SELECT mock_get_data('users', 'Member'))) = 3,
  'All valid event types allowed'
);

-- 13. Cabin must belong to organization (composite FK)
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$INSERT INTO events (organization_id, from_user_id, to_user_id, type, cabin_id) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$, $$ || quote_literal((SELECT mock_get_data('users', 'Admin'))) || $$, 'ring', gen_random_uuid())$$);
RESET ROLE;

-- 14. Event with cabin reference
SELECT mock_as_authenticated('Owner');
INSERT INTO events (organization_id, from_user_id, to_user_id, type, cabin_id)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Owner')),
  (SELECT mock_get_data('users', 'Admin')),
  'invite_to_room',
  (SELECT mock_get_data('cabins', 'MeetingRoom1'))
);
RESET ROLE;
SELECT ok(
  (SELECT cabin_id FROM events WHERE from_user_id = (SELECT mock_get_data('users', 'Owner')) AND to_user_id = (SELECT mock_get_data('users', 'Admin')) AND type = 'invite_to_room') = (SELECT mock_get_data('cabins', 'MeetingRoom1')),
  'Event can reference cabin_id'
);

-- 15. CASCADE delete on cabin deletion
SELECT mock_as_authenticated('Owner');
DELETE FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM events WHERE cabin_id = (SELECT mock_get_data('cabins', 'MeetingRoom1'))) = 0,
  'Events CASCADE deleted when cabin deleted'
);

-- 16. CASCADE delete on user deletion
SELECT mock_as_authenticated('Admin');
DELETE FROM events WHERE to_user_id = (SELECT mock_get_data('users', 'Admin'));
RESET ROLE;
-- Delete Member user (will CASCADE delete all events from/to Member)
DELETE FROM users WHERE id = (SELECT mock_get_data('users', 'Member'));
SELECT ok(
  (SELECT COUNT(*) FROM events WHERE from_user_id = (SELECT mock_get_data('users', 'Member')) OR to_user_id = (SELECT mock_get_data('users', 'Member'))) = 0,
  'Events CASCADE deleted when user deleted'
);

-- 17. created_at is set automatically
SELECT mock_as_authenticated('Owner');
INSERT INTO events (organization_id, from_user_id, to_user_id, type)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Owner')),
  (SELECT mock_get_data('users', 'Admin')),
  'ring'
);
RESET ROLE;
SELECT ok(
  (SELECT created_at IS NOT NULL FROM events WHERE from_user_id = (SELECT mock_get_data('users', 'Owner')) AND to_user_id = (SELECT mock_get_data('users', 'Admin')) AND type = 'ring' ORDER BY created_at DESC LIMIT 1),
  'created_at is set automatically'
);

SELECT * FROM finish();

ROLLBACK;
