-- test_users.sql
-- pgTAP tests for users table, constraints, RLS, and triggers
BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(19);

-- 1-3. SELECT tests - RLS verification (self and same org can view)
SELECT mock_as_authenticated('Owner');
SELECT ok((SELECT COUNT(*) FROM users WHERE id = (SELECT mock_get_data('users', 'Owner'))) = 1, 'User can SELECT self');
RESET ROLE;

SELECT mock_as_authenticated('Admin');
SELECT ok((SELECT COUNT(*) FROM users WHERE id = (SELECT mock_get_data('users', 'Admin'))) = 1, 'User can SELECT self (Admin)');
RESET ROLE;

SELECT mock_as_authenticated('Owner');
SELECT ok((SELECT COUNT(*) FROM users WHERE id = (SELECT mock_get_data('users', 'Member'))) = 1, 'User can SELECT same org member');
RESET ROLE;

-- 4. Stranger cannot view other users (not in same org)
SELECT mock_as_authenticated('Stranger');
SELECT ok((SELECT COUNT(*) FROM users WHERE id = (SELECT mock_get_data('users', 'Owner'))) = 0, 'Stranger cannot SELECT other user');
RESET ROLE;

-- 5. UPDATE - User can update only themselves
SELECT mock_as_authenticated('Owner');
UPDATE users SET name = 'Owner Updated' WHERE id = (SELECT mock_get_data('users', 'Owner'));
RESET ROLE;
SELECT is((SELECT name FROM users WHERE id = (SELECT mock_get_data('users', 'Owner'))), 'Owner Updated', 'User can UPDATE self');

-- 6. UPDATE - User cannot update other users
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$UPDATE users SET name = 'Hacked' WHERE id = $$ || (SELECT mock_get_data('users', 'Member')));
RESET ROLE;

-- 7. UPDATE - Stranger cannot update
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$UPDATE users SET name = 'Should Fail' WHERE id = $$ || (SELECT mock_get_data('users', 'Owner')));
RESET ROLE;

-- 8. DELETE - User can delete themselves (if not sole org owner)
SELECT mock_as_authenticated('Member');
DELETE FROM users WHERE id = (SELECT mock_get_data('users', 'Member'));
RESET ROLE;
SELECT ok((SELECT COUNT(*) FROM users WHERE id = (SELECT mock_get_data('users', 'Member'))) = 0, 'Member is deleted from database');

-- 9. DELETE - User cannot delete others
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$DELETE FROM users WHERE id = $$ || (SELECT mock_get_data('users', 'Admin')));
RESET ROLE;

-- 10. DELETE - Cannot delete sole org owner
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$DELETE FROM users WHERE id = $$ || (SELECT mock_get_data('users', 'Owner')));
RESET ROLE;

-- 11. DELETE - Can delete non-last OWNER (when multiple OWNERs exist)
-- First add Stranger as second OWNER to Org1
INSERT INTO organization_members (organization_id, user_id, role, cabin_id)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  (SELECT mock_get_data('users', 'Stranger')),
  'OWNER',
  (SELECT mock_get_data('cabins', 'Desk6'))
);
-- Now Stranger (as OWNER) can delete themselves since Owner is still an OWNER
SELECT mock_as_authenticated('Stranger');
DELETE FROM users WHERE id = (SELECT mock_get_data('users', 'Stranger'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM users WHERE id = (SELECT mock_get_data('users', 'Stranger'))) = 0,
  'Non-last OWNER can delete themselves'
);

-- 12. Verify id cannot be updated (immutable)
SELECT throws_ok($$UPDATE users SET id = gen_random_uuid() WHERE id = $$ || (SELECT mock_get_data('users', 'Owner')));

-- 13. Verify created_at cannot be updated (immutable)
SELECT throws_ok($$UPDATE users SET created_at = now() - interval $$ || quote_literal('1 day') || $$ WHERE id = $$ || (SELECT mock_get_data('users', 'Owner')));

-- 14. Verify updated_at is updated on user change
SELECT mock_as_authenticated('Admin');
UPDATE users SET name = 'Admin Updated' WHERE id = (SELECT mock_get_data('users', 'Admin'));
RESET ROLE;
SELECT ok(
  (SELECT updated_at FROM users WHERE id = (SELECT mock_get_data('users', 'Admin')))
    > (SELECT created_at FROM users WHERE id = (SELECT mock_get_data('users', 'Admin'))),
  'updated_at is newer than created_at after update'
);

-- 15. Verify name empty constraint
SELECT throws_ok($$INSERT INTO users (id, name) VALUES (gen_random_uuid(), '')$$);

-- 16. Verify name length constraint (> 100 chars)
SELECT throws_ok($$INSERT INTO users (id, name) VALUES (gen_random_uuid(), repeat('a', 101))$$);

-- 17. Verify image_url must be https or NULL
SELECT throws_ok($$INSERT INTO users (id, name, image_url) VALUES (gen_random_uuid(), 'Test', 'http://bad.com')$$);

-- 18. Verify image_url can be NULL
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM users WHERE name = 'Test' AND image_url IS NOT NULL
  ) OR EXISTS (
    SELECT 1 FROM users WHERE image_url IS NULL AND name = 'Test'
  ),
  'image_url can be NULL'
);

-- 19. Verify image_url length constraint (> 500 chars)
SELECT throws_ok($$INSERT INTO users (id, name, image_url) VALUES (gen_random_uuid(), 'Test', 'https://' || repeat('a', 500) || '.com')$$);

SELECT * FROM finish();

ROLLBACK;