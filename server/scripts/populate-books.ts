#!/usr/bin/env npx tsx

import { config } from 'dotenv';
import axios from 'axios';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { BookService } from '../src/services/bookService';
import { OpenAIService } from '../src/services/openaiService';
import { supabase } from '../src/config/supabase';
import chalk from 'chalk';

// Load environment variables
config();

// NYT API configuration
const NYT_API_KEY = process.env.NYT_API_KEY;
const NYT_BASE_URL = 'https://api.nytimes.com/svc/books/v3';

// Non-fiction bestseller lists for NYT
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

// Comprehensive categories for Google Books discovery
const BOOK_CATEGORIES = [
  // Personal Development & Psychology  
  { name: 'Self-Help', query: 'subject:self-help', priority: 'high', source: 'google' },
  { name: 'Psychology', query: 'subject:psychology', priority: 'high', source: 'google' },
  { name: 'Personal Development', query: 'personal development', priority: 'high', source: 'google' },
  { name: 'Productivity', query: 'productivity habits', priority: 'medium', source: 'google' },
  { name: 'Mindfulness', query: 'mindfulness meditation', priority: 'medium', source: 'google' },
  
  // Business & Economics
  { name: 'Business', query: 'subject:business', priority: 'high', source: 'google' },
  { name: 'Entrepreneurship', query: 'entrepreneurship startup', priority: 'high', source: 'google' },
  { name: 'Economics', query: 'subject:economics', priority: 'medium', source: 'google' },
  { name: 'Leadership', query: 'leadership management', priority: 'high', source: 'google' },
  { name: 'Innovation', query: 'innovation disruption', priority: 'medium', source: 'google' },
  { name: 'Marketing', query: 'marketing advertising', priority: 'medium', source: 'google' },
  
  // Science & Technology
  { name: 'Science', query: 'subject:science', priority: 'high', source: 'google' },
  { name: 'Technology', query: 'technology future', priority: 'high', source: 'google' },
  { name: 'Biology', query: 'subject:biology', priority: 'medium', source: 'google' },
  { name: 'Physics', query: 'subject:physics', priority: 'medium', source: 'google' },
  { name: 'Medicine', query: 'subject:medicine', priority: 'medium', source: 'google' },
  { name: 'Environment', query: 'environment climate', priority: 'medium', source: 'google' },
  
  // History & Biography
  { name: 'History', query: 'subject:history', priority: 'high', source: 'google' },
  { name: 'Biography', query: 'subject:biography', priority: 'high', source: 'google' },
  { name: 'Memoir', query: 'memoir autobiography', priority: 'high', source: 'google' },
  { name: 'World War', query: 'world war history', priority: 'medium', source: 'google' },
  { name: 'American History', query: 'american history', priority: 'medium', source: 'google' },
  
  // Health & Wellness
  { name: 'Health', query: 'subject:health', priority: 'high', source: 'google' },
  { name: 'Nutrition', query: 'nutrition diet food', priority: 'medium', source: 'google' },
  { name: 'Fitness', query: 'fitness exercise', priority: 'medium', source: 'google' },
  { name: 'Mental Health', query: 'mental health therapy', priority: 'high', source: 'google' },
  
  // Philosophy & Religion
  { name: 'Philosophy', query: 'subject:philosophy', priority: 'medium', source: 'google' },
  { name: 'Religion', query: 'subject:religion', priority: 'medium', source: 'google' },
  { name: 'Spirituality', query: 'spirituality consciousness', priority: 'medium', source: 'google' },
  
  // Social Sciences
  { name: 'Sociology', query: 'subject:sociology', priority: 'medium', source: 'google' },
  { name: 'Politics', query: 'subject:politics', priority: 'medium', source: 'google' },
  { name: 'Anthropology', query: 'subject:anthropology', priority: 'medium', source: 'google' },
  { name: 'Education', query: 'subject:education', priority: 'medium', source: 'google' },
  
  // Arts & Culture
  { name: 'Art', query: 'subject:art', priority: 'low', source: 'google' },
  { name: 'Music', query: 'subject:music', priority: 'low', source: 'google' },
  { name: 'Travel', query: 'subject:travel', priority: 'low', source: 'google' },
  { name: 'Cooking', query: 'cooking recipes', priority: 'low', source: 'google' }
];

