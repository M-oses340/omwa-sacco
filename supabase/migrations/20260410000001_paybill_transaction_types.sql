-- ============================================================
-- Add paybill and till to transaction_type enum
-- ============================================================
-- Postgres requires adding enum values outside a transaction
-- when using ALTER TYPE ... ADD VALUE

ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'paybill';
ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'till';
ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'airtime';
