-- test_organization_members.sql
-- pgTAP tests for organization_members table, constraints, RLS, triggers, and business logic
BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(24);

-- 1. MEMBER can SELECT organization members
SELECT mock_as_authenticated('Member');
SELECT ok(
  (SELECT COUNT(*) FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) >= 3,
  'MEMBER can SELECT org members'
);
RESET ROLE;

-- 2. STRANGER cannot SELECT organization members
SELECT mock_as_authenticated('Stranger');
SELECT ok(
  (SELECT COUNT(*) FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 0,
  'STRANGER cannot SELECT org members'
);
RESET ROLE;

-- 3. OWNER can add member via invitation acceptance
SELECT mock_as_authenticated('Owner');
INSERT INTO organization_invitations (organization_id, email, message)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  'invited2@example.com',
  'Join the org'
);
RESET ROLE;
SELECT mock_as_authenticated('Invited2');
SELECT accept_invitation((SELECT id FROM organization_invitations WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND email = 'invited2@example.com' LIMIT 1));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Invited2'))) = 1,
  'Member added via invitation acceptance'
);

-- 4. ADMIN can add member via invitation acceptance
SELECT mock_as_authenticated('Admin');
INSERT INTO organization_invitations (organization_id, email, message)
VALUES (
  (SELECT mock_get_data('organizations', 'Org1')),
  'stranger@example.com',
  'Join the org'
);
RESET ROLE;
SELECT mock_as_authenticated('Stranger');
SELECT accept_invitation((SELECT id FROM organization_invitations WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND email = 'stranger@example.com' LIMIT 1));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Stranger'))) = 1,
  'Member added via invitation acceptance'
);


-- 5. MEMBER cannot INSERT member directly (RLS blocks all direct inserts)
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO organization_members (organization_id, user_id, role, cabin_id) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, gen_random_uuid(), 'MEMBER', $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk3'))) || $$)$$);
RESET ROLE;

-- 6. OWNER can UPDATE member role
SELECT mock_as_authenticated('Owner');
UPDATE organization_members
SET role = 'ADMIN'
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Invited2'));
RESET ROLE;
SELECT is(
  (SELECT role FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Invited2'))),
  'ADMIN',
  'OWNER can UPDATE member role'
);

-- 7. OWNER can UPDATE member cabin_id
SELECT mock_as_authenticated('Owner');
UPDATE organization_members
SET cabin_id = (SELECT mock_get_data('cabins', 'Desk6'))
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Invited2'));
RESET ROLE;
SELECT is(
  (SELECT cabin_id FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Invited2'))),
  (SELECT mock_get_data('cabins', 'Desk6')),
  'OWNER can UPDATE member cabin_id'
);

-- 8. OWNER can DELETE member (this frees Desk5 for later tests)
SELECT mock_as_authenticated('Owner');
DELETE FROM organization_members
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Stranger'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Stranger'))) = 0,
  'OWNER can DELETE member'
);

-- 9. immutability: organization_id cannot be updated
SELECT throws_ok($$UPDATE organization_members SET organization_id = gen_random_uuid() WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$$$);

-- 10. immutability: user_id cannot be updated
SELECT throws_ok($$UPDATE organization_members SET user_id = gen_random_uuid() WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$$$);

-- 11. immutability: created_at cannot be updated
SELECT throws_ok($$UPDATE organization_members SET created_at = now() - interval '1 day' WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$$$);

-- 12. invalid role is blocked by CHECK constraint
SELECT throws_ok($$INSERT INTO organization_members (organization_id, user_id, role, cabin_id) VALUES ((SELECT mock_get_data('organizations', 'Org1')), gen_random_uuid(), 'INVALID_ROLE', (SELECT mock_get_data('cabins', 'Desk1')))$$);

-- 13. cabin must be desk type, not room (enforce_cabin_is_desk trigger)
SELECT throws_ok($$INSERT INTO organization_members (organization_id, user_id, role, cabin_id) VALUES ((SELECT mock_get_data('organizations', 'Org1')), gen_random_uuid(), 'MEMBER', (SELECT mock_get_data('cabins', 'MeetingRoom1')))$$);

