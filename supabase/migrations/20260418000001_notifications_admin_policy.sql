-- Allow admins to insert notifications for any member (read policy already exists in 20260416000001)
DROP POLICY IF EXISTS "notifications_admin_insert" ON notifications;
CREATE POLICY "notifications_admin_insert" ON notifications
  FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'treasurer', 'secretary', 'chairman'));
