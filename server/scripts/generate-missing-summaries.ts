import { config } from 'dotenv';
import { OpenAIService } from '../src/services/openaiService';
import { supabase } from '../src/config/supabase';

// Load environment variables
config();

interface BookWithoutSummary {
  id: string;
  title: string;
  subtitle?: string;
  authors: string[];
  description?: string;
  categories: string[];
}

interface SummaryResult {
  bookId: string;
  title: string;
  success: boolean;
  hasRegularSummary: boolean;
  hasExtendedSummary: boolean;
  error?: string;
  duration?: number;
  wordCount?: number;
}

async function findBooksWithoutSummaries(): Promise<BookWithoutSummary[]> {
  console.log('🔍 Searching for books without summaries...');
  
  try {
    // Use LEFT JOIN to find books without summaries - this is more reliable
    const { data: booksWithSummaryInfo, error } = await supabase
      .from('books')
      .select(`
        id,
        title,
        subtitle,
        authors,
        description,
        categories,
        summaries!left(id)
      `);

    if (error) {
      throw new Error(`Failed to fetch books: ${error.message}`);
    }

    if (!booksWithSummaryInfo) {
      return [];
    }

    // Filter out books that have summaries and clean the data
    const booksWithoutSummaries = booksWithSummaryInfo
      .filter(book => !book.summaries || book.summaries.length === 0)
      .map(book => ({
        id: book.id,
        title: book.title,
        subtitle: book.subtitle,
        authors: book.authors,
        description: book.description,
        categories: book.categories
      }));

    return booksWithoutSummaries;
  } catch (error) {
    console.error('Error finding books without summaries:', error);
    throw error;
  }
}

async function generateSummaryForBook(book: BookWithoutSummary): Promise<SummaryResult> {
  const openai = new OpenAIService();
  const startTime = Date.now();
  
  try {
    console.log(`  🤖 Generating summaries for: "${book.title}"`);
    
    // Double-check that no summary exists (race condition protection)
    const { data: existingSummary } = await supabase
      .from('summaries')
      .select('id, extended_summary')
      .eq('book_id', book.id)
      .single();

    if (existingSummary) {
      console.log(`  📋 Summary now exists (likely created by another process), skipping`);
      const hasExtended = !!(existingSummary.extended_summary && existingSummary.extended_summary.trim() !== '');
      return { 
        bookId: book.id, 
        title: book.title, 
        success: true,
        hasRegularSummary: true,
        hasExtendedSummary: hasExtended,
        duration: Date.now() - startTime
      };
    }

    // Generate regular summary using OpenAI
    console.log(`     📝 Generating regular summary...`);
    const summaryData = await openai.generateBookSummary(
      book.title,
      book.authors || [],
      book.description || '',
      book.categories || [],
      'full'
    );

    console.log(`     💾 Saving regular summary to database...`);
    // Save regular summary to database
    const { data: savedSummary, error } = await supabase
      .from('summaries')
      .insert({
        book_id: book.id,
        ...summaryData
      })
      .select('id')
      .single();

    if (error) {
      console.error(`     ❌ Regular summary save failed: ${error.message}`);
      return { 
        bookId: book.id, 
        title: book.title, 
        success: false,
        hasRegularSummary: false,
        hasExtendedSummary: false,
        error: `Regular summary save failed: ${error.message}`,
        duration: Date.now() - startTime
      };
    }

    let hasExtendedSummary = false;
    let extendedWordCount = 0;

    // Add delay between regular and extended summary generation
    console.log(`     ⏸️  Waiting 2 seconds before generating extended summary...`);
    await new Promise(resolve => setTimeout(resolve, 2000));

    try {
      // Generate extended summary
      console.log(`     📖 Generating extended summary (using cheaper model)...`);
      const extendedSummary = await openai.generateExtendedSummary(
        book.title,
        book.authors || [],
        book.description || '',
        book.categories || []
      );

      console.log(`     💾 Updating with extended summary...`);
      // Update the summary with extended summary
      const { error: extendedError } = await supabase
        .from('summaries')
        .update({
          extended_summary: extendedSummary
        })
        .eq('id', savedSummary.id);

      if (extendedError) {
        console.error(`     ⚠️  Extended summary save failed: ${extendedError.message}`);
        console.log(`     ✅ Regular summary saved, but extended summary failed`);
      } else {
        hasExtendedSummary = true;
        extendedWordCount = extendedSummary.split(/\s+/).length;
        console.log(`     ✅ Extended summary saved (~${extendedWordCount} words)`);
      }
    } catch (extendedError) {
      const extendedErrorMessage = extendedError instanceof Error ? extendedError.message : 'Unknown error';
      console.error(`     ⚠️  Extended summary generation failed: ${extendedErrorMessage}`);
      console.log(`     ✅ Regular summary saved, but extended summary failed`);
    }

    const duration = Date.now() - startTime;
    const summaryTypes = ['regular'];
    if (hasExtendedSummary) summaryTypes.push('extended');
    
    console.log(`     ✅ Summary generation completed (${Math.round(duration/1000)}s, ${summaryTypes.join(' + ')})`);
    return { 
      bookId: book.id, 
      title: book.title, 
      success: true,
      hasRegularSummary: true,
      hasExtendedSummary,
      duration,
      wordCount: extendedWordCount
    };

  } catch (error) {
    const duration = Date.now() - startTime;
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error(`     ❌ Generation failed: ${errorMessage}`);
    return { 
      bookId: book.id, 
      title: book.title, 
      success: false,
      hasRegularSummary: false,
      hasExtendedSummary: false,
      error: errorMessage,
      duration
    };
  }
}

