-- ============================================================
-- Atomic member registration function
-- Uses a sequence for race-condition-free member numbers.
-- Runs as SECURITY DEFINER so RLS doesn't block inserts.
-- ============================================================

-- Sequence for member numbers (starts at 1, no gaps on failure
-- because we pad the number into the final string)
CREATE SEQUENCE IF NOT EXISTS member_number_seq START 1;

CREATE OR REPLACE FUNCTION create_member(
  p_user_id     UUID,
  p_full_name   TEXT,
  p_national_id TEXT,
  p_phone_number TEXT,
  p_email       TEXT
)
RETURNS TEXT   -- returns the generated member_number
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_number TEXT;
  v_member_id     UUID;
BEGIN
  -- Ensure the caller can only register themselves
  IF p_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: cannot register on behalf of another user';
  END IF;

  -- Prevent duplicate registration
  IF EXISTS (SELECT 1 FROM members WHERE user_id = p_user_id) THEN
    RAISE EXCEPTION 'A member record already exists for this user';
  END IF;

  -- Generate a unique, sequential member number atomically
  v_member_number := 'OM' || LPAD(nextval('member_number_seq')::TEXT, 4, '0');

  -- Insert member record
  INSERT INTO members (
    user_id,
    member_number,
    full_name,
    national_id,
    phone_number,
    email,
    status
  ) VALUES (
    p_user_id,
    v_member_number,
    p_full_name,
    p_national_id,
    p_phone_number,
    p_email,
    'active'
  )
  RETURNING id INTO v_member_id;

  -- Create BOSA account
  INSERT INTO bosa_accounts (
    member_id,
    account_number,
    savings_balance,
    shares_balance
  ) VALUES (
    v_member_id,
    'BOSA-' || v_member_number,
    0.00,
    0.00
  );

  -- Create FOSA account
  INSERT INTO fosa_accounts (
    member_id,
    account_number,
    balance
  ) VALUES (
    v_member_id,
    'FOSA-' || v_member_number,
    0.00
  );

  RETURN v_member_number;
END;
$$;

-- Only allow authenticated users to call this function,
-- and only for their own user_id
REVOKE ALL ON FUNCTION create_member(UUID, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_member(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
