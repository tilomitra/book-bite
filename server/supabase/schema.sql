-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create books table
CREATE TABLE books (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    subtitle TEXT,
    authors TEXT[] NOT NULL,
    isbn10 VARCHAR(10),
    isbn13 VARCHAR(13),
    published_year INTEGER,
    publisher TEXT,
    categories TEXT[],
    cover_url TEXT,
    description TEXT,
    source_attribution TEXT[],
    google_books_id VARCHAR(50),
    open_library_id VARCHAR(50),
    popularity_rank INTEGER,
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create summaries table
CREATE TABLE summaries (
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

-- Create summary_generation_jobs table
CREATE TABLE summary_generation_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    status VARCHAR(20) CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Add unique constraint for author + title combination to prevent duplicates
-- Note: This uses array-to-string conversion for authors array comparison
ALTER TABLE books ADD CONSTRAINT unique_book_author_title 
UNIQUE (title, (array_to_string(authors, '|')));

-- Create indexes for better query performance
CREATE INDEX idx_books_isbn10 ON books(isbn10);
CREATE INDEX idx_books_isbn13 ON books(isbn13);
CREATE INDEX idx_books_title ON books(title);
CREATE INDEX idx_books_authors ON books USING GIN(authors);
CREATE INDEX idx_books_categories ON books USING GIN(categories);
CREATE INDEX idx_books_popularity_rank ON books(popularity_rank);
CREATE INDEX idx_books_is_featured ON books(is_featured);
CREATE INDEX idx_summaries_book_id ON summaries(book_id);
CREATE INDEX idx_jobs_book_id ON summary_generation_jobs(book_id);
CREATE INDEX idx_jobs_status ON summary_generation_jobs(status);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers for updated_at
CREATE TRIGGER update_books_updated_at BEFORE UPDATE ON books
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_summaries_updated_at BEFORE UPDATE ON summaries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON summary_generation_jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS)
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE summary_generation_jobs ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Books are viewable by everyone" ON books
    FOR SELECT USING (true);

CREATE POLICY "Summaries are viewable by everyone" ON summaries
    FOR SELECT USING (true);

-- Admin-only write policies (requires authenticated user with admin role)
CREATE POLICY "Only admins can insert books" ON books
    FOR INSERT WITH CHECK (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Only admins can update books" ON books
    FOR UPDATE USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Only admins can delete books" ON books
    FOR DELETE USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Only admins can manage summaries" ON summaries
    FOR ALL USING (auth.jwt() ->> 'role' = 'admin');

-- Create chat_conversations table
CREATE TABLE chat_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    title TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create chat_messages table
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create indexes for chat tables
CREATE INDEX idx_chat_conversations_book_id ON chat_conversations(book_id);
CREATE INDEX idx_chat_messages_conversation_id ON chat_messages(conversation_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at);

-- Add triggers for chat tables updated_at
CREATE TRIGGER update_chat_conversations_updated_at BEFORE UPDATE ON chat_conversations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS for chat tables
ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Create policies for chat tables (public read/write for now)
CREATE POLICY "Chat conversations are viewable by everyone" ON chat_conversations
    FOR SELECT USING (true);

CREATE POLICY "Anyone can create chat conversations" ON chat_conversations
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update chat conversations" ON chat_conversations
    FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete chat conversations" ON chat_conversations
    FOR DELETE USING (true);

CREATE POLICY "Chat messages are viewable by everyone" ON chat_messages
    FOR SELECT USING (true);

CREATE POLICY "Anyone can create chat messages" ON chat_messages
    FOR INSERT WITH CHECK (true);

-- Create user profiles table
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    bio TEXT,
    avatar_url TEXT,
    favorite_categories TEXT[],
    reading_goal INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Create user favorites table
CREATE TABLE user_favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(user_id, book_id)
);

-- Create user reading history table
CREATE TABLE user_reading_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    reading_time_minutes INTEGER DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(user_id, book_id)
);

-- Create indexes for user tables
CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_profiles_deleted_at ON user_profiles(deleted_at);
CREATE INDEX idx_user_favorites_user_id ON user_favorites(user_id);
CREATE INDEX idx_user_favorites_book_id ON user_favorites(book_id);
CREATE INDEX idx_user_favorites_created_at ON user_favorites(created_at);
CREATE INDEX idx_user_reading_history_user_id ON user_reading_history(user_id);
CREATE INDEX idx_user_reading_history_book_id ON user_reading_history(book_id);
CREATE INDEX idx_user_reading_history_completed ON user_reading_history(completed);

-- Add triggers for user tables updated_at
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_reading_history_updated_at BEFORE UPDATE ON user_reading_history
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS for user tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reading_history ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for user tables

-- User profiles: Users can only access their own profile
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- User favorites: Users can only access their own favorites
CREATE POLICY "Users can view own favorites" ON user_favorites
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own favorites" ON user_favorites
    FOR ALL USING (auth.uid() = user_id);

-- User reading history: Users can only access their own history
CREATE POLICY "Users can view own reading history" ON user_reading_history
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own reading history" ON user_reading_history
    FOR ALL USING (auth.uid() = user_id);

-- Function to handle user profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, display_name)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email)
  );
  RETURN NEW;
END;
$$ language 'plpgsql' security definer;

-- Trigger to create user profile when user signs up
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();