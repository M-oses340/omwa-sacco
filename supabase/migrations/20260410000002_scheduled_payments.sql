-- ============================================================
-- Scheduled Payments Table (Ratiba)
-- ============================================================

CREATE TYPE schedule_frequency AS ENUM ('daily', 'weekly', 'monthly');
CREATE TYPE schedule_status    AS ENUM ('active', 'paused', 'cancelled', 'completed');
CREATE TYPE schedule_payment_type AS ENUM ('savings', 'loan_repayment', 'shares');

CREATE TABLE scheduled_payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id       UUID REFERENCES members(id) ON DELETE CASCADE NOT NULL,
  payment_type    schedule_payment_type NOT NULL,
  amount          DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  frequency       schedule_frequency NOT NULL DEFAULT 'monthly',
  next_run_date   DATE NOT NULL,
  last_run_date   DATE,
  description     TEXT,
  status          schedule_status NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE scheduled_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "schedules_read_own" ON scheduled_payments
  FOR SELECT USING (member_id = get_my_member_id());

CREATE POLICY "schedules_insert_own" ON scheduled_payments
  FOR INSERT WITH CHECK (member_id = get_my_member_id());

CREATE POLICY "schedules_update_own" ON scheduled_payments
  FOR UPDATE USING (member_id = get_my_member_id());

CREATE POLICY "schedules_admin_all" ON scheduled_payments
  FOR ALL USING (get_my_role() IN ('admin', 'treasurer'));

-- Indexes
CREATE INDEX idx_scheduled_payments_member_id  ON scheduled_payments(member_id);
CREATE INDEX idx_scheduled_payments_next_run   ON scheduled_payments(next_run_date) WHERE status = 'active';

-- Auto-update updated_at
CREATE TRIGGER scheduled_payments_updated_at
  BEFORE UPDATE ON scheduled_payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
