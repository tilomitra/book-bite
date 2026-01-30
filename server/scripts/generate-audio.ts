/**
 * CLI Command: Generate Audio Summary for a Book
 *
 * Usage:
 *   npm run generate-audio -- --book-id <uuid>        # Generate for specific book
 *   npm run generate-audio -- --title "Atomic Habits" # Search by title
 *   npm run generate-audio -- --list-missing          # List books without audio
 *   npm run generate-audio -- --book-id <uuid> --dry-run  # Preview script only
 *   npm run generate-audio -- --book-id <uuid> --voice-id <id>  # Custom voice
 *
 * This command gives you full control over audio generation costs by processing
 * one book at a time with confirmation prompts.
 */

import dotenv from 'dotenv';
dotenv.config();

import chalk from 'chalk';
import { createInterface } from 'readline';
import { supabase } from '../src/config/supabase';
import { AudioSummaryService } from '../src/services/audioSummaryService';
import { ElevenLabsService } from '../src/services/elevenLabsService';
import { Book, Summary } from '../src/models/types';

const audioService = new AudioSummaryService();

// Parse command line arguments
function parseArgs(): {
  bookId?: string;
  title?: string;
  listMissing: boolean;
  dryRun: boolean;
  voiceId?: string;
  force: boolean;
  help: boolean;
} {
  const args = process.argv.slice(2);
  const result: any = {
    listMissing: false,
    dryRun: false,
    force: false,
    help: false
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--book-id':
        result.bookId = args[++i];
        break;
      case '--title':
        result.title = args[++i];
        break;
      case '--list-missing':
        result.listMissing = true;
        break;
      case '--dry-run':
        result.dryRun = true;
        break;
      case '--voice-id':
        result.voiceId = args[++i];
        break;
      case '--force':
        result.force = true;
        break;
      case '--help':
      case '-h':
        result.help = true;
        break;
    }
  }

  return result;
}

function showHelp() {
  console.log(`
${chalk.bold('Generate Audio Summary for Books')}

${chalk.yellow('Usage:')}
  npm run generate-audio -- [options]

${chalk.yellow('Options:')}
  --book-id <uuid>    Generate audio for a specific book by ID
  --title <string>    Search for a book by title and generate audio
  --list-missing      List all books that don't have audio summaries
  --dry-run           Generate script only, don't create audio (for cost preview)
  --voice-id <id>     Use a specific ElevenLabs voice (default: Adam)
  --force             Regenerate audio even if it already exists
  --help, -h          Show this help message

${chalk.yellow('Examples:')}
  # Generate audio for a specific book
  npm run generate-audio -- --book-id 123e4567-e89b-12d3-a456-426614174000

  # Search by title and generate
  npm run generate-audio -- --title "Atomic Habits"

  # Preview script and cost estimate (no audio generated)
  npm run generate-audio -- --title "Deep Work" --dry-run

  # List books needing audio
  npm run generate-audio -- --list-missing

  # Force regenerate with custom voice
  npm run generate-audio -- --book-id <uuid> --force --voice-id EXAVITQu4vr4xnSDxMaL

${chalk.yellow('Available Voices:')}
  pNInz6obpgDQGcFmaJgB - Adam (default) - Warm, conversational male
  EXAVITQu4vr4xnSDxMaL - Bella - Warm, friendly female
  21m00Tcm4TlvDq8ikWAM - Rachel - Calm, clear female
  ErXwobaYiN019PkySvjV - Antoni - Well-rounded male
`);
}

async function prompt(question: string): Promise<string> {
  const rl = createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim().toLowerCase());
    });
  });
}

