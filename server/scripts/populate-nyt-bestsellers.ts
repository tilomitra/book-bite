#!/usr/bin/env npx tsx

import axios from 'axios';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { BookService } from '../src/services/bookService';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { OpenAIService } from '../src/services/openAIService';
import { supabase } from '../src/config/supabase';
import chalk from 'chalk';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
dotenv.config({ path: path.join(__dirname, '..', '.env') });

// NYT API configuration
const NYT_API_KEY = process.env.NYT_API_KEY;
const NYT_BASE_URL = 'https://api.nytimes.com/svc/books/v3';

// Non-fiction bestseller lists
const NONFICTION_LISTS = [
  'hardcover-nonfiction',
  'paperback-nonfiction',
  'combined-print-and-e-book-nonfiction',
  'advice-how-to-and-miscellaneous',
  'business-books',
  'science',
  'sports',
  'travel',
  'health',
  'politics',
  'education',
  'food-and-fitness',
  'culture',
  'religion-spirituality-and-faith',
  'biography',
  'social-science'
];

interface NYTBook {
  rank: number;
  rank_last_week: number;
  weeks_on_list: number;
  primary_isbn13: string;
  primary_isbn10: string;
  title: string;
  author: string;
  description: string;
  book_image: string;
  amazon_product_url: string;
}

interface NYTListResponse {
  status: string;
  results: {
    list_name: string;
    list_name_encoded: string;
    bestsellers_date: string;
    published_date: string;
    display_name: string;
    books: NYTBook[];
  };
}

class NYTBestsellerPopulator {
  private bookService: BookService;
  private googleBooksService: GoogleBooksService;
  private openAIService: OpenAIService;
  private processedISBNs: Set<string> = new Set();
  private stats = {
    totalProcessed: 0,
    newBooks: 0,
    duplicates: 0,
    errors: 0,
    skipped: 0
  };

  constructor() {
    this.bookService = new BookService();
    this.googleBooksService = new GoogleBooksService();
    this.openAIService = new OpenAIService();
  }

  async fetchNYTList(listName: string): Promise<NYTBook[]> {
    if (!NYT_API_KEY) {
      throw new Error('NYT_API_KEY environment variable is not set');
    }

    try {
      console.log(chalk.blue(`📚 Fetching NYT ${listName} list...`));
      
      const response = await axios.get<NYTListResponse>(
        `${NYT_BASE_URL}/lists/current/${listName}.json`,
        {
          params: {
            'api-key': NYT_API_KEY
          }
        }
      );

      if (response.data.status === 'OK' && response.data.results?.books) {
        const books = response.data.results.books;
        console.log(chalk.green(`✅ Found ${books.length} books in ${listName}`));
        return books;
      }

      return [];
    } catch (error) {
      if (axios.isAxiosError(error)) {
        if (error.response?.status === 429) {
          console.log(chalk.yellow('⏳ Rate limit hit, waiting 12 seconds...'));
          await new Promise(resolve => setTimeout(resolve, 12000));
          return this.fetchNYTList(listName); // Retry
        }
        console.error(chalk.red(`❌ Error fetching ${listName}:`, error.response?.data || error.message));
      }
      return [];
    }
  }

