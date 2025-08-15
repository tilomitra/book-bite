import { config } from 'dotenv';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { BookService } from '../src/services/bookService';
import { OpenAIService } from '../src/services/openaiService';
import { supabase } from '../src/config/supabase';

// Load environment variables
config();

// Popular non-fiction books with diverse topics
const POPULAR_NONFICTION_BOOKS = [
  // Self-Help & Personal Development
  { title: "Atomic Habits", author: "James Clear", subject: "self-improvement" },
  { title: "The 7 Habits of Highly Effective People", author: "Stephen Covey", subject: "self-improvement" },
  { title: "Think and Grow Rich", author: "Napoleon Hill", subject: "success" },
  { title: "Mindset", author: "Carol Dweck", subject: "psychology+self-improvement" },
  
  // Biography & Memoir
  { title: "Educated", author: "Tara Westover", subject: "memoir" },
  { title: "Becoming", author: "Michelle Obama", subject: "memoir" },
  { title: "Steve Jobs", author: "Walter Isaacson", subject: "biography" },
  
  // Science & Nature
  { title: "Sapiens", author: "Yuval Noah Harari", subject: "history+anthropology" },
  { title: "The Immortal Life of Henrietta Lacks", author: "Rebecca Skloot", subject: "science" },
  { title: "Silent Spring", author: "Rachel Carson", subject: "environment" },
  
  // Psychology & Society
  { title: "Thinking, Fast and Slow", author: "Daniel Kahneman", subject: "psychology" },
  { title: "The Power of Now", author: "Eckhart Tolle", subject: "mindfulness" },
  { title: "Outliers", author: "Malcolm Gladwell", subject: "psychology+success" },
  
  // Business & Economics
  { title: "The Lean Startup", author: "Eric Ries", subject: "business+entrepreneurship" },
  { title: "Good to Great", author: "Jim Collins", subject: "business+management" },
  { title: "Freakonomics", author: "Steven Levitt", subject: "economics" },
  
  // History & Politics
  { title: "The Guns of August", author: "Barbara Tuchman", subject: "history" },
  { title: "A People's History of the United States", author: "Howard Zinn", subject: "history" },
  { title: "The Righteous Mind", author: "Jonathan Haidt", subject: "politics+psychology" },
  
  // Health & Wellness
  { title: "The Blue Zones", author: "Dan Buettner", subject: "health+longevity" },
  { title: "Being Mortal", author: "Atul Gawande", subject: "medicine+philosophy" }
];

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
        console.log(`  📋 Duplicate found by Google Books ID: ${bookData.title}`);
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
        console.log(`  📋 Duplicate found by ISBN13: ${bookData.title}`);
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
        console.log(`  📋 Duplicate found by ISBN10: ${bookData.title}`);
        return true;
      }
    }

    // Check by title and authors (fuzzy match for similar titles)
    if (bookData.title && bookData.authors && bookData.authors.length > 0) {
      const { data } = await supabase
        .from('books')
        .select('id, title, authors')
        .ilike('title', `%${bookData.title}%`)
        .contains('authors', bookData.authors);
      
      if (data && data.length > 0) {
        console.log(`  📋 Potential duplicate found by title/author: ${bookData.title}`);
        return true;
      }
    }

    return false;
  } catch (error) {
    // If there's an error checking duplicates, we'll assume it's not a duplicate
    console.log(`  ⚠️  Error checking duplicates for ${bookData.title}: ${error.message}`);
    return false;
  }
}

async function generateSummaryForBook(bookId: string, title: string): Promise<{success: boolean, error?: string}> {
  const openai = new OpenAIService();
  
  try {
    console.log(`    🤖 Generating AI summary...`);
    
    // Check if summary already exists
    const { data: existingSummary } = await supabase
      .from('summaries')
      .select('id')
      .eq('book_id', bookId)
      .single();

    if (existingSummary) {
      console.log(`    📋 Summary already exists, skipping AI generation`);
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
      console.error(`    ❌ Failed to save summary: ${error.message}`);
      return { success: false, error: error.message };
    }

    console.log(`    ✅ AI summary generated and saved`);
    return { success: true };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error(`    ❌ Error generating summary:`, errorMessage);
    return { success: false, error: errorMessage };
  }
}

