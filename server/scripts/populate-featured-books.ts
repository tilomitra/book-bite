import { config } from 'dotenv';
import { GoogleBooksService } from '../src/services/googleBooksService';
import { BookService } from '../src/services/bookService';

// Load environment variables
config();

// Top 100 Management and Software Development Books
const TOP_100_BOOKS = [
  // Management & Leadership Books (50 books)
  { title: "Good to Great", author: "Jim Collins", isbn: "9780066620992" },
  { title: "The Lean Startup", author: "Eric Ries", isbn: "9780307887894" },
  { title: "Built to Last", author: "Jim Collins", isbn: "9780060516406" },
  { title: "The First 90 Days", author: "Michael Watkins", isbn: "9781422188613" },
  { title: "The Five Dysfunctions of a Team", author: "Patrick Lencioni", isbn: "9780787960759" },
  { title: "High Output Management", author: "Andrew Grove", isbn: "9780679762881" },
  { title: "The Hard Thing About Hard Things", author: "Ben Horowitz", isbn: "9780062273208" },
  { title: "Crossing the Chasm", author: "Geoffrey Moore", isbn: "9780060517120" },
  { title: "The Innovator's Dilemma", author: "Clayton Christensen", isbn: "9780875845852" },
  { title: "Zero to One", author: "Peter Thiel", isbn: "9780804139298" },
  { title: "The E-Myth Revisited", author: "Michael Gerber", isbn: "9780887307287" },
  { title: "The Goal", author: "Eliyahu Goldratt", isbn: "9780884271956" },
  { title: "Radical Candor", author: "Kim Scott", isbn: "9781250103505" },
  { title: "The Manager's Path", author: "Camille Fournier", isbn: "9781491973899" },
  { title: "Measure What Matters", author: "John Doerr", isbn: "9780525536222" },
  { title: "The Culture Code", author: "Daniel Coyle", isbn: "9780525492733" },
  { title: "Principles", author: "Ray Dalio", isbn: "9781501124020" },
  { title: "The 7 Habits of Highly Effective People", author: "Stephen Covey", isbn: "9780743269513" },
  { title: "Drive", author: "Daniel Pink", isbn: "9781594484803" },
  { title: "Thinking, Fast and Slow", author: "Daniel Kahneman", isbn: "9780374275631" },
  { title: "Good Strategy Bad Strategy", author: "Richard Rumelt", isbn: "9780307886231" },
  { title: "The Lean Six Sigma Pocket Toolbook", author: "Michael George", isbn: "9780071441438" },
  { title: "Scrum: The Art of Doing Twice the Work in Half the Time", author: "Jeff Sutherland", isbn: "9781847941107" },
  { title: "Team of Teams", author: "General Stanley McChrystal", isbn: "9781591847489" },
  { title: "The Phoenix Project", author: "Gene Kim", isbn: "9780988262508" },
  { title: "Accelerate", author: "Nicole Forsgren", isbn: "9781942788331" },
  { title: "The DevOps Handbook", author: "Gene Kim", isbn: "9781942788003" },
  { title: "Multipliers", author: "Liz Wiseman", isbn: "9780061964398" },
  { title: "The Challenger Sale", author: "Matthew Dixon", isbn: "9781591844358" },
  { title: "Blue Ocean Strategy", author: "W. Chan Kim", isbn: "9781591396192" },
  { title: "The Outsiders", author: "William Thorndike", isbn: "9781422162673" },
  { title: "Crucial Conversations", author: "Kerry Patterson", isbn: "9780071401944" },
  { title: "Getting Things Done", author: "David Allen", isbn: "9780142000281" },
  { title: "The One Minute Manager", author: "Kenneth Blanchard", isbn: "9780688014292" },
  { title: "Leadership in Turbulent Times", author: "Doris Kearns Goodwin", isbn: "9781476795928" },
  { title: "The Advantage", author: "Patrick Lencioni", isbn: "9780470941522" },
  { title: "Switch", author: "Chip Heath", isbn: "9780385528757" },
  { title: "Made to Stick", author: "Chip Heath", isbn: "9781400064281" },
  { title: "The Tipping Point", author: "Malcolm Gladwell", isbn: "9780316346627" },
  { title: "Outliers", author: "Malcolm Gladwell", isbn: "9780316017930" },
  { title: "Blink", author: "Malcolm Gladwell", isbn: "9780316010665" },
  { title: "The Power of Moments", author: "Chip Heath", isbn: "9781501147760" },
  { title: "Atomic Habits", author: "James Clear", isbn: "9780735211292" },
  { title: "The Effective Executive", author: "Peter Drucker", isbn: "9780060833459" },
  { title: "The Practice of Management", author: "Peter Drucker", isbn: "9780060878979" },
  { title: "Management", author: "Peter Drucker", isbn: "9780887306136" },
  { title: "The Essential Drucker", author: "Peter Drucker", isbn: "9780060742515" },
  { title: "Emotional Intelligence", author: "Daniel Goleman", isbn: "9780553383713" },
  { title: "Primal Leadership", author: "Daniel Goleman", isbn: "9780071388085" },
  { title: "The Art of War", author: "Sun Tzu", isbn: "9780140439199" },

  // Software Development Books (50 books)
  { title: "Clean Code", author: "Robert Martin", isbn: "9780132350884" },
  { title: "Code Complete", author: "Steve McConnell", isbn: "9780735619678" },
  { title: "The Pragmatic Programmer", author: "Andy Hunt", isbn: "9780201616224" },
  { title: "Refactoring", author: "Martin Fowler", isbn: "9780201485677" },
  { title: "Design Patterns", author: "Erich Gamma", isbn: "9780201633610" },
  { title: "Clean Architecture", author: "Robert Martin", isbn: "9780134494166" },
  { title: "The Clean Coder", author: "Robert Martin", isbn: "9780137081073" },
  { title: "You Don't Know JS", author: "Kyle Simpson", isbn: "9781491924464" },
  { title: "Effective Java", author: "Joshua Bloch", isbn: "9780134685991" },
  { title: "Head First Design Patterns", author: "Eric Freeman", isbn: "9780596007126" },
  { title: "The Mythical Man-Month", author: "Frederick Brooks", isbn: "9780201835953" },
  { title: "Introduction to Algorithms", author: "Thomas Cormen", isbn: "9780262033848" },
  { title: "Cracking the Coding Interview", author: "Gayle McDowell", isbn: "9780984782857" },
  { title: "System Design Interview", author: "Alex Xu", isbn: "9798664653403" },
  { title: "Designing Data-Intensive Applications", author: "Martin Kleppmann", isbn: "9781449373320" },
  { title: "Building Microservices", author: "Sam Newman", isbn: "9781491950357" },
  { title: "Domain-Driven Design", author: "Eric Evans", isbn: "9780321125217" },
  { title: "Patterns of Enterprise Application Architecture", author: "Martin Fowler", isbn: "9780321127426" },
  { title: "Enterprise Integration Patterns", author: "Gregor Hohpe", isbn: "9780321200686" },
  { title: "Test Driven Development", author: "Kent Beck", isbn: "9780321146533" },
  { title: "Continuous Delivery", author: "Jez Humble", isbn: "9780321601919" },
  { title: "Site Reliability Engineering", author: "Niall Murphy", isbn: "9781491929124" },
  { title: "The Site Reliability Workbook", author: "Betsy Beyer", isbn: "9781492029502" },
  { title: "Release It!", author: "Michael Nygard", isbn: "9780978739218" },
  { title: "Working Effectively with Legacy Code", author: "Michael Feathers", isbn: "9780131177055" },
  { title: "The Art of Computer Programming", author: "Donald Knuth", isbn: "9780201896831" },
  { title: "Structure and Interpretation of Computer Programs", author: "Harold Abelson", isbn: "9780262011532" },
  { title: "Computer Systems: A Programmer's Perspective", author: "Randal Bryant", isbn: "9780134092669" },
  { title: "Operating System Concepts", author: "Abraham Silberschatz", isbn: "9781119800361" },
  { title: "Database System Concepts", author: "Abraham Silberschatz", isbn: "9780078022159" },
  { title: "Modern Operating Systems", author: "Andrew Tanenbaum", isbn: "9780133591620" },
  { title: "Computer Networks", author: "Andrew Tanenbaum", isbn: "9780132553179" },
  { title: "The Algorithm Design Manual", author: "Steven Skiena", isbn: "9781849967204" },
  { title: "Programming Pearls", author: "Jon Bentley", isbn: "9780201657883" },
  { title: "The Practice of Programming", author: "Brian Kernighan", isbn: "9780201615869" },
  { title: "Compilers: Principles, Techniques, and Tools", author: "Alfred Aho", isbn: "9780321486813" },
  { title: "Artificial Intelligence: A Modern Approach", author: "Stuart Russell", isbn: "9780134610993" },
  { title: "Machine Learning", author: "Tom Mitchell", isbn: "9780070428072" },
  { title: "Deep Learning", author: "Ian Goodfellow", isbn: "9780262035613" },
  { title: "Hands-On Machine Learning", author: "Aurélien Géron", isbn: "9781491962299" },
  { title: "The Elements of Statistical Learning", author: "Trevor Hastie", isbn: "9780387848570" },
  { title: "Python Crash Course", author: "Eric Matthes", isbn: "9781593279288" },
  { title: "Automate the Boring Stuff with Python", author: "Al Sweigart", isbn: "9781593275990" },
  { title: "JavaScript: The Good Parts", author: "Douglas Crockford", isbn: "9780596517748" },
  { title: "Eloquent JavaScript", author: "Marijn Haverbeke", isbn: "9781593275846" },
  { title: "Learning React", author: "Alex Banks", isbn: "9781491954621" },
  { title: "Node.js in Action", author: "Mike Cantelon", isbn: "9781617290572" },
  { title: "Spring in Action", author: "Craig Walls", isbn: "9781617294945" },
  { title: "Kubernetes in Action", author: "Marko Luksa", isbn: "9781617293726" },
  { title: "Docker Deep Dive", author: "Nigel Poulton", isbn: "9781521822807" },
  { title: "Learning SQL", author: "Alan Beaulieu", isbn: "9780596520830" }
];