async function listBooksWithoutAudio() {
  console.log(chalk.blue('\nFetching books without audio summaries...\n'));

  const books = await audioService.getBooksWithoutAudio(100);

  if (books.length === 0) {
    console.log(chalk.green('All books with summaries have audio!'));
    return;
  }

  console.log(chalk.yellow(`Found ${books.length} books without audio:\n`));

  books.forEach((book, i) => {
    console.log(`  ${chalk.gray(`${i + 1}.`)} ${book.title}`);
    console.log(`     ${chalk.gray('ID:')} ${book.id}`);
    console.log(`     ${chalk.gray('Authors:')} ${book.authors.join(', ')}`);
    console.log();
  });

  console.log(chalk.gray('\nUse --book-id <uuid> to generate audio for a specific book.'));
}

async function findBookByTitle(title: string): Promise<Book | null> {
  const { data, error } = await supabase
    .from('books')
    .select('*')
    .ilike('title', `%${title}%`)
    .limit(10);

  if (error || !data || data.length === 0) {
    return null;
  }

  if (data.length === 1) {
    return data[0] as Book;
  }

  // Multiple matches - let user choose
  console.log(chalk.yellow(`\nFound ${data.length} books matching "${title}":\n`));
  data.forEach((book, i) => {
    console.log(`  ${chalk.cyan(`${i + 1})`)} ${book.title}`);
    console.log(`     ${chalk.gray('Authors:')} ${book.authors.join(', ')}`);
    console.log(`     ${chalk.gray('ID:')} ${book.id}`);
    console.log();
  });

  const answer = await prompt('Enter number to select (or q to quit): ');
  if (answer === 'q') return null;

  const index = parseInt(answer) - 1;
  if (index >= 0 && index < data.length) {
    return data[index] as Book;
  }

  console.log(chalk.red('Invalid selection'));
  return null;
}

async function getBookById(bookId: string): Promise<Book | null> {
  const { data, error } = await supabase
    .from('books')
    .select('*')
    .eq('id', bookId)
    .single();

  if (error || !data) return null;
  return data as Book;
}

async function getSummaryForBook(bookId: string): Promise<Summary | null> {
  const { data, error } = await supabase
    .from('summaries')
    .select('*')
    .eq('book_id', bookId)
    .single();

  if (error || !data) return null;
  return data as Summary;
}