async function populateNonfictionBooks() {
  const googleBooksService = new GoogleBooksService();
  const bookService = new BookService();
  const openai = new OpenAIService();
  
  console.log('🚀 Starting to populate popular non-fiction books...');
  console.log(`📚 Target: ${POPULAR_NONFICTION_BOOKS.length} books\n`);
  
  let successCount = 0;
  let failCount = 0;
  let duplicateCount = 0;
  let summarySuccessCount = 0;
  let summaryFailCount = 0;
  
  for (let i = 0; i < POPULAR_NONFICTION_BOOKS.length; i++) {
    const bookInfo = POPULAR_NONFICTION_BOOKS[i];
    const bookNumber = i + 1;
    
    try {
      console.log(`📖 Processing ${bookNumber}/${POPULAR_NONFICTION_BOOKS.length}: "${bookInfo.title}" by ${bookInfo.author}`);
      
      // Search for the book using title and author
      const searchQuery = `${bookInfo.title} ${bookInfo.author}`;
      const searchResults = await googleBooksService.searchBooks(searchQuery, 5);
      
      if (searchResults.length === 0) {
        console.log(`  ❌ No results found for: ${bookInfo.title}`);
        failCount++;
        continue;
      }
      
      // Find the best match (prefer books that match both title and author)
      let bestMatch = searchResults[0];
      for (const result of searchResults) {
        const titleMatch = result.title?.toLowerCase().includes(bookInfo.title.toLowerCase());
        const authorMatch = result.authors?.some(author => 
          author.toLowerCase().includes(bookInfo.author.toLowerCase())
        );
        
        if (titleMatch && authorMatch) {
          bestMatch = result;
          break;
        }
      }
      
      // Check for duplicates before adding
      const isDuplicate = await checkForDuplicates(bestMatch);
      if (isDuplicate) {
        duplicateCount++;
        continue;
      }
      
      // Add categories to help with filtering
      const categories = bestMatch.categories || [];
      if (!categories.includes('Nonfiction')) {
        categories.push('Nonfiction');
      }
      
      // Add subject-specific category
      if (bookInfo.subject) {
        const subjectCategories = bookInfo.subject.split('+');
        subjectCategories.forEach(cat => {
          const capitalizedCat = cat.charAt(0).toUpperCase() + cat.slice(1);
          if (!categories.includes(capitalizedCat)) {
            categories.push(capitalizedCat);
          }
        });
      }
      
      // Prepare book data
      const bookData = {
        ...bestMatch,
        categories,
        source_attribution: ['Google Books API', 'Popular Nonfiction Collection']
      };
      
      // Create the book in database
      const createdBook = await bookService.createBook(bookData);
      console.log(`  ✅ Added: "${createdBook.title}"`);
      console.log(`     📚 Categories: ${createdBook.categories.join(', ')}`);
      console.log(`     👤 Authors: ${createdBook.authors.join(', ')}`);
      
      successCount++;
      
      // Generate AI summary for the newly added book
      const summaryResult = await generateSummaryForBook(createdBook.id, createdBook.title);
      if (summaryResult.success) {
        summarySuccessCount++;
        
        // Also generate extended summary using cheaper model
        console.log(`    📖 Generating extended summary...`);
        try {
          const extendedSummary = await openai.generateExtendedSummary(
            createdBook.title,
            createdBook.authors,
            createdBook.description || '',
            createdBook.categories
          );
          
          // Update the summary with extended summary
          const { error: updateError } = await supabase
            .from('summaries')
            .update({ extended_summary: extendedSummary })
            .eq('book_id', createdBook.id);
          
          if (updateError) {
            console.log(`    ⚠️  Extended summary save failed: ${updateError.message}`);
          } else {
            const wordCount = extendedSummary.split(/\s+/).length;
            console.log(`    ✅ Extended summary generated (~${wordCount} words)`);
          }
        } catch (error) {
          console.log(`    ⚠️  Extended summary generation failed: ${error.message}`);
        }
      } else {
        summaryFailCount++;
        console.log(`     ⚠️  Summary generation failed: ${summaryResult.error}`);
      }
      
      // Add delay to respect both Google Books and OpenAI API rate limits
      await new Promise(resolve => setTimeout(resolve, 2000));
      
    } catch (error) {
      console.error(`  ❌ Error processing "${bookInfo.title}":`, error.message);
      failCount++;
    }
    
    // Add extra space between books for readability
    console.log('');
  }
  
  console.log('═══════════════════════════════════════');
  console.log('📊 POPULATION SUMMARY');
  console.log('═══════════════════════════════════════');
  console.log(`✅ Books successfully added: ${successCount}`);
  console.log(`📋 Duplicates skipped: ${duplicateCount}`);
  console.log(`❌ Books failed to add: ${failCount}`);
  console.log(`🤖 AI summaries generated: ${summarySuccessCount}`);
  console.log(`⚠️  AI summary failures: ${summaryFailCount}`);
  console.log(`📝 Total processed: ${successCount + duplicateCount + failCount}/${POPULAR_NONFICTION_BOOKS.length}`);
  console.log('═══════════════════════════════════════\n');
  
  return {
    booksSuccess: successCount,
    duplicates: duplicateCount,
    booksFailures: failCount,
    summarySuccess: summarySuccessCount,
    summaryFailures: summaryFailCount,
    total: POPULAR_NONFICTION_BOOKS.length
  };
}

// Run the script
if (require.main === module) {
  populateNonfictionBooks()
    .then((results) => {
      if (results.booksSuccess > 0) {
        console.log('🎉 Non-fiction books population completed successfully!');
        if (results.summarySuccess > 0) {
          console.log(`🤖 Generated ${results.summarySuccess} AI summaries!`);
        }
      } else {
        console.log('⚠️ No books were added. Check the logs above for details.');
      }
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n💥 Fatal error during population:', error);
      process.exit(1);
    });
}

export { populateNonfictionBooks, checkForDuplicates };