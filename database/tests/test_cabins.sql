-- test_cabins.sql
-- pgTAP tests for cabins table, constraints, RLS, and triggers
BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(29);

-- 1. MEMBER can SELECT cabins
SELECT mock_as_authenticated('Member');
SELECT ok(
  (SELECT COUNT(*) FROM cabins WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) >= 5,
  'MEMBER can SELECT org cabins'
);
RESET ROLE;

-- 2. STRANGER cannot SELECT cabins
SELECT mock_as_authenticated('Stranger');
SELECT ok(
  (SELECT COUNT(*) FROM cabins WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 0,
  'STRANGER cannot SELECT org cabins'
);
RESET ROLE;

-- 3. ADMIN can INSERT cabin
SELECT mock_as_authenticated('Admin');
INSERT INTO cabins (id, organization_id, map_id, name, type, x, y, width, height)
VALUES (
  (SELECT mock_get_data('cabins', 'TempCabin')),
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('maps', 'Map1')),
  'New Cabin',
  'desk',
  10, 10, 1, 1
);
SELECT ok(
  (SELECT COUNT(*) FROM cabins
   WHERE id = (SELECT mock_get_data('cabins', 'TempCabin'))) = 1,
  'ADMIN can INSERT cabin'
);
RESET ROLE;

-- 4. MEMBER cannot INSERT cabin
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, $$ || quote_literal((SELECT mock_get_data('maps', 'Map1'))) || $$, 'Hacker Cabin', 'desk', 20, 20, 1, 1)$$);
RESET ROLE;

-- 5. ADMIN can UPDATE cabin fields
SELECT mock_as_authenticated('Admin');
UPDATE cabins
SET name = 'Updated Cabin Name', x = 12
WHERE id = (SELECT mock_get_data('cabins', 'TempCabin'));
SELECT is(
  (SELECT name FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'TempCabin'))),
  'Updated Cabin Name',
  'ADMIN can UPDATE cabin fields'
);
RESET ROLE;

-- 6. MEMBER can UPDATE own cabin name, cabin_url, and link_url
SELECT mock_as_authenticated('Member');
UPDATE cabins
SET name = 'Desk3 Updated by Member', cabin_url = 'https://example.com/meet', link_url = 'https://example.com/link'
WHERE id = (SELECT mock_get_data('cabins', 'Desk3'));
SELECT is(
  (SELECT name FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'Desk3'))),
  'Desk3 Updated by Member',
  'MEMBER can UPDATE own cabin name'
);
SELECT is(
  (SELECT cabin_url FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'Desk3'))),
  'https://example.com/meet',
  'MEMBER can UPDATE own cabin cabin_url'
);
SELECT is(
  (SELECT link_url FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'Desk3'))),
  'https://example.com/link',
  'MEMBER can UPDATE own cabin link_url'
);
RESET ROLE;

-- 7. MEMBER cannot update x coordinate on own cabin
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$UPDATE cabins SET x = 99 WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk3'))) || $$$$, 'Members cannot modify layout or structural fields');
RESET ROLE;

-- 8. MEMBER cannot update width on own cabin
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$UPDATE cabins SET width = 20 WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk3'))) || $$$$, 'Members cannot modify layout or structural fields');
RESET ROLE;

-- 9. MEMBER cannot modify structural fields on other cabins (trigger exception)
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$UPDATE cabins SET y = 99 WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$$$);
RESET ROLE;

-- 10. MEMBER cannot DELETE cabins (row remains)
SELECT mock_as_authenticated('Member');
DELETE FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'TempCabin'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'TempCabin'))) = 1,
  'MEMBER cannot DELETE cabin'
);

-- 11. OWNER can DELETE cabins
SELECT mock_as_authenticated('Owner');
DELETE FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'TempCabin'));
SELECT ok(
  (SELECT COUNT(*) FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'TempCabin'))) = 0,
  'OWNER can DELETE cabin'
);
RESET ROLE;

-- 12. locked cannot be set to true without presence in cabin
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$UPDATE cabins SET is_locked = true WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'MeetingRoom1'))) || $$$$);
RESET ROLE;

-- 13. locked can be set to true if presence is in cabin
SELECT mock_as_authenticated('Member');
DELETE FROM presence WHERE user_id = (SELECT mock_get_data('users', 'Member'));
INSERT INTO presence (user_id, organization_id, cabin_id, status)
VALUES ((SELECT mock_get_data('users', 'Member')), (SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('cabins', 'MeetingRoom1')), 'ACTIVE');
UPDATE cabins
SET is_locked = true
WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'));
SELECT is(
  (SELECT is_locked FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'))),
  true,
  'locked can be set to true when presence is in cabin'
);
RESET ROLE;

-- 14. locked cannot be set to false if presence still in cabin
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$UPDATE cabins SET is_locked = false WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'MeetingRoom1'))) || $$$$);
RESET ROLE;