async function populateFeaturedBooks() {
  const googleBooksService = new GoogleBooksService();
  const bookService = new BookService();
  
  console.log('Starting to populate featured books...');
  
  let successCount = 0;
  let failCount = 0;
  
  for (let i = 0; i < TOP_100_BOOKS.length; i++) {
    const bookInfo = TOP_100_BOOKS[i];
    const rank = i + 1;
    
    try {
      console.log(`Processing ${rank}/100: ${bookInfo.title} by ${bookInfo.author}`);
      
      // Try to find book by ISBN first
      let bookData = await googleBooksService.getBookByISBN(bookInfo.isbn);
      
      // If not found by ISBN, try searching by title and author
      if (!bookData) {
        console.log(`  ISBN search failed, trying title/author search...`);
        const searchResults = await googleBooksService.searchBooks(`${bookInfo.title} ${bookInfo.author}`, 5);
        if (searchResults.length > 0) {
          bookData = searchResults[0];
        }
      }
      
      if (!bookData) {
        console.log(`  ❌ Could not find book: ${bookInfo.title}`);
        failCount++;
        continue;
      }
      
      // Add featured book properties
      const featuredBookData = {
        ...bookData,
        popularity_rank: rank,
        is_featured: true
      };
      
      // Create the book in database
      const createdBook = await bookService.createBook(featuredBookData);
      console.log(`  ✅ Added: ${createdBook.title} (Rank: ${rank})`);
      successCount++;
      
      // Add small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 200));
      
    } catch (error) {
      console.error(`  ❌ Error processing ${bookInfo.title}:`, error.message);
      failCount++;
    }
  }
  
  console.log('\n📊 Population Summary:');
  console.log(`✅ Successfully added: ${successCount} books`);
  console.log(`❌ Failed to add: ${failCount} books`);
  console.log(`📝 Total processed: ${successCount + failCount}/100`);
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