-- 14. duplicate cabin_id is blocked by UNIQUE constraint
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$INSERT INTO organization_members (organization_id, user_id, role, cabin_id) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, gen_random_uuid(), 'MEMBER', $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk3'))) || $$)$$);
RESET ROLE;

-- 15. delete_presence_on_member_remove: deleting member also deletes their presence
-- Switch to Member to insert their own presence
SELECT mock_as_authenticated('Member');
UPDATE presence SET cabin_id = (SELECT mock_get_data('cabins', 'Desk5')) WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Member'));
RESET ROLE;
-- Delete member as Owner
SELECT mock_as_authenticated('Owner');
DELETE FROM organization_members
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Member'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM presence WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Member'))) = 0,
  'Presence deleted when member is removed'
);

-- 16. updated_at changes on UPDATE
SELECT mock_as_authenticated('Owner');
UPDATE organization_members
SET cabin_id = (SELECT mock_get_data('cabins', 'Desk2'))
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Admin'));
RESET ROLE;
SELECT ok(
  (SELECT updated_at > created_at FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Admin'))),
  'updated_at changes on update'
);

-- 17. Direct INSERT is blocked for all users (members can only be added via invitation acceptance)
SELECT mock_as_authenticated('Admin');
SELECT throws_ok($$INSERT INTO organization_members (organization_id, user_id, role, cabin_id) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, gen_random_uuid(), 'OWNER', $$ || quote_literal((SELECT mock_get_data('cabins', 'Desk1'))) || $$)$$);
RESET ROLE;

-- 18. ADMIN cannot promote member to OWNER (enforce_member_mutation_rules)
SELECT mock_as_authenticated('Admin');
SELECT throws_ok($$UPDATE organization_members SET role = 'OWNER' WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$ AND user_id = $$ || quote_literal((SELECT mock_get_data('users', 'Invited2'))) || $$$$);
RESET ROLE;

-- 19. ADMIN cannot demote OWNER (enforce_member_mutation_rules)
SELECT mock_as_authenticated('Admin');
SELECT throws_ok($$UPDATE organization_members SET role = 'ADMIN' WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$ AND user_id = $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$$$);
RESET ROLE;

-- 20. ADMIN cannot delete OWNER (enforce_member_mutation_rules)
SELECT mock_as_authenticated('Admin');
SELECT throws_ok($$DELETE FROM organization_members WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$ AND user_id = $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$$$);
RESET ROLE;

-- 21. Cannot delete the last OWNER (prevent_last_owner_removal)
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$DELETE FROM organization_members WHERE organization_id = $$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$ AND user_id = $$ || quote_literal((SELECT mock_get_data('users', 'Owner'))) || $$$$);
RESET ROLE;


-- 23. Member can delete self
SELECT mock_as_authenticated('Member');
DELETE FROM organization_members
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Member'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Member'))) = 0,
  'Member can delete self'
);

-- 24. Member cannot delete other members
SELECT mock_as_authenticated('Member');
DELETE FROM organization_members
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Admin'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Admin'))) = 1,
  'Member cannot delete other members (still exists)'
);

-- 25. MEMBER cannot perform UPDATE operations on other members
SELECT mock_as_authenticated('Member');
-- Try to update Admin's cabin to Desk1 (Admin currently has Desk2)
UPDATE organization_members
SET cabin_id = (SELECT mock_get_data('cabins', 'Desk1'))
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND user_id = (SELECT mock_get_data('users', 'Admin'));
RESET ROLE;
SELECT ok(
  (SELECT cabin_id FROM organization_members WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND user_id = (SELECT mock_get_data('users', 'Admin'))) = (SELECT mock_get_data('cabins', 'Desk2')),
  'MEMBER cannot perform UPDATE operations (data unchanged)'
);

SELECT * FROM finish();

ROLLBACK;
