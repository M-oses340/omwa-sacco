-- ============================================================
-- Ratiba: link transactions to scheduled payments
-- ============================================================

-- Add scheduled_payment as a transaction type
ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'scheduled_payment';

-- Link transactions back to the schedule that triggered them
ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS scheduled_payment_id UUID REFERENCES scheduled_payments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_scheduled_payment_id
  ON transactions(scheduled_payment_id);
