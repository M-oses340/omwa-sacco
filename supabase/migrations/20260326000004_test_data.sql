-- ============================================================
-- Test data — creates auth user first, then member + accounts
-- ============================================================
-- Note: test user is created via the app's OTP flow, not here
-- This migration only creates the member record if the auth user exists

-- Member record (only if auth user exists)
INSERT INTO members (user_id, member_number, full_name, national_id, phone_number, email, status)
SELECT 
  'a05a73a1-6809-4fb2-b39c-1d56282a1ef2',
  'OM0001',
  'Moses Omwa',
  '35392727',
  '0714794915',
  'mosesomwa7@gmail.com',
  'active'
WHERE EXISTS (
  SELECT 1 FROM auth.users WHERE id = 'a05a73a1-6809-4fb2-b39c-1d56282a1ef2'
)
ON CONFLICT (member_number) DO NOTHING;

-- BOSA account
INSERT INTO bosa_accounts (member_id, account_number, savings_balance)
SELECT id, 'BOSA-0001', 50000.00
FROM members WHERE member_number = 'OM0001'
ON CONFLICT (member_id) DO NOTHING;

-- FOSA account
INSERT INTO fosa_accounts (member_id, account_number, balance, salary_amount, employer)
SELECT id, 'FOSA-0001', 5000.00, 80000.00, 'Test Employer Ltd'
FROM members WHERE member_number = 'OM0001'
ON CONFLICT (member_id) DO NOTHING;

-- Test pending transaction
INSERT INTO transactions (member_id, account_type, transaction_type, amount, reference, description, status)
SELECT id, 'bosa', 'deposit', 500.00, 'DEP-TEST-001', 'Test deposit via webhook', 'pending'
FROM members WHERE member_number = 'OM0001'
ON CONFLICT (reference) DO NOTHING;