// Add NYT lists as "categories"
NONFICTION_LISTS.forEach(listName => {
  BOOK_CATEGORIES.push({
    name: `NYT ${listName.replace(/-/g, ' ')}`,
    query: listName,
    priority: 'high',
    source: 'nyt'
  });
});

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

interface PopulationStats {
  totalCategories: number;
  processedCategories: number;
  totalBooksAttempted: number;
  totalBooksAdded: number;
  totalDuplicates: number;
  totalFailures: number;
  totalSummariesGenerated: number;
  totalSummaryFailures: number;
  categoryStats: Array<{
    name: string;
    attempted: number;
    added: number;
    duplicates: number;
    failures: number;
    summariesGenerated: number;
    summaryFailures: number;
  }>;
}

class BookPopulator {
  private googleBooksService: GoogleBooksService;
  private bookService: BookService;
  private openAIService: OpenAIService;
  private processedISBNs: Set<string> = new Set();
  private processedGoogleIds: Set<string> = new Set();

  constructor() {
    this.googleBooksService = new GoogleBooksService();
    this.bookService = new BookService();
    this.openAIService = new OpenAIService();
  }

  async checkForDuplicates(bookData: any): Promise<boolean> {
    try {
      // Check by Google Books ID first
      if (bookData.google_books_id) {
        const { data } = await supabase
          .from('books')
          .select('id')
          .eq('google_books_id', bookData.google_books_id)
          .single();
        
        if (data) return true;
      }

      // Check by ISBN13
      if (bookData.isbn13) {
        const { data } = await supabase
          .from('books')
          .select('id')
          .eq('isbn13', bookData.isbn13)
          .single();
        
        if (data) return true;
      }

      // Check by title and author combination
      if (bookData.title && bookData.authors && bookData.authors.length > 0) {
        const { data } = await supabase
          .from('books')
          .select('id')
          .eq('title', bookData.title)
          .contains('authors', [bookData.authors[0]])
          .single();
        
        if (data) return true;
      }

      return false;
    } catch (error) {
      return false;
    }
  }

  async fetchNYTList(listName: string): Promise<NYTBook[]> {
    if (!NYT_API_KEY) {
      console.warn(chalk.yellow('NYT_API_KEY not set, skipping NYT lists'));
      return [];
    }

    try {
      console.log(chalk.blue(`📚 Fetching NYT ${listName} list...`));
      
      const response = await axios.get<NYTListResponse>(
        `${NYT_BASE_URL}/lists/current/${listName}.json`,
        {
          params: { 'api-key': NYT_API_KEY },
          timeout: 10000
        }
      );

      if (response.data.status === 'OK') {
        console.log(chalk.green(`✅ Found ${response.data.results.books.length} books in ${listName}`));
        return response.data.results.books;
      } else {
        console.error(chalk.red(`❌ NYT API error for ${listName}: ${response.data.status}`));
        return [];
      }
    } catch (error) {
      console.error(chalk.red(`❌ Failed to fetch NYT list ${listName}:`, error instanceof Error ? error.message : error));
      return [];
    }
  }

