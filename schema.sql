CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT,
  phone_number TEXT UNIQUE,
  instagram_id TEXT UNIQUE,
  email TEXT,
  language TEXT DEFAULT 'ar',
  lead_stage TEXT DEFAULT 'new',
  buying_intent_score INT DEFAULT 0,
  lead_score INT DEFAULT 0,
  last_intent TEXT,
  last_interaction TIMESTAMPTZ,
  budget_estimate INT,
  notes TEXT,
  consent_given BOOLEAN DEFAULT false,
  consent_date TIMESTAMPTZ,
  assigned_agent TEXT,
  assigned_agent_id TEXT,
  meta JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  channel TEXT NOT NULL DEFAULT 'web',
  channel_conversation_id TEXT,
  status TEXT DEFAULT 'open',
  human_takeover BOOLEAN DEFAULT false,
  is_human_takeover BOOLEAN DEFAULT false,
  assigned_agent TEXT,
  assigned_agent_id TEXT,
  ai_model TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  customer_id UUID,
  direction TEXT,
  content TEXT NOT NULL,
  content_type TEXT DEFAULT 'text',
  media_url TEXT,
  media_mime TEXT,
  is_ai_generated BOOLEAN DEFAULT true,
  channel TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cv_analyses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  original_filename TEXT,
  overall_score INT,
  ats_score INT,
  formatting_score INT,
  keyword_score INT,
  grammar_score INT,
  achievements_score INT,
  linkedin_compatibility_score INT,
  improvement_suggestions TEXT[],
  budget_estimate INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vector_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  text_chunk TEXT NOT NULL,
  embedding vector(768),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS broadcasts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  channel TEXT,
  audience_filter JSONB,
  content TEXT NOT NULL,
  status TEXT DEFAULT 'draft',
  scheduled_at TIMESTAMPTZ,
  sent_count INT DEFAULT 0,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS templates (
  name TEXT PRIMARY KEY,
  category TEXT,
  content TEXT NOT NULL,
  language TEXT DEFAULT 'ar',
  variables JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE UNIQUE NOT NULL,
  total_conversations INT DEFAULT 0,
  ai_resolved INT DEFAULT 0,
  human_takeover INT DEFAULT 0,
  leads_qualified INT DEFAULT 0,
  cvs_analyzed INT DEFAULT 0,
  offers_sent INT DEFAULT 0,
  sales_won INT DEFAULT 0,
  revenue_aed DECIMAL(10,2) DEFAULT 0,
  avg_response_time_seconds INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agents (
  email TEXT PRIMARY KEY,
  full_name TEXT,
  role TEXT CHECK (role IN ('admin','agent','viewer')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customers_lead_stage ON customers(lead_stage);
CREATE INDEX IF NOT EXISTS idx_customers_intent ON customers(buying_intent_score);
CREATE INDEX IF NOT EXISTS idx_conversations_customer ON conversations(customer_id);
CREATE INDEX IF NOT EXISTS idx_conversations_status ON conversations(status);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_cv_analyses_customer ON cv_analyses(customer_id);
CREATE INDEX IF NOT EXISTS idx_broadcasts_scheduled ON broadcasts(scheduled_at) WHERE status = 'scheduled';

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE OR REPLACE TRIGGER trg_customers_updated
  BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE OR REPLACE TRIGGER trg_conversations_updated
  BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE VIEW inbox_messages AS
SELECT m.id, m.conversation_id, conv.customer_id, conv.channel,
  m.direction, m.content, m.content_type, m.is_ai_generated, m.created_at,
  cust.full_name, cust.phone_number, cust.instagram_id, cust.lead_stage, conv.human_takeover
FROM messages m
JOIN conversations conv ON conv.id = m.conversation_id
JOIN customers cust ON cust.id = conv.customer_id;