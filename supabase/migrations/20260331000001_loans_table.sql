-- ============================================================
-- Loans Table Migration
-- ============================================================
-- Business rules:
--   • BOSA monthly contribution = 12% of basic salary
--   • All BOSA loans disbursed through FOSA
--   • Loan limit = 5× BOSA savings (4× for Muslim loans)
--   • Muslim loans: 0% interest + 7% one-off commission, no dividends
--   • Salary advances: salary must be processed through FOSA
--   • Q-Cash: max KES 40,000, 5% flat at disbursement, 60-day max
--   • Dividend Advance: up to 50% of prior-year dividends, 10% flat
-- ============================================================

CREATE TYPE loan_status AS ENUM (
  'pending',
  'approved',
  'disbursed',
  'rejected',
  'repaid',
  'defaulted'
);

CREATE TYPE loan_type AS ENUM (
  -- BOSA loans
  'normal',
  'jumbo',
  'bima',
  'premier',
  'super',
  'mega',
  'refinancing',
  'emergency',
  'school_fees',
  'asset_financing',
  -- Muslim loans (BOSA)
  'muslim',
  'muslim_emergency',
  -- FOSA salary advances
  'msasa',
  'fosa_flex',
  'fosa_golden',
  'fosa_ultra',
  -- Special products
  'qcash',
  'dividend_advance'
);


-- ============================================================
-- LOAN PRODUCTS reference table (single source of truth for rules)
-- ============================================================
CREATE TABLE loan_products (
  loan_type         loan_type PRIMARY KEY,
  display_name      VARCHAR(60) NOT NULL,
  category          VARCHAR(20) NOT NULL,   -- 'bosa', 'fosa_advance', 'special'
  max_duration_months INTEGER NOT NULL,
  deposit_multiplier DECIMAL(4,1) NOT NULL, -- e.g. 5.0 or 4.0
  interest_rate_pa  DECIMAL(5,2) NOT NULL,  -- annual %; 0 for Muslim/Q-Cash
  interest_type     VARCHAR(20) NOT NULL,   -- 'reducing_balance' | 'flat_monthly' | 'flat_disbursement' | 'none'
  commission_pct    DECIMAL(5,2) DEFAULT 0.00, -- one-off % of principal (Muslim loans)
  max_amount        DECIMAL(15,2),          -- NULL = no cap; Q-Cash = 40000
  salary_required   BOOLEAN DEFAULT FALSE,  -- FOSA salary advances
  no_dividends      BOOLEAN DEFAULT FALSE,  -- Muslim loans
  notes             TEXT
);

