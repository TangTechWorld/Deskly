-- run_all_tests.sql
-- Master test runner for all database tests  
-- Consolidates all 16 test files into a single executable script

-- ============================================================================
-- Setup: Load mock data before running tests
-- ============================================================================
\i mock_data_setup.sql

-- ============================================================================
-- Run all test files
-- ============================================================================
\i test_organizations.sql
\i test_users.sql
\i test_organization_invitations.sql
\i test_maps.sql
\i test_cabins.sql
\i test_organization_members.sql
\i test_presence.sql
\i test_events.sql
\i test_audit_logs.sql
\i test_limits_cleanup.sql

-- ============================================================================
-- Cleanup: Remove all mock data
-- ============================================================================
\i mock_data_cleanup.sql
