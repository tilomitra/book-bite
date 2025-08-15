import { config } from 'dotenv';
import { OpenAIService } from '../src/services/openaiService';
import { supabase } from '../src/config/supabase';

// Load environment variables
config();

interface BookWithSummary {
  id: string;
  title: string;
  subtitle?: string;
  authors: string[];
  description?: string;
  categories: string[];
  summary_id: string;
  has_extended_summary: boolean;
}

interface ExtendedSummaryResult {
  bookId: string;
  summaryId: string;
  title: string;
  success: boolean;
  error?: string;
  duration?: number;
  wordCount?: number;
}

async function findBooksNeedingExtendedSummaries(): Promise<BookWithSummary[]> {
  console.log('🔍 Searching for books that need extended summaries...');
  
  try {
    // Find books that have regular summaries but no extended summaries
    const { data: booksWithSummaries, error } = await supabase
      .from('books')
      .select(`
        id,
        title,
        subtitle,
        authors,
        description,
        categories,
        summaries!inner(
          id,
          extended_summary
        )
      `)
      .not('summaries.id', 'is', null);

    if (error) {
      throw new Error(`Failed to fetch books with summaries: ${error.message}`);
    }

    if (!booksWithSummaries) {
      return [];
    }

    // Filter to books that don't have extended summaries yet
    const booksNeedingExtended = booksWithSummaries
      .filter(book => 
        book.summaries && 
        book.summaries.length > 0 && 
        (!book.summaries[0].extended_summary || book.summaries[0].extended_summary.trim() === '')
      )
      .map(book => ({
        id: book.id,
        title: book.title,
        subtitle: book.subtitle,
        authors: book.authors,
        description: book.description,
        categories: book.categories,
        summary_id: book.summaries[0].id,
        has_extended_summary: false
      }));

    return booksNeedingExtended;
  } catch (error) {
    console.error('Error finding books needing extended summaries:', error);
    throw error;
  }
}

async function generateExtendedSummaryForBook(book: BookWithSummary): Promise<ExtendedSummaryResult> {
  const openai = new OpenAIService();
  const startTime = Date.now();
  
  try {
    console.log(`  📝 Generating extended summary for: "${book.title}"`);
    
    // Double-check that no extended summary exists
    const { data: currentSummary } = await supabase
      .from('summaries')
      .select('extended_summary')
      .eq('id', book.summary_id)
      .single();

    if (currentSummary?.extended_summary && currentSummary.extended_summary.trim() !== '') {
      console.log(`  📋 Extended summary now exists, skipping`);
      return { 
        bookId: book.id, 
        summaryId: book.summary_id,
        title: book.title, 
        success: true,
        duration: Date.now() - startTime
      };
    }

    console.log(`     🤖 Calling OpenAI API (using ${openai['cheaperModel'] || 'gpt-3.5-turbo'})...`);
    
    // Generate extended summary using cheaper model
    const extendedSummary = await openai.generateExtendedSummary(
      book.title,
      book.authors || [],
      book.description || '',
      book.categories || []
    );

    console.log(`     💾 Saving to database...`);
    
    // Update the summary with the extended summary
    const { error } = await supabase
      .from('summaries')
      .update({
        extended_summary: extendedSummary
      })
      .eq('id', book.summary_id);

    if (error) {
      console.error(`     ❌ Database update failed: ${error.message}`);
      return { 
        bookId: book.id,
        summaryId: book.summary_id,
        title: book.title, 
        success: false, 
        error: `Database update failed: ${error.message}`,
        duration: Date.now() - startTime
      };
    }

    const duration = Date.now() - startTime;
    const wordCount = extendedSummary.split(/\s+/).length;
    console.log(`     ✅ Extended summary generated and saved (${Math.round(duration/1000)}s, ~${wordCount} words)`);
    
    return { 
      bookId: book.id,
      summaryId: book.summary_id,
      title: book.title, 
      success: true,
      duration,
      wordCount
    };

  } catch (error) {
    const duration = Date.now() - startTime;
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error(`     ❌ Generation failed: ${errorMessage}`);
    return { 
      bookId: book.id,
      summaryId: book.summary_id,
      title: book.title, 
      success: false, 
      error: errorMessage,
      duration
    };
  }
}