INSERT INTO loan_products VALUES
  -- BOSA loans
  ('normal',          'Normal Loan',          'bosa',         48,  5.0, 12.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('jumbo',           'Jumbo Loan',           'bosa',         108, 5.0, 15.6,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('bima',            'Bima Loan',            'bosa',         12,  5.0, 10.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('premier',         'Premier Loan',         'bosa',         96,  5.0, 15.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('super',           'Super Loan',           'bosa',         72,  5.0, 14.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('mega',            'Mega Loan',            'bosa',         84,  5.0, 14.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('refinancing',     'Refinancing Loan',     'bosa',         60,  5.0, 12.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('emergency',       'Emergency Loan',       'bosa',         24,  5.0, 12.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('school_fees',     'School Fees Loan',     'bosa',         12,  5.0, 12.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  ('asset_financing', 'Asset Financing Loan', 'bosa',         24,  5.0, 12.0,  'reducing_balance', 0,    NULL,  FALSE, FALSE, NULL),
  -- Muslim loans
  ('muslim',          'Muslim Loan',          'bosa',         60,  4.0, 0.0,   'none',             7.0,  NULL,  FALSE, TRUE,  'No interest. 7% one-off commission. No dividends.'),
  ('muslim_emergency','Muslim Emergency Loan','bosa',         24,  4.0, 0.0,   'none',             7.0,  NULL,  FALSE, TRUE,  'No interest. 7% one-off commission. No dividends.'),
  -- FOSA salary advances
  ('msasa',           'M-Sasa',               'fosa_advance', 3,   0.0, 0.0,   'flat_monthly',     0,    NULL,  TRUE,  FALSE, '2% per month flat'),
  ('fosa_flex',       'FOSA Flex',            'fosa_advance', 6,   0.0, 0.0,   'flat_monthly',     0,    NULL,  TRUE,  FALSE, '3% per month flat'),
  ('fosa_golden',     'FOSA Golden',          'fosa_advance', 9,   0.0, 0.0,   'reducing_balance', 0,    NULL,  TRUE,  FALSE, '3.5% per month on reducing balance'),
  ('fosa_ultra',      'FOSA Ultra',           'fosa_advance', 12,  0.0, 0.0,   'flat_monthly',     0,    NULL,  TRUE,  FALSE, '4% per month flat'),
  -- Special
  ('qcash',           'Q-Cash',               'special',      2,   0.0, 0.0,   'flat_disbursement',0,    40000, FALSE, FALSE, '5% charged at disbursement. Max KES 40,000. 2 equal instalments. 60-day max.'),
  ('dividend_advance','Dividend Advance',     'special',      1,   0.0, 0.0,   'flat_disbursement',0,    NULL,  FALSE, FALSE, 'Up to 50% of prior-year dividends. 10% flat charge.');

-- Store per-product monthly rate separately for FOSA advances (not annual)
-- We use a separate column rather than overloading interest_rate_pa
ALTER TABLE loan_products
  ADD COLUMN monthly_rate DECIMAL(5,2) DEFAULT 0.00;

UPDATE loan_products SET monthly_rate = 2.0  WHERE loan_type = 'msasa';
UPDATE loan_products SET monthly_rate = 3.0  WHERE loan_type = 'fosa_flex';
UPDATE loan_products SET monthly_rate = 3.5  WHERE loan_type = 'fosa_golden';
UPDATE loan_products SET monthly_rate = 4.0  WHERE loan_type = 'fosa_ultra';

-- ============================================================
-- LOANS table
-- ============================================================
CREATE TABLE loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE NOT NULL,
  loan_number VARCHAR(30) UNIQUE NOT NULL,
  loan_type loan_type NOT NULL DEFAULT 'normal',
  principal DECIMAL(15,2) NOT NULL,
  commission_amount DECIMAL(15,2) DEFAULT 0.00, -- Muslim loans one-off
  interest_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  duration_months INTEGER NOT NULL,
  monthly_repayment DECIMAL(15,2),
  total_repayable DECIMAL(15,2),
  amount_repaid DECIMAL(15,2) DEFAULT 0.00,
  outstanding_balance DECIMAL(15,2),
  status loan_status DEFAULT 'pending',
  purpose TEXT,
  -- Disbursement always goes to FOSA
  disbursed_to_fosa_id UUID REFERENCES fosa_accounts(id),
  disbursed_at TIMESTAMPTZ,
  due_date DATE,
  approved_by UUID REFERENCES members(id),
  approved_at TIMESTAMPTZ,
  rejected_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE loans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "loans_read_own" ON loans
  FOR SELECT USING (member_id = get_my_member_id());

CREATE POLICY "loans_insert_own" ON loans
  FOR INSERT WITH CHECK (member_id = get_my_member_id());

CREATE POLICY "loans_admin_all" ON loans
  FOR ALL USING (get_my_role() IN ('admin', 'treasurer', 'chairman'));

-- loan_products is read-only for all authenticated users
ALTER TABLE loan_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "loan_products_read_all" ON loan_products
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE INDEX idx_loans_member_id ON loans(member_id);
CREATE INDEX idx_loans_status ON loans(status);

CREATE TRIGGER loans_updated_at BEFORE UPDATE ON loans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
