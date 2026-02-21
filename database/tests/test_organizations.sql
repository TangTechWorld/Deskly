-- test_organizations.sql
-- pgTAP tests for organizations table, constraints, RLS, and triggers
BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(19);

-- 1-3. SELECT tests - RLS verification (members can view)
SELECT mock_as_authenticated('Owner');
SELECT ok((SELECT COUNT(*) FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1'))) = 1, 'OWNER can SELECT org');
RESET ROLE;

SELECT mock_as_authenticated('Admin');
SELECT ok((SELECT COUNT(*) FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1'))) = 1, 'ADMIN can SELECT org');
RESET ROLE;

SELECT mock_as_authenticated('Member');
SELECT ok((SELECT COUNT(*) FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1'))) = 1, 'MEMBER can SELECT org');
RESET ROLE;

-- 4. Stranger cannot view
SELECT mock_as_authenticated('Stranger');
SELECT ok((SELECT COUNT(*) FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1'))) = 0, 'Stranger cannot SELECT org');
RESET ROLE;

-- 5. Invited user can view org via invitation
SELECT mock_as_authenticated('Invited');
SELECT ok((SELECT COUNT(*) FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1'))) = 1, 'Invited user can SELECT org');
RESET ROLE;

-- 6. UPDATE by OWNER
SELECT mock_as_authenticated('Owner');
UPDATE organizations SET name = 'Updated by Owner' WHERE id = (SELECT mock_get_data('organizations', 'Org1'));
SELECT is((SELECT name FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1'))), 'Updated by Owner', 'OWNER can UPDATE org');
RESET ROLE;

-- 7. UPDATE by ADMIN
SELECT mock_as_authenticated('Admin');
UPDATE organizations SET name = 'Updated by Admin' WHERE id = (SELECT mock_get_data('organizations', 'Org1'));
SELECT is((SELECT name FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1'))), 'Updated by Admin', 'ADMIN can UPDATE org');
RESET ROLE;

-- 8. Member cannot update
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$UPDATE organizations SET name = 'Should Fail' WHERE id = $$ || (SELECT mock_get_data('organizations', 'Org1')));
RESET ROLE;

-- 9. Stranger cannot update
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$UPDATE organizations SET name = 'Should Fail' WHERE id = $$ || (SELECT mock_get_data('organizations', 'Org1')));
RESET ROLE;

-- 10. DELETE - Admin cannot delete
SELECT mock_as_authenticated('Admin');
SELECT throws_ok($$DELETE FROM organizations WHERE id = $$ || (SELECT mock_get_data('organizations', 'Org1')));
RESET ROLE;

-- 11. DELETE - Member cannot delete
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$DELETE FROM organizations WHERE id = $$ || (SELECT mock_get_data('organizations', 'Org1')));
RESET ROLE;

-- 12. DELETE - Stranger cannot delete
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$DELETE FROM organizations WHERE id = $$ || (SELECT mock_get_data('organizations', 'Org1')));
RESET ROLE;

-- 13. DELETE - Owner can delete
SELECT mock_as_authenticated('Owner');
DELETE FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'OrgToDelete'));
RESET ROLE;
SELECT ok((SELECT COUNT(*) FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'OrgToDelete'))) = 0, 'OWNER can DELETE org');

-- 14. Direct INSERT into organizations should fail (RLS policy blocks it for everyone)
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$INSERT INTO organizations (name) VALUES ('Direct Insert')$$);
RESET ROLE;

-- 15. Verify id cannot be updated (immutable)
SELECT throws_ok($$UPDATE organizations SET id = gen_random_uuid() WHERE id = $$ || (SELECT mock_get_data('organizations', 'Org1')));

-- 16. Verify created_at cannot be updated (immutable)
SELECT throws_ok($$UPDATE organizations SET created_at = now() - interval $$ || quote_literal('1 day') || $$ WHERE id = $$ || (SELECT mock_get_data('organizations', 'Org1')));

-- 17. Verify org name empty constraint
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$SELECT create_organization('')$$);
RESET ROLE;

-- 18. Verify org name length constraint
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$SELECT create_organization(repeat('a', 101))$$);
RESET ROLE;

-- 19. Verify updated_at is updated on organization change
SELECT mock_as_authenticated('Owner');
SELECT ok(
  (SELECT updated_at FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1')))
    > (SELECT created_at FROM organizations WHERE id = (SELECT mock_get_data('organizations', 'Org1'))),
  'updated_at is newer than created_at after update'
);
RESET ROLE;

SELECT * FROM finish();

ROLLBACK;