-- One embedding per key idea and per "how to apply" action, for Ask (POST /api/ask).
-- Apply in the Supabase SQL editor after add-book-embeddings.sql, then run `npm run embed-ideas`.
-- Until this exists, Ask falls back to matching whole books (match_books) and ranking their
-- ideas in memory.

CREATE TABLE IF NOT EXISTS idea_embeddings (
    -- "<book_id>:<kind>:<position>"
    id TEXT PRIMARY KEY,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('idea', 'apply')),
    position INT NOT NULL,
    text TEXT NOT NULL,
    embedding extensions.vector(1536) NOT NULL,
    model TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_idea_embeddings_book ON idea_embeddings (book_id);
CREATE INDEX IF NOT EXISTS idx_idea_embeddings_hnsw
    ON idea_embeddings USING hnsw (embedding extensions.vector_cosine_ops);

ALTER TABLE idea_embeddings ENABLE ROW LEVEL SECURITY;
-- No policies: only the server (service key) reads or writes embeddings.

-- Ideas nearest to `query` (cosine similarity, 1 = identical).
CREATE OR REPLACE FUNCTION match_ideas(
    query extensions.vector(1536),
    match_count INT DEFAULT 60
)
RETURNS TABLE (id TEXT, book_id UUID, kind TEXT, text TEXT, similarity FLOAT)
LANGUAGE sql STABLE
SET search_path = public, extensions
AS $$
    SELECT e.id, e.book_id, e.kind, e.text, 1 - (e.embedding <=> query) AS similarity
    FROM idea_embeddings e
    ORDER BY e.embedding <=> query
    LIMIT match_count;
$$;

REVOKE EXECUTE ON FUNCTION match_ideas FROM PUBLIC, anon, authenticated;
