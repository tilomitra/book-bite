import Anthropic from '@anthropic-ai/sdk';
import { Summary, KeyIdea, ApplicationPoint, Citation } from '../models/types';
import { v4 as uuidv4 } from 'uuid';

export class ClaudeService {
  private client: Anthropic;
  private model = 'claude-3-5-sonnet-20241022';

  constructor() {
    if (!process.env.ANTHROPIC_API_KEY) {
      throw new Error('Anthropic API key not configured');
    }
    
    this.client = new Anthropic({
      apiKey: process.env.ANTHROPIC_API_KEY
    });
  }

  async generateBookSummary(
    bookTitle: string,
    bookAuthors: string[],
    bookDescription: string,
    bookCategories: string[],
    style: 'brief' | 'full' = 'full'
  ): Promise<Omit<Summary, 'id' | 'book_id' | 'created_at' | 'updated_at'>> {
    const prompt = this.buildSummaryPrompt(
      bookTitle,
      bookAuthors,
      bookDescription,
      bookCategories,
      style
    );

    try {
      const response = await this.client.messages.create({
        model: this.model,
        max_tokens: 4000,
        temperature: 0.7,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      });

      const content = response.content[0];
      if (content.type !== 'text') {
        throw new Error('Unexpected response type from Claude');
      }

      const parsedResponse = JSON.parse(content.text);
      
      return this.transformClaudeResponseToSummary(parsedResponse, style);
    } catch (error) {
      console.error('Error generating summary with Claude:', error);
      throw new Error('Failed to generate book summary');
    }
  }

  private buildSummaryPrompt(
    title: string,
    authors: string[],
    description: string,
    categories: string[],
    style: 'brief' | 'full'
  ): string {
    const briefInstructions = style === 'brief' 
      ? 'Create a concise summary with 3-4 key ideas and 2-3 application points.'
      : 'Create a comprehensive summary with 5-7 key ideas and 4-5 application points.';

    return `Generate a structured book summary for the following book. ${briefInstructions}

Book Information:
- Title: ${title}
- Authors: ${authors.join(', ')}
- Categories: ${categories.join(', ')}
- Description: ${description}

Please provide a JSON response with the following structure:
{
  "oneSentenceHook": "A compelling one-sentence summary that captures the essence of the book",
  "keyIdeas": [
    {
      "idea": "The main insight or concept",
      "tags": ["relevant", "tags"],
      "confidence": "high|medium|low",
      "sources": ["Chapter reference or context"]
    }
  ],
  "howToApply": [
    {
      "action": "A specific, actionable way to apply the book's concepts",
      "tags": ["relevant", "tags"]
    }
  ],
  "commonPitfalls": ["Common mistakes when applying these concepts"],
  "critiques": ["Valid criticisms or limitations of the book's arguments"],
  "whoShouldRead": "Description of the ideal reader for this book",
  "limitations": "Key limitations or caveats about the book's content",
  "citations": [
    {
      "source": "Source name",
      "url": "Optional URL if available"
    }
  ],
  "readTimeMinutes": estimated_reading_time_in_minutes
}

Ensure all arrays have at least one item, and confidence levels are realistic based on the description provided.`;
  }

  private transformClaudeResponseToSummary(
    response: any,
    style: 'brief' | 'full'
  ): Omit<Summary, 'id' | 'book_id' | 'created_at' | 'updated_at'> {
    // Transform key ideas with generated IDs
    const keyIdeas: KeyIdea[] = response.keyIdeas.map((idea: any) => ({
      id: uuidv4(),
      idea: idea.idea,
      tags: idea.tags || [],
      confidence: idea.confidence || 'medium',
      sources: idea.sources || []
    }));

    // Transform application points with generated IDs
    const howToApply: ApplicationPoint[] = response.howToApply.map((point: any) => ({
      id: uuidv4(),
      action: point.action,
      tags: point.tags || []
    }));

    // Transform citations
    const citations: Citation[] = (response.citations || []).map((citation: any) => ({
      source: citation.source,
      url: citation.url || null
    }));

    return {
      one_sentence_hook: response.oneSentenceHook,
      key_ideas: keyIdeas,
      how_to_apply: howToApply,
      common_pitfalls: response.commonPitfalls || [],
      critiques: response.critiques || [],
      who_should_read: response.whoShouldRead || '',
      limitations: response.limitations || '',
      citations: citations,
      read_time_minutes: response.readTimeMinutes || 15,
      style: style,
      llm_model: this.model,
      llm_version: '20241022',
      generation_date: new Date()
    };
  }

  async enhanceSummaryWithFullText(
    existingSummary: Summary,
    fullText: string
  ): Promise<Omit<Summary, 'id' | 'book_id' | 'created_at' | 'updated_at'>> {
    const prompt = `Given the following book text and existing summary, enhance the summary with more specific details and examples from the actual text.

Existing Summary:
${JSON.stringify(existingSummary, null, 2)}

Book Text (excerpt):
${fullText.substring(0, 10000)} // Limit to first 10k characters for token management

Please enhance the summary with:
1. More specific examples from the text
2. Direct quotes where relevant
3. Page or chapter references
4. More nuanced critiques based on the actual content
5. Updated confidence levels based on evidence in the text

Return the enhanced summary in the same JSON structure as the input.`;

    try {
      const response = await this.client.messages.create({
        model: this.model,
        max_tokens: 4000,
        temperature: 0.5,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      });

      const content = response.content[0];
      if (content.type !== 'text') {
        throw new Error('Unexpected response type from Claude');
      }

      const parsedResponse = JSON.parse(content.text);
      return this.transformClaudeResponseToSummary(parsedResponse, existingSummary.style);
    } catch (error) {
      console.error('Error enhancing summary:', error);
      // Return original summary if enhancement fails
      const { id, book_id, created_at, updated_at, ...summaryWithoutIds } = existingSummary;
      return summaryWithoutIds;
    }
  }
}