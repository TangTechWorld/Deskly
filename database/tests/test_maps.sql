-- test_maps.sql
-- pgTAP tests for maps table, constraints, and RLS
BEGIN TRANSACTION;

SET search_path TO public, tap;
SELECT plan(16);

-- 1. OWNER can SELECT maps
SELECT mock_as_authenticated('Owner');
SELECT ok(
  (SELECT COUNT(*) FROM maps WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 1,
  'OWNER can SELECT org map'
);
RESET ROLE;

-- 2. ADMIN can SELECT maps
SELECT mock_as_authenticated('Admin');
SELECT ok(
  (SELECT COUNT(*) FROM maps WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 1,
  'ADMIN can SELECT org map'
);
RESET ROLE;

-- 3. MEMBER can SELECT maps
SELECT mock_as_authenticated('Member');
SELECT ok(
  (SELECT COUNT(*) FROM maps WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 1,
  'MEMBER can SELECT org map'
);
RESET ROLE;

-- 4. STRANGER cannot SELECT maps
SELECT mock_as_authenticated('Stranger');
SELECT ok(
  (SELECT COUNT(*) FROM maps WHERE organization_id = (SELECT mock_get_data('organizations', 'Org1'))) = 0,
  'STRANGER cannot SELECT org map'
);
RESET ROLE;

-- 5. OWNER insert passes RLS but hits one-map-per-org constraint
SELECT mock_as_authenticated('Owner');
SELECT throws_ok($$INSERT INTO maps (organization_id) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$)$$);
RESET ROLE;

-- 6. MEMBER cannot INSERT maps
SELECT mock_as_authenticated('Member');
SELECT throws_ok($$INSERT INTO maps (organization_id) VALUES ($$ || quote_literal((SELECT mock_get_data('organizations', 'Org1'))) || $$)$$);
RESET ROLE;

-- 7. ADMIN can UPDATE maps
SELECT mock_as_authenticated('Admin');
UPDATE maps
SET background_url = 'https://example.com/bg.png'
WHERE id = (SELECT mock_get_data('maps', 'Map1'));
SELECT is(
  (SELECT background_url FROM maps WHERE id = (SELECT mock_get_data('maps', 'Map1'))),
  'https://example.com/bg.png',
  'ADMIN can UPDATE map'
);
RESET ROLE;

-- 8. MEMBER cannot UPDATE maps (no-op)
SELECT mock_as_authenticated('Member');
UPDATE maps
SET cabin_url = 'https://example.com/member-should-not-update.png'
WHERE id = (SELECT mock_get_data('maps', 'Map1'));
RESET ROLE;
SELECT ok(
  (SELECT COALESCE(cabin_url, '') FROM maps WHERE id = (SELECT mock_get_data('maps', 'Map1')))
    <> 'https://example.com/member-should-not-update.png',
  'MEMBER cannot UPDATE map (value unchanged)'
);

-- 9. ADMIN cannot DELETE maps (owner-only delete; no-op)
SELECT mock_as_authenticated('Admin');
DELETE FROM maps WHERE id = (SELECT mock_get_data('maps', 'Map1'));
RESET ROLE;
SELECT ok(
  (SELECT COUNT(*) FROM maps WHERE id = (SELECT mock_get_data('maps', 'Map1'))) = 1,
  'ADMIN cannot DELETE map'
);

-- 10. id cannot be updated
SELECT throws_ok($$UPDATE maps SET id = gen_random_uuid() WHERE id = $$ || quote_literal((SELECT mock_get_data('maps', 'Map1'))) || $$$$);

-- 11. organization_id cannot be updated
SELECT throws_ok($$UPDATE maps SET organization_id = gen_random_uuid() WHERE id = $$ || quote_literal((SELECT mock_get_data('maps', 'Map1'))) || $$$$);

-- 12. created_at cannot be updated
SELECT throws_ok($$UPDATE maps SET created_at = now() - interval '1 day' WHERE id = $$ || quote_literal((SELECT mock_get_data('maps', 'Map1'))) || $$$$);

-- 13. background_url must be https
SELECT throws_ok($$UPDATE maps SET background_url = 'http://bad.com' WHERE id = $$ || quote_literal((SELECT mock_get_data('maps', 'Map1'))) || $$$$);

-- 14. cabin_url must be https
SELECT throws_ok($$UPDATE maps SET cabin_url = 'http://bad.com' WHERE id = $$ || quote_literal((SELECT mock_get_data('maps', 'Map1'))) || $$$$);

-- 15. NULL URLs are allowed
UPDATE maps
SET background_url = NULL,
    cabin_url = NULL
WHERE id = (SELECT mock_get_data('maps', 'Map1'));
SELECT ok(
  (SELECT background_url IS NULL AND cabin_url IS NULL FROM maps WHERE id = (SELECT mock_get_data('maps', 'Map1'))),
  'NULL URLs are allowed'
);

-- 16. updated_at changes on UPDATE
UPDATE maps
SET background_url = 'https://example.com/updated-at-check.png'
WHERE id = (SELECT mock_get_data('maps', 'Map1'));
SELECT ok(
  (SELECT updated_at > created_at FROM maps WHERE id = (SELECT mock_get_data('maps', 'Map1'))),
  'updated_at changes on update'
);

SELECT * FROM finish();

ROLLBACK;
