-- Allow authenticated users to insert their own member record
CREATE POLICY "members_self_register" ON members
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Allow members to update their own record
CREATE POLICY "members_update_own" ON members
  FOR UPDATE USING (user_id = auth.uid());
