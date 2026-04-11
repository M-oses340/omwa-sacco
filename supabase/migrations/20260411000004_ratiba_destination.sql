-- ============================================================
-- Add destination fields to scheduled_payments
-- The payment is deducted from FOSA and sent to a destination
-- via IntaSend (M-Pesa B2C, PayBill, Till, or PesaLink)
-- ============================================================

-- Destination provider type
CREATE TYPE schedule_destination AS ENUM ('mpesa', 'paybill', 'till', 'pesalink');

ALTER TABLE scheduled_payments
  ADD COLUMN destination_type  schedule_destination NOT NULL DEFAULT 'mpesa',
  ADD COLUMN destination_account TEXT,        -- phone / till / business number / bank account
  ADD COLUMN destination_name    TEXT,        -- recipient name (for display + narrative)
  ADD COLUMN destination_ref     TEXT;        -- paybill account ref (e.g. meter number)
