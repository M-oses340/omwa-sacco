-- Create BOSA and FOSA accounts for any members that don't have them yet
INSERT INTO bosa_accounts (member_id, account_number, savings_balance, shares_balance)
SELECT 
  m.id,
  'BOSA-' || m.member_number,
  0.00,
  0.00
FROM members m
LEFT JOIN bosa_accounts b ON b.member_id = m.id
WHERE b.id IS NULL;

INSERT INTO fosa_accounts (member_id, account_number, balance)
SELECT 
  m.id,
  'FOSA-' || m.member_number,
  0.00
FROM members m
LEFT JOIN fosa_accounts f ON f.member_id = m.id
WHERE f.id IS NULL;
