import express from 'express';
import { ChatService } from '../services/ChatService';

const router = express.Router();
const chatService = new ChatService();

// Create a new conversation for a book
router.post('/books/:bookId/chat/conversations', async (req, res) => {
  try {
    const { bookId } = req.params;
    
    // Validate bookId is UUID
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(bookId)) {
      return res.status(400).json({ error: 'Invalid book ID format' });
    }

    const conversation = await chatService.createConversation(bookId);
    return res.json(conversation);
  } catch (error) {
    console.error('Error creating conversation:', error);
    return res.status(500).json({ error: 'Failed to create conversation' });
  }
});

// Get conversation details with messages
router.get('/books/:bookId/chat/conversations/:conversationId', async (req, res) => {
  try {
    const { conversationId } = req.params;
    
    // Validate conversationId is UUID
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(conversationId)) {
      return res.status(400).json({ error: 'Invalid conversation ID format' });
    }

    const conversation = await chatService.getConversation(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    const messages = await chatService.getConversationMessages(conversationId);
    
    return res.json({
      conversation,
      messages
    });
  } catch (error) {
    console.error('Error fetching conversation:', error);
    return res.status(500).json({ error: 'Failed to fetch conversation' });
  }
});

// Send a message in a conversation (non-streaming)
router.post('/books/:bookId/chat/conversations/:conversationId/messages', async (req, res) => {
  try {
    const { bookId, conversationId } = req.params;
    const { message } = req.body;
    
    // Validate UUIDs
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(bookId)) {
      return res.status(400).json({ error: 'Invalid book ID format' });
    }
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(conversationId)) {
      return res.status(400).json({ error: 'Invalid conversation ID format' });
    }
    
    // Validate message
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'Message is required' });
    }

    if (message.length > 2000) {
      return res.status(400).json({ error: 'Message too long (max 2000 characters)' });
    }

    // Verify conversation exists and belongs to book
    const conversation = await chatService.getConversation(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }
    if (conversation.book_id !== bookId) {
      return res.status(400).json({ error: 'Conversation does not belong to this book' });
    }

    // Get book context
    const bookContext = await chatService.getBookContext(bookId);
    
    // Generate response
    const assistantResponse = await chatService.generateResponse(
      conversationId, 
      message.trim(), 
      bookContext
    );

    // Get updated messages
    const messages = await chatService.getConversationMessages(conversationId);
    
    return res.json({
      message: assistantResponse,
      messages
    });
  } catch (error) {
    console.error('Error sending message:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to send message';
    return res.status(500).json({ error: errorMessage });
  }
});

// Send a message in a conversation (streaming)
router.post('/books/:bookId/chat/conversations/:conversationId/messages/stream', async (req, res) => {
  try {
    const { bookId, conversationId } = req.params;
    const { message } = req.body;
    
    // Validate UUIDs
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(bookId)) {
      return res.status(400).json({ error: 'Invalid book ID format' });
    }
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(conversationId)) {
      return res.status(400).json({ error: 'Invalid conversation ID format' });
    }
    
    // Validate message
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'Message is required' });
    }

    if (message.length > 2000) {
      return res.status(400).json({ error: 'Message too long (max 2000 characters)' });
    }

    // Verify conversation exists and belongs to book
    const conversation = await chatService.getConversation(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }
    if (conversation.book_id !== bookId) {
      return res.status(400).json({ error: 'Conversation does not belong to this book' });
    }

    // Set up SSE headers
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Cache-Control'
    });

    // Get book context
    const bookContext = await chatService.getBookContext(bookId);
    
    // Generate streaming response
    await chatService.generateStreamingResponse(
      conversationId,
      message.trim(),
      bookContext,
      (chunk: string, isComplete: boolean) => {
        if (isComplete) {
          res.write(`data: ${JSON.stringify({ type: 'complete', content: chunk })}\n\n`);
          res.end();
        } else {
          res.write(`data: ${JSON.stringify({ type: 'chunk', content: chunk })}\n\n`);
        }
      }
    );

  } catch (error) {
    console.error('Error sending streaming message:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to send message';
    res.write(`data: ${JSON.stringify({ type: 'error', error: errorMessage })}\n\n`);
    res.end();
  }
  
  // Note: No return needed here as the response is handled by the streaming callback
  return;
});

// Get all conversations for a book
router.get('/books/:bookId/chat/conversations', async (req, res) => {
  try {
    const { bookId } = req.params;
    
    // Validate bookId is UUID
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(bookId)) {
      return res.status(400).json({ error: 'Invalid book ID format' });
    }

    const conversations = await chatService.getBookConversations(bookId);
    return res.json(conversations);
  } catch (error) {
    console.error('Error fetching conversations:', error);
    return res.status(500).json({ error: 'Failed to fetch conversations' });
  }
});

// Delete a conversation
router.delete('/books/:bookId/chat/conversations/:conversationId', async (req, res) => {
  try {
    const { bookId, conversationId } = req.params;
    
    // Validate UUIDs
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(bookId)) {
      return res.status(400).json({ error: 'Invalid book ID format' });
    }
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(conversationId)) {
      return res.status(400).json({ error: 'Invalid conversation ID format' });
    }

    // Verify conversation exists and belongs to book
    const conversation = await chatService.getConversation(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }
    if (conversation.book_id !== bookId) {
      return res.status(400).json({ error: 'Conversation does not belong to this book' });
    }

    await chatService.deleteConversation(conversationId);
    return res.json({ success: true });
  } catch (error) {
    console.error('Error deleting conversation:', error);
    return res.status(500).json({ error: 'Failed to delete conversation' });
  }
});

export default router;