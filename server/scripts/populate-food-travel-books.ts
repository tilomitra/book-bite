#!/usr/bin/env npx tsx

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

// Food and Travel books to populate
const FOOD_TRAVEL_BOOKS = [
  // Travel Books
  { title: "In a Sunburned Country", author: "Bill Bryson", category: "Travel" },
  { title: "The Geography of Bliss", author: "Eric Weiner", category: "Travel" },
  { title: "Vagabonding", author: "Rolf Potts", category: "Travel" },
  { title: "Into the Wild", author: "Jon Krakauer", category: "Travel" },
  { title: "Wild", author: "Cheryl Strayed", category: "Travel" },
  
  // Food & Cooking Books
  { title: "Salt, Fat, Acid, Heat", author: "Samin Nosrat", category: "Cooking" },
  { title: "Kitchen Confidential", author: "Anthony Bourdain", category: "Food" },
  { title: "The Omnivore's Dilemma", author: "Michael Pollan", category: "Food" },
  { title: "Fast Food Nation", author: "Eric Schlosser", category: "Food" },
  { title: "In Defense of Food", author: "Michael Pollan", category: "Food" }
];

class FoodTravelBookPopulator {
  private bookService: BookService;
  private googleBooksService: GoogleBooksService;
  private openAIService: OpenAIService;
  private stats = {
    processed: 0,
    added: 0,
    skipped: 0,
    errors: 0
  };

  constructor() {
    this.bookService = new BookService();
    this.googleBooksService = new GoogleBooksService();
    this.openAIService = new OpenAIService();
  }

  async processBook(bookInfo: typeof FOOD_TRAVEL_BOOKS[0]) {
    try {
      console.log(chalk.cyan(`\n📘 Processing: ${bookInfo.title} by ${bookInfo.author}`));
      
      // Check if book already exists
      const { data: existingBook } = await supabase
        .from('books')
        .select('id')
        .ilike('title', `%${bookInfo.title}%`)
        .single();

      if (existingBook) {
        console.log(chalk.gray(`  ↩️ Already exists, skipping...`));
        this.stats.skipped++;
        return;
      }

      // Search for book via Google Books API
      const searchQuery = `${bookInfo.title} ${bookInfo.author}`;
      const googleBook = await this.googleBooksService.searchBooks(searchQuery, 1);
      
      if (!googleBook || googleBook.length === 0) {
        console.log(chalk.yellow(`  ⚠️ Not found in Google Books`));
        this.stats.errors++;
        return;
      }

      const bookData = googleBook[0];
      bookData.categories = [bookInfo.category];

      // Save book
      const savedBook = await this.bookService.createBook(bookData);
      
      if (savedBook) {
        console.log(chalk.green(`  ✅ Book saved`));
        this.stats.added++;

        // Generate summary (simplified - no extended summary for speed)
        try {
          const summaryData = await this.openAIService.generateBookSummary(
            savedBook.title,
            savedBook.authors,
            savedBook.description || '',
            savedBook.categories || [],
            'brief'
          );

          await supabase
            .from('summaries')
            .insert({
              book_id: savedBook.id,
              ...summaryData
            });
          
          console.log(chalk.green(`  ✅ Summary generated`));
        } catch (error) {
          console.log(chalk.yellow(`  ⚠️ Summary generation failed`));
        }
      }

      this.stats.processed++;
      
      // Small delay for rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000));
      
    } catch (error) {
      console.error(chalk.red(`  ❌ Error: ${error}`));
      this.stats.errors++;
    }
  }

  async run() {
    console.log(chalk.bold.blue('\n📚 Food & Travel Books Populator\n'));
    console.log(chalk.cyan(`Processing ${FOOD_TRAVEL_BOOKS.length} books...`));
    
    for (const book of FOOD_TRAVEL_BOOKS) {
      await this.processBook(book);
    }

    // Print statistics
    console.log(chalk.bold.green('\n\n📊 Final Statistics:'));
    console.log(chalk.gray('═'.repeat(50)));
    console.log(chalk.white(`📚 Total Processed: ${this.stats.processed}`));
    console.log(chalk.green(`✅ Books Added: ${this.stats.added}`));
    console.log(chalk.yellow(`↩️ Skipped: ${this.stats.skipped}`));
    console.log(chalk.red(`❌ Errors: ${this.stats.errors}`));
    console.log(chalk.gray('═'.repeat(50)));
  }
}

// Main execution
(async () => {
  const populator = new FoodTravelBookPopulator();
  
  try {
    await populator.run();
    console.log(chalk.bold.green('\n✨ Food & Travel book population completed!'));
  } catch (error) {
    console.error(chalk.red('Fatal error:', error));
    process.exit(1);
  }
})();