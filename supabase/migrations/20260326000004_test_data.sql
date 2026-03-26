-- Ensure member record exists for test user
INSERT INTO members (user_id, member_number, full_name, national_id, phone_number, email, status)
VALUES (
  'a05a73a1-6809-4fb2-b39c-1d56282a1ef2',
  'OM0001',
  'Moses Omwa',
  '35392727',
  '0714794915',
  'mosesomwa7@gmail.com',
  'active'
) ON CONFLICT (member_number) DO NOTHING;

-- Ensure BOSA account exists
INSERT INTO bosa_accounts (member_id, account_number, savings_balance)
SELECT id, 'BOSA-0001', 0.00
FROM members WHERE user_id = 'a05a73a1-6809-4fb2-b39c-1d56282a1ef2'
ON CONFLICT (member_id) DO NOTHING;

-- Test pending transaction for webhook test
INSERT INTO transactions (member_id, account_type, transaction_type, amount, reference, description, status)
SELECT id, 'bosa', 'deposit', 500.00, 'DEP-TEST-001', 'Test deposit via webhook', 'pending'
FROM members WHERE user_id = 'a05a73a1-6809-4fb2-b39c-1d56282a1ef2'
ON CONFLICT (reference) DO NOTHING;
