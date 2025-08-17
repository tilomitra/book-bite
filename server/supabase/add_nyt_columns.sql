-- Add NYT bestseller columns to books table
ALTER TABLE books 
ADD COLUMN IF NOT EXISTS is_nyt_bestseller BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS nyt_rank INTEGER,
ADD COLUMN IF NOT EXISTS nyt_weeks_on_list INTEGER,
ADD COLUMN IF NOT EXISTS nyt_list VARCHAR(100),
ADD COLUMN IF NOT EXISTS nyt_last_updated TIMESTAMP WITH TIME ZONE;

-- Create index for NYT bestseller queries
CREATE INDEX IF NOT EXISTS idx_books_nyt_bestseller ON books(is_nyt_bestseller);
CREATE INDEX IF NOT EXISTS idx_books_nyt_list ON books(nyt_list);
CREATE INDEX IF NOT EXISTS idx_books_nyt_rank ON books(nyt_rank);

-- Add comment to explain the columns
COMMENT ON COLUMN books.is_nyt_bestseller IS 'Whether this book is/was a NYT bestseller';
COMMENT ON COLUMN books.nyt_rank IS 'Current or last known NYT bestseller rank';
COMMENT ON COLUMN books.nyt_weeks_on_list IS 'Number of weeks on NYT bestseller list';
COMMENT ON COLUMN books.nyt_list IS 'The specific NYT list (e.g., hardcover-nonfiction)';
COMMENT ON COLUMN books.nyt_last_updated IS 'When the NYT bestseller data was last updated';