import { config } from 'dotenv';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { BookService } from '../src/services/bookService';
import { OpenAIService } from '../src/services/openaiService';
import { supabase } from '../src/config/supabase';

// Load environment variables
config();

// Comprehensive non-fiction categories for discovery
const NONFICTION_CATEGORIES = [
  // Personal Development & Psychology
  { name: 'Self-Help', query: 'subject:self-help', priority: 'high' },
  { name: 'Psychology', query: 'subject:psychology', priority: 'high' },
  { name: 'Personal Development', query: 'personal development', priority: 'high' },
  { name: 'Productivity', query: 'productivity habits', priority: 'medium' },
  { name: 'Mindfulness', query: 'mindfulness meditation', priority: 'medium' },
  
  // Business & Economics
  { name: 'Business', query: 'subject:business', priority: 'high' },
  { name: 'Entrepreneurship', query: 'entrepreneurship startup', priority: 'high' },
  { name: 'Economics', query: 'subject:economics', priority: 'medium' },
  { name: 'Leadership', query: 'leadership management', priority: 'high' },
  { name: 'Innovation', query: 'innovation disruption', priority: 'medium' },
  { name: 'Marketing', query: 'marketing advertising', priority: 'medium' },
  
  // Science & Technology
  { name: 'Science', query: 'subject:science', priority: 'high' },
  { name: 'Technology', query: 'technology future', priority: 'high' },
  { name: 'Biology', query: 'subject:biology', priority: 'medium' },
  { name: 'Physics', query: 'subject:physics', priority: 'medium' },
  { name: 'Medicine', query: 'subject:medicine', priority: 'medium' },
  { name: 'Environment', query: 'environment climate', priority: 'medium' },
  
  // History & Biography
  { name: 'History', query: 'subject:history', priority: 'high' },
  { name: 'Biography', query: 'subject:biography', priority: 'high' },
  { name: 'Memoir', query: 'memoir autobiography', priority: 'high' },
  { name: 'World War', query: 'world war history', priority: 'medium' },
  { name: 'American History', query: 'american history', priority: 'medium' },
  
  // Health & Wellness
  { name: 'Health', query: 'subject:health', priority: 'high' },
  { name: 'Nutrition', query: 'nutrition diet food', priority: 'medium' },
  { name: 'Fitness', query: 'fitness exercise', priority: 'medium' },
  { name: 'Mental Health', query: 'mental health therapy', priority: 'high' },
  
  // Philosophy & Religion
  { name: 'Philosophy', query: 'subject:philosophy', priority: 'medium' },
  { name: 'Religion', query: 'subject:religion', priority: 'medium' },
  { name: 'Spirituality', query: 'spirituality consciousness', priority: 'medium' },
  
  // Social Sciences
  { name: 'Sociology', query: 'subject:sociology', priority: 'medium' },
  { name: 'Politics', query: 'subject:politics', priority: 'medium' },
  { name: 'Anthropology', query: 'subject:anthropology', priority: 'medium' },
  { name: 'Education', query: 'subject:education', priority: 'medium' },
  
  // Arts & Culture
  { name: 'Art', query: 'subject:art', priority: 'low' },
  { name: 'Music', query: 'subject:music', priority: 'low' },
  { name: 'Travel', query: 'subject:travel', priority: 'low' },
  { name: 'Cooking', query: 'cooking recipes', priority: 'low' }
];

interface CategoryStats {
  name: string;
  attempted: number;
  added: number;
  duplicates: number;
  failures: number;
  summariesGenerated: number;
  summaryFailures: number;
}

async function checkForDuplicates(bookData: any): Promise<boolean> {
  try {
    // Check by Google Books ID first
    if (bookData.google_books_id) {
      const { data } = await supabase
        .from('books')
        .select('id')
        .eq('google_books_id', bookData.google_books_id)
        .single();
      
      if (data) {
        return true;
      }
    }

    // Check by ISBN13
    if (bookData.isbn13) {
      const { data } = await supabase
        .from('books')
        .select('id')
        .eq('isbn13', bookData.isbn13)
        .single();
      
      if (data) {
        return true;
      }
    }

    // Check by ISBN10
    if (bookData.isbn10) {
      const { data } = await supabase
        .from('books')
        .select('id')
        .eq('isbn10', bookData.isbn10)
        .single();
      
      if (data) {
        return true;
      }
    }

    return false;
  } catch (error) {
    return false;
  }
}

