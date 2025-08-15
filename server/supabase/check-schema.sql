-- Check existing database schema
-- Run this to see what tables and columns already exist

-- Check if main tables exist
SELECT 
    table_name,
    CASE 
        WHEN table_name IN (
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status
FROM (
    VALUES ('books'), ('summaries'), ('summary_generation_jobs')
) AS expected_tables(table_name);

-- Check books table columns
SELECT 
    'books' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'books'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check summaries table columns (if exists)
SELECT 
    'summaries' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'summaries'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check summary_generation_jobs table columns (if exists)
SELECT 
    'summary_generation_jobs' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'summary_generation_jobs'
AND table_schema = 'public'
ORDER BY ordinal_position;