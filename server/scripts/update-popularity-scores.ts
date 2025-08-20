#!/usr/bin/env npx tsx

import { config } from 'dotenv';
import axios from 'axios';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { supabase } from '../src/config/supabase';
import chalk from 'chalk';

// Load environment variables
config();

const GOOGLE_BOOKS_API_BASE = 'https://www.googleapis.com/books/v1';

interface GoogleBookRatingInfo {
  averageRating?: number;
  ratingsCount?: number;
}

class PopularityScoreUpdater {
  private googleBooksService: GoogleBooksService;
  private batchSize: number;
  private delayMs: number;
  private apiCallCount: number = 0;
  private rateLimitWindow: number = 60000; // 1 minute
  private maxCallsPerWindow: number = 100; // Google Books API limit
  private lastResetTime: number = Date.now();

  constructor(batchSize: number = 2, delayMs: number = 3000) {
    this.googleBooksService = new GoogleBooksService();
    this.batchSize = batchSize;
    this.delayMs = delayMs;
  }

  async enforceRateLimit(): Promise<void> {
    const now = Date.now();
    
    // Reset counter if window has passed
    if (now - this.lastResetTime > this.rateLimitWindow) {
      this.apiCallCount = 0;
      this.lastResetTime = now;
      console.log(chalk.gray(`🔄 Rate limit window reset. API calls this window: ${this.apiCallCount}`));
    }
    
    // Check if we're approaching the limit
    if (this.apiCallCount >= this.maxCallsPerWindow) {
      const timeToWait = this.rateLimitWindow - (now - this.lastResetTime);
      console.log(chalk.yellow(`⏸️  Rate limit reached (${this.apiCallCount}/${this.maxCallsPerWindow}). Waiting ${Math.ceil(timeToWait / 1000)}s...`));
      await new Promise(resolve => setTimeout(resolve, timeToWait + 1000));
      this.apiCallCount = 0;
      this.lastResetTime = Date.now();
    }
  }

  async getBooksWithoutScores() {
    console.log(chalk.blue('📚 Fetching books without popularity scores from database...'));
    
    const { data: books, error } = await supabase
      .from('books')
      .select('id, title, authors, isbn10, isbn13, google_books_id, popularity_score')
      .or('popularity_score.is.null,popularity_score.eq.0')
      .order('created_at', { ascending: true });

    if (error) {
      throw new Error(`Failed to fetch books: ${error.message}`);
    }

    console.log(chalk.green(`✅ Found ${books?.length || 0} books without popularity scores`));
    return books || [];
  }

  async fetchRatingInfo(book: any): Promise<GoogleBookRatingInfo | null> {
    try {
      let googleBookData = null;
      
      // Enforce rate limiting before each API call
      await this.enforceRateLimit();
      
      // Try to get by Google Books ID first
      if (book.google_books_id) {
        try {
          this.apiCallCount++;
          console.log(chalk.gray(`    📡 API call ${this.apiCallCount}/${this.maxCallsPerWindow} - Fetching by Google Books ID`));
          
          const response = await axios.get(
            `${GOOGLE_BOOKS_API_BASE}/volumes/${book.google_books_id}`,
            {
              params: { key: process.env.GOOGLE_BOOKS_API_KEY },
              timeout: 10000
            }
          );
          googleBookData = response.data;
          
          // Small delay between API calls
          await new Promise(resolve => setTimeout(resolve, 500));
          
        } catch (err) {
          console.log(chalk.yellow(`⚠️  Failed to fetch by Google Books ID for "${book.title}"`));
        }
      }

      // If no Google Books ID or fetch failed, try by ISBN
      if (!googleBookData && (book.isbn13 || book.isbn10)) {
        await this.enforceRateLimit();
        
        const isbn = book.isbn13 || book.isbn10;
        try {
          this.apiCallCount++;
          console.log(chalk.gray(`    📡 API call ${this.apiCallCount}/${this.maxCallsPerWindow} - Fetching by ISBN: ${isbn}`));
          
          const response = await axios.get(`${GOOGLE_BOOKS_API_BASE}/volumes`, {
            params: {
              q: `isbn:${isbn}`,
              key: process.env.GOOGLE_BOOKS_API_KEY
            },
            timeout: 10000
          });
          
          if (response.data.items && response.data.items.length > 0) {
            googleBookData = response.data.items[0];
          }
          
          // Small delay between API calls
          await new Promise(resolve => setTimeout(resolve, 500));
          
        } catch (err) {
          console.log(chalk.yellow(`⚠️  Failed to fetch by ISBN for "${book.title}"`));
        }
      }

      // If still no data, try by title and author
      if (!googleBookData) {
        await this.enforceRateLimit();
        
        const author = Array.isArray(book.authors) ? book.authors[0] : book.authors;
        const query = `intitle:"${book.title}"${author ? ` inauthor:"${author}"` : ''}`;
        
        try {
          this.apiCallCount++;
          console.log(chalk.gray(`    📡 API call ${this.apiCallCount}/${this.maxCallsPerWindow} - Searching by title/author`));
          
          const response = await axios.get(`${GOOGLE_BOOKS_API_BASE}/volumes`, {
            params: {
              q: query,
              maxResults: 1,
              key: process.env.GOOGLE_BOOKS_API_KEY
            },
            timeout: 10000
          });
          
          if (response.data.items && response.data.items.length > 0) {
            googleBookData = response.data.items[0];
          }
          
          // Small delay between API calls
          await new Promise(resolve => setTimeout(resolve, 500));
          
        } catch (err) {
          console.log(chalk.yellow(`⚠️  Failed to search for "${book.title}"`));
        }
      }

      if (!googleBookData || !googleBookData.volumeInfo) {
        return null;
      }

      const volumeInfo = googleBookData.volumeInfo;
      return {
        averageRating: volumeInfo.averageRating,
        ratingsCount: volumeInfo.ratingsCount
      };

    } catch (error) {
      console.error(chalk.red(`❌ Error fetching rating info for "${book.title}":`, error));
      return null;
    }
  }