async function generateSummaryForBook(bookId: string, title: string): Promise<{success: boolean, error?: string}> {
  const openai = new OpenAIService();
  
  try {
    // Check if summary already exists
    const { data: existingSummary } = await supabase
      .from('summaries')
      .select('id')
      .eq('book_id', bookId)
      .single();

    if (existingSummary) {
      return { success: true };
    }

    // Get book details for summary generation
    const { data: book } = await supabase
      .from('books')
      .select('*')
      .eq('id', bookId)
      .single();

    if (!book) {
      return { success: false, error: 'Book not found' };
    }

    // Generate summary using OpenAI
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
      return { success: false, error: error.message };
    }

    // Generate extended summary
    try {
      const extendedSummary = await openai.generateExtendedSummary(
        book.title,
        book.authors,
        book.description || '',
        book.categories
      );
      
      await supabase
        .from('summaries')
        .update({ extended_summary: extendedSummary })
        .eq('book_id', bookId);
    } catch (error) {
      // Extended summary failure is not critical
    }

    return { success: true };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}

async function processCategory(
  category: { name: string; query: string; priority: string }, 
  targetCount: number = 50
): Promise<CategoryStats> {
  const googleBooksService = new GoogleBooksService();
  const bookService = new BookService();
  
  const stats: CategoryStats = {
    name: category.name,
    attempted: 0,
    added: 0,
    duplicates: 0,
    failures: 0,
    summariesGenerated: 0,
    summaryFailures: 0
  };

  console.log(`\n📚 Processing category: ${category.name}`);
  console.log(`🔍 Query: "${category.query}"`);
  console.log(`🎯 Target: ${targetCount} books`);
  console.log('─'.repeat(50));

  try {
    // Search for books in this category, get more than needed to account for duplicates
    const maxResults = Math.min(targetCount * 2, 40); // Google Books API limit is 40 per request
    const searchResults = await googleBooksService.searchBooks(
      category.query, 
      maxResults,
      {
        orderBy: 'relevance',
        filter: 'ebooks', // Prefer books with more metadata
        langRestrict: 'en'
      }
    );

    if (searchResults.length === 0) {
      console.log(`❌ No results found for category: ${category.name}`);
      return stats;
    }

    console.log(`📖 Found ${searchResults.length} potential books`);

    // Process books until we reach target count
    for (const bookData of searchResults) {
      if (stats.added >= targetCount) {
        break;
      }

      stats.attempted++;

      try {
        // Check for duplicates
        const isDuplicate = await checkForDuplicates(bookData);
        if (isDuplicate) {
          stats.duplicates++;
          console.log(`  📋 Duplicate: ${bookData.title}`);
          continue;
        }

        // Enhance categories
        const categories = bookData.categories || [];
        if (!categories.includes('Nonfiction')) {
          categories.push('Nonfiction');
        }
        if (!categories.includes(category.name)) {
          categories.push(category.name);
        }

        // Prepare book data
        const enhancedBookData = {
          ...bookData,
          categories,
          source_attribution: ['Google Books API', `Category: ${category.name}`]
        };

        // Create the book
        const createdBook = await bookService.createBook(enhancedBookData);
        stats.added++;
        
        console.log(`  ✅ Added: "${createdBook.title}" by ${createdBook.authors.join(', ')}`);

        // Generate summary
        const summaryResult = await generateSummaryForBook(createdBook.id, createdBook.title);
        if (summaryResult.success) {
          stats.summariesGenerated++;
          console.log(`    🤖 Summary generated`);
        } else {
          stats.summaryFailures++;
          console.log(`    ⚠️  Summary failed: ${summaryResult.error}`);
        }

        // Rate limiting
        await new Promise(resolve => setTimeout(resolve, 1500));

      } catch (error) {
        stats.failures++;
        console.log(`  ❌ Failed to process: ${bookData.title} - ${error.message}`);
      }
    }

  } catch (error) {
    console.error(`💥 Error processing category ${category.name}:`, error.message);
  }

  console.log(`\n📊 Category "${category.name}" Summary:`);
  console.log(`   ✅ Added: ${stats.added}/${targetCount}`);
  console.log(`   📋 Duplicates: ${stats.duplicates}`);
  console.log(`   ❌ Failures: ${stats.failures}`);
  console.log(`   🤖 Summaries: ${stats.summariesGenerated}`);

  return stats;
}

