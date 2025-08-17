#!/usr/bin/env npx tsx

/**
 * Script to update book cover images using Open Library Covers API
 * 
 * Features:
 * - Fetches high-quality book covers from Open Library
 * - Updates Supabase database with new cover URLs
 * - Rate limiting compliant (100 requests per 5 minutes)
 * - Batch processing for large datasets
 * - Skip books that already have cover URLs (optional)
 * - Detailed logging and progress tracking
 * 
 * Usage:
 *   npx tsx scripts/update-book-covers.ts [options]
 * 
 * Options:
 *   --force          Update covers even if book already has a cover URL
 *   --limit <number> Limit number of books to process (default: all)
 *   --dry-run        Show what would be updated without making changes
 *   --size <size>    Cover size: S (small), M (medium), L (large) - default: L
 */

import { createClient } from '@supabase/supabase-js';
import { Book } from '../src/models/types';
import dotenv from 'dotenv';

dotenv.config();

// Configuration
const OPEN_LIBRARY_COVERS_BASE_URL = 'https://covers.openlibrary.org';
const RATE_LIMIT_DELAY = 3000; // 3 seconds between requests (well under 100 req/5min limit)
const BATCH_SIZE = 20; // Process books in batches
const DEFAULT_COVER_SIZE = 'L'; // Large size by default

interface ScriptOptions {
  force: boolean;
  limit?: number;
  dryRun: boolean;
  size: 'S' | 'M' | 'L';
}

interface CoverUpdateResult {
  bookId: string;
  title: string;
  isbn: string;
  oldCoverUrl: string | null;
  newCoverUrl: string | null;
  success: boolean;
  error?: string;
}

class BookCoverUpdater {
  private supabase;
  private results: CoverUpdateResult[] = [];

  constructor(private options: ScriptOptions) {
    if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_KEY) {
      throw new Error('Missing Supabase environment variables');
    }
    
