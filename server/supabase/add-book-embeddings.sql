-- Book embeddings for personalized recommendations (POST /api/books/for-you).
-- Apply in the Supabase SQL editor, then run `npm run embed-books`.
-- Kept out of `books` so `select *` on books doesn't ship 1536 floats per row.

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS book_embeddings (
    book_id UUID PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
    embedding extensions.vector(1536) NOT NULL,
    model TEXT NOT NULL,
    -- Hash of the embedded text, so re-runs only embed books whose text changed
    content_hash TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_book_embeddings_hnsw
    ON book_embeddings USING hnsw (embedding extensions.vector_cosine_ops);

ALTER TABLE book_embeddings ENABLE ROW LEVEL SECURITY;
-- No policies: only the server (service key) reads or writes embeddings.

-- Books with a summary nearest to `taste` (cosine similarity, 1 = identical).
CREATE OR REPLACE FUNCTION match_books(
    taste extensions.vector(1536),
    exclude_ids UUID[] DEFAULT '{}',
    match_count INT DEFAULT 50
)
RETURNS TABLE (book_id UUID, similarity FLOAT)
LANGUAGE sql STABLE
SET search_path = public, extensions
AS $$
    SELECT e.book_id, 1 - (e.embedding <=> taste) AS similarity
    FROM book_embeddings e
    WHERE NOT (e.book_id = ANY (exclude_ids))
      AND EXISTS (SELECT 1 FROM summaries s WHERE s.book_id = e.book_id)
    ORDER BY e.embedding <=> taste
    LIMIT match_count;
$$;

REVOKE EXECUTE ON FUNCTION match_books FROM PUBLIC, anon, authenticated;
