#!/usr/bin/env ts-node

import { config } from 'dotenv';
import path from 'path';
import { populateBusinessBooks } from './populate-business-books';
import { generateSummariesForFeaturedBooks } from './generate-summaries';

// Load environment variables
config({ path: path.join(__dirname, '../.env') });

async function setupFeaturedBooks() {
  console.log('🚀 Setting up featured books with summaries...');
  console.log('This will populate the database with business books and generate AI summaries.\n');
  
  try {
    // Step 1: Populate business books
    console.log('📚 STEP 1: Populating featured business books...');
    const populationResult = await populateBusinessBooks();
    
    if (populationResult.successful.length === 0) {
      console.log('❌ No books were successfully imported. Aborting summary generation.');
      return;
    }
    
    // Add a pause between steps
    console.log('\n⏱️  Waiting 5 seconds before starting summary generation...');
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Step 2: Generate summaries
    console.log('\n📝 STEP 2: Generating AI summaries for featured books...');
    const summaryResult = await generateSummariesForFeaturedBooks();
    
    // Final summary
    console.log('\n🎯 FINAL RESULTS:');
    console.log(`📚 Books imported/updated: ${populationResult.successful.length}`);
    console.log(`📝 Summaries generated: ${summaryResult.successful.length}`);
    console.log(`❌ Total failures: ${populationResult.failed.length + summaryResult.failed.length}`);
    
    if (summaryResult.successful.length > 0) {
      console.log('\n✨ Your database now has featured books with AI-generated summaries!');
      console.log('The iOS app can now fetch these books and display their summaries.');
    }
    
  } catch (error) {
    console.error('❌ Setup failed:', error);
    throw error;
  }
}

// Run the script
if (require.main === module) {
  setupFeaturedBooks()
    .then(() => {
      console.log('\n🎉 Featured books setup completed successfully!');
      process.exit(0);
    })
    .catch(error => {
      console.error('\n💥 Setup failed:', error);
      process.exit(1);
    });
}

export { setupFeaturedBooks };