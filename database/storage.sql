/* Storage Buckets and Policies
avatars/
  {user_id}/avatar.png

org-assets/
  {org_id}/map-background.png
  {org_id}/cabins/{cabin_id}.png
  {org_id}/default-cabin.png
*/

-- Create buckets
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('avatars', 'avatars', true),        -- public read, controlled write
  ('org-assets', 'org-assets', true);   -- public read, controlled write

UPDATE storage.buckets
SET file_size_limit = 2097152,  -- 2MB
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp']
WHERE id IN ('avatars', 'org-assets');

-- AVATARS: users can upload/update/delete their own avatar
CREATE POLICY "avatar_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'avatars'
  AND auth.uid() IS NOT NULL
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "avatar_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "avatar_delete" ON storage.objects
FOR DELETE USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ORG-ASSETS: only OWNER/ADMIN can upload org images
CREATE POLICY "org_assets_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'org-assets'
  AND EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.organization_id = (storage.foldername(name))[1]::uuid
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER', 'ADMIN')
  )
);

-- Only OWNER/ADMIN can update org images
CREATE POLICY "org_assets_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'org-assets'
  AND EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.organization_id = (storage.foldername(name))[1]::uuid
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER', 'ADMIN')
  )
);

-- Only OWNER/ADMIN can delete org images
CREATE POLICY "org_assets_delete" ON storage.objects
FOR DELETE USING (
  bucket_id = 'org-assets'
  AND EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.organization_id = (storage.foldername(name))[1]::uuid
      AND m.user_id = auth.uid()
      AND m.role IN ('OWNER', 'ADMIN')
  )
);

-- Members can upload cabin images for their own cabin
CREATE POLICY "org_assets_member_cabin_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'org-assets'
  AND (storage.foldername(name))[2] = 'cabins'
  AND storage.filename(name) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(png|jpg|jpeg|webp)$'
  AND EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.organization_id = (storage.foldername(name))[1]::uuid
      AND m.user_id = auth.uid()
      AND m.cabin_id::text = split_part(storage.filename(name), '.', 1)
      AND m.role = 'MEMBER'
  )
);

-- Members can update cabin images for their own cabin
CREATE POLICY "org_assets_member_cabin_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'org-assets'
  AND (storage.foldername(name))[2] = 'cabins'
  AND storage.filename(name) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(png|jpg|jpeg|webp)$'
  AND EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.organization_id = (storage.foldername(name))[1]::uuid
      AND m.user_id = auth.uid()
      AND m.cabin_id::text = split_part(storage.filename(name), '.', 1)
      AND m.role = 'MEMBER'
  )
);

/*
const { data, error } = await supabase.storage
  .from('avatars')
  .upload(`${userId}/avatar.png`, file, {
    upsert: true,
    contentType: file.type
  })

await supabase.storage
  .from('org-assets')
  .upload(`${orgId}/cabins/${cabinId}.png`, file, { upsert: true })
*/