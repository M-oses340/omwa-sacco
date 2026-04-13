-- ============================================================
-- Notifications & Reports Support Tables
-- ============================================================

-- ── 1. device_tokens ─────────────────────────────────────────────────────────
-- Stores FCM push tokens per device per member

CREATE TABLE IF NOT EXISTS device_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id   UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  token       TEXT NOT NULL,
  platform    VARCHAR(20) DEFAULT 'android', -- android | ios
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_member_id ON device_tokens(member_id);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Members can manage their own tokens; service role bypasses RLS
CREATE POLICY "device_tokens_own" ON device_tokens
  FOR ALL USING (member_id = get_my_member_id());

-- ── 2. notification_preferences ──────────────────────────────────────────────
-- Per-member opt-in/out per notification type

CREATE TABLE IF NOT EXISTS notification_preferences (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id            UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  deposits             BOOLEAN DEFAULT TRUE,
  withdrawals          BOOLEAN DEFAULT TRUE,
  loan_updates         BOOLEAN DEFAULT TRUE,
  repayment_reminders  BOOLEAN DEFAULT TRUE,
  dividends            BOOLEAN DEFAULT TRUE,
  system_alerts        BOOLEAN DEFAULT TRUE,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id)
);

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_prefs_own" ON notification_preferences
  FOR ALL USING (member_id = get_my_member_id());

CREATE TRIGGER notif_prefs_updated_at
  BEFORE UPDATE ON notification_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── 3. notifications (inbox) ──────────────────────────────────────────────────
-- Persisted notification inbox per member

CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id   UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  data        JSONB DEFAULT '{}',
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_member_id     ON notifications(member_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at    ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread        ON notifications(member_id) WHERE read_at IS NULL;

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Members read/update their own notifications
CREATE POLICY "notifications_read_own" ON notifications
  FOR SELECT USING (member_id = get_my_member_id());

CREATE POLICY "notifications_update_own" ON notifications
  FOR UPDATE USING (member_id = get_my_member_id());

-- Service role (edge functions) can insert for any member
-- This is handled via service_role key which bypasses RLS

-- ── 4. audit_logs ────────────────────────────────────────────────────────────
-- System-wide audit trail for admin operational report

CREATE TABLE IF NOT EXISTS audit_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  member_id   UUID REFERENCES members(id) ON DELETE SET NULL,
  action      VARCHAR(100) NOT NULL,
  table_name  VARCHAR(100),
  record_id   UUID,
  details     JSONB DEFAULT '{}',
  ip_address  INET,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_member_id  ON audit_logs(member_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action     ON audit_logs(action);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can read audit logs
CREATE POLICY "audit_logs_admin_read" ON audit_logs
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer', 'chairman'));

-- ── 5. members: add last_activity_at column ───────────────────────────────────
-- Used by dormant members report

ALTER TABLE members
  ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill from latest transaction per member
UPDATE members m
SET last_activity_at = (
  SELECT MAX(created_at) FROM transactions t WHERE t.member_id = m.id
)
WHERE EXISTS (SELECT 1 FROM transactions t WHERE t.member_id = m.id);

CREATE INDEX IF NOT EXISTS idx_members_last_activity ON members(last_activity_at);

-- ── 6. transactions: add payment_method and created_by columns ────────────────
-- Used by M-Pesa reconciliation and teller reconciliation reports

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50),
  ADD COLUMN IF NOT EXISTS created_by     UUID REFERENCES members(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_payment_method ON transactions(payment_method);

-- ── 7. Auto-update last_activity_at on new transactions ──────────────────────

CREATE OR REPLACE FUNCTION update_member_last_activity()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE members
  SET last_activity_at = NOW()
  WHERE id = NEW.member_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER transactions_update_last_activity
  AFTER INSERT ON transactions
  FOR EACH ROW EXECUTE FUNCTION update_member_last_activity();

-- ── 8. Auto-log key actions to audit_logs ────────────────────────────────────

CREATE OR REPLACE FUNCTION audit_loan_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO audit_logs(member_id, action, table_name, record_id, details)
    VALUES (
      NEW.member_id,
      'loan_status_changed',
      'loans',
      NEW.id,
      jsonb_build_object(
        'loan_number', NEW.loan_number,
        'old_status', OLD.status,
        'new_status', NEW.status,
        'amount', NEW.principal_amount
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER loans_audit
  AFTER UPDATE ON loans
  FOR EACH ROW EXECUTE FUNCTION audit_loan_changes();

-- ── 9. bosa_accounts: add status column if missing ───────────────────────────
-- Some report queries reference bosa_accounts.status

ALTER TABLE bosa_accounts
  ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';

ALTER TABLE fosa_accounts
  ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
