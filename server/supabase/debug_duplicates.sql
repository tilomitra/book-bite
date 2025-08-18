-- Debug duplicate books query
-- Run this to identify and inspect duplicate books

-- 1. Find books with exact same title and authors (case-insensitive)
SELECT 
    title,
    authors,
    array_to_string(authors, '|') as authors_str,
    COUNT(*) as duplicate_count,
    array_agg(id ORDER BY created_at) as all_ids,
    array_agg(created_at ORDER BY created_at) as all_created_dates
FROM books
GROUP BY title, authors
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, title;

-- 2. Alternative: Check using LOWER() for case-insensitive comparison
SELECT 
    LOWER(title) as lower_title,
    authors,
    COUNT(*) as duplicate_count,
    array_agg(title ORDER BY created_at) as original_titles,
    array_agg(id ORDER BY created_at) as all_ids
FROM books
GROUP BY LOWER(title), authors
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 3. Find books with same title only (to catch potential author variations)
SELECT 
    title,
    COUNT(*) as count_same_title,
    array_agg(DISTINCT authors) as different_authors,
    array_agg(id ORDER BY created_at) as all_ids
FROM books
GROUP BY title
HAVING COUNT(*) > 1
ORDER BY count_same_title DESC;

-- 4. Check specific "Coming Up Short" example
SELECT 
    id,
    title,
    authors,
    created_at,
    google_books_id
FROM books 
WHERE title = 'Coming Up Short'
ORDER BY created_at;