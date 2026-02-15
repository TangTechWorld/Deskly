

-- Functions for complex operations that involve multiple steps and need to bypass RLS policies. These functions are defined with SECURITY DEFINER to allow them to perform actions that the calling user may not have direct permissions for, while still enforcing necessary checks within the function logic.
-- The create_organization function creates a new organization, a default map, and a default cabin for the creator, and adds the creator as an OWNER member. It checks that the user is authenticated and has a profile before allowing organization creation.
CREATE OR REPLACE FUNCTION create_organization(
  org_name text
) RETURNS uuid AS $$
DECLARE
  new_org_id uuid;
  new_map_id uuid;
  new_cabin_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid()) THEN
    RAISE EXCEPTION 'User profile not found. Complete signup first.';
  END IF;

  -- Insert organization
  INSERT INTO public.organizations (name)
  VALUES (org_name)
  RETURNING id INTO new_org_id;
  
  -- Insert map
  INSERT INTO public.maps (organization_id)
  VALUES (new_org_id)
  RETURNING id INTO new_map_id;
  
  -- Insert first cabin
  INSERT INTO public.cabins (organization_id, map_id, name, type, x, y, width, height)
  VALUES (new_org_id, new_map_id, 'Owner Cabin', 'desk', 0, 0, 100, 100)
  RETURNING id INTO new_cabin_id;
  
  -- Insert creator as OWNER with default cabin
  INSERT INTO public.organization_members (organization_id, user_id, role, default_cabin_id)
  VALUES (new_org_id, auth.uid(), 'OWNER', new_cabin_id);
  
  RETURN new_org_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION create_organization(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_organization(text) TO authenticated;

------------------------------------------------------------------------------------------------------------------------------------------------

-- The accept_invitation function allows a user to accept an invitation to join an organization. It checks that the invitation exists and belongs to the user, that the user is not already a member of the organization, and then adds the user as a MEMBER with an assigned cabin. It also deletes the invitation after acceptance.
CREATE OR REPLACE FUNCTION accept_invitation(
  p_invitation_id uuid
) RETURNS void AS $$
DECLARE
  v_org_id uuid;
  v_email text;
  v_map_id uuid;
  v_cabin_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid()) THEN
    RAISE EXCEPTION 'User profile not found. Complete signup first.';
  END IF;

  -- Validate invitation exists and belongs to this user
  SELECT organization_id, email INTO v_org_id, v_email
  FROM organization_invitations
  WHERE id = p_invitation_id;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;

  IF LOWER(v_email) <> LOWER(auth.email()) THEN
    RAISE EXCEPTION 'Invitation does not belong to this user';
  END IF;

  -- Check not already a member
  IF EXISTS (
    SELECT 1 FROM organization_members
    WHERE organization_id = v_org_id AND user_id = auth.uid()
  ) THEN
    DELETE FROM public.organization_invitations WHERE id = p_invitation_id; -- Clean up the invitation
    RETURN; -- Already a member, nothing to do
  END IF;

  -- Get the map for this org
  SELECT id INTO v_map_id FROM maps WHERE organization_id = v_org_id LIMIT 1;

  IF v_map_id IS NULL THEN
    RAISE EXCEPTION 'Organization has no map';
  END IF;

  -- Select an available cabin for the new member. Any available cabin not assigned will do.
  SELECT c.id INTO v_cabin_id
  FROM cabins c
  WHERE c.organization_id = v_org_id
    AND c.map_id = v_map_id
    AND c.type = 'desk'
    AND NOT EXISTS (
      SELECT 1 FROM organization_members om 
      WHERE om.organization_id = v_org_id
        AND om.default_cabin_id = c.id
    )
  ORDER BY c.created_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_cabin_id IS NULL THEN
    RAISE EXCEPTION 'No available cabins for new member';
  END IF;

  -- Insert as MEMBER
  INSERT INTO public.organization_members (organization_id, user_id, role, default_cabin_id)
  VALUES (v_org_id, auth.uid(), 'MEMBER', v_cabin_id);

  -- Delete the invitation
  DELETE FROM public.organization_invitations WHERE id = p_invitation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION accept_invitation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION accept_invitation(uuid) TO authenticated;

------------------------------------------------------------------------------------------------------------------------------------------------

-- Get recent activity for an org (for admin dashboard)
CREATE OR REPLACE FUNCTION get_audit_logs(
  p_org_id uuid,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
) RETURNS TABLE (
  id uuid,
  actor_id uuid,
  actor_name text,
  action text,
  target_type text,
  target_id uuid,
  metadata jsonb,
  created_at timestamptz
) AS $$
BEGIN
  -- Check caller is OWNER/ADMIN
  IF NOT EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.organization_id = p_org_id
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER', 'ADMIN')
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT 
    a.id,
    a.actor_id,
    u.name as actor_name,
    a.action,
    a.target_type,
    a.target_id,
    a.metadata,
    a.created_at
  FROM audit_logs a
  LEFT JOIN users u ON u.id = a.actor_id
  WHERE a.organization_id = p_org_id
  ORDER BY a.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION get_audit_logs FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_audit_logs TO authenticated;