    this.supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_KEY,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    );
  }

  /**
   * Main execution method
   */
  async run(): Promise<void> {
    console.log('🚀 Starting Book Cover Update Script');
    console.log(`📋 Options:`, {
      force: this.options.force,
      limit: this.options.limit || 'all',
      dryRun: this.options.dryRun,
      size: this.options.size
    });

    try {
      const books = await this.fetchBooksToUpdate();
      console.log(`📚 Found ${books.length} books to process`);

      if (books.length === 0) {
        console.log('✅ No books need cover updates');
        return;
      }

      if (this.options.dryRun) {
        console.log('🔍 DRY RUN - No changes will be made');
        await this.previewUpdates(books);
        return;
      }

      await this.processBooksInBatches(books);
      await this.printSummary();

    } catch (error) {
      console.error('❌ Script failed:', error);
      process.exit(1);
    }
  }

  /**
   * Fetch books that need cover updates
   */
  private async fetchBooksToUpdate(): Promise<Book[]> {
    console.log('📖 Fetching books from database...');

    let query = this.supabase
      .from('books')
      .select('*')
      .not('isbn13', 'is', null); // Must have ISBN13 for Open Library lookup

    // Only fetch books without covers unless force flag is set
    if (!this.options.force) {
      query = query.or('cover_url.is.null,cover_url.eq.');
    }

    if (this.options.limit) {
      query = query.limit(this.options.limit);
    }

    const { data: books, error } = await query;

    if (error) {
      throw new Error(`Failed to fetch books: ${error.message}`);
    }

    return books || [];
  }

  /**
   * Preview what would be updated in dry run mode
   */
  private async previewUpdates(books: Book[]): Promise<void> {
    console.log('\n📋 DRY RUN PREVIEW:');
    console.log('─'.repeat(80));

    for (const book of books) {
      const isbn = book.isbn13 || book.isbn10;
      if (!isbn) continue;

      const coverUrl = await this.getCoverUrl(isbn);
      console.log(`📖 ${book.title}`);
      console.log(`   ISBN: ${isbn}`);
      console.log(`   Current: ${book.cover_url || 'None'}`);
      console.log(`   New: ${coverUrl || 'Not found'}`);
      console.log('');
    }
  }

  /**
   * Process books in batches with rate limiting
   */
  private async processBooksInBatches(books: Book[]): Promise<void> {
    const batches = this.chunkArray(books, BATCH_SIZE);

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      console.log(`\n🔄 Processing batch ${i + 1}/${batches.length} (${batch.length} books)`);

      for (const book of batch) {
        await this.updateBookCover(book);
        
        // Rate limiting: wait between requests
        if (book !== batch[batch.length - 1]) {
          await this.delay(RATE_LIMIT_DELAY);
        }
      }

      // Longer delay between batches
      if (i < batches.length - 1) {
        console.log('⏳ Waiting between batches...');
        await this.delay(RATE_LIMIT_DELAY * 2);
      }
    }
  }

  /**
   * Update cover for a single book
   */
  private async updateBookCover(book: Book): Promise<void> {
    const isbn = book.isbn13 || book.isbn10;
    
    if (!isbn) {
      this.results.push({
        bookId: book.id!,
        title: book.title,
        isbn: 'None',
        oldCoverUrl: book.cover_url || null,
        newCoverUrl: null,
        success: false,
        error: 'No ISBN available'
      });
      return;
    }

    try {
      console.log(`🔍 Processing: ${book.title} (ISBN: ${isbn})`);
      
      const newCoverUrl = await this.getCoverUrl(isbn);
      
      if (!newCoverUrl) {
        this.results.push({
          bookId: book.id!,
          title: book.title,
          isbn,
          oldCoverUrl: book.cover_url || null,
          newCoverUrl: null,
          success: false,
          error: 'Cover not found in Open Library'
        });
        console.log(`   ⚠️  Cover not found`);
        return;
      }

      // Update the database
      const { error } = await this.supabase
        .from('books')
        .update({ 
          cover_url: newCoverUrl,
          updated_at: new Date().toISOString()
        })
        .eq('id', book.id);

      if (error) {
        throw new Error(`Database update failed: ${error.message}`);
      }

      this.results.push({
        bookId: book.id!,
        title: book.title,
        isbn,
        oldCoverUrl: book.cover_url || null,
        newCoverUrl,
        success: true
      });

      console.log(`   ✅ Updated cover: ${newCoverUrl}`);

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      
      this.results.push({
        bookId: book.id!,
        title: book.title,
        isbn,
        oldCoverUrl: book.cover_url || null,
        newCoverUrl: null,
        success: false,
        error: errorMessage
      });

      console.log(`   ❌ Error: ${errorMessage}`);
    }
  }

  /**
   * Get cover URL from Open Library API
   */
  private async getCoverUrl(isbn: string): Promise<string | null> {
    try {
      // First, check if cover exists by trying to fetch metadata
      const metadataUrl = `${OPEN_LIBRARY_COVERS_BASE_URL}/b/isbn/${isbn}.json`;
      const metadataResponse = await fetch(metadataUrl);
      
      if (!metadataResponse.ok) {
        return null;
      }

      // If metadata exists, construct the cover URL
      const coverUrl = `${OPEN_LIBRARY_COVERS_BASE_URL}/b/isbn/${isbn}-${this.options.size}.jpg`;
      
      // Verify the actual image exists
      const imageResponse = await fetch(coverUrl, { method: 'HEAD' });
      
      if (imageResponse.ok) {
        return coverUrl;
      }

      return null;
    } catch (error) {
      console.warn(`Failed to check cover for ISBN ${isbn}:`, error);
      return null;
    }
  }

  /**
   * Print summary of results
   */
  private async printSummary(): Promise<void> {
    const successful = this.results.filter(r => r.success);
    const failed = this.results.filter(r => !r.success);

    console.log('\n📊 SUMMARY');
    console.log('═'.repeat(50));
    console.log(`✅ Successfully updated: ${successful.length}`);
    console.log(`❌ Failed updates: ${failed.length}`);
    console.log(`📋 Total processed: ${this.results.length}`);

    if (failed.length > 0) {
      console.log('\n❌ FAILED UPDATES:');
      console.log('─'.repeat(50));
      failed.forEach(result => {
        console.log(`📖 ${result.title} (${result.isbn})`);
        console.log(`   Error: ${result.error}`);
      });
    }

    if (successful.length > 0) {
      console.log('\n✅ SUCCESSFUL UPDATES:');
      console.log('─'.repeat(50));
      successful.slice(0, 10).forEach(result => {
        console.log(`📖 ${result.title}`);
        console.log(`   New cover: ${result.newCoverUrl}`);
      });
      
      if (successful.length > 10) {
        console.log(`   ... and ${successful.length - 10} more`);
      }
    }
  }

  /**
   * Utility: Split array into chunks
   */
  private chunkArray<T>(array: T[], size: number): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }

  /**
   * Utility: Async delay
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

/**
 * Parse command line arguments
 */
function parseArguments(): ScriptOptions {
  const args = process.argv.slice(2);
  const options: ScriptOptions = {
    force: false,
    dryRun: false,
    size: DEFAULT_COVER_SIZE as 'L'
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    switch (arg) {
      case '--force':
        options.force = true;
        break;
      case '--dry-run':
        options.dryRun = true;
        break;
      case '--limit':
        const limitValue = parseInt(args[++i]);
        if (isNaN(limitValue) || limitValue <= 0) {
          throw new Error('--limit must be a positive number');
        }
        options.limit = limitValue;
        break;
      case '--size':
        const sizeValue = args[++i];
        if (!['S', 'M', 'L'].includes(sizeValue)) {
          throw new Error('--size must be S, M, or L');
        }
        options.size = sizeValue as 'S' | 'M' | 'L';
        break;
      case '--help':
        console.log(`
Usage: npx tsx scripts/update-book-covers.ts [options]

Options:
  --force          Update covers even if book already has a cover URL
  --limit <number> Limit number of books to process (default: all)
  --dry-run        Show what would be updated without making changes
  --size <size>    Cover size: S (small), M (medium), L (large) - default: L
  --help           Show this help message

Examples:
  npx tsx scripts/update-book-covers.ts --dry-run
  npx tsx scripts/update-book-covers.ts --limit 50
  npx tsx scripts/update-book-covers.ts --force --size M
        `);
        process.exit(0);
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

/**
 * Main execution
 */
async function main() {
  try {
    const options = parseArguments();
    const updater = new BookCoverUpdater(options);
    await updater.run();
  } catch (error) {
    console.error('❌ Script failed:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}