async function generateMissingSummaries(options: {
  batchSize?: number;
  delayBetweenBatches?: number;
  maxBooks?: number;
} = {}) {
  const {
    batchSize = 5,
    delayBetweenBatches = 5000, // 5 seconds between batches
    maxBooks = 100 // Safety limit
  } = options;

  console.log('🚀 Starting missing summaries generation...');
  console.log('📝 This will generate both regular and extended summaries');
  console.log(`⚙️  Batch size: ${batchSize} books`);
  console.log(`⏱️  Delay between batches: ${delayBetweenBatches/1000}s`);
  console.log(`📊 Max books to process: ${maxBooks}`);
  console.log('');

  // Find books without summaries
  const booksWithoutSummaries = await findBooksWithoutSummaries();
  
  if (!booksWithoutSummaries || booksWithoutSummaries.length === 0) {
    console.log('🎉 All books already have summaries! Nothing to do.');
    return {
      totalFound: 0,
      processed: 0,
      successful: 0,
      failed: 0,
      results: []
    };
  }

  const totalFound = booksWithoutSummaries.length;
  const booksToProcess = booksWithoutSummaries.slice(0, maxBooks);
  const actualBooksToProcess = booksToProcess.length;

  console.log(`📚 Found ${totalFound} books without summaries`);
  if (totalFound > maxBooks) {
    console.log(`⚠️  Processing first ${maxBooks} books (safety limit)`);
  }
  console.log(`🎯 Will process ${actualBooksToProcess} books in batches of ${batchSize}\n`);

  const results: SummaryResult[] = [];
  let processedCount = 0;
  
  // Process in batches
  for (let i = 0; i < actualBooksToProcess; i += batchSize) {
    const batch = booksToProcess.slice(i, i + batchSize);
    const batchNumber = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(actualBooksToProcess / batchSize);
    
    console.log(`📦 Processing batch ${batchNumber}/${totalBatches} (${batch.length} books)`);
    console.log('─'.repeat(60));

    // Process batch sequentially to avoid overwhelming the APIs
    for (let j = 0; j < batch.length; j++) {
      const book = batch[j];
      const globalIndex = i + j + 1;
      
      console.log(`[${globalIndex}/${actualBooksToProcess}] Processing: "${book.title}"`);
      console.log(`     👤 Authors: ${book.authors.join(', ')}`);
      console.log(`     📚 Categories: ${book.categories.join(', ')}`);
      
      const result = await generateSummaryForBook(book);
      results.push(result);
      processedCount++;
      
      // Add delay between individual books in a batch (except last book)
      if (j < batch.length - 1) {
        console.log(`     ⏸️  Waiting 2s before next book...`);
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
      
      console.log(''); // Add spacing between books
    }
    
    // Add delay between batches (except after last batch)
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
  const regularSummariesCreated = results.filter(r => r.hasRegularSummary).length;
  const extendedSummariesCreated = results.filter(r => r.hasExtendedSummary).length;
  const totalWords = successful.reduce((sum, r) => sum + (r.wordCount || 0), 0);
  const averageWords = extendedSummariesCreated > 0 ? totalWords / extendedSummariesCreated : 0;

  console.log('═'.repeat(80));
  console.log('📊 SUMMARY GENERATION REPORT');
  console.log('═'.repeat(80));
  console.log(`📚 Books found without summaries: ${totalFound}`);
  console.log(`🎯 Books processed: ${processedCount}`);
  console.log(`✅ Books with summaries successfully generated: ${successful.length}`);
  console.log(`📝 Regular summaries created: ${regularSummariesCreated}`);
  console.log(`📖 Extended summaries created: ${extendedSummariesCreated}`);
  console.log(`❌ Generation failures: ${failed.length}`);
  console.log(`⏱️  Average generation time: ${Math.round(averageDuration/1000)}s`);
  console.log(`🕐 Total processing time: ${Math.round(totalDuration/1000)}s`);
  if (totalWords > 0) {
    console.log(`📝 Total words in extended summaries: ${totalWords.toLocaleString()}`);
    console.log(`📖 Average words per extended summary: ${Math.round(averageWords)}`);
  }
  
  if (failed.length > 0) {
    console.log('\n❌ Failed Summary Generations:');
    console.log('─'.repeat(40));
    failed.forEach((f, index) => {
      console.log(`${index + 1}. "${f.title}"`);
      console.log(`   Error: ${f.error}`);
      console.log(`   Duration: ${Math.round((f.duration || 0)/1000)}s`);
    });
  }
  
  if (successful.length > 0) {
    console.log('\n✅ Successfully Generated Summaries:');
    console.log('─'.repeat(40));
    successful.slice(0, 10).forEach((s, index) => { // Show first 10
      const summaryTypes = [];
      if (s.hasRegularSummary) summaryTypes.push('regular');
      if (s.hasExtendedSummary) summaryTypes.push('extended');
      const wordInfo = s.wordCount ? `, ${s.wordCount} words` : '';
      console.log(`${index + 1}. "${s.title}" (${Math.round((s.duration || 0)/1000)}s, ${summaryTypes.join(' + ')}${wordInfo})`);
    });
    if (successful.length > 10) {
      console.log(`   ... and ${successful.length - 10} more`);
    }
  }
  
  console.log('═'.repeat(80));
  
  if (successful.length > 0) {
    console.log('🎉 Summary generation completed successfully!');
    console.log(`💰 Generated ${regularSummariesCreated} regular summaries and ${extendedSummariesCreated} extended summaries`);
  } else if (failed.length > 0) {
    console.log('⚠️ Summary generation completed with errors. Check the failed list above.');
  }

  return {
    totalFound,
    processed: processedCount,
    successful: successful.length,
    failed: failed.length,
    regularSummariesCreated,
    extendedSummariesCreated,
    results
  };
}

// CLI interface
if (require.main === module) {
  const batchSizeArg = process.argv[2];
  const maxBooksArg = process.argv[3];
  
  const options = {
    batchSize: batchSizeArg ? parseInt(batchSizeArg) : 5,
    maxBooks: maxBooksArg ? parseInt(maxBooksArg) : 100,
    delayBetweenBatches: 5000
  };
  
  // Validate arguments
  if (isNaN(options.batchSize) || options.batchSize < 1) {
    console.error('❌ Invalid batch size. Must be a positive number.');
    console.log('Usage: tsx scripts/generate-missing-summaries.ts [batchSize] [maxBooks]');
    console.log('Example: tsx scripts/generate-missing-summaries.ts 3 50');
    console.log('Note: Generates both regular summaries AND extended summaries');
    process.exit(1);
  }
  
  if (isNaN(options.maxBooks) || options.maxBooks < 1) {
    console.error('❌ Invalid max books. Must be a positive number.');
    console.log('Usage: tsx scripts/generate-missing-summaries.ts [batchSize] [maxBooks]');
    console.log('Example: tsx scripts/generate-missing-summaries.ts 3 50');
    console.log('Note: Generates both regular summaries AND extended summaries');
    process.exit(1);
  }

  generateMissingSummaries(options)
    .then((results) => {
      process.exit(results.failed > 0 ? 1 : 0);
    })
    .catch((error) => {
      console.error('\n💥 Fatal error during summary generation:', error);
      process.exit(1);
    });
}

export { generateMissingSummaries, findBooksWithoutSummaries };

// Note: This script generates both regular summaries AND extended summaries
// for books that don't have any summary in the database. It replaces the need
// for separate scripts by creating complete summary records in one operation.