async function populateBooksByCategory(
  booksPerCategory: number = 50,
  priorityFilter?: 'high' | 'medium' | 'low'
) {
  console.log('🚀 Starting category-based book population...');
  console.log(`📈 Target: ${booksPerCategory} books per category`);
  
  // Filter categories by priority if specified
  let categoriesToProcess = NONFICTION_CATEGORIES;
  if (priorityFilter) {
    categoriesToProcess = NONFICTION_CATEGORIES.filter(cat => cat.priority === priorityFilter);
    console.log(`🎯 Processing only "${priorityFilter}" priority categories`);
  }
  
  console.log(`📚 Processing ${categoriesToProcess.length} categories\n`);

  const allStats: CategoryStats[] = [];

  for (let i = 0; i < categoriesToProcess.length; i++) {
    const category = categoriesToProcess[i];
    const progress = `${i + 1}/${categoriesToProcess.length}`;
    
    console.log(`\n🔄 Progress: ${progress}`);
    
    const categoryStats = await processCategory(category, booksPerCategory);
    allStats.push(categoryStats);

    // Longer delay between categories to respect rate limits
    if (i < categoriesToProcess.length - 1) {
      console.log(`⏸️  Waiting 5 seconds before next category...`);
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }

  // Final summary
  const totalStats = allStats.reduce((acc, stats) => ({
    attempted: acc.attempted + stats.attempted,
    added: acc.added + stats.added,
    duplicates: acc.duplicates + stats.duplicates,
    failures: acc.failures + stats.failures,
    summariesGenerated: acc.summariesGenerated + stats.summariesGenerated,
    summaryFailures: acc.summaryFailures + stats.summaryFailures
  }), {
    attempted: 0,
    added: 0,
    duplicates: 0,
    failures: 0,
    summariesGenerated: 0,
    summaryFailures: 0
  });

  console.log('\n' + '═'.repeat(60));
  console.log('📊 FINAL SUMMARY');
  console.log('═'.repeat(60));
  console.log(`📚 Categories processed: ${categoriesToProcess.length}`);
  console.log(`📖 Total books attempted: ${totalStats.attempted}`);
  console.log(`✅ Total books added: ${totalStats.added}`);
  console.log(`📋 Total duplicates: ${totalStats.duplicates}`);
  console.log(`❌ Total failures: ${totalStats.failures}`);
  console.log(`🤖 Total summaries generated: ${totalStats.summariesGenerated}`);
  console.log(`⚠️  Total summary failures: ${totalStats.summaryFailures}`);
  console.log(`📈 Success rate: ${((totalStats.added / totalStats.attempted) * 100).toFixed(1)}%`);
  console.log('═'.repeat(60));

  return {
    totalStats,
    categoryStats: allStats,
    categoriesProcessed: categoriesToProcess.length
  };
}

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const booksPerCategory = parseInt(args[0]) || 50;
  const priority = args[1] as 'high' | 'medium' | 'low' | undefined;

  console.log('📚 BookBite Category-Based Book Population');
  console.log('==========================================');
  
  if (priority) {
    console.log(`🎯 Processing only "${priority}" priority categories`);
  }
  
  populateBooksByCategory(booksPerCategory, priority)
    .then((results) => {
      if (results.totalStats.added > 0) {
        console.log('\n🎉 Category-based population completed successfully!');
        console.log(`📚 Added ${results.totalStats.added} books across ${results.categoriesProcessed} categories`);
      } else {
        console.log('\n⚠️ No books were added. Check the logs above for details.');
      }
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n💥 Fatal error during population:', error);
      process.exit(1);
    });
}

export { populateBooksByCategory, processCategory };