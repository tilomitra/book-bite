-- Add extended_summary column to summaries table
-- This will store longer, more detailed summaries (approximately 1000 words)

ALTER TABLE summaries 
ADD COLUMN extended_summary TEXT;

-- Add comment to document the purpose of this column
COMMENT ON COLUMN summaries.extended_summary IS 'Extended summary of approximately 1000 words, generated using cost-effective AI model';

-- Create index for potential text search on extended summaries
CREATE INDEX idx_summaries_extended_summary_search ON summaries USING gin(to_tsvector('english', extended_summary));

-- Update the trigger to handle the new column
-- (The existing updated_at trigger will automatically handle this new column)