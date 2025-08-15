#!/usr/bin/env ts-node

import { config } from 'dotenv';
import path from 'path';
import { supabase } from '../src/config/supabase';
import { OpenAIService } from '../src/services/openaiService';
import { SummaryService } from '../src/services/summaryService';

// Load environment variables
config({ path: path.join(__dirname, '../.env') });

interface SummaryResult {
  bookId: string;
  title: string;
  success: boolean;
  error?: string;
}

async function generateSummaryForBook(bookId: string, title: string): Promise<SummaryResult> {
  const openai = new OpenAIService();
  
  try {
    console.log(`📝 Generating summary for: ${title}`);
    
    // Check if summary already exists
    const { data: existingSummary } = await supabase
      .from('summaries')
      .select('id')
      .eq('book_id', bookId)
      .single();

    if (existingSummary) {
      console.log(`📋 Summary already exists for: ${title}`);
      return { bookId, title, success: true };
    }

    // Get book details for summary generation
    const { data: book } = await supabase
      .from('books')
      .select('*')
      .eq('id', bookId)
      .single();

    if (!book) {
      console.log(`❌ Book not found: ${bookId}`);
      return { bookId, title, success: false, error: 'Book not found' };
    }

    // Generate summary using OpenAI
    console.log(`  🤖 Calling OpenAI API for summary generation...`);
    const summaryData = await openai.generateBookSummary(
      book.title,
      book.authors,
      book.description || '',
      book.categories,
      'full'
    );

    // Save to database
    const { error } = await supabase
      .from('summaries')
      .insert({
        book_id: bookId,
        ...summaryData
      });

    if (error) {
      console.error(`❌ Failed to save summary for ${title}: ${error.message}`);
      return { bookId, title, success: false, error: error.message };
    }

    console.log(`✅ Generated and saved summary for: ${title}`);
    return { bookId, title, success: true };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error(`❌ Error generating summary for ${title}:`, errorMessage);
    return { bookId, title, success: false, error: errorMessage };
  }
}

async function generateSummariesForFeaturedBooks() {
  console.log('🚀 Starting summary generation for featured books...');
  
  // Get all featured books that don't have summaries yet
  const { data: featuredBooks, error } = await supabase
    .from('books')
    .select('id, title')
    .eq('is_featured', true)
    .order('popularity_rank', { ascending: true });

  if (error) {
    throw new Error(`Failed to fetch featured books: ${error.message}`);
  }

  if (!featuredBooks || featuredBooks.length === 0) {
    console.log('📚 No featured books found. Run populate-business-books.ts first.');
    return;
  }

  console.log(`📚 Found ${featuredBooks.length} featured books\n`);

  const results: SummaryResult[] = [];
  
  // Generate summaries sequentially to avoid overwhelming the API
  for (let i = 0; i < featuredBooks.length; i++) {
    const book = featuredBooks[i];
    console.log(`\n[${i + 1}/${featuredBooks.length}] Processing: ${book.title}`);
    
    const result = await generateSummaryForBook(book.id, book.title);
    results.push(result);
    
    // Add delay between API calls to avoid rate limiting
    if (i < featuredBooks.length - 1) {
      console.log(`  ⏱️  Waiting 3 seconds before next summary...`);
      await new Promise(resolve => setTimeout(resolve, 3000));
    }
  }
  
  // Summary of results
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  
  console.log('\n📊 Summary Generation Results:');
  console.log(`✅ Successfully generated: ${successful.length} summaries`);
  console.log(`❌ Failed generations: ${failed.length} summaries`);
  
  if (failed.length > 0) {
    console.log('\n❌ Failed summaries:');
    failed.forEach(f => console.log(`  - ${f.title}: ${f.error}`));
  }
  
  if (successful.length > 0) {
    console.log('\n✅ Successfully generated summaries for:');
    successful.forEach((s, index) => {
      console.log(`  ${index + 1}. ${s.title}`);
    });
  }
  
  console.log('\n🎉 Summary generation completed!');
  return { successful, failed };
}

async function generateSummaryForSpecificBook(bookId: string) {
  console.log(`🚀 Generating summary for specific book: ${bookId}`);
  
  // Get book details
  const { data: book, error } = await supabase
    .from('books')
    .select('id, title')
    .eq('id', bookId)
    .single();

  if (error) {
    throw new Error(`Failed to fetch book: ${error.message}`);
  }

  if (!book) {
    throw new Error('Book not found');
  }

  const result = await generateSummaryForBook(book.id, book.title);
  
  if (result.success) {
    console.log('✅ Summary generated successfully!');
  } else {
    console.error(`❌ Failed to generate summary: ${result.error}`);
  }
  
  return result;
}

// CLI interface
if (require.main === module) {
  const command = process.argv[2];
  const bookId = process.argv[3];
  
  if (command === 'single' && bookId) {
    // Generate summary for a specific book
    generateSummaryForSpecificBook(bookId)
      .then(() => process.exit(0))
      .catch(error => {
        console.error('❌ Summary generation failed:', error);
        process.exit(1);
      });
  } else {
    // Generate summaries for all featured books
    generateSummariesForFeaturedBooks()
      .then(() => process.exit(0))
      .catch(error => {
        console.error('❌ Summary generation failed:', error);
        process.exit(1);
      });
  }
}

export { generateSummariesForFeaturedBooks, generateSummaryForSpecificBook };