-- 15. locked can be set to false if presence is removed
SELECT mock_as_authenticated('Member');
UPDATE cabins SET is_locked = true WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'));
DELETE FROM presence WHERE cabin_id = (SELECT mock_get_data('cabins', 'MeetingRoom1'));
SELECT mock_as_authenticated('Owner');
UPDATE cabins
SET is_locked = false
WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'));
SELECT is(
  (SELECT is_locked FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'))),
  false,
  'locked can be set to false when no presence in cabin'
);
RESET ROLE;

-- 16. member can lock cabin they are present in, even if not assigned to them
SELECT mock_as_authenticated('Admin');
DELETE FROM presence WHERE user_id = (SELECT mock_get_data('users', 'Admin'));
INSERT INTO presence (user_id, organization_id, cabin_id, status)
VALUES ((SELECT mock_get_data('users', 'Admin')), (SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('cabins', 'Desk1')), 'ACTIVE');
UPDATE cabins
SET is_locked = true
WHERE id = (SELECT mock_get_data('cabins', 'Desk1'));
SELECT is(
  (SELECT is_locked FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'Desk1'))),
  true,
  'member can lock cabin when present even if not assigned to them'
);
DELETE FROM presence WHERE cabin_id = (SELECT mock_get_data('cabins', 'Desk1'));
RESET ROLE;

-- 17. link_url can be updated for meeting room cabins
SELECT mock_as_authenticated('Admin');
UPDATE cabins
SET link_url = 'https://meet.example.com/room1'
WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'));
SELECT is(
  (SELECT link_url FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'MeetingRoom1'))),
  'https://meet.example.com/room1',
  'link_url can be updated for meeting room cabins'
);
RESET ROLE;

-- 18. presence is migrated to own cabin when non-desk cabin is deleted
SELECT mock_as_authenticated('Member');
DELETE FROM presence WHERE user_id = (SELECT mock_get_data('users', 'Member'));
INSERT INTO presence (user_id, organization_id, cabin_id, status)
VALUES ((SELECT mock_get_data('users', 'Member')), (SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('cabins', 'FocusZone1')), 'ACTIVE');
SELECT ok(
  (SELECT cabin_id FROM presence WHERE user_id = (SELECT mock_get_data('users', 'Member'))) = (SELECT mock_get_data('cabins', 'FocusZone1')),
  'Member presence in FocusZone1'
);
SELECT mock_as_authenticated('Owner');
DELETE FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'FocusZone1'));
SELECT ok(
  (SELECT cabin_id FROM presence WHERE user_id = (SELECT mock_get_data('users', 'Member'))) = (SELECT cabin_id FROM organization_members WHERE user_id = (SELECT mock_get_data('users', 'Member'))),
  'Presence migrated to own cabin after deletion'
);
RESET ROLE;

-- 19. id cannot be updated
SELECT throws_ok($$UPDATE cabins SET id = gen_random_uuid() WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$$$);

-- 20. organization_id cannot be updated
SELECT throws_ok($$UPDATE cabins SET organization_id = gen_random_uuid() WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$$$);

-- 21. map_id cannot be updated
SELECT throws_ok($$UPDATE cabins SET map_id = gen_random_uuid() WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$$$);

-- 22. created_at cannot be updated
SELECT throws_ok($$UPDATE cabins SET created_at = now() - interval '1 day' WHERE id = $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$$$);

-- 23. invalid type is blocked
SELECT throws_ok($$INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height) VALUES ((SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('maps', 'Map1')), 'Bad Type Cabin', 'invalid', 30, 30, 1, 1)$$);

-- 24. width <= 0 is blocked
SELECT throws_ok($$INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height) VALUES ((SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('maps', 'Map1')), 'Bad Width Cabin', 'desk', 31, 31, 0, 1)$$);

-- 25. non-https cabin_url is blocked
SELECT throws_ok($$INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height, cabin_url) VALUES ((SELECT mock_get_data('organizations', 'Org1')), (SELECT mock_get_data('maps', 'Map1')), 'Bad Cabin Url', 'desk', 32, 32, 1, 1, 'http://bad.com')$$);

-- 26. updated_at changes on UPDATE
UPDATE cabins
SET name = 'Desk2 Updated Timestamp'
WHERE id = (SELECT mock_get_data('cabins', 'Desk2'));
SELECT ok(
  (SELECT updated_at > created_at FROM cabins WHERE id = (SELECT mock_get_data('cabins', 'Desk2'))),
  'updated_at changes on update'
);

SELECT * FROM finish();

ROLLBACK;
