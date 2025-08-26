#!/usr/bin/env npx tsx

import { config } from 'dotenv';
import axios from 'axios';
import * as cheerio from 'cheerio';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { BookService } from '../src/services/bookService';
import { OpenAIService } from '../src/services/openaiService';
import { supabase } from '../src/config/supabase';
import chalk from 'chalk';

// Load environment variables
config();

interface IndigoBook {
  title: string;
  author: string;
  isbn?: string;
  price?: string;
  imageUrl?: string;
  productUrl?: string;
}

interface PopulationStats {
  totalBooksFound: number;
  totalBooksProcessed: number;
  totalBooksAdded: number;
  totalDuplicates: number;
  totalFailures: number;
  totalSummariesGenerated: number;
}

class IndigoBookPopulator {
  private googleBooksService: GoogleBooksService;
  private bookService: BookService;
  private openAIService: OpenAIService;
  private processedISBNs: Set<string> = new Set();
  private processedTitles: Set<string> = new Set();

  constructor() {
    this.googleBooksService = new GoogleBooksService();
    this.bookService = new BookService();
    this.openAIService = new OpenAIService();
  }

  async fetchIndigoBooks(url: string): Promise<IndigoBook[]> {
    try {
      console.log(chalk.blue(`🔍 Fetching books from Indigo: ${url}`));
      
      const response = await axios.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache'
        },
        timeout: 15000
      });

      const $ = cheerio.load(response.data);
      const books: IndigoBook[] = [];

      // Indigo typically uses product cards with specific classes
      // We'll look for common patterns in their HTML structure
      $('.product-list-item, .product-item, .item-product, [data-product], .book-item').each((index, element) => {
        try {
          const $el = $(element);
          
          // Try multiple selectors to find book details
          const title = $el.find('.product-title, .item-title, .title, h3, h4, [itemprop="name"]').first().text().trim() ||
                       $el.find('a[title]').attr('title')?.trim() ||
                       $el.find('.product-name').text().trim();
          
          const author = $el.find('.product-author, .author, .contributor, [itemprop="author"]').first().text().trim() ||
                        $el.find('.by-line').text().replace(/^by\s+/i, '').trim();
          
          const price = $el.find('.product-price, .price, .item-price, [itemprop="price"]').first().text().trim();
          
          // Try to extract ISBN from data attributes or links
          const isbn = $el.attr('data-isbn') || 
                      $el.find('[data-isbn]').attr('data-isbn') ||
                      $el.attr('data-sku') ||
                      $el.find('a[href*="isbn"]').attr('href')?.match(/isbn[=\/](\d{10,13})/i)?.[1];
          
          const imageUrl = $el.find('img').first().attr('src') || 
                          $el.find('img').first().attr('data-src') ||
                          $el.find('[itemprop="image"]').attr('content');
          
          const productLink = $el.find('a').first().attr('href');
          const productUrl = productLink ? 
            (productLink.startsWith('http') ? productLink : `https://www.indigo.ca${productLink}`) : 
            undefined;

          if (title && author) {
            books.push({
              title: this.cleanTitle(title),
              author: this.cleanAuthor(author),
              isbn,
              price,
              imageUrl: imageUrl ? this.fixImageUrl(imageUrl) : undefined,
              productUrl
            });
          }
        } catch (err) {
          console.warn(chalk.yellow(`⚠️  Failed to parse book element: ${err}`));
        }
      });

      // If no books found with initial selectors, try alternative structure
      if (books.length === 0) {
        console.log(chalk.yellow('⚠️  No books found with primary selectors, trying alternatives...'));
        
        // Try grid or list layouts
        $('.grid-item, .list-item, article.product').each((index, element) => {
          try {
            const $el = $(element);
            const titleEl = $el.find('h2, h3, h4').first();
            const title = titleEl.text().trim();
            const author = titleEl.next('.author, .by').text().trim() || 
                          $el.find('.author').text().trim();
            
            if (title && author) {
              books.push({
                title: this.cleanTitle(title),
                author: this.cleanAuthor(author)
              });
            }
          } catch (err) {
            console.warn(chalk.yellow(`⚠️  Failed to parse alternative element: ${err}`));
          }
        });
      }

      console.log(chalk.green(`✅ Found ${books.length} books on Indigo page`));
      return books;

    } catch (error) {
      console.error(chalk.red(`❌ Failed to fetch Indigo books: ${error instanceof Error ? error.message : error}`));
      throw error;
    }
  }

  private cleanTitle(title: string): string {
    return title
      .replace(/\s+/g, ' ')
      .replace(/['"]/g, '')
      .replace(/\s*:\s*$/, '')
      .replace(/\s*\([^)]*\)$/, '') // Remove trailing parentheses
      .trim();
  }

  private cleanAuthor(author: string): string {
    return author
      .replace(/^by\s+/i, '')
      .replace(/\s+/g, ' ')
      .replace(/['"]/g, '')
      .trim();
  }

  private fixImageUrl(url: string): string {
    if (url.startsWith('//')) {
      return `https:${url}`;
    }
    if (!url.startsWith('http')) {
      return `https://www.indigo.ca${url}`;
    }
    return url;
  }

  async checkForDuplicates(bookData: any): Promise<boolean> {
    try {
      // Check by ISBN13 first
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

  async generateSummariesForBook(book: any): Promise<boolean> {
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
        console.error(chalk.red(`    ❌ Regular summary failed: ${summaryError.message}`));
        return false;
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

      return true;
    } catch (error) {
      console.error(chalk.red(`    ❌ Summary generation failed: ${error instanceof Error ? error.message : error}`));
      return false;
    }
  }

  async processIndigoBook(indigoBook: IndigoBook): Promise<{ added: boolean; isDuplicate: boolean; error?: string }> {
    try {
      // Skip if we've already processed this title
      const titleKey = `${indigoBook.title}-${indigoBook.author}`.toLowerCase();
      if (this.processedTitles.has(titleKey)) {
        return { added: false, isDuplicate: true };
      }

      console.log(chalk.blue(`  📖 Processing: ${indigoBook.title} by ${indigoBook.author}`));

      // Search Google Books for more complete data
      let googleBook = null;
      
      // Try ISBN search first if available
      if (indigoBook.isbn) {
        googleBook = await this.googleBooksService.searchByISBN(indigoBook.isbn);
      }
      
      // If no ISBN or no result, search by title and author
      if (!googleBook) {
        const searchQuery = `${indigoBook.title} ${indigoBook.author}`;
        const searchResults = await this.googleBooksService.searchBooks(searchQuery, 3);
        
        // Find best match
        for (const book of searchResults) {
          const volumeInfo = book.volumeInfo || {};
          const title = volumeInfo.title || '';
          const authors = volumeInfo.authors || [];
          
          // Check if title and author match
          if (title.toLowerCase().includes(indigoBook.title.toLowerCase()) ||
              indigoBook.title.toLowerCase().includes(title.toLowerCase())) {
            if (authors.some((a: string) => a.toLowerCase().includes(indigoBook.author.toLowerCase()) ||
                indigoBook.author.toLowerCase().includes(a.toLowerCase()))) {
              googleBook = book;
              break;
            }
          }
        }
      }

      if (!googleBook) {
        console.log(chalk.yellow(`    ⚠️  No Google Books match found for: ${indigoBook.title}`));
        return { added: false, isDuplicate: false, error: 'No Google Books data found' };
      }

      // Extract book data from Google Books
      let bookData = await this.googleBooksService.extractBookData(googleBook);
      
      // Add source attribution
      bookData.source_attribution = ['Indigo New Releases', 'Google Books'];
      
      // Add popularity data
      const volumeInfo = googleBook.volumeInfo || {};
      const averageRating = volumeInfo.averageRating || 0;
      const ratingsCount = volumeInfo.ratingsCount || 0;
      const popularityScore = averageRating * Math.log10(ratingsCount + 1);
      
      bookData = {
        ...bookData,
        average_rating: averageRating,
        ratings_count: ratingsCount,
        popularity_score: popularityScore,
        is_featured: true // Mark as featured since it's a new release
      };

      console.log(chalk.gray(`    📊 Popularity: ${averageRating}/5 (${ratingsCount} reviews) → Score: ${popularityScore.toFixed(2)}`));

      // Check for duplicates
      const isDuplicate = await this.checkForDuplicates(bookData);
      if (isDuplicate) {
        console.log(chalk.yellow(`    📋 Duplicate: ${bookData.title}`));
        return { added: false, isDuplicate: true };
      }

      // Save book to database
      const { data: savedBook, error } = await supabase
        .from('books')
        .insert(bookData)
        .select()
        .single();

      if (error) {
        console.error(chalk.red(`    ❌ Failed to save: ${error.message}`));
        return { added: false, isDuplicate: false, error: error.message };
      }

      console.log(chalk.green(`    ✅ Added: ${bookData.title}`));
      this.processedTitles.add(titleKey);

      // Generate summaries
      await this.generateSummariesForBook(savedBook);

      return { added: true, isDuplicate: false };

    } catch (error) {
      console.error(chalk.red(`    ❌ Error processing book: ${error instanceof Error ? error.message : error}`));
      return { added: false, isDuplicate: false, error: error instanceof Error ? error.message : String(error) };
    }
  }

  async populateFromIndigo(url: string): Promise<PopulationStats> {
    const stats: PopulationStats = {
      totalBooksFound: 0,
      totalBooksProcessed: 0,
      totalBooksAdded: 0,
      totalDuplicates: 0,
      totalFailures: 0,
      totalSummariesGenerated: 0
    };

    try {
      // Fetch books from Indigo
      const indigoBooks = await this.fetchIndigoBooks(url);
      stats.totalBooksFound = indigoBooks.length;

      if (indigoBooks.length === 0) {
        console.log(chalk.yellow('⚠️  No books found on the Indigo page'));
        return stats;
      }

      console.log(chalk.blue(`\n📚 Processing ${indigoBooks.length} books from Indigo...\n`));

      // Process each book
      for (const indigoBook of indigoBooks) {
        stats.totalBooksProcessed++;
        
        const result = await this.processIndigoBook(indigoBook);
        
        if (result.added) {
          stats.totalBooksAdded++;
          stats.totalSummariesGenerated++;
        } else if (result.isDuplicate) {
          stats.totalDuplicates++;
        } else {
          stats.totalFailures++;
        }

        // Rate limiting
        await new Promise(resolve => setTimeout(resolve, 2000));
      }

    } catch (error) {
      console.error(chalk.red(`\n💥 Fatal error: ${error instanceof Error ? error.message : error}`));
    }

    return stats;
  }
}

async function main() {
  console.log(chalk.bold.blue('🍁 Indigo New Non-Fiction Books Populator'));
  console.log('═'.repeat(60));
  
  const populator = new IndigoBookPopulator();
  
  // URLs for different Indigo non-fiction sections
  const urls = [
    'https://www.indigo.ca/en-ca/new-hot-books/new-this-week/new-this-week-non-fiction/',
    // Additional URLs can be added here for other sections
    // 'https://www.indigo.ca/en-ca/books/bestsellers/non-fiction/',
    // 'https://www.indigo.ca/en-ca/books/new-releases/non-fiction/'
  ];

  let totalStats: PopulationStats = {
    totalBooksFound: 0,
    totalBooksProcessed: 0,
    totalBooksAdded: 0,
    totalDuplicates: 0,
    totalFailures: 0,
    totalSummariesGenerated: 0
  };

  for (const url of urls) {
    console.log(chalk.cyan(`\n📍 Fetching from: ${url}\n`));
    
    const stats = await populator.populateFromIndigo(url);
    
    // Aggregate stats
    totalStats.totalBooksFound += stats.totalBooksFound;
    totalStats.totalBooksProcessed += stats.totalBooksProcessed;
    totalStats.totalBooksAdded += stats.totalBooksAdded;
    totalStats.totalDuplicates += stats.totalDuplicates;
    totalStats.totalFailures += stats.totalFailures;
    totalStats.totalSummariesGenerated += stats.totalSummariesGenerated;
    
    // Wait between URLs
    if (urls.indexOf(url) < urls.length - 1) {
      console.log(chalk.gray('\n⏸️  Waiting 5 seconds before next URL...'));
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }

  // Print final report
  console.log('\n' + '═'.repeat(60));
  console.log(chalk.bold.green('📊 INDIGO POPULATION REPORT'));
  console.log('═'.repeat(60));
  console.log(chalk.white(`🔍 Books found: ${totalStats.totalBooksFound}`));
  console.log(chalk.white(`📚 Books processed: ${totalStats.totalBooksProcessed}`));
  console.log(chalk.green(`✅ Books added: ${totalStats.totalBooksAdded}`));
  console.log(chalk.yellow(`📋 Duplicates skipped: ${totalStats.totalDuplicates}`));
  console.log(chalk.red(`❌ Failures: ${totalStats.totalFailures}`));
  console.log(chalk.blue(`🤖 Summaries generated: ${totalStats.totalSummariesGenerated}`));
  console.log('═'.repeat(60));
  
  if (totalStats.totalBooksAdded > 0) {
    console.log(chalk.bold.green('🎉 Successfully added new books from Indigo!'));
  } else {
    console.log(chalk.yellow('⚠️  No new books were added (all may be duplicates)'));
  }
}

// Run the script
if (require.main === module) {
  main()
    .then(() => {
      console.log(chalk.green('\n✨ Script completed successfully'));
      process.exit(0);
    })
    .catch((error) => {
      console.error(chalk.red('\n💥 Script failed:', error));
      process.exit(1);
    });
}

export { IndigoBookPopulator };