  async processNYTCategory(categoryName: string, listName: string, maxBooks: number): Promise<any> {
    const stats = {
      name: categoryName,
      attempted: 0,
      added: 0,
      duplicates: 0,
      failures: 0,
      summariesGenerated: 0,
      summaryFailures: 0
    };

    try {
      const nytBooks = await this.fetchNYTList(listName);
      const booksToProcess = nytBooks.slice(0, maxBooks);

      for (const nytBook of booksToProcess) {
        stats.attempted++;
        
        // Skip if we've already processed this ISBN
        if (nytBook.primary_isbn13 && this.processedISBNs.has(nytBook.primary_isbn13)) {
          stats.duplicates++;
          continue;
        }

        try {
          // Enrich with Google Books data
          let googleBook = null;
          if (nytBook.primary_isbn13) {
            googleBook = await this.googleBooksService.searchByISBN(nytBook.primary_isbn13);
          }
          
          if (!googleBook && nytBook.title && nytBook.author) {
            const searchResults = await this.googleBooksService.searchBooks(`${nytBook.title} ${nytBook.author}`, 1);
            googleBook = searchResults.length > 0 ? searchResults[0] : null;
          }

          let bookData;
          if (googleBook) {
            bookData = await this.googleBooksService.extractBookData(googleBook);
            bookData.source_attribution = ['NYT Bestseller', 'Google Books'];
          } else {
            // Create from NYT data only
            bookData = {
              title: nytBook.title,
              authors: [nytBook.author],
              isbn13: nytBook.primary_isbn13,
              isbn10: nytBook.primary_isbn10,
              description: nytBook.description,
              cover_url: nytBook.book_image,
              categories: [categoryName.replace('NYT ', '')],
              source_attribution: ['NYT Bestseller']
            };
          }

          // Add NYT-specific metadata
          bookData.popularity_rank = nytBook.rank;
          bookData.is_featured = nytBook.rank <= 10;

          // Check for duplicates
          const isDuplicate = await this.checkForDuplicates(bookData);
          if (isDuplicate) {
            stats.duplicates++;
            console.log(chalk.yellow(`  📋 Duplicate: ${bookData.title}`));
            continue;
          }

          // Save book
          const { data: savedBook, error } = await supabase
            .from('books')
            .insert(bookData)
            .select()
            .single();

          if (error) {
            stats.failures++;
            console.error(chalk.red(`  ❌ Failed to save ${bookData.title}: ${error.message}`));
            continue;
          }

          stats.added++;
          this.processedISBNs.add(nytBook.primary_isbn13);
          
          console.log(chalk.green(`  ✅ Added: ${bookData.title} (Rank #${nytBook.rank})`));

          // Generate summaries
          await this.generateSummariesForBook(savedBook, stats);

          // Rate limiting
          await new Promise(resolve => setTimeout(resolve, 1000));

        } catch (error) {
          stats.failures++;
          console.error(chalk.red(`  ❌ Error processing NYT book: ${error instanceof Error ? error.message : error}`));
        }
      }
    } catch (error) {
      console.error(chalk.red(`❌ Error processing NYT category ${categoryName}: ${error instanceof Error ? error.message : error}`));
    }

    return stats;
  }

  async processGoogleCategory(categoryName: string, query: string, maxBooks: number): Promise<any> {
    const stats = {
      name: categoryName,
      attempted: 0,
      added: 0,
      duplicates: 0,
      failures: 0,
      summariesGenerated: 0,
      summaryFailures: 0
    };

    try {
      console.log(chalk.blue(`📚 Searching Google Books for category: ${categoryName}`));
      console.log(chalk.gray(`   Query: "${query}"`));

      const books = await this.googleBooksService.searchBooks(query, Math.min(maxBooks * 2, 40)); // Google Books API max is 40 results
      const booksToProcess = books.slice(0, maxBooks);

      for (const book of booksToProcess) {
        stats.attempted++;

        // Skip if we've already processed this Google Books ID
        if (book.id && this.processedGoogleIds.has(book.id)) {
          stats.duplicates++;
          continue;
        }

        try {
          const bookData = await this.googleBooksService.extractBookData(book);
          bookData.source_attribution = ['Google Books'];
          
          // Ensure the category is included
          if (!bookData.categories.includes(categoryName)) {
            bookData.categories.unshift(categoryName);
          }

          // Check for duplicates
          const isDuplicate = await this.checkForDuplicates(bookData);
          if (isDuplicate) {
            stats.duplicates++;
            console.log(chalk.yellow(`  📋 Duplicate: ${bookData.title}`));
            continue;
          }

          // Save book
          const { data: savedBook, error } = await supabase
            .from('books')
            .insert(bookData)
            .select()
            .single();

          if (error) {
            stats.failures++;
            console.error(chalk.red(`  ❌ Failed to save ${bookData.title}: ${error.message}`));
            continue;
          }

          stats.added++;
          this.processedGoogleIds.add(book.id);
          
          console.log(chalk.green(`  ✅ Added: ${bookData.title} by ${bookData.authors.join(', ')}`));

          // Generate summaries
          await this.generateSummariesForBook(savedBook, stats);

          // Rate limiting
          await new Promise(resolve => setTimeout(resolve, 1000));

        } catch (error) {
          stats.failures++;
          console.error(chalk.red(`  ❌ Error processing book: ${error instanceof Error ? error.message : error}`));
        }
      }
    } catch (error) {
      console.error(chalk.red(`❌ Error processing Google category ${categoryName}: ${error instanceof Error ? error.message : error}`));
    }

    return stats;
  }

