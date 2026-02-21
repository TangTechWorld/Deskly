-- Run every 5 minutes
SELECT cron.schedule('cleanup-presence', '*/5 * * * *', 'SELECT cleanup_stale_presence()');
-- Daily at 3am: stale invitations
SELECT cron.schedule('cleanup-invitations', '0 3 * * *', 'SELECT cleanup_stale_invitations()');
-- Daily at 3am: audit logs
SELECT cron.schedule('cleanup-audit-logs', '0 3 * * *', 'SELECT cleanup_old_audit_logs()');
-- Daily at 3am: events
SELECT cron.schedule('cleanup-events', '0 3 * * *', 'SELECT cleanup_old_events()');

-- Stale presence: 30 minutes no update
CREATE OR REPLACE FUNCTION cleanup_stale_presence(retention interval DEFAULT '30 minutes')
RETURNS integer AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM presence
  WHERE updated_at < now() - retention;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET row_security = OFF;

-- Stale invitations: 30 days
CREATE OR REPLACE FUNCTION cleanup_stale_invitations(retention interval DEFAULT '30 days')
RETURNS integer AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM organization_invitations
  WHERE created_at < now() - retention;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET row_security = OFF;

-- Audit logs: 90 days
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(retention interval DEFAULT '90 days')
RETURNS integer AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM audit_logs
  WHERE created_at < now() - retention;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET row_security = OFF;

-- Events: 7 days
CREATE OR REPLACE FUNCTION cleanup_old_events(retention interval DEFAULT '7 days')
RETURNS integer AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM events
  WHERE created_at < now() - retention;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET row_security = OFF;

