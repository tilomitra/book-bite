import { config } from 'dotenv';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { BookService } from '../src/services/bookService';

// Load environment variables
config();

// Open Library Covers API configuration
const OPEN_LIBRARY_COVERS_BASE_URL = 'https://covers.openlibrary.org';
const COVER_SIZE = 'L'; // Large size covers

// Top 100 Popular Bestseller Books
const TOP_100_BOOKS = [
  // Self-Help & Productivity
  { title: "Atomic Habits", author: "James Clear", isbn: "9780735211292" },
  { title: "The 7 Habits of Highly Effective People", author: "Stephen R. Covey", isbn: "9781982137274" },
  { title: "Think and Grow Rich", author: "Napoleon Hill", isbn: "9781585424337" },
  { title: "The Power of Positive Thinking", author: "Norman Vincent Peale", isbn: "9780743234801" },
  { title: "How to Win Friends and Influence People", author: "Dale Carnegie", isbn: "9780671027032" },
  { title: "The Subtle Art of Not Giving a F*ck", author: "Mark Manson", isbn: "9780062457714" },
  { title: "12 Rules for Life", author: "Jordan B. Peterson", isbn: "9780345816023" },
  { title: "Mindset", author: "Carol S. Dweck", isbn: "9780345472328" },
  { title: "The Four Agreements", author: "Don Miguel Ruiz", isbn: "9781878424310" },
  { title: "The Alchemist", author: "Paulo Coelho", isbn: "9780061122415" },

  // Business & Entrepreneurship
  { title: "Rich Dad Poor Dad", author: "Robert T. Kiyosaki", isbn: "9781612680194" },
  { title: "Good to Great", author: "Jim Collins", isbn: "9780066620992" },
  { title: "Zero to One", author: "Peter Thiel", isbn: "9780804139298" },
  { title: "The Lean Startup", author: "Eric Ries", isbn: "9780307887894" },
  { title: "The $100 Startup", author: "Chris Guillebeau", isbn: "9780307951526" },
  { title: "The E-Myth Revisited", author: "Michael E. Gerber", isbn: "9780887307287" },
  { title: "Built to Last", author: "Jim Collins", isbn: "9780060516406" },
  { title: "The Hard Thing About Hard Things", author: "Ben Horowitz", isbn: "9780062273208" },
  { title: "Principles", author: "Ray Dalio", isbn: "9781501124020" },
  { title: "The Millionaire Next Door", author: "Thomas J. Stanley", isbn: "9781589795471" },

  // Psychology & Human Behavior
  { title: "Thinking, Fast and Slow", author: "Daniel Kahneman", isbn: "9780374275631" },
  { title: "Freakonomics", author: "Steven D. Levitt", isbn: "9780061234002" },
  { title: "The Tipping Point", author: "Malcolm Gladwell", isbn: "9780316346627" },
  { title: "Outliers", author: "Malcolm Gladwell", isbn: "9780316017930" },
  { title: "Blink", author: "Malcolm Gladwell", isbn: "9780316010665" },
  { title: "Predictably Irrational", author: "Dan Ariely", isbn: "9780061353246" },
  { title: "The Power of Habit", author: "Charles Duhigg", isbn: "9780812981605" },
  { title: "Influence", author: "Robert B. Cialdini", isbn: "9780061241895" },
  { title: "Nudge", author: "Richard H. Thaler", isbn: "9780300122237" },
  { title: "The Happiness Hypothesis", author: "Jonathan Haidt", isbn: "9780465028023" },

  // History & Biography
  { title: "Sapiens", author: "Yuval Noah Harari", isbn: "9780062316097" },
  { title: "Homo Deus", author: "Yuval Noah Harari", isbn: "9780062464316" },
  { title: "21 Lessons for the 21st Century", author: "Yuval Noah Harari", isbn: "9780525512172" },
  { title: "Educated", author: "Tara Westover", isbn: "9780399590504" },
  { title: "Becoming", author: "Michelle Obama", isbn: "9781524763138" },
  { title: "The Autobiography of Malcolm X", author: "Malcolm X", isbn: "9780345350688" },
  { title: "Steve Jobs", author: "Walter Isaacson", isbn: "9781451648539" },
  { title: "Benjamin Franklin", author: "Walter Isaacson", isbn: "9780743258074" },
  { title: "The Wright Brothers", author: "David McCullough", isbn: "9781476728759" },
  { title: "John Adams", author: "David McCullough", isbn: "9780743223133" },

  // Science & Technology
  { title: "A Brief History of Time", author: "Stephen Hawking", isbn: "9780553380163" },
  { title: "The Immortal Life of Henrietta Lacks", author: "Rebecca Skloot", isbn: "9781400052189" },
  { title: "Mary Roach's Packing for Mars", author: "Mary Roach", isbn: "9780393339918" },
  { title: "The Gene", author: "Siddhartha Mukherjee", isbn: "9781476733524" },
  { title: "Cosmos", author: "Carl Sagan", isbn: "9780345331359" },
  { title: "The Elegant Universe", author: "Brian Greene", isbn: "9780393058581" },
  { title: "Silent Spring", author: "Rachel Carson", isbn: "9780618249060" },
  { title: "The Double Helix", author: "James D. Watson", isbn: "9780743216302" },
  { title: "The Structure of Scientific Revolutions", author: "Thomas S. Kuhn", isbn: "9780226458120" },
  { title: "Freakonomics", author: "Steven D. Levitt", isbn: "9780061234002" },

  // Health & Wellness
  { title: "The Body Keeps the Score", author: "Bessel van der Kolk", isbn: "9780143127741" },
  { title: "How Not to Die", author: "Michael Greger", isbn: "9781250066114" },
  { title: "Atomic Habits", author: "James Clear", isbn: "9780735211292" },
  { title: "The 4-Hour Workweek", author: "Timothy Ferriss", isbn: "9780307465351" },
  { title: "Born to Run", author: "Christopher McDougall", isbn: "9780307279187" },
  { title: "The Blue Zones", author: "Dan Buettner", isbn: "9781426203008" },
  { title: "Why We Sleep", author: "Matthew Walker", isbn: "9781501144318" },
  { title: "The Power of Now", author: "Eckhart Tolle", isbn: "9781577314806" },
  { title: "Wherever You Go, There You Are", author: "Jon Kabat-Zinn", isbn: "9781401307783" },
  { title: "The Whole30", author: "Melissa Hartwig Urban", isbn: "9780544609716" },

  // Economics & Politics
  { title: "Capital in the Twenty-First Century", author: "Thomas Piketty", isbn: "9780674430006" },
  { title: "The Wealth of Nations", author: "Adam Smith", isbn: "9780553585971" },
  { title: "Democracy in America", author: "Alexis de Tocqueville", isbn: "9780226805368" },
  { title: "The Road to Serfdom", author: "F.A. Hayek", isbn: "9780226320557" },
  { title: "Free to Choose", author: "Milton Friedman", isbn: "9780156334600" },
  { title: "The Black Swan", author: "Nassim Nicholas Taleb", isbn: "9780812973815" },
  { title: "Antifragile", author: "Nassim Nicholas Taleb", isbn: "9780812979688" },
  { title: "The Righteous Mind", author: "Jonathan Haidt", isbn: "9780307455772" },
  { title: "The End of History and the Last Man", author: "Francis Fukuyama", isbn: "9780743284554" },
  { title: "The Clash of Civilizations", author: "Samuel P. Huntington", isbn: "9781451628975" },

  // Personal Finance
  { title: "The Total Money Makeover", author: "Dave Ramsey", isbn: "9781595555274" },
  { title: "Your Money or Your Life", author: "Vicki Robin", isbn: "9780143115762" },
  { title: "The Richest Man in Babylon", author: "George S. Clason", isbn: "9780451205360" },
  { title: "I Will Teach You to Be Rich", author: "Ramit Sethi", isbn: "9781523505746" },
  { title: "The Intelligent Investor", author: "Benjamin Graham", isbn: "9780060555665" },
  { title: "A Random Walk Down Wall Street", author: "Burton G. Malkiel", isbn: "9781324002185" },
  { title: "The Bogleheads' Guide to Investing", author: "Taylor Larimore", isbn: "9781118921289" },
  { title: "Think and Grow Rich", author: "Napoleon Hill", isbn: "9781585424337" },
  { title: "The Millionaire Mind", author: "Thomas J. Stanley", isbn: "9780740718588" },
  { title: "Rich Dad's Cashflow Quadrant", author: "Robert T. Kiyosaki", isbn: "9781612680057" },

  // Philosophy & Spirituality
  { title: "Man's Search for Meaning", author: "Viktor E. Frankl", isbn: "9780807014271" },
  { title: "The Art of War", author: "Sun Tzu", isbn: "9780140439199" },
  { title: "Meditations", author: "Marcus Aurelius", isbn: "9780140449334" },
  { title: "The Republic", author: "Plato", isbn: "9780140455113" },
  { title: "The Nicomachean Ethics", author: "Aristotle", isbn: "9780140449495" },
  { title: "The Prince", author: "Niccolò Machiavelli", isbn: "9780140449150" },
  { title: "Beyond Good and Evil", author: "Friedrich Nietzsche", isbn: "9780140449235" },
  { title: "The Way of Zen", author: "Alan W. Watts", isbn: "9780375705106" },
  { title: "The Tao of Physics", author: "Fritjof Capra", isbn: "9781590308356" },
  { title: "A New Earth", author: "Eckhart Tolle", isbn: "9780452289963" },

  // Communication & Relationships
  { title: "Nonviolent Communication", author: "Marshall B. Rosenberg", isbn: "9781892005281" },
  { title: "Getting to Yes", author: "Roger Fisher", isbn: "9780143118756" },
  { title: "Crucial Conversations", author: "Kerry Patterson", isbn: "9780071771320" },
  { title: "The Five Love Languages", author: "Gary Chapman", isbn: "9780802473158" },
  { title: "Men Are from Mars, Women Are from Venus", author: "John Gray", isbn: "9780060574215" },
  { title: "The Art of Listening", author: "Erich Fromm", isbn: "9780826414137" },
  { title: "Emotional Intelligence", author: "Daniel Goleman", isbn: "9780553383713" },
  { title: "The Charisma Myth", author: "Olivia Fox Cabane", isbn: "9781591845942" },
  { title: "Never Eat Alone", author: "Keith Ferrazzi", isbn: "9780385512053" },
  { title: "The Like Switch", author: "Jack Schafer", isbn: "9781476754482" }
];

