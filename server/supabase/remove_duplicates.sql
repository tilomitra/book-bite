-- Remove duplicate books script
-- This script identifies and removes duplicate books based on title + authors combination
-- Keeps the oldest record (by created_at) for each duplicate group

BEGIN;

-- First, let's see what duplicates exist (for logging purposes)
DO $$
DECLARE
    duplicate_count INTEGER;
    total_duplicates INTEGER;
BEGIN
    -- Count duplicate groups
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT title, authors, COUNT(*) as count
        FROM books
        GROUP BY title, authors
        HAVING COUNT(*) > 1
    ) duplicates;
    
    -- Count total duplicate records (excluding the one we'll keep)
    SELECT SUM(count - 1) INTO total_duplicates
    FROM (
        SELECT title, authors, COUNT(*) as count
        FROM books
        GROUP BY title, authors
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE 'Found % duplicate book groups with % total duplicate records before cleanup', duplicate_count, total_duplicates;
END $$;

-- Show examples of duplicates before deletion
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE 'Examples of duplicate books found:';
    FOR rec IN 
        SELECT 
            title,
            authors,
            COUNT(*) as count,
            string_agg(id::text, ', ' ORDER BY created_at) as ids
        FROM books
        GROUP BY title, authors
        HAVING COUNT(*) > 1
        ORDER BY COUNT(*) DESC
        LIMIT 5
    LOOP
        RAISE NOTICE 'Title: "%" | Authors: % | Count: % | IDs: %', rec.title, rec.authors, rec.count, rec.ids;
    END LOOP;
END $$;

-- Delete duplicate books, keeping only the oldest (first created) record
WITH duplicates AS (
    SELECT 
        id,
        title,
        authors,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY title, authors 
            ORDER BY created_at ASC
        ) as rn
    FROM books
),
books_to_delete AS (
    SELECT id, title, authors
    FROM duplicates
    WHERE rn > 1
)
DELETE FROM books
WHERE id IN (SELECT id FROM books_to_delete);

-- Log the cleanup results
DO $$
DECLARE
    deleted_count INTEGER;
    remaining_duplicates INTEGER;
BEGIN
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    SELECT COUNT(*) INTO remaining_duplicates
    FROM (
        SELECT title, authors, COUNT(*) as count
        FROM books
        GROUP BY title, authors
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE 'Deleted % duplicate book records', deleted_count;
    RAISE NOTICE 'Remaining duplicate groups: %', remaining_duplicates;
    
    IF remaining_duplicates = 0 THEN
        RAISE NOTICE 'SUCCESS: All duplicates have been removed!';
    ELSE
        RAISE NOTICE 'WARNING: Some duplicates may still exist';
    END IF;
END $$;

-- Now add the unique constraint to prevent future duplicates
-- Note: This will fail if there are still duplicates, which is intended behavior
ALTER TABLE books ADD CONSTRAINT unique_book_author_title 
UNIQUE (title, (array_to_string(authors, '|')));

RAISE NOTICE 'Unique constraint added successfully to prevent future duplicates';

COMMIT;