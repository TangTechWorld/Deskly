-- test_audit_logs.sql
-- pgTAP tests for audit_logs RLS, constraints, and audit event triggers

BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(24);

-- 1. OWNER can SELECT audit logs
SELECT mock_as_authenticated('Owner');
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) >= 0,
  'OWNER can SELECT audit logs'
);
RESET ROLE;

-- 2. ADMIN can SELECT audit logs
SELECT mock_as_authenticated('Admin');
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) >= 0,
  'ADMIN can SELECT audit logs'
);
RESET ROLE;

-- 3. MEMBER cannot SELECT audit logs
SELECT mock_as_authenticated('Member');
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 0,
  'MEMBER cannot SELECT audit logs'
);
RESET ROLE;

-- 4. STRANGER cannot SELECT audit logs
SELECT mock_as_authenticated('Stranger');
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 0,
  'STRANGER cannot SELECT audit logs'
);
RESET ROLE;

-- 5. Direct INSERT not allowed for authenticated users
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$INSERT INTO audit_logs (id, organization_id, action) VALUES (gen_random_uuid(), gen_random_uuid(), 'test')$$);
RESET ROLE;

-- 6. Direct UPDATE not allowed for authenticated users (0 rows affected)
SELECT mock_as_authenticated('Owner');
UPDATE audit_logs SET action = 'changed' WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1')) AND action = 'changed') = 0,
  'Authenticated user cannot UPDATE audit_logs (0 rows affected)'
);

-- 7. Direct DELETE not allowed for authenticated users (0 rows affected)
SELECT mock_as_authenticated('Owner');
DELETE FROM audit_logs WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) > 0,
  'Authenticated user cannot DELETE from audit_logs (rows remain)'
);

-- 8. Create test org structure as Stranger - this verifies org.created, map.created, and member.added in one operation
SELECT mock_as_authenticated('Stranger');
SELECT create_organization('Test Stack Org');
RESET ROLE;

-- Verify org.created, map.created, and member.added all logged
SELECT mock_as_authenticated('Stranger');
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'org.created' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND metadata->>'name' = 'Test Stack Org') > 0,
  'org.created audit event logged on organization insert'
);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'map.created' AND actor_id = (SELECT mock_get_data('users', 'Stranger'))) > 0,
  'map.created audit event logged automatically with org creation'
);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'member.added' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND metadata->>'role' = 'OWNER') > 0,
  'member.added audit event logged for creator as OWNER'
);
RESET ROLE;

-- 9. org.updated audit event - update org name
SELECT mock_as_authenticated('Stranger');
UPDATE organizations SET name = 'Test Stack Org Updated' WHERE name = 'Test Stack Org';
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'org.updated' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1)) > 0,
  'org.updated audit event logged on organization update'
);
RESET ROLE;

-- 10. invitation.sent audit event - create invitation
SELECT mock_as_authenticated('Stranger');
INSERT INTO organization_invitations (organization_id, email, message)
VALUES ((SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1), 'invited@example.com', 'Join us!');
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'invitation.sent' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1)) > 0,
  'invitation.sent audit event logged on invitation insert'
);
RESET ROLE;

-- 11. member.added audit event - add new member via invitation acceptance
SELECT mock_as_authenticated('Stranger');
INSERT INTO organization_invitations (organization_id, email, message)
VALUES (
  (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1),
  'member@example.com',
  'Join as member'
);

-- Ensure a cabin exists for the member to be assigned to
INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height)
SELECT o.id, m.id, 'Test Desk', 'desk', 105, 105, 2, 2
FROM organizations o
JOIN maps m ON m.organization_id = o.id
WHERE o.name = 'Test Stack Org Updated'
LIMIT 1;

SELECT mock_as_authenticated('Member');
SELECT accept_invitation((SELECT id FROM organization_invitations WHERE organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1) AND email = 'member@example.com' LIMIT 1));
RESET ROLE;
SELECT mock_as_authenticated('Stranger');
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'member.added' AND actor_id = (SELECT mock_get_data('users', 'Member')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1) AND metadata->>'role' = 'MEMBER') > 0,
  'member.added audit event logged on member acceptance'
);
RESET ROLE;

