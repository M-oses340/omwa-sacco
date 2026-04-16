-- ============================================================
-- Fix RLS policies to allow all admin roles to read all data
-- chairman and secretary were missing from read policies
-- ============================================================

-- Drop the restrictive policies
DROP POLICY IF EXISTS "transactions_admin_read_all" ON transactions;
DROP POLICY IF EXISTS "bosa_admin_read_all" ON bosa_accounts;
DROP POLICY IF EXISTS "fosa_admin_read_all" ON fosa_accounts;
DROP POLICY IF EXISTS "members_admin_read_all" ON members;

-- Recreate with all four admin roles
CREATE POLICY "transactions_admin_read_all" ON transactions
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer', 'secretary', 'chairman'));

CREATE POLICY "bosa_admin_read_all" ON bosa_accounts
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer', 'secretary', 'chairman'));

CREATE POLICY "fosa_admin_read_all" ON fosa_accounts
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer', 'secretary', 'chairman'));

CREATE POLICY "members_admin_read_all" ON members
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer', 'secretary', 'chairman'));

-- Also allow admin roles to read loans and notifications
DROP POLICY IF EXISTS "loans_admin_read_all" ON loans;
CREATE POLICY "loans_admin_read_all" ON loans
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer', 'secretary', 'chairman'));

DROP POLICY IF EXISTS "notifications_admin_read_all" ON notifications;
CREATE POLICY "notifications_admin_read_all" ON notifications
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer', 'secretary', 'chairman'));
