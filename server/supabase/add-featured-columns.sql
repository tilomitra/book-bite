-- Migration: Add featured book columns to existing schema
-- This script safely adds missing columns for featured books functionality

-- Add is_featured column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='is_featured') THEN
        ALTER TABLE books ADD COLUMN is_featured BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- Add popularity_rank column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='popularity_rank') THEN
        ALTER TABLE books ADD COLUMN popularity_rank INTEGER;
    END IF;
END $$;

-- Add index on is_featured if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_books_is_featured ON books(is_featured);

-- Add index on popularity_rank if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_books_popularity_rank ON books(popularity_rank);

-- Verify the columns were added
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'books' 
AND column_name IN ('is_featured', 'popularity_rank')
ORDER BY column_name;