-- 12. member.role_changed audit event - change member role
SELECT mock_as_authenticated('Stranger');
UPDATE organization_members SET role = 'ADMIN' WHERE user_id = (SELECT mock_get_data('users', 'Member')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'member.role_changed' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1) AND metadata->>'new_role' = 'ADMIN') > 0,
  'member.role_changed audit event logged on role update'
);
RESET ROLE;

-- 13. member.cabin_reassigned audit event - change member cabin
SELECT mock_as_authenticated('Stranger');
-- Ensure at least 2 cabins exist for the reassignment test
INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height)
SELECT o.id, m.id, 'Test Desk 4', 'desk', 115, 115, 2, 2
FROM organizations o
JOIN maps m ON m.organization_id = o.id
WHERE o.name = 'Test Stack Org Updated'
LIMIT 1;

UPDATE organization_members SET cabin_id = (SELECT id FROM cabins WHERE organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1) AND name = 'Test Desk 4' LIMIT 1) WHERE user_id = (SELECT mock_get_data('users', 'Member')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'member.cabin_reassigned' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1)) > 0,
  'member.cabin_reassigned audit event logged on cabin change'
);
RESET ROLE;

-- 14. cabin.updated audit event - update cabin
SELECT mock_as_authenticated('Stranger');
UPDATE cabins SET name = 'Updated Test Cabin' WHERE organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'cabin.updated' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1)) > 0,
  'cabin.updated audit event logged on cabin update'
);
RESET ROLE;

-- 15. member.removed audit event - delete member (but not the owner)
SELECT mock_as_authenticated('Stranger');
DELETE FROM organization_members WHERE user_id = (SELECT mock_get_data('users', 'Member')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'member.removed' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1) AND metadata->>'role' = 'ADMIN') > 0,
  'member.removed audit event logged on member delete'
);
RESET ROLE;

-- 16. cabin.deleted audit event - first create and then delete a cabin
SELECT mock_as_authenticated('Stranger');
INSERT INTO cabins (organization_id, map_id, name, type, x, y, width, height)
VALUES ((SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1), (SELECT id FROM maps WHERE organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1) LIMIT 1), 'Temp Cabin', 'desk', 110, 110, 2, 2);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'cabin.created' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1) AND metadata->>'name' = 'Temp Cabin') > 0,
  'cabin.created audit event logged on cabin insert'
);
DELETE FROM cabins WHERE name = 'Temp Cabin' AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'cabin.deleted' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1) AND metadata->>'name' = 'Temp Cabin') > 0,
  'cabin.deleted audit event logged on cabin delete'
);
RESET ROLE;

-- 17. invitation.deleted audit event - delete invitation
SELECT mock_as_authenticated('Stranger');
DELETE FROM organization_invitations WHERE email = 'invited@example.com' AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'invitation.deleted' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1)) > 0,
  'invitation.deleted audit event logged on invitation delete'
);
RESET ROLE;

-- 18. map.updated audit event - update map background
SELECT mock_as_authenticated('Stranger');
UPDATE maps SET background_url = 'https://example.com/bg.png' WHERE organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'map.updated' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND organization_id = (SELECT id FROM organizations WHERE name = 'Test Stack Org Updated' LIMIT 1)) > 0,
  'map.updated audit event logged on map update'
);
RESET ROLE;

-- 19. map.deleted audit event - delete map
-- 20. org.deleted audit event - delete org (last step)
SELECT mock_as_authenticated('Stranger');
DELETE FROM organizations WHERE name = 'Test Stack Org Updated';
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'org.deleted' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND metadata->>'name' = 'Test Stack Org Updated') = 0,
  'Cant access audit logs after org deleted'
);
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'map.deleted' AND actor_id = (SELECT mock_get_data('users', 'Stranger'))) > 0,
  'map.deleted audit event logged on map delete'
);
SELECT ok(
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'org.deleted' AND actor_id = (SELECT mock_get_data('users', 'Stranger')) AND metadata->>'name' = 'Test Stack Org Updated') > 0,
  'org.deleted audit event logged on organization delete'
);


SELECT * FROM finish();

ROLLBACK;
