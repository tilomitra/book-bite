import OpenAI from 'openai';
import { supabase } from '../config/supabase';
import { ChatConversation, ChatMessage, Book, Summary } from '../models/types';

export class ChatService {
  private openai: OpenAI;

  constructor() {
    this.openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }

  async createConversation(bookId: string): Promise<ChatConversation> {
    const { data, error } = await supabase
      .from('chat_conversations')
      .insert({
        book_id: bookId,
        title: null
      })
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to create conversation: ${error.message}`);
    }

    return data;
  }

  async getConversation(conversationId: string): Promise<ChatConversation | null> {
    const { data, error } = await supabase
      .from('chat_conversations')
      .select('*')
      .eq('id', conversationId)
      .single();

    if (error) {
      if (error.code === 'PGRST116') return null; // Not found
      throw new Error(`Failed to fetch conversation: ${error.message}`);
    }

    return data;
  }

  async getConversationMessages(conversationId: string): Promise<ChatMessage[]> {
    const { data, error } = await supabase
      .from('chat_messages')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true });

    if (error) {
      throw new Error(`Failed to fetch messages: ${error.message}`);
    }

    return data || [];
  }

  async addMessage(conversationId: string, role: 'user' | 'assistant', content: string): Promise<ChatMessage> {
    const { data, error } = await supabase
      .from('chat_messages')
      .insert({
        conversation_id: conversationId,
        role,
        content
      })
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to add message: ${error.message}`);
    }

    return data;
  }

  async updateConversationTitle(conversationId: string, title: string): Promise<void> {
    const { error } = await supabase
      .from('chat_conversations')
      .update({ title })
      .eq('id', conversationId);

    if (error) {
      throw new Error(`Failed to update conversation title: ${error.message}`);
    }
  }

  async deleteConversation(conversationId: string): Promise<void> {
    const { error } = await supabase
      .from('chat_conversations')
      .delete()
      .eq('id', conversationId);

    if (error) {
      throw new Error(`Failed to delete conversation: ${error.message}`);
    }
  }

  async getBookContext(bookId: string): Promise<{ book: Book; summary?: Summary }> {
    // Get book details
    const { data: book, error: bookError } = await supabase
      .from('books')
      .select('*')
      .eq('id', bookId)
      .single();

    if (bookError) {
      throw new Error(`Failed to fetch book: ${bookError.message}`);
    }

    // Get summary if available
    const { data: summary } = await supabase
      .from('summaries')
      .select('*')
      .eq('book_id', bookId)
      .single();

    return { book, summary };
  }

  async generateResponse(
    conversationId: string, 
    userMessage: string, 
    bookContext: { book: Book; summary?: Summary }
  ): Promise<string> {
    // Save user message
    await this.addMessage(conversationId, 'user', userMessage);

    // Get conversation history
    const messages = await this.getConversationMessages(conversationId);

    // Build context prompt
    const systemPrompt = this.buildSystemPrompt(bookContext);

    // Prepare messages for OpenAI
    const openaiMessages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
      { role: 'system', content: systemPrompt },
      ...messages.map(msg => ({
        role: msg.role as 'user' | 'assistant',
        content: msg.content
      }))
    ];

    try {
      const completion = await this.openai.chat.completions.create({
        model: 'gpt-4',
        messages: openaiMessages,
        max_tokens: 1000,
        temperature: 0.7,
      });

      const assistantResponse = completion.choices[0]?.message?.content;
      if (!assistantResponse) {
        throw new Error('No response from OpenAI');
      }

      // Save assistant response
      await this.addMessage(conversationId, 'assistant', assistantResponse);

      // Auto-generate title for first message
      if (messages.length === 1) { // Only user message exists
        await this.generateConversationTitle(conversationId, userMessage);
      }

      return assistantResponse;
    } catch (error) {
      console.error('OpenAI API error:', error);
      throw new Error('Failed to generate response. Please try again.');
    }
  }

  async generateStreamingResponse(
    conversationId: string, 
    userMessage: string, 
    bookContext: { book: Book; summary?: Summary },
    onChunk: (chunk: string, isComplete: boolean) => void
  ): Promise<void> {
    // Save user message
    await this.addMessage(conversationId, 'user', userMessage);

    // Get conversation history
    const messages = await this.getConversationMessages(conversationId);

    // Build context prompt
    const systemPrompt = this.buildSystemPrompt(bookContext);

    // Prepare messages for OpenAI
    const openaiMessages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
      { role: 'system', content: systemPrompt },
      ...messages.map(msg => ({
        role: msg.role as 'user' | 'assistant',
        content: msg.content
      }))
    ];

    try {
      const stream = await this.openai.chat.completions.create({
        model: 'gpt-4',
        messages: openaiMessages,
        max_tokens: 1000,
        temperature: 0.7,
        stream: true,
      });

      let fullResponse = '';
      
      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || '';
        if (content) {
          fullResponse += content;
          onChunk(content, false);
        }
      }

      if (!fullResponse) {
        throw new Error('No response from OpenAI');
      }

      // Save assistant response
      await this.addMessage(conversationId, 'assistant', fullResponse);

      // Auto-generate title for first message
      if (messages.length === 1) { // Only user message exists
        await this.generateConversationTitle(conversationId, userMessage);
      }

      // Send completion signal
      onChunk('', true);
    } catch (error) {
      console.error('OpenAI API streaming error:', error);
      throw new Error('Failed to generate response. Please try again.');
    }
  }

  private buildSystemPrompt(context: { book: Book; summary?: Summary }): string {
    const { book, summary } = context;
    
    let prompt = `You are a knowledgeable assistant helping someone understand and discuss the book "${book.title}"`;
    
    if (book.authors.length > 0) {
      prompt += ` by ${book.authors.join(', ')}`;
    }
    
    prompt += '.\n\n';
    
    // Add book description if available
    if (book.description) {
      prompt += `Book Description: ${book.description}\n\n`;
    }
    
    // Add summary context if available
    if (summary) {
      prompt += `Book Summary Context:\n`;
      prompt += `- One-sentence hook: ${summary.one_sentence_hook}\n`;
      
      if (summary.key_ideas && Array.isArray(summary.key_ideas)) {
        prompt += `- Key Ideas: ${summary.key_ideas.map((idea: any) => idea.idea || idea).join('; ')}\n`;
      }
      
      if (summary.who_should_read) {
        prompt += `- Target Audience: ${summary.who_should_read}\n`;
      }
      
      if (summary.extended_summary) {
        prompt += `- Extended Summary: ${summary.extended_summary}\n`;
      }
      
      prompt += '\n';
    }
    
    prompt += `Guidelines for responses:
1. Stay focused on topics related to this book and its themes
2. Reference specific concepts, ideas, or examples from the book when relevant
3. Be helpful, informative, and engaging
4. If asked about topics unrelated to the book, gently redirect the conversation back to the book
5. Keep responses concise but informative (aim for 2-4 paragraphs)
6. Use a conversational, approachable tone
7. When discussing applications, relate them to the book's teachings
8. **IMPORTANT: Always end your response with an actionable follow-up offer to encourage continued conversation. Use phrases like "Would you like me to..." or "How about I..." to offer specific help. Examples:**
   - "Would you like me to explain how others have successfully applied these concepts?"
   - "How about I share some practical exercises based on this chapter?"
   - "Would you like me to dive deeper into any particular aspect of this idea?"
   - "How about I suggest some ways to implement this in daily life?"
   - "Would you like me to explore what the author says about common challenges with this approach?"
   - "How about I explain how this concept connects to other ideas in the book?"`;

    return prompt;
  }

  private async generateConversationTitle(conversationId: string, firstMessage: string): Promise<void> {
    try {
      const completion = await this.openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'Generate a short, descriptive title (max 6 words) for a conversation that starts with this message. Return only the title, no quotes or extra text.'
          },
          {
            role: 'user',
            content: firstMessage
          }
        ],
        max_tokens: 20,
        temperature: 0.5,
      });

      const title = completion.choices[0]?.message?.content?.trim();
      if (title) {
        await this.updateConversationTitle(conversationId, title);
      }
    } catch (error) {
      console.error('Failed to generate conversation title:', error);
      // Continue without title - not critical
    }
  }

  async getBookConversations(bookId: string): Promise<ChatConversation[]> {
    const { data, error } = await supabase
      .from('chat_conversations')
      .select('*')
      .eq('book_id', bookId)
      .order('updated_at', { ascending: false });

    if (error) {
      throw new Error(`Failed to fetch conversations: ${error.message}`);
    }

    return data || [];
  }
}