async function generateAudioForBook(
  book: Book,
  summary: Summary,
  options: { dryRun: boolean; voiceId?: string; force: boolean }
) {
  console.log(chalk.blue('\n' + '='.repeat(60)));
  console.log(chalk.bold(`Book: ${book.title}`));
  console.log(chalk.gray(`Authors: ${book.authors.join(', ')}`));
  console.log(chalk.gray(`ID: ${book.id}`));
  console.log(chalk.blue('='.repeat(60) + '\n'));

  // Check if audio already exists
  const hasAudio = await audioService.hasAudio(book.id!);
  if (hasAudio && !options.force) {
    console.log(chalk.yellow('This book already has audio. Use --force to regenerate.'));
    return;
  }

  // Step 1: Generate script
  console.log(chalk.cyan('Step 1: Generating audio script...'));
  const scriptResult = await audioService.generateAudioScript(book, summary);

  console.log(chalk.green(`\nScript generated:`));
  console.log(chalk.gray(`  Words: ${scriptResult.wordCount}`));
  console.log(chalk.gray(`  Est. Duration: ${scriptResult.estimatedDurationMinutes.toFixed(1)} minutes`));

  // Show cost estimate
  const { characterCount, estimatedCost } = audioService.estimateCost(scriptResult.script);
  console.log(chalk.yellow(`\nCost estimate:`));
  console.log(chalk.gray(`  Characters: ${characterCount.toLocaleString()}`));
  console.log(chalk.gray(`  Est. Cost: $${estimatedCost.toFixed(2)}`));

  // Show script preview
  console.log(chalk.cyan('\nScript preview (first 500 chars):'));
  console.log(chalk.gray('-'.repeat(40)));
  console.log(scriptResult.script.substring(0, 500) + '...');
  console.log(chalk.gray('-'.repeat(40)));

  if (options.dryRun) {
    console.log(chalk.yellow('\n[DRY RUN] Script generated but no audio created.'));
    console.log(chalk.gray('Full script saved to stdout. Remove --dry-run to generate audio.'));

    // Print full script
    console.log(chalk.cyan('\n' + '='.repeat(60)));
    console.log(chalk.bold('FULL SCRIPT:'));
    console.log(chalk.cyan('='.repeat(60) + '\n'));
    console.log(scriptResult.script);
    return;
  }

  // Confirm before generating audio (this costs money!)
  console.log();
  const confirm = await prompt(
    chalk.yellow(`Generate audio for $${estimatedCost.toFixed(2)}? (y/n): `)
  );

  if (confirm !== 'y' && confirm !== 'yes') {
    console.log(chalk.gray('Cancelled.'));
    return;
  }

  // Step 2: Generate audio
  console.log(chalk.cyan('\nStep 2: Generating audio with ElevenLabs...'));

  const result = await audioService.processAudioGeneration(
    book,
    summary,
    { voiceId: options.voiceId },
    undefined,
    (status, message) => {
      const statusColor = {
        script_generating: chalk.blue,
        audio_generating: chalk.yellow,
        uploading: chalk.cyan,
        completed: chalk.green,
        failed: chalk.red
      }[status] || chalk.white;

      console.log(statusColor(`  [${status}] ${message}`));
    }
  );

  // Success!
  console.log(chalk.green('\n' + '='.repeat(60)));
  console.log(chalk.bold.green('SUCCESS!'));
  console.log(chalk.green('='.repeat(60)));
  console.log();
  console.log(`  ${chalk.gray('Audio URL:')} ${result.audioUrl}`);
  console.log(`  ${chalk.gray('Duration:')} ${formatDuration(result.durationSeconds)}`);
  console.log(`  ${chalk.gray('File Size:')} ${formatFileSize(result.fileSizeBytes)}`);
  console.log(`  ${chalk.gray('Voice ID:')} ${result.voiceId}`);
  console.log();
}

function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

function formatFileSize(bytes: number): string {
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(2)} MB`;
}

async function main() {
  const args = parseArgs();

  if (args.help) {
    showHelp();
    return;
  }

  if (args.listMissing) {
    await listBooksWithoutAudio();
    return;
  }

  if (!args.bookId && !args.title) {
    console.log(chalk.red('Error: Please provide --book-id or --title'));
    console.log(chalk.gray('Use --help for usage information.'));
    process.exit(1);
  }

  // Find the book
  let book: Book | null = null;

  if (args.bookId) {
    book = await getBookById(args.bookId);
    if (!book) {
      console.log(chalk.red(`Book not found with ID: ${args.bookId}`));
      process.exit(1);
    }
  } else if (args.title) {
    book = await findBookByTitle(args.title);
    if (!book) {
      console.log(chalk.red(`No book found matching: ${args.title}`));
      process.exit(1);
    }
  }

  if (!book) {
    console.log(chalk.red('Could not find book.'));
    process.exit(1);
  }

  // Get summary
  const summary = await getSummaryForBook(book.id!);
  if (!summary) {
    console.log(chalk.red('Book does not have a summary. Generate a summary first.'));
    process.exit(1);
  }

  if (!summary.extended_summary) {
    console.log(chalk.yellow('Warning: Book does not have an extended summary.'));
    console.log(chalk.gray('Audio quality will be better with an extended summary.'));
    const proceed = await prompt('Continue anyway? (y/n): ');
    if (proceed !== 'y' && proceed !== 'yes') {
      console.log(chalk.gray('Cancelled. Run generate-extended-summaries first.'));
      process.exit(0);
    }
  }

  // Generate audio
  await generateAudioForBook(book, summary, {
    dryRun: args.dryRun,
    voiceId: args.voiceId,
    force: args.force
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(chalk.red('Error:'), error.message);
    process.exit(1);
  });