  async generateSummariesForBook(book: any, stats: any): Promise<void> {
    try {
      console.log(chalk.cyan(`    🤖 Generating summaries for: ${book.title}`));

      // Generate regular summary
      const summaryData = await this.openAIService.generateBookSummary(
        book.title,
        book.authors || [],
        book.description || '',
        book.categories || [],
        'full'
      );

      // Save regular summary
      const { data: savedSummary, error: summaryError } = await supabase
        .from('summaries')
        .insert({
          book_id: book.id,
          ...summaryData
        })
        .select('id')
        .single();

      if (summaryError) {
        stats.summaryFailures++;
        console.error(chalk.red(`    ❌ Regular summary failed: ${summaryError.message}`));
        return;
      }

      console.log(chalk.green(`    ✅ Regular summary generated`));

      // Wait before generating extended summary
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Generate extended summary
      console.log(chalk.cyan(`    📖 Generating extended summary...`));
      const extendedSummary = await this.openAIService.generateExtendedSummary(
        book.title,
        book.authors || [],
        book.description || '',
        book.categories || []
      );

      // Update with extended summary
      const { error: extendedError } = await supabase
        .from('summaries')
        .update({ extended_summary: extendedSummary })
        .eq('id', savedSummary.id);

      if (extendedError) {
        console.error(chalk.red(`    ⚠️  Extended summary failed: ${extendedError.message}`));
      } else {
        console.log(chalk.green(`    ✅ Extended summary generated`));
      }

      stats.summariesGenerated++;

    } catch (error) {
      stats.summaryFailures++;
      console.error(chalk.red(`    ❌ Summary generation failed: ${error instanceof Error ? error.message : error}`));
    }
  }
}