  calculatePopularityScore(averageRating: number, ratingsCount: number): number {
    // Formula: averageRating * log10(ratingsCount + 1)
    // This balances quality (rating) with engagement (review volume)
    return averageRating * Math.log10(ratingsCount + 1);
  }

  async updateBookPopularity(bookId: string, ratingInfo: GoogleBookRatingInfo) {
    const averageRating = ratingInfo.averageRating || 0;
    const ratingsCount = ratingInfo.ratingsCount || 0;
    const popularityScore = averageRating > 0 ? this.calculatePopularityScore(averageRating, ratingsCount) : 0;

    const { error } = await supabase
      .from('books')
      .update({
        average_rating: averageRating,
        ratings_count: ratingsCount,
        popularity_score: popularityScore
      })
      .eq('id', bookId);

    if (error) {
      throw new Error(`Failed to update book ${bookId}: ${error.message}`);
    }

    return { averageRating, ratingsCount, popularityScore };
  }

  async processBooks() {
    const books = await this.getBooksWithoutScores();
    
    if (books.length === 0) {
      console.log(chalk.green('🎉 All books already have popularity scores! Nothing to update.'));
      return;
    }

    let processed = 0;
    let updated = 0;
    let skipped = 0;
    let errors = 0;

    console.log(chalk.blue(`🚀 Starting to process ${books.length} books without scores in batches of ${this.batchSize}...`));
    console.log(chalk.gray(`⏱️  Rate limiting: Max ${this.maxCallsPerWindow} API calls per ${this.rateLimitWindow/1000}s window`));
    console.log(chalk.gray(`📦 Batch delay: ${this.delayMs}ms between batches`));

    for (let i = 0; i < books.length; i += this.batchSize) {
      const batch = books.slice(i, i + this.batchSize);
      
      console.log(chalk.cyan(`\n📦 Processing batch ${Math.floor(i / this.batchSize) + 1}/${Math.ceil(books.length / this.batchSize)} (books ${i + 1}-${Math.min(i + this.batchSize, books.length)})`));

      // Process batch concurrently
      const batchPromises = batch.map(async (book) => {
        try {
          processed++;
          
          console.log(chalk.gray(`  📖 Processing: "${book.title}" by ${Array.isArray(book.authors) ? book.authors.join(', ') : book.authors}`));
          
          const ratingInfo = await this.fetchRatingInfo(book);
          
          if (!ratingInfo || (!ratingInfo.averageRating && !ratingInfo.ratingsCount)) {
            console.log(chalk.yellow(`  ⏭️  No rating data found for "${book.title}"`));
            skipped++;
            return;
          }

          const result = await this.updateBookPopularity(book.id, ratingInfo);
          
          console.log(chalk.green(`  ✅ Updated "${book.title}": Rating ${result.averageRating}/5 (${result.ratingsCount} reviews) → Score: ${result.popularityScore.toFixed(2)}`));
          updated++;
          
        } catch (error) {
          console.error(chalk.red(`  ❌ Error processing "${book.title}":`, error));
          errors++;
        }
      });

      await Promise.all(batchPromises);

      // Rate limiting delay between batches
      if (i + this.batchSize < books.length) {
        console.log(chalk.gray(`  ⏱️  Waiting ${this.delayMs}ms before next batch...`));
        await new Promise(resolve => setTimeout(resolve, this.delayMs));
      }
    }

    // Final summary
    console.log(chalk.blue('\n📊 Final Summary:'));
    console.log(chalk.green(`✅ Successfully updated: ${updated} books`));
    console.log(chalk.yellow(`⏭️  Skipped (no data): ${skipped} books`));
    console.log(chalk.red(`❌ Errors: ${errors} books`));
    console.log(chalk.blue(`📈 Total processed: ${processed} books`));

    if (updated > 0) {
      console.log(chalk.green('\n🎉 Popularity scores have been updated! You can now sort books by popularity_score.'));
    }
  }
}

// CLI interface
async function main() {
  try {
    const args = process.argv.slice(2);
    const batchSize = args[0] ? parseInt(args[0]) : 2;
    const delayMs = args[1] ? parseInt(args[1]) : 3000;

    console.log(chalk.blue('🔄 BookBite Popularity Score Updater'));
    console.log(chalk.gray(`Configuration: Batch size: ${batchSize}, Delay: ${delayMs}ms`));
    console.log(chalk.gray(`Rate limiting: Respects Google Books API limits with dynamic throttling\n`));

    const updater = new PopularityScoreUpdater(batchSize, delayMs);
    await updater.processBooks();

  } catch (error) {
    console.error(chalk.red('💥 Script failed:'), error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

export { PopularityScoreUpdater };