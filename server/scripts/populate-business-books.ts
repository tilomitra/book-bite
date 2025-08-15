#!/usr/bin/env ts-node

import { config } from 'dotenv';
import path from 'path';
import { supabase } from '../src/config/supabase';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { BookService } from '../src/services/bookService';

// Load environment variables
config({ path: path.join(__dirname, '../.env') });

// Top business/self-development books that are great for summaries
const FEATURED_BUSINESS_BOOKS = [
  { title: "Atomic Habits", author: "James Clear", isbn: "9780735211292" },
  { title: "Start With Why", author: "Simon Sinek", isbn: "9781591846482" },
  { title: "Mindset", author: "Carol Dweck", isbn: "9780399563829" },
  { title: "Sapiens", author: "Yuval Noah Harari", isbn: "9780062316097" },
  { title: "Thinking, Fast and Slow", author: "Daniel Kahneman", isbn: "9780143110422" },
  { title: "The 7 Habits of Highly Effective People", author: "Stephen Covey", isbn: "9780743269513" },
  { title: "Deep Work", author: "Cal Newport", isbn: "9781501144318" },
  { title: "Getting Things Done", author: "David Allen", isbn: "9780142000281" },
  { title: "Good to Great", author: "Jim Collins", isbn: "9780066620992" },
  { title: "Influence", author: "Robert Cialdini", isbn: "9780547928227" },
  { title: "Range", author: "David Epstein", isbn: "9780735219090" },
  { title: "The Subtle Art of Not Giving a F*ck", author: "Mark Manson", isbn: "9780062457714" },
  { title: "Drive", author: "Daniel H. Pink", isbn: "9781594484803" },
  { title: "Option B", author: "Sheryl Sandberg", isbn: "9780062515483" },
  { title: "The Lean Startup", author: "Eric Ries", isbn: "9780307887894" },
  { title: "The Hard Thing About Hard Things", author: "Ben Horowitz", isbn: "9780062273208" },
  { title: "Zero to One", author: "Peter Thiel", isbn: "9780804139298" },
  { title: "Principles", author: "Ray Dalio", isbn: "9781501124020" },
  { title: "The Culture Code", author: "Daniel Coyle", isbn: "9780525492733" },
  { title: "Radical Candor", author: "Kim Scott", isbn: "9781250103505" },
];

interface BookImportResult {
  bookInfo: typeof FEATURED_BUSINESS_BOOKS[0];
  success: boolean;
  bookId?: string;
  title?: string;
  error?: string;
}

async function importBookFromData(bookInfo: typeof FEATURED_BUSINESS_BOOKS[0], rank: number): Promise<BookImportResult> {
  const googleBooks = new GoogleBooksService();
  const bookService = new BookService();
  
  try {
    console.log(`🔍 Processing ${rank}/${FEATURED_BUSINESS_BOOKS.length}: ${bookInfo.title} by ${bookInfo.author}`);
    
    // Check if book already exists
    const { data: existingBook } = await supabase
      .from('books')
      .select('id, title, is_featured')
      .or(`isbn10.eq.${bookInfo.isbn},isbn13.eq.${bookInfo.isbn}`)
      .single();

    if (existingBook) {
      // Update existing book to be featured if not already
      if (!existingBook.is_featured) {
        await supabase
          .from('books')
          .update({ is_featured: true, popularity_rank: rank })
          .eq('id', existingBook.id);
        console.log(`📚 Updated existing book to featured: ${existingBook.title}`);
      } else {
        console.log(`📚 Book already featured: ${existingBook.title}`);
      }
      
      return {
        bookInfo,
        success: true,
        bookId: existingBook.id,
        title: existingBook.title
      };
    }

    // Try to fetch from Google Books using ISBN first
    let googleBook = await googleBooks.getBookByISBN(bookInfo.isbn);
    
    // If not found by ISBN, try searching by title and author
    if (!googleBook) {
      console.log(`  📖 ISBN search failed, trying title/author search...`);
      const searchResults = await googleBooks.searchBooks(`${bookInfo.title} ${bookInfo.author}`, 3);
      if (searchResults.length > 0) {
        // Find the best match by title similarity
        googleBook = searchResults.find(book => 
          book.title?.toLowerCase().includes(bookInfo.title.toLowerCase()) ||
          bookInfo.title.toLowerCase().includes(book.title?.toLowerCase() || '')
        ) || searchResults[0];
      }
    }
    
    if (!googleBook) {
      console.log(`  ❌ Could not find book: ${bookInfo.title}`);
      return { bookInfo, success: false, error: 'Book not found' };
    }

    console.log(`📖 Found: ${googleBook.title} by ${googleBook.authors?.join(', ')}`);

    // Create book in database with featured flag and popularity rank
    const bookToCreate = {
      ...googleBook,
      authors: googleBook.authors || [bookInfo.author],
      categories: googleBook.categories || ['Business', 'Self-Development'],
      is_featured: true,
      popularity_rank: rank
    };

    const createdBook = await bookService.createBook(bookToCreate);
    console.log(`✅ Created featured book: ${createdBook.title} (Rank: ${rank})`);
    
    return {
      bookInfo,
      success: true,
      bookId: createdBook.id,
      title: createdBook.title
    };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error(`❌ Error importing book ${bookInfo.title}:`, errorMessage);
    return { bookInfo, success: false, error: errorMessage };
  }
}

async function populateBusinessBooks() {
  console.log('🚀 Starting business books population...');
  console.log(`📚 Processing ${FEATURED_BUSINESS_BOOKS.length} featured business/self-development books\n`);
  
  const results: BookImportResult[] = [];
  
  // Import books sequentially to avoid rate limiting
  for (let i = 0; i < FEATURED_BUSINESS_BOOKS.length; i++) {
    const bookInfo = FEATURED_BUSINESS_BOOKS[i];
    const rank = i + 1;
    
    const result = await importBookFromData(bookInfo, rank);
    results.push(result);
    
    // Add small delay to be respectful to Google Books API
    await new Promise(resolve => setTimeout(resolve, 800));
  }
  
  // Summary of import results
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  
  console.log('\n📊 Import Results:');
  console.log(`✅ Successfully imported/updated: ${successful.length} books`);
  console.log(`❌ Failed imports: ${failed.length} books`);
  
  if (failed.length > 0) {
    console.log('\n❌ Failed imports:');
    failed.forEach(f => console.log(`  - ${f.bookInfo.title}: ${f.error}`));
  }
  
  if (successful.length > 0) {
    console.log('\n✅ Successfully processed books:');
    successful.forEach((s, index) => {
      console.log(`  ${index + 1}. ${s.title || s.bookInfo.title}`);
    });
  }
  
  console.log('\n🎉 Business books population completed!');
  return { successful, failed };
}

// Run the script
if (require.main === module) {
  populateBusinessBooks()
    .then(() => process.exit(0))
    .catch(error => {
      console.error('❌ Population failed:', error);
      process.exit(1);
    });
}

export { populateBusinessBooks, FEATURED_BUSINESS_BOOKS };