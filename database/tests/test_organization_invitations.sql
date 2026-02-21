-- test_organization_invitations.sql
-- pgTAP tests for organization_invitations table, constraints, RLS, and triggers
BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(21);

-- 1. OWNER can SELECT invitations for org
SELECT mock_as_authenticated('Owner');
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations
   WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) >= 1,
  'OWNER can SELECT org invitations'
);
RESET ROLE;

-- 2. ADMIN can SELECT invitations for org
SELECT mock_as_authenticated('Admin');
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations
   WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) >= 1,
  'ADMIN can SELECT org invitations'
);
RESET ROLE;

-- 3. MEMBER cannot SELECT invitations for org
SELECT mock_as_authenticated('Member');
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations
   WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 0,
  'MEMBER cannot SELECT org invitations'
);
RESET ROLE;

-- 4. Invited user can SELECT own invitation
SELECT mock_as_authenticated('Invited');
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations WHERE LOWER(email) = 'invited@example.com') = 1,
  'Invited user can SELECT own invitation'
);
RESET ROLE;

-- 5. OWNER can INSERT invitation
SELECT mock_as_authenticated('Owner');
INSERT INTO organization_invitations (id, organization_id, email, message)
VALUES ((SELECT mock_get_data('invitations', 'TempInvitation1')), (SELECT mock_get_data('organizations', 'Org1')), 'owner-invite@example.com', 'Welcome!');
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'))) = 1,
  'OWNER can INSERT invitation'
);


-- 7. ADMIN can INSERT invitation
SELECT mock_as_authenticated('Admin');
INSERT INTO organization_invitations (id, organization_id, email, message)
VALUES ((SELECT mock_get_data('invitations', 'TempInvitation2')), (SELECT mock_get_data('organizations', 'Org1')), 'admin-invite@example.com', 'Please join');
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation2'))) = 1,
  'ADMIN can INSERT invitation'
);


-- 9. MEMBER cannot INSERT invitation
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, 'member-blocked@example.com', 'msg')$$);
RESET ROLE;

-- 10. STRANGER cannot INSERT invitation
SELECT mock_as_authenticated('Stranger');
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, 'stranger-blocked@example.com', 'msg')$$);
RESET ROLE;

-- 11. Invited user cannot INSERT invitation
SELECT mock_as_authenticated('Invited');
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, 'invited-blocked@example.com', 'msg')$$);
RESET ROLE;

-- 12. OWNER can DELETE invitation
SELECT mock_as_authenticated('Owner');
DELETE FROM organization_invitations
WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation2'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation2'))) = 0,
  'OWNER can DELETE invitation'
);


-- 14. MEMBER cannot DELETE invitation
SELECT mock_as_authenticated('Member');
DELETE FROM organization_invitations
WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'))) = 1,
  'MEMBER cannot DELETE invitation (row remains)'
);

-- 15. Invited user can DELETE own invitation
SELECT mock_as_authenticated('Invited');
DELETE FROM organization_invitations
WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))
  AND LOWER(email) = 'invited@example.com';
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations WHERE LOWER(email) = 'invited@example.com') = 0,
  'Invited user can DELETE own invitation'
);


-- 17. UPDATE is denied for OWNER
SELECT mock_as_authenticated('Owner');
UPDATE organization_invitations
SET message = 'Updated'
WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations
   WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'))
     AND message = 'Welcome!') = 1,
  'UPDATE is denied for OWNER (message unchanged)'
);

-- 18. UPDATE is denied for ADMIN
SELECT mock_as_authenticated('Admin');
UPDATE organization_invitations
SET message = 'Updated'
WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations
   WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'))
     AND message = 'Welcome!') = 1,
  'UPDATE is denied for ADMIN (message unchanged)'
);

-- 19. UPDATE is denied for MEMBER
SELECT mock_as_authenticated('Member');
UPDATE organization_invitations
SET message = 'Updated'
WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations
   WHERE id = (SELECT mock_get_data('invitations', 'TempInvitation1'))
     AND message = 'Welcome!') = 1,
  'UPDATE is denied for MEMBER (message unchanged)'
);

-- 20. Existing member cannot be invited
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, 'admin@example.com', 'msg')$$);
RESET ROLE;

-- 21. Duplicate invitation (same org + email) is blocked
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$, 'owner-invite@example.com', 'duplicate')$$);
RESET ROLE;

-- 22. Invalid email is blocked by constraint
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ((SELECT mock_get_data('organizations', 'Org1')), 'bademail', 'msg')$$);

-- 23. Empty message is blocked by constraint
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ((SELECT mock_get_data('organizations', 'Org1')), 'empty-message@example.com', '')$$);

-- 24. Message > 500 chars is blocked by constraint
SELECT throws_ok($$INSERT INTO organization_invitations (organization_id, email, message) VALUES ((SELECT mock_get_data('organizations', 'Org1')), 'long-message@example.com', repeat('a', 501))$$);

-- 25. Same email can be invited to different organizations
SELECT mock_as_authenticated('Owner');
-- First, insert an invitation to OrgToDelete with an email
INSERT INTO organization_invitations (organization_id, email, message)
VALUES ((SELECT mock_get_data('organizations', 'OrgToDelete')), 'multi-org@example.com', 'Join Org1');
-- Then, insert the same email to Org1
INSERT INTO organization_invitations (organization_id, email, message)
VALUES ((SELECT mock_get_data('organizations', 'Org1')), 'multi-org@example.com', 'Join Org2');
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM organization_invitations WHERE email = 'multi-org@example.com') = 2,
  'Same email can be invited to different organizations'
);

SELECT * FROM finish();

ROLLBACK;
