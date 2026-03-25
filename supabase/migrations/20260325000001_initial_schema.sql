-- ============================================================
-- Omwa Sacco - Initial Schema Migration
-- ============================================================

-- UUID generation is built-in via gen_random_uuid()

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE member_role AS ENUM ('member', 'treasurer', 'secretary', 'chairman', 'admin');
CREATE TYPE member_status AS ENUM ('pending', 'active', 'suspended', 'exited');
CREATE TYPE device_status AS ENUM ('pending', 'active', 'revoked');
CREATE TYPE account_type AS ENUM ('bosa', 'fosa');
CREATE TYPE transaction_type AS ENUM ('deposit', 'withdrawal', 'transfer', 'loan_disbursement', 'loan_repayment', 'dividend', 'share_purchase');
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed', 'reversed');

-- ============================================================
-- MEMBERS TABLE
-- ============================================================
CREATE TABLE members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  member_number VARCHAR(20) UNIQUE NOT NULL,
  full_name VARCHAR(100) NOT NULL,
  national_id VARCHAR(20) UNIQUE NOT NULL,
  phone_number VARCHAR(15) UNIQUE NOT NULL,
  email VARCHAR(100) UNIQUE,
  date_of_birth DATE,
  role member_role DEFAULT 'member',
  status member_status DEFAULT 'pending',
  joined_date DATE DEFAULT CURRENT_DATE,
  next_of_kin_name VARCHAR(100),
  next_of_kin_phone VARCHAR(15),
  next_of_kin_relationship VARCHAR(50),
  profile_photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MEMBER DEVICES TABLE
-- ============================================================
CREATE TABLE member_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE,
  device_id VARCHAR(255) NOT NULL,
  device_name VARCHAR(100),
  device_model VARCHAR(100),
  platform VARCHAR(20),
  status device_status DEFAULT 'pending',
  otp_verified BOOLEAN DEFAULT FALSE,
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  revoked_by UUID REFERENCES members(id),
  UNIQUE(member_id, device_id)
);

-- ============================================================
-- BOSA ACCOUNTS TABLE
-- ============================================================
CREATE TABLE bosa_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE UNIQUE,
  account_number VARCHAR(20) UNIQUE NOT NULL,
  savings_balance DECIMAL(15,2) DEFAULT 0.00,
  shares_balance DECIMAL(15,2) DEFAULT 0.00,
  total_shares INTEGER DEFAULT 0,
  loan_limit DECIMAL(15,2) DEFAULT 0.00,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FOSA ACCOUNTS TABLE
-- ============================================================
CREATE TABLE fosa_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE UNIQUE,
  account_number VARCHAR(20) UNIQUE NOT NULL,
  balance DECIMAL(15,2) DEFAULT 0.00,
  salary_amount DECIMAL(15,2) DEFAULT 0.00,
  employer VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TRANSACTIONS TABLE
-- ============================================================
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE SET NULL,
  account_type account_type NOT NULL,
  transaction_type transaction_type NOT NULL,
  amount DECIMAL(15,2) NOT NULL,
  balance_before DECIMAL(15,2),
  balance_after DECIMAL(15,2),
  reference VARCHAR(100) UNIQUE,
  intasend_ref VARCHAR(100),
  mpesa_ref VARCHAR(100),
  description TEXT,
  status transaction_status DEFAULT 'pending',
  initiated_by UUID REFERENCES members(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE bosa_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE fosa_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Helper function to get current member's role
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS member_role AS $$
  SELECT role FROM members WHERE user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper function to get current member's id
CREATE OR REPLACE FUNCTION get_my_member_id()
RETURNS UUID AS $$
  SELECT id FROM members WHERE user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- MEMBERS policies
CREATE POLICY "members_read_own" ON members
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "members_admin_read_all" ON members
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer', 'secretary', 'chairman'));

CREATE POLICY "members_admin_write" ON members
  FOR ALL USING (get_my_role() = 'admin');

-- MEMBER DEVICES policies
CREATE POLICY "devices_read_own" ON member_devices
  FOR SELECT USING (member_id = get_my_member_id());

CREATE POLICY "devices_insert_own" ON member_devices
  FOR INSERT WITH CHECK (member_id = get_my_member_id());

CREATE POLICY "devices_admin_all" ON member_devices
  FOR ALL USING (get_my_role() = 'admin');

-- BOSA ACCOUNTS policies
CREATE POLICY "bosa_read_own" ON bosa_accounts
  FOR SELECT USING (member_id = get_my_member_id());

CREATE POLICY "bosa_admin_read_all" ON bosa_accounts
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer'));

-- FOSA ACCOUNTS policies
CREATE POLICY "fosa_read_own" ON fosa_accounts
  FOR SELECT USING (member_id = get_my_member_id());

CREATE POLICY "fosa_admin_read_all" ON fosa_accounts
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer'));

-- TRANSACTIONS policies
CREATE POLICY "transactions_read_own" ON transactions
  FOR SELECT USING (member_id = get_my_member_id());

CREATE POLICY "transactions_admin_read_all" ON transactions
  FOR SELECT USING (get_my_role() IN ('admin', 'treasurer'));

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_members_user_id ON members(user_id);
CREATE INDEX idx_members_phone ON members(phone_number);
CREATE INDEX idx_member_devices_member_id ON member_devices(member_id);
CREATE INDEX idx_transactions_member_id ON transactions(member_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);

-- ============================================================
-- AUTO-UPDATE updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER members_updated_at BEFORE UPDATE ON members
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER bosa_updated_at BEFORE UPDATE ON bosa_accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER fosa_updated_at BEFORE UPDATE ON fosa_accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER transactions_updated_at BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
