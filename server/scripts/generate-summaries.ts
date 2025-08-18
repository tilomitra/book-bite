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
  hasRegularSummary: boolean;
  hasExtendedSummary: boolean;
  error?: string;
}

async function generateSummaryForBook(bookId: string, title: string): Promise<SummaryResult> {
  const openai = new OpenAIService();
  
  try {
    console.log(`📝 Generating summaries for: ${title}`);
    
    // Check if summaries already exist
    const { data: existingSummary } = await supabase
      .from('summaries')
      .select('id')
      .eq('book_id', bookId)
      .single();

    const { data: existingExtendedSummary } = await supabase
      .from('extended_summaries')
      .select('id')
      .eq('book_id', bookId)
      .single();

    let hasRegularSummary = !!existingSummary;
    let hasExtendedSummary = !!existingExtendedSummary;

    if (hasRegularSummary && hasExtendedSummary) {
      console.log(`📋 Both summaries already exist for: ${title}`);
      return { bookId, title, success: true, hasRegularSummary: true, hasExtendedSummary: true };
    }

    // Get book details for summary generation
    const { data: book } = await supabase
      .from('books')
      .select('*')
      .eq('id', bookId)
      .single();

    if (!book) {
      console.log(`❌ Book not found: ${bookId}`);
      return { bookId, title, success: false, hasRegularSummary: false, hasExtendedSummary: false, error: 'Book not found' };
    }

    // Generate regular summary if it doesn't exist
    if (!hasRegularSummary) {
      console.log(`  🤖 Generating regular summary...`);
      const summaryData = await openai.generateBookSummary(
        book.title,
        book.authors,
        book.description || '',
        book.categories,
        'full'
      );

      const { error: summaryError } = await supabase
        .from('summaries')
        .insert({
          book_id: bookId,
          ...summaryData
        });

      if (summaryError) {
        console.error(`❌ Failed to save regular summary for ${title}: ${summaryError.message}`);
        return { bookId, title, success: false, hasRegularSummary: false, hasExtendedSummary, error: summaryError.message };
      }

      hasRegularSummary = true;
      console.log(`  ✅ Regular summary generated`);
    }

    // Add delay between regular and extended summary generation
    if (hasRegularSummary && !hasExtendedSummary) {
      console.log(`  ⏱️  Waiting 2 seconds before generating extended summary...`);
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Generate extended summary if it doesn't exist
    if (!hasExtendedSummary) {
      console.log(`  🔥 Generating extended summary...`);
      const extendedSummaryData = await openai.generateExtendedBookSummary(
        book.title,
        book.authors,
        book.description || '',
        book.categories
      );

      const { error: extendedError } = await supabase
        .from('extended_summaries')
        .insert({
          book_id: bookId,
          ...extendedSummaryData
        });

      if (extendedError) {
        console.error(`❌ Failed to save extended summary for ${title}: ${extendedError.message}`);
        return { bookId, title, success: hasRegularSummary, hasRegularSummary, hasExtendedSummary: false, error: extendedError.message };
      }

      hasExtendedSummary = true;
      console.log(`  ✅ Extended summary generated`);
    }

    console.log(`✅ Generated summaries for: ${title}`);
    return { bookId, title, success: true, hasRegularSummary, hasExtendedSummary };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error(`❌ Error generating summaries for ${title}:`, errorMessage);
    return { bookId, title, success: false, hasRegularSummary: false, hasExtendedSummary: false, error: errorMessage };
  }
}

async function generateSummariesForFeaturedBooks() {
  console.log('🚀 Starting summary generation for featured books...');
  console.log('📝 This will generate both regular and extended summaries');
  
  // Get all featured books
  const { data: featuredBooks, error } = await supabase
    .from('books')
    .select('id, title')
    .eq('is_featured', true)
    .order('popularity_rank', { ascending: true });

  if (error) {
    throw new Error(`Failed to fetch featured books: ${error.message}`);
  }

  if (!featuredBooks || featuredBooks.length === 0) {
    console.log('📚 No featured books found. Run populate-featured-books.ts first.');
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
    
    // Add longer delay between API calls since we're making multiple calls per book
    if (i < featuredBooks.length - 1) {
      console.log(`  ⏱️  Waiting 5 seconds before next book...`);
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
  
  // Summary of results
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  const regularSummariesCreated = results.filter(r => r.hasRegularSummary).length;
  const extendedSummariesCreated = results.filter(r => r.hasExtendedSummary).length;
  
  console.log('\n📊 Summary Generation Results:');
  console.log(`✅ Books processed successfully: ${successful.length}`);
  console.log(`📝 Regular summaries created: ${regularSummariesCreated}`);
  console.log(`🔥 Extended summaries created: ${extendedSummariesCreated}`);
  console.log(`❌ Failed processing: ${failed.length}`);
  
  if (failed.length > 0) {
    console.log('\n❌ Failed books:');
    failed.forEach(f => console.log(`  - ${f.title}: ${f.error}`));
  }
  
  if (successful.length > 0) {
    console.log('\n✅ Successfully processed books:');
    successful.forEach((s, index) => {
      const summaryTypes = [];
      if (s.hasRegularSummary) summaryTypes.push('regular');
      if (s.hasExtendedSummary) summaryTypes.push('extended');
      console.log(`  ${index + 1}. ${s.title} (${summaryTypes.join(', ')})`);
    });
  }
  
  console.log('\n🎉 Summary generation completed!');
  return { successful, failed, regularSummariesCreated, extendedSummariesCreated };
}

async function generateSummaryForSpecificBook(bookId: string) {
  console.log(`🚀 Generating summaries for specific book: ${bookId}`);
  console.log('📝 This will generate both regular and extended summaries');
  
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
    const summaryTypes = [];
    if (result.hasRegularSummary) summaryTypes.push('regular');
    if (result.hasExtendedSummary) summaryTypes.push('extended');
    console.log(`✅ Summaries generated successfully! (${summaryTypes.join(', ')})`);
  } else {
    console.error(`❌ Failed to generate summaries: ${result.error}`);
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