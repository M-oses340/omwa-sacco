-- ============================================================
-- Test data — creates auth user first, then member + accounts
-- ============================================================

-- Create the auth user so the FK on members.user_id is satisfied
INSERT INTO auth.users (
  id,
  instance_id,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  aud,
  role
) VALUES (
  'a05a73a1-6809-4fb2-b39c-1d56282a1ef2',
  '00000000-0000-0000-0000-000000000000',
  'mosesomwa7@gmail.com',
  crypt('testpassword123', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

-- Member record
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

-- BOSA account (with a salary so monthly_contribution computes)
INSERT INTO bosa_accounts (member_id, account_number, savings_balance, basic_salary)
SELECT id, 'BOSA-0001', 50000.00, 80000.00
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