/**
 * Get cover URL from Open Library API using ISBN
 */
async function getCoverUrl(isbn: string): Promise<string | null> {
  try {
    // First, check if cover exists by trying to fetch metadata
    const metadataUrl = `${OPEN_LIBRARY_COVERS_BASE_URL}/b/isbn/${isbn}.json`;
    const metadataResponse = await fetch(metadataUrl);
    
    if (!metadataResponse.ok) {
      return null;
    }

    // If metadata exists, construct the cover URL
    const coverUrl = `${OPEN_LIBRARY_COVERS_BASE_URL}/b/isbn/${isbn}-${COVER_SIZE}.jpg`;
    
    // Verify the actual image exists
    const imageResponse = await fetch(coverUrl, { method: 'HEAD' });
    
    if (imageResponse.ok) {
      return coverUrl;
    }

    return null;
  } catch (error) {
    console.warn(`    ⚠️  Failed to check cover for ISBN ${isbn}:`, error);
    return null;
  }
}

async function populateFeaturedBooks() {
  const googleBooksService = new GoogleBooksService();
  const bookService = new BookService();
  
  console.log('Starting to populate featured books...');
  
  let successCount = 0;
  let failCount = 0;
  let skippedCount = 0;
  
  for (let i = 0; i < TOP_100_BOOKS.length; i++) {
    const bookInfo = TOP_100_BOOKS[i];
    const rank = i + 1;
    
    try {
      console.log(`Processing ${rank}/100: ${bookInfo.title} by ${bookInfo.author}`);
      
      // Check if book already exists in database by title
      console.log(`    🔍 Checking for existing book...`);
      const existingBooks = await bookService.searchBooks(bookInfo.title, 1);
      
      if (existingBooks.length > 0) {
        const existingBook = existingBooks[0];
        // Check if it's a close match (fuzzy matching for slight title variations)
        const titleMatch = existingBook.title.toLowerCase().includes(bookInfo.title.toLowerCase()) || 
                          bookInfo.title.toLowerCase().includes(existingBook.title.toLowerCase());
        
        if (titleMatch) {
          console.log(`    ⏭️  Book already exists: ${existingBook.title} - Skipping`);
          skippedCount++;
          continue;
        }
      }
      
      // Try to find book by ISBN first
      let bookData = await googleBooksService.getBookByISBN(bookInfo.isbn);
      
      // If not found by ISBN, try searching by title and author
      if (!bookData) {
        console.log(`    📚 ISBN search failed, trying title/author search...`);
        const searchResults = await googleBooksService.searchBooks(`${bookInfo.title} ${bookInfo.author}`, 5);
        if (searchResults.length > 0) {
          bookData = searchResults[0];
        }
      }
      
      if (!bookData) {
        console.log(`    ❌ Could not find book: ${bookInfo.title}`);
        failCount++;
        continue;
      }
      
      // Try to get a high-quality cover image from Open Library
      console.log(`    🖼️  Fetching cover image...`);
      const coverUrl = await getCoverUrl(bookInfo.isbn);
      
      // Add featured book properties with cover URL
      const featuredBookData = {
        ...bookData,
        popularity_rank: rank,
        is_featured: true,
        cover_url: coverUrl || bookData.cover_url // Use Open Library cover if available, fallback to Google Books
      };
      
      // Create the book in database
      const createdBook = await bookService.createBook(featuredBookData);
      
      if (coverUrl) {
        console.log(`    ✅ Added: ${createdBook.title} (Rank: ${rank}) with high-quality cover`);
      } else {
        console.log(`    ✅ Added: ${createdBook.title} (Rank: ${rank}) with fallback cover`);
      }
      successCount++;
      
      // Add delay to avoid rate limiting (both Google Books and Open Library)
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.error(`    ❌ Error processing ${bookInfo.title}:`, error.message);
      failCount++;
    }
  }
  
  console.log('\n📊 Population Summary:');
  console.log(`✅ Successfully added: ${successCount} books`);
  console.log(`⏭️  Skipped (already exist): ${skippedCount} books`);
  console.log(`❌ Failed to add: ${failCount} books`);
  console.log(`📝 Total processed: ${successCount + skippedCount + failCount}/100`);
}

// Run the script
if (require.main === module) {
  populateFeaturedBooks()
    .then(() => {
      console.log('\n🎉 Featured books population completed!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n💥 Fatal error:', error);
      process.exit(1);
    });
}

export { populateFeaturedBooks };