async function generateExtendedSummaries(options: {
  batchSize?: number;
  delayBetweenBatches?: number;
  maxBooks?: number;
} = {}) {
  const {
    batchSize = 3, // Smaller batches since these are longer summaries
    delayBetweenBatches = 8000, // 8 seconds between batches (longer for cost control)
    maxBooks = 50 // Conservative limit
  } = options;

  console.log('🚀 Starting extended summaries generation...');
  console.log(`⚙️  Batch size: ${batchSize} books`);
  console.log(`⏱️  Delay between batches: ${delayBetweenBatches/1000}s`);
  console.log(`📊 Max books to process: ${maxBooks}`);
  console.log(`💰 Using cheaper model (gpt-3.5-turbo) for cost efficiency`);
  console.log('');

  // Find books needing extended summaries
  const booksNeedingExtended = await findBooksNeedingExtendedSummaries();
  
  if (!booksNeedingExtended || booksNeedingExtended.length === 0) {
    console.log('🎉 All books with summaries already have extended summaries! Nothing to do.');
    return {
      totalFound: 0,
      processed: 0,
      successful: 0,
      failed: 0,
      results: []
    };
  }

  const totalFound = booksNeedingExtended.length;
  const booksToProcess = booksNeedingExtended.slice(0, maxBooks);
  const actualBooksToProcess = booksToProcess.length;

  console.log(`📚 Found ${totalFound} books needing extended summaries`);
  if (totalFound > maxBooks) {
    console.log(`⚠️  Processing first ${maxBooks} books (safety limit)`);
  }
  console.log(`🎯 Will process ${actualBooksToProcess} books in batches of ${batchSize}\n`);

  const results: ExtendedSummaryResult[] = [];
  let processedCount = 0;
  
  // Process in batches
  for (let i = 0; i < actualBooksToProcess; i += batchSize) {
    const batch = booksToProcess.slice(i, i + batchSize);
    const batchNumber = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(actualBooksToProcess / batchSize);
    
    console.log(`📦 Processing batch ${batchNumber}/${totalBatches} (${batch.length} books)`);
    console.log('─'.repeat(60));

    // Process batch sequentially to control costs and avoid rate limits
    for (let j = 0; j < batch.length; j++) {
      const book = batch[j];
      const globalIndex = i + j + 1;
      
      console.log(`[${globalIndex}/${actualBooksToProcess}] Processing: "${book.title}"`);
      console.log(`     👤 Authors: ${book.authors.join(', ')}`);
      console.log(`     📚 Categories: ${book.categories.join(', ')}`);
      
      const result = await generateExtendedSummaryForBook(book);
      results.push(result);
      processedCount++;
      
      // Add delay between individual books in a batch
      if (j < batch.length - 1) {
        console.log(`     ⏸️  Waiting 3s before next book...`);
        await new Promise(resolve => setTimeout(resolve, 3000));
      }
      
      console.log(''); // Add spacing between books
    }
    
    // Add delay between batches
    if (i + batchSize < actualBooksToProcess) {
      console.log(`🛑 Batch ${batchNumber} completed. Waiting ${delayBetweenBatches/1000}s before next batch...`);
      console.log('═'.repeat(60));
      await new Promise(resolve => setTimeout(resolve, delayBetweenBatches));
      console.log('');
    }
  }
  
  // Generate summary report
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  const totalDuration = results.reduce((sum, r) => sum + (r.duration || 0), 0);
  const averageDuration = results.length > 0 ? totalDuration / results.length : 0;
  const totalWords = successful.reduce((sum, r) => sum + (r.wordCount || 0), 0);
  const averageWords = successful.length > 0 ? totalWords / successful.length : 0;

  console.log('═'.repeat(80));
  console.log('📊 EXTENDED SUMMARY GENERATION REPORT');
  console.log('═'.repeat(80));
  console.log(`📚 Books found needing extended summaries: ${totalFound}`);
  console.log(`🎯 Books processed: ${processedCount}`);
  console.log(`✅ Extended summaries successfully generated: ${successful.length}`);
  console.log(`❌ Generation failures: ${failed.length}`);
  console.log(`⏱️  Average generation time: ${Math.round(averageDuration/1000)}s`);
  console.log(`🕐 Total processing time: ${Math.round(totalDuration/1000)}s`);
  console.log(`📝 Total words generated: ${totalWords.toLocaleString()}`);
  console.log(`📖 Average words per summary: ${Math.round(averageWords)}`);
  
  if (failed.length > 0) {
    console.log('\n❌ Failed Extended Summary Generations:');
    console.log('─'.repeat(40));
    failed.forEach((f, index) => {
      console.log(`${index + 1}. "${f.title}"`);
      console.log(`   Error: ${f.error}`);
      console.log(`   Duration: ${Math.round((f.duration || 0)/1000)}s`);
    });
  }
  
  if (successful.length > 0) {
    console.log('\n✅ Successfully Generated Extended Summaries:');
    console.log('─'.repeat(40));
    successful.slice(0, 10).forEach((s, index) => { // Show first 10
      console.log(`${index + 1}. "${s.title}" (${Math.round((s.duration || 0)/1000)}s, ${s.wordCount || 0} words)`);
    });
    if (successful.length > 10) {
      console.log(`   ... and ${successful.length - 10} more`);
    }
  }
  
  console.log('═'.repeat(80));
  
  if (successful.length > 0) {
    console.log('🎉 Extended summary generation completed successfully!');
    console.log(`💰 Used cost-effective model for ${successful.length} summaries`);
  } else if (failed.length > 0) {
    console.log('⚠️ Extended summary generation completed with errors. Check the failed list above.');
  }

  return {
    totalFound,
    processed: processedCount,
    successful: successful.length,
    failed: failed.length,
    results
  };
}

// CLI interface
if (require.main === module) {
  const batchSizeArg = process.argv[2];
  const maxBooksArg = process.argv[3];
  
  const options = {
    batchSize: batchSizeArg ? parseInt(batchSizeArg) : 3,
    maxBooks: maxBooksArg ? parseInt(maxBooksArg) : 50,
    delayBetweenBatches: 8000
  };
  
  // Validate arguments
  if (isNaN(options.batchSize) || options.batchSize < 1) {
    console.error('❌ Invalid batch size. Must be a positive number.');
    console.log('Usage: tsx scripts/generate-extended-summaries.ts [batchSize] [maxBooks]');
    console.log('Example: tsx scripts/generate-extended-summaries.ts 2 20');
    process.exit(1);
  }
  
  if (isNaN(options.maxBooks) || options.maxBooks < 1) {
    console.error('❌ Invalid max books. Must be a positive number.');
    console.log('Usage: tsx scripts/generate-extended-summaries.ts [batchSize] [maxBooks]');
    console.log('Example: tsx scripts/generate-extended-summaries.ts 2 20');
    process.exit(1);
  }

  generateExtendedSummaries(options)
    .then((results) => {
      process.exit(results.failed > 0 ? 1 : 0);
    })
    .catch((error) => {
      console.error('\n💥 Fatal error during extended summary generation:', error);
      process.exit(1);
    });
}

export { generateExtendedSummaries, findBooksNeedingExtendedSummaries };