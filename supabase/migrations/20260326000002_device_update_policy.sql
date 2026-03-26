-- Allow members to update their own device records (needed for upsert)
CREATE POLICY "devices_update_own" ON member_devices
  FOR UPDATE USING (member_id = get_my_member_id());
