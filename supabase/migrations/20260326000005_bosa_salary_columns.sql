-- Add salary columns to bosa_accounts
-- basic_salary: member's gross basic pay
-- monthly_contribution: computed as 12% of basic salary (SACCO rule)
ALTER TABLE bosa_accounts
  ADD COLUMN IF NOT EXISTS basic_salary DECIMAL(15,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS monthly_contribution DECIMAL(15,2)
    GENERATED ALWAYS AS (ROUND(basic_salary * 0.12, 2)) STORED;
