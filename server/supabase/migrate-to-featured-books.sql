-- Complete migration script for featured books functionality
-- This script will work with existing databases and only add missing components

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Update books table: Add missing columns
DO $$ 
BEGIN 
    -- Add is_featured column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='is_featured') THEN
        ALTER TABLE books ADD COLUMN is_featured BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add popularity_rank column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='popularity_rank') THEN
        ALTER TABLE books ADD COLUMN popularity_rank INTEGER;
    END IF;
    
    -- Add other columns that might be missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='google_books_id') THEN
        ALTER TABLE books ADD COLUMN google_books_id VARCHAR(50);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='open_library_id') THEN
        ALTER TABLE books ADD COLUMN open_library_id VARCHAR(50);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='source_attribution') THEN
        ALTER TABLE books ADD COLUMN source_attribution TEXT[];
    END IF;
END $$;

-- Create summaries table if it doesn't exist
CREATE TABLE IF NOT EXISTS summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    one_sentence_hook TEXT NOT NULL,
    key_ideas JSONB NOT NULL,
    how_to_apply JSONB NOT NULL,
    common_pitfalls TEXT[],
    critiques TEXT[],
    who_should_read TEXT,
    limitations TEXT,
    citations JSONB,
    read_time_minutes INTEGER,
    style VARCHAR(20) CHECK (style IN ('brief', 'full')),
    llm_model VARCHAR(100),
    llm_version VARCHAR(50),
    generation_date TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create summary_generation_jobs table if it doesn't exist
CREATE TABLE IF NOT EXISTS summary_generation_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    status VARCHAR(20) CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_books_isbn10 ON books(isbn10);
CREATE INDEX IF NOT EXISTS idx_books_isbn13 ON books(isbn13);
CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
CREATE INDEX IF NOT EXISTS idx_books_is_featured ON books(is_featured);
CREATE INDEX IF NOT EXISTS idx_books_popularity_rank ON books(popularity_rank);
CREATE INDEX IF NOT EXISTS idx_summaries_book_id ON summaries(book_id);
CREATE INDEX IF NOT EXISTS idx_jobs_book_id ON summary_generation_jobs(book_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON summary_generation_jobs(status);

-- Create GIN indexes for array columns if they don't exist
DO $$
BEGIN
    -- Check if authors column exists and is an array type
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='books' AND column_name='authors' 
        AND data_type='ARRAY'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_books_authors ON books USING GIN(authors);
    END IF;
    
    -- Check if categories column exists and is an array type
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='books' AND column_name='categories' 
        AND data_type='ARRAY'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_books_categories ON books USING GIN(categories);
    END IF;
END $$;

-- Create or replace the updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers for updated_at if they don't exist
DO $$
BEGIN
    -- Books table trigger
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'update_books_updated_at'
    ) THEN
        CREATE TRIGGER update_books_updated_at 
            BEFORE UPDATE ON books
            FOR EACH ROW 
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    -- Summaries table trigger
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'update_summaries_updated_at'
    ) THEN
        CREATE TRIGGER update_summaries_updated_at 
            BEFORE UPDATE ON summaries
            FOR EACH ROW 
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    -- Jobs table trigger
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'update_jobs_updated_at'
    ) THEN
        CREATE TRIGGER update_jobs_updated_at 
            BEFORE UPDATE ON summary_generation_jobs
            FOR EACH ROW 
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Enable Row Level Security on all tables
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE summary_generation_jobs ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access (if they don't exist)
DO $$
BEGIN
    -- Books read policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'books' AND policyname = 'Books are viewable by everyone'
    ) THEN
        CREATE POLICY "Books are viewable by everyone" ON books
            FOR SELECT USING (true);
    END IF;
    
    -- Summaries read policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'summaries' AND policyname = 'Summaries are viewable by everyone'
    ) THEN
        CREATE POLICY "Summaries are viewable by everyone" ON summaries
            FOR SELECT USING (true);
    END IF;
    
    -- Admin-only write policies for books
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'books' AND policyname = 'Only admins can insert books'
    ) THEN
        CREATE POLICY "Only admins can insert books" ON books
            FOR INSERT WITH CHECK (auth.jwt() ->> 'role' = 'admin');
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'books' AND policyname = 'Only admins can update books'
    ) THEN
        CREATE POLICY "Only admins can update books" ON books
            FOR UPDATE USING (auth.jwt() ->> 'role' = 'admin');
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'books' AND policyname = 'Only admins can delete books'
    ) THEN
        CREATE POLICY "Only admins can delete books" ON books
            FOR DELETE USING (auth.jwt() ->> 'role' = 'admin');
    END IF;
    
    -- Admin-only policies for summaries
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'summaries' AND policyname = 'Only admins can manage summaries'
    ) THEN
        CREATE POLICY "Only admins can manage summaries" ON summaries
            FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
    END IF;
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE 'Tables and columns have been updated for featured books functionality.';
END $$;