  async processBook(nytBook: NYTBook, listName: string): Promise<void> {
    const isbn = nytBook.primary_isbn13 || nytBook.primary_isbn10;
    
    if (!isbn) {
      console.log(chalk.yellow(`⚠️ Skipping book without ISBN: ${nytBook.title}`));
      this.stats.skipped++;
      return;
    }

    // Check if we've already processed this ISBN
    if (this.processedISBNs.has(isbn)) {
      console.log(chalk.gray(`↩️ Already processed: ${nytBook.title}`));
      this.stats.duplicates++;
      return;
    }

    try {
      // Check if book already exists in database
      const { data: existingBook } = await supabase
        .from('books')
        .select('id')
        .eq('isbn', isbn)
        .single();

      if (existingBook) {
        console.log(chalk.gray(`📖 Book already in database: ${nytBook.title}`));
        this.processedISBNs.add(isbn);
        this.stats.duplicates++;
        return;
      }

      console.log(chalk.cyan(`\n📘 Processing: ${nytBook.title} by ${nytBook.author}`));
      console.log(chalk.gray(`   ISBN: ${isbn}`));
      console.log(chalk.gray(`   Rank: #${nytBook.rank} | Weeks on list: ${nytBook.weeks_on_list}`));

      // Fetch detailed info from Google Books
      const googleBookInfo = await this.googleBooksService.getBookByISBN(isbn);
      
      if (!googleBookInfo) {
        console.log(chalk.yellow(`⚠️ No Google Books data found for ISBN ${isbn}`));
        this.stats.skipped++;
        return;
      }

      // Map NYT category to our categories
      const category = this.mapNYTListToCategory(listName);

      // Ensure authors is always an array
      const authors = googleBookInfo.authors || [nytBook.author];

      // Create book object with NYT bestseller data
      const bookData = {
        ...googleBookInfo,
        authors: Array.isArray(authors) ? authors : [authors].filter(Boolean),
        categories: googleBookInfo.categories || [category],
        is_nyt_bestseller: true,
        nyt_rank: nytBook.rank,
        nyt_weeks_on_list: nytBook.weeks_on_list,
        nyt_list: listName,
        nyt_last_updated: new Date(),
        // Use NYT image if Google Books doesn't have one
        cover_url: googleBookInfo.cover_url || nytBook.book_image || ''
      };

      // Save book to database first
      const savedBook = await this.bookService.createBook(bookData);

      if (savedBook) {
        console.log(chalk.green(`✅ Saved: ${bookData.title}`));
        this.processedISBNs.add(isbn);
        this.stats.newBooks++;

        // Generate AI summaries
        console.log(chalk.blue('🤖 Generating AI summaries...'));
        try {
          const summaryData = await this.openAIService.generateBookSummary(
            savedBook.title,
            savedBook.authors,
            savedBook.description || '',
            savedBook.categories || [],
            'full'
          );

          // Save summary to database
          const { error: summaryError } = await supabase
            .from('summaries')
            .insert({
              book_id: savedBook.id,
              ...summaryData
            });

          if (summaryError) {
            console.log(chalk.yellow(`⚠️ Summary save failed: ${summaryError.message}`));
          } else {
            console.log(chalk.green('✅ AI summary generated and saved'));

            // Generate extended summary
            console.log(chalk.blue('📖 Generating extended summary...'));
            const extendedSummary = await this.openAIService.generateExtendedSummary(
              savedBook.title,
              savedBook.authors,
              savedBook.description || '',
              savedBook.categories || []
            );

            // Update summary with extended summary
            const { error: updateError } = await supabase
              .from('summaries')
              .update({ extended_summary: extendedSummary })
              .eq('book_id', savedBook.id);

            if (updateError) {
              console.log(chalk.yellow(`⚠️ Extended summary save failed: ${updateError.message}`));
            } else {
              const wordCount = extendedSummary.split(/\s+/).length;
              console.log(chalk.green(`✅ Extended summary generated (~${wordCount} words)`));
            }
          }
        } catch (summaryError) {
          console.log(chalk.yellow(`⚠️ Failed to generate summaries: ${summaryError}`));
        }
      }

      this.stats.totalProcessed++;

      // Rate limiting: wait between books
      await new Promise(resolve => setTimeout(resolve, 2000));

    } catch (error) {
      console.error(chalk.red(`❌ Error processing ${nytBook.title}:`, error));
      this.stats.errors++;
    }
  }

  mapNYTListToCategory(listName: string): string {
    const categoryMap: Record<string, string> = {
      'hardcover-nonfiction': 'Non-Fiction',
      'paperback-nonfiction': 'Non-Fiction',
      'combined-print-and-e-book-nonfiction': 'Non-Fiction',
      'advice-how-to-and-miscellaneous': 'Self-Help',
      'business-books': 'Business',
      'science': 'Science',
      'sports': 'Sports',
      'travel': 'Travel',
      'health': 'Health',
      'politics': 'Politics',
      'education': 'Education',
      'food-and-fitness': 'Health',
      'culture': 'Culture',
      'religion-spirituality-and-faith': 'Religion',
      'biography': 'Biography',
      'social-science': 'Psychology'
    };

    return categoryMap[listName] || 'Non-Fiction';
  }

  async run(specificLists?: string[]): Promise<void> {
    console.log(chalk.bold.blue('\n📚 NYT Bestsellers Non-Fiction Book Populator\n'));
    
    if (!NYT_API_KEY) {
      console.error(chalk.red('❌ NYT_API_KEY environment variable is not set'));
      console.log(chalk.yellow('Please add NYT_API_KEY to your .env file'));
      console.log(chalk.yellow('Get your API key at: https://developer.nytimes.com'));
      process.exit(1);
    }

    const listsToProcess = specificLists || NONFICTION_LISTS;
    
    console.log(chalk.cyan(`Processing ${listsToProcess.length} non-fiction lists:`));
    listsToProcess.forEach(list => console.log(chalk.gray(`  • ${list}`)));
    console.log();

    for (const listName of listsToProcess) {
      console.log(chalk.bold.blue(`\n📑 Processing list: ${listName}`));
      console.log(chalk.gray('─'.repeat(50)));
      
      const books = await this.fetchNYTList(listName);
      
      for (const book of books) {
        await this.processBook(book, listName);
      }

      // Rate limiting between lists
      if (listsToProcess.indexOf(listName) < listsToProcess.length - 1) {
        console.log(chalk.yellow('\n⏳ Waiting before next list...'));
        await new Promise(resolve => setTimeout(resolve, 6000));
      }
    }

    // Print final statistics
    console.log(chalk.bold.green('\n\n📊 Final Statistics:'));
    console.log(chalk.gray('═'.repeat(50)));
    console.log(chalk.white(`📚 Total Processed: ${this.stats.totalProcessed}`));
    console.log(chalk.green(`✅ New Books Added: ${this.stats.newBooks}`));
    console.log(chalk.yellow(`↩️ Duplicates Skipped: ${this.stats.duplicates}`));
    console.log(chalk.gray(`⏭️ Books Skipped: ${this.stats.skipped}`));
    console.log(chalk.red(`❌ Errors: ${this.stats.errors}`));
    console.log(chalk.gray('═'.repeat(50)));
  }
}

// Main execution
(async () => {
  const populator = new NYTBestsellerPopulator();
  
  // Check command line arguments
  const args = process.argv.slice(2);
  let listsToProcess: string[] | undefined;
  
  if (args.length > 0) {
    if (args[0] === '--list' && args[1]) {
      // Process specific list
      listsToProcess = [args[1]];
    } else if (args[0] === '--priority') {
      // Process only high-priority lists
      listsToProcess = [
        'combined-print-and-e-book-nonfiction',
        'hardcover-nonfiction',
        'business-books',
        'science',
        'biography'
      ];
    } else if (args[0] === '--help') {
      console.log(chalk.bold('Usage:'));
      console.log('  npx tsx scripts/populate-nyt-bestsellers.ts          # Process all non-fiction lists');
      console.log('  npx tsx scripts/populate-nyt-bestsellers.ts --priority  # Process priority lists only');
      console.log('  npx tsx scripts/populate-nyt-bestsellers.ts --list business-books  # Process specific list');
      console.log('\nAvailable lists:', NONFICTION_LISTS.join(', '));
      process.exit(0);
    }
  }
  
  try {
    await populator.run(listsToProcess);
    console.log(chalk.bold.green('\n✨ NYT Bestseller population completed!'));
  } catch (error) {
    console.error(chalk.red('Fatal error:', error));
    process.exit(1);
  }
})();