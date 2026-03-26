-- Allow members to insert their own transactions
CREATE POLICY "transactions_insert_own" ON transactions
  FOR INSERT WITH CHECK (member_id = get_my_member_id());

-- Allow members to update their own BOSA account balance
CREATE POLICY "bosa_update_own" ON bosa_accounts
  FOR UPDATE USING (member_id = get_my_member_id());

-- Allow members to update their own FOSA account balance
CREATE POLICY "fosa_update_own" ON fosa_accounts
  FOR UPDATE USING (member_id = get_my_member_id());
