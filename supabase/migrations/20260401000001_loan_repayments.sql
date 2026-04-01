-- ============================================================
-- Loan Repayments & Improvements Migration
-- ============================================================

-- ── Loan repayments table ─────────────────────────────────────────────────────
CREATE TABLE loan_repayments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id UUID REFERENCES loans(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES members(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  principal_portion DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  interest_portion DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  balance_before DECIMAL(15,2) NOT NULL,
  balance_after DECIMAL(15,2) NOT NULL,
  payment_method VARCHAR(30) DEFAULT 'fosa_debit', -- fosa_debit | mpesa | bank
  transaction_id UUID REFERENCES transactions(id),
  notes TEXT,
  recorded_by UUID REFERENCES members(id), -- admin who recorded it
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE loan_repayments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "repayments_read_own" ON loan_repayments
  FOR SELECT USING (member_id = get_my_member_id());

CREATE POLICY "repayments_admin_all" ON loan_repayments
  FOR ALL USING (get_my_role() IN ('admin', 'treasurer', 'chairman'));

CREATE INDEX idx_loan_repayments_loan_id ON loan_repayments(loan_id);
CREATE INDEX idx_loan_repayments_member_id ON loan_repayments(member_id);

-- ── Add missing indexes on loans ──────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_loans_created_at ON loans(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_loans_due_date ON loans(due_date);

-- ── Valid status transitions constraint ───────────────────────────────────────
-- Prevents invalid state changes at DB level
ALTER TABLE loans ADD CONSTRAINT valid_loan_status_transition
  CHECK (status IN ('pending', 'approved', 'disbursed', 'rejected', 'repaid', 'defaulted'));

-- ── Auto-set due_date on disbursement via trigger ─────────────────────────────
CREATE OR REPLACE FUNCTION set_loan_due_date()
RETURNS TRIGGER AS $$
BEGIN
  -- Set due_date when loan is disbursed
  IF NEW.status = 'disbursed' AND OLD.status != 'disbursed' THEN
    NEW.disbursed_at = COALESCE(NEW.disbursed_at, NOW());
    NEW.due_date = (NOW() + (NEW.duration_months || ' months')::INTERVAL)::DATE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER loan_disbursement_trigger
  BEFORE UPDATE ON loans
  FOR EACH ROW EXECUTE FUNCTION set_loan_due_date();

-- ── Update outstanding_balance when repayment recorded ───────────────────────
CREATE OR REPLACE FUNCTION update_loan_after_repayment()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE loans SET
    amount_repaid = amount_repaid + NEW.amount,
    outstanding_balance = GREATEST(0, outstanding_balance - NEW.amount),
    status = CASE
      WHEN outstanding_balance - NEW.amount <= 0 THEN 'repaid'::loan_status
      ELSE status
    END
  WHERE id = NEW.loan_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER loan_repayment_trigger
  AFTER INSERT ON loan_repayments
  FOR EACH ROW EXECUTE FUNCTION update_loan_after_repayment();

-- ── RLS: allow members to update their own loan cancellation only ─────────────
CREATE POLICY "loans_member_cancel" ON loans
  FOR UPDATE USING (
    member_id = get_my_member_id()
    AND status = 'pending'
  )
  WITH CHECK (
    status = 'rejected'
    AND rejected_reason IS NOT NULL
  );
