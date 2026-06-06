-- تفعيل الإضافات اللازمة
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector; 

-- مسح العناصر القديمة لضمان توافق الهجرة
DROP VIEW IF EXISTS conversation_summary CASCADE;
DROP VIEW IF EXISTS inbox_messages CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS broadcasts CASCADE;
DROP TABLE IF EXISTS templates CASCADE;
DROP TRIGGER IF EXISTS update_customers_modtime ON customers;
DROP TRIGGER IF EXISTS update_conversations_modtime ON conversations;
DROP FUNCTION IF EXISTS update_modified_column CASCADE;

-- 1. جدول المشتركين (Customers)
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  phone_number TEXT UNIQUE,
  instagram_id TEXT UNIQUE,
  email TEXT,
  language TEXT DEFAULT 'ar',
  country TEXT DEFAULT 'AE',
  lead_stage TEXT DEFAULT 'new', 
  buying_intent_score INT DEFAULT 0,
  ltv_aed DECIMAL(10, 2) DEFAULT 0,
  last_interaction TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. جدول المحادثات (Conversations)
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  channel TEXT NOT NULL DEFAULT 'whatsapp', 
  status TEXT DEFAULT 'open',
  human_takeover BOOLEAN DEFAULT false,
  assigned_agent_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. جدول الرسائل (Messages)
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id),
  direction TEXT NOT NULL,
  content TEXT NOT NULL,
  content_type TEXT DEFAULT 'text',
  is_ai_generated BOOLEAN DEFAULT false,
  ai_model TEXT,
  channel TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. جدول القوالب (Templates)
CREATE TABLE templates (
  name TEXT PRIMARY KEY,
  category TEXT,
  content TEXT NOT NULL,
  language TEXT DEFAULT 'ar',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- دالة لتحديث حقل updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- تفعيل الـ Triggers
CREATE TRIGGER update_customers_modtime BEFORE UPDATE ON customers FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_conversations_modtime BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

-- إضافة بيانات تجريبية
INSERT INTO templates (name, category, content, language) VALUES
('welcome_ar', 'welcome', 'أهلاً بك في CVPRO! كيف يمكننا مساعدتك اليوم؟', 'ar'),
('welcome_en', 'welcome', 'Welcome to CVPRO! How can we help you today?', 'en')
ON CONFLICT (name) DO NOTHING;

-- إنشاء View لتسهيل عرض الـ Inbox
CREATE VIEW conversation_summary AS
SELECT 
    conv.id,
    conv.customer_id,
    cust.full_name as customer_name,
    conv.channel,
    conv.human_takeover,
    conv.status,
    conv.updated_at,
    (SELECT content FROM messages WHERE conversation_id = conv.id ORDER BY created_at DESC LIMIT 1) as last_message
FROM conversations conv
JOIN customers cust ON conv.customer_id = cust.id;

-- صلاحيات الوصول (RLS)
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE templates ENABLE ROW LEVEL SECURITY;

-- السياسات
CREATE POLICY "Full Access" ON customers FOR ALL TO public USING (true);
CREATE POLICY "Full Access" ON conversations FOR ALL TO public USING (true);
CREATE POLICY "Full Access" ON messages FOR ALL TO public USING (true);
CREATE POLICY "Full Access" ON templates FOR ALL TO public USING (true);