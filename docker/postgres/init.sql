-- Helix PostgreSQL Initialization Script
-- Creates tables for conversation history and analytics (future features)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255),
    title VARCHAR(500),
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    total_words INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Transcripts table
CREATE TABLE IF NOT EXISTS transcripts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    speaker VARCHAR(100),
    text TEXT NOT NULL,
    confidence DECIMAL(3,2),
    timestamp_offset INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- AI Insights table
CREATE TABLE IF NOT EXISTS ai_insights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    insight_type VARCHAR(50) NOT NULL, -- fact_check, action_item, summary, etc.
    content TEXT NOT NULL,
    confidence DECIMAL(3,2),
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Fact checks table
CREATE TABLE IF NOT EXISTS fact_checks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    claim TEXT NOT NULL,
    status VARCHAR(50) NOT NULL, -- verified, disputed, uncertain
    explanation TEXT,
    sources JSONB,
    confidence DECIMAL(3,2),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_started_at ON conversations(started_at);
CREATE INDEX IF NOT EXISTS idx_transcripts_conversation_id ON transcripts(conversation_id);
CREATE INDEX IF NOT EXISTS idx_ai_insights_conversation_id ON ai_insights(conversation_id);
CREATE INDEX IF NOT EXISTS idx_ai_insights_type ON ai_insights(insight_type);
CREATE INDEX IF NOT EXISTS idx_fact_checks_conversation_id ON fact_checks(conversation_id);
CREATE INDEX IF NOT EXISTS idx_fact_checks_status ON fact_checks(status);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add trigger to conversations table
CREATE TRIGGER update_conversations_updated_at BEFORE UPDATE ON conversations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data for development
INSERT INTO conversations (id, user_id, title, started_at, total_words) VALUES
    ('00000000-0000-0000-0000-000000000001', 'dev-user-1', 'Sample Conversation 1', NOW() - INTERVAL '2 hours', 150),
    ('00000000-0000-0000-0000-000000000002', 'dev-user-1', 'Sample Conversation 2', NOW() - INTERVAL '1 day', 300);

INSERT INTO transcripts (conversation_id, speaker, text, confidence) VALUES
    ('00000000-0000-0000-0000-000000000001', 'User', 'Hello, can you help me with this project?', 0.95),
    ('00000000-0000-0000-0000-000000000001', 'Assistant', 'Of course! I would be happy to help.', 0.98);

INSERT INTO ai_insights (conversation_id, insight_type, content, confidence) VALUES
    ('00000000-0000-0000-0000-000000000001', 'summary', 'User requested help with a project.', 0.92);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO helix;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO helix;