async function populateBooks(options: {
  booksPerCategory?: number;
  priority?: 'high' | 'medium' | 'low' | 'all';
  source?: 'google' | 'nyt' | 'all';
  maxCategories?: number;
} = {}): Promise<PopulationStats> {
  const {
    booksPerCategory = 25,
    priority = 'all',
    source = 'all',
    maxCategories = 100
  } = options;

  console.log(chalk.bold.blue('🚀 Starting comprehensive book population...'));
  console.log(chalk.gray(`📊 Books per category: ${booksPerCategory}`));
  console.log(chalk.gray(`🎯 Priority filter: ${priority}`));
  console.log(chalk.gray(`📚 Source filter: ${source}`));
  console.log(chalk.gray(`📂 Max categories: ${maxCategories}`));
  console.log('');

  const populator = new BookPopulator();
  const stats: PopulationStats = {
    totalCategories: 0,
    processedCategories: 0,
    totalBooksAttempted: 0,
    totalBooksAdded: 0,
    totalDuplicates: 0,
    totalFailures: 0,
    totalSummariesGenerated: 0,
    totalSummaryFailures: 0,
    categoryStats: []
  };

  // Filter categories based on options
  let categoriesToProcess = BOOK_CATEGORIES.filter(cat => {
    if (priority !== 'all' && cat.priority !== priority) return false;
    if (source !== 'all' && cat.source !== source) return false;
    return true;
  });

  categoriesToProcess = categoriesToProcess.slice(0, maxCategories);
  stats.totalCategories = categoriesToProcess.length;

  console.log(chalk.blue(`📂 Processing ${stats.totalCategories} categories...`));
  console.log('');

  for (const category of categoriesToProcess) {
    console.log(chalk.bold.cyan(`\n📂 Processing: ${category.name} (${category.source}, ${category.priority} priority)`));
    console.log('─'.repeat(60));

    let categoryStats;
    
    if (category.source === 'nyt') {
      categoryStats = await populator.processNYTCategory(category.name, category.query, booksPerCategory);
    } else {
      categoryStats = await populator.processGoogleCategory(category.name, category.query, booksPerCategory);
    }

    // Update overall stats
    stats.processedCategories++;
    stats.totalBooksAttempted += categoryStats.attempted;
    stats.totalBooksAdded += categoryStats.added;
    stats.totalDuplicates += categoryStats.duplicates;
    stats.totalFailures += categoryStats.failures;
    stats.totalSummariesGenerated += categoryStats.summariesGenerated;
    stats.totalSummaryFailures += categoryStats.summaryFailures;
    stats.categoryStats.push(categoryStats);

    console.log(chalk.blue(`📊 Category summary: ${categoryStats.added} added, ${categoryStats.duplicates} duplicates, ${categoryStats.failures} failures`));
    
    // Rate limiting between categories
    if (stats.processedCategories < stats.totalCategories) {
      console.log(chalk.gray('⏸️  Waiting 3 seconds before next category...'));
      await new Promise(resolve => setTimeout(resolve, 3000));
    }
  }

  // Generate final report
  console.log('\n' + '═'.repeat(80));
  console.log(chalk.bold.green('📊 BOOK POPULATION REPORT'));
  console.log('═'.repeat(80));
  console.log(chalk.white(`📂 Categories processed: ${stats.processedCategories}/${stats.totalCategories}`));
  console.log(chalk.white(`📚 Books attempted: ${stats.totalBooksAttempted}`));
  console.log(chalk.green(`✅ Books added: ${stats.totalBooksAdded}`));
  console.log(chalk.yellow(`📋 Duplicates skipped: ${stats.totalDuplicates}`));
  console.log(chalk.red(`❌ Failures: ${stats.totalFailures}`));
  console.log(chalk.blue(`🤖 Summaries generated: ${stats.totalSummariesGenerated}`));
  console.log(chalk.red(`🤖 Summary failures: ${stats.totalSummaryFailures}`));

  // Show top performing categories
  const sortedStats = stats.categoryStats
    .filter(cat => cat.added > 0)
    .sort((a, b) => b.added - a.added)
    .slice(0, 10);

  if (sortedStats.length > 0) {
    console.log('\n📈 Top Categories by Books Added:');
    console.log('─'.repeat(40));
    sortedStats.forEach((cat, index) => {
      console.log(chalk.white(`${index + 1}. ${cat.name}: ${cat.added} books`));
    });
  }

  console.log('═'.repeat(80));
  console.log(chalk.bold.green('🎉 Book population completed!'));

  return stats;
}

// CLI interface
if (require.main === module) {
  const booksPerCategoryArg = process.argv[2];
  const priorityArg = process.argv[3] as 'high' | 'medium' | 'low' | 'all';
  const sourceArg = process.argv[4] as 'google' | 'nyt' | 'all';

  const options = {
    booksPerCategory: booksPerCategoryArg ? parseInt(booksPerCategoryArg) : 25,
    priority: priorityArg || 'all',
    source: sourceArg || 'all',
    maxCategories: 100
  };

  // Validate arguments
  if (isNaN(options.booksPerCategory) || options.booksPerCategory < 1) {
    console.error(chalk.red('❌ Invalid books per category. Must be a positive number.'));
    console.log('Usage: tsx scripts/populate-books.ts [booksPerCategory] [priority] [source]');
    console.log('Example: tsx scripts/populate-books.ts 20 high google');
    console.log('Priority: high, medium, low, all (default: all)');
    console.log('Source: google, nyt, all (default: all)');
    process.exit(1);
  }

  populateBooks(options)
    .then((stats) => {
      process.exit(stats.totalFailures > 0 ? 1 : 0);
    })
    .catch((error) => {
      console.error(chalk.red('\n💥 Fatal error during book population:', error));
      process.exit(1);
    });
}

export { populateBooks };