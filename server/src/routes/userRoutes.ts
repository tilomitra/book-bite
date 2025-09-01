import express from 'express';
import { authenticate } from '../middleware/auth';
import { supabase } from '../config/supabase';
import { z } from 'zod';

const router = express.Router();

// Validation schemas
const favoriteSchema = z.object({
  book_id: z.string().uuid()
});

const readingHistorySchema = z.object({
  book_id: z.string().uuid(),
  reading_time_minutes: z.number().int().positive().optional(),
  completed: z.boolean().optional(),
  notes: z.string().max(1000).optional()
});

/**
 * GET /api/user/favorites
 * Get user's favorite books
 */
router.get('/favorites', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 20 } = req.query;
    
    const offset = (Number(page) - 1) * Number(limit);
    
    const { data: favorites, error } = await supabase
      .from('user_favorites')
      .select(`
        id,
        created_at,
        books (
          id,
          title,
          subtitle,
          authors,
          cover_url,
          categories,
          publisher,
          published_year
        )
      `)
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .range(offset, offset + Number(limit) - 1);
    
    if (error) {
      console.error('Error fetching favorites:', error);
      return res.status(500).json({ error: 'Failed to fetch favorites' });
    }
    
    res.json({
      favorites: favorites || [],
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: favorites?.length || 0
      }
    });
  } catch (error) {
    console.error('Favorites fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/user/favorites
 * Add a book to user's favorites
 */
router.post('/favorites', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const validation = favoriteSchema.safeParse(req.body);
    
    if (!validation.success) {
      return res.status(400).json({ 
        error: 'Invalid input',
        details: validation.error.errors
      });
    }
    
    const { book_id } = validation.data;
    
    // Check if book exists
    const { data: book, error: bookError } = await supabase
      .from('books')
      .select('id')
      .eq('id', book_id)
      .single();
    
    if (bookError || !book) {
      return res.status(404).json({ error: 'Book not found' });
    }
    
    // Add to favorites (ignore if already exists)
    const { data: favorite, error } = await supabase
      .from('user_favorites')
      .insert({
        user_id: userId,
        book_id: book_id
      })
      .select()
      .single();
    
    if (error) {
      if (error.code === '23505') { // Unique constraint violation
        return res.status(409).json({ error: 'Book already in favorites' });
      }
      console.error('Error adding to favorites:', error);
      return res.status(500).json({ error: 'Failed to add to favorites' });
    }
    
    res.status(201).json(favorite);
  } catch (error) {
    console.error('Add favorite error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * DELETE /api/user/favorites/:bookId
 * Remove a book from user's favorites
 */
router.delete('/favorites/:bookId', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId } = req.params;
    
    if (!bookId) {
      return res.status(400).json({ error: 'Book ID is required' });
    }
    
    const { error } = await supabase
      .from('user_favorites')
      .delete()
      .eq('user_id', userId)
      .eq('book_id', bookId);
    
    if (error) {
      console.error('Error removing from favorites:', error);
      return res.status(500).json({ error: 'Failed to remove from favorites' });
    }
    
    res.json({ message: 'Removed from favorites' });
  } catch (error) {
    console.error('Remove favorite error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/user/reading-history
 * Get user's reading history
 */
router.get('/reading-history', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 20 } = req.query;
    
    const offset = (Number(page) - 1) * Number(limit);
    
    const { data: history, error } = await supabase
      .from('user_reading_history')
      .select(`
        id,
        reading_time_minutes,
        completed,
        notes,
        created_at,
        updated_at,
        books (
          id,
          title,
          subtitle,
          authors,
          cover_url,
          categories,
          publisher,
          published_year
        )
      `)
      .eq('user_id', userId)
      .order('updated_at', { ascending: false })
      .range(offset, offset + Number(limit) - 1);
    
    if (error) {
      console.error('Error fetching reading history:', error);
      return res.status(500).json({ error: 'Failed to fetch reading history' });
    }
    
    res.json({
      history: history || [],
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: history?.length || 0
      }
    });
  } catch (error) {
    console.error('Reading history fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/user/reading-history
 * Add or update reading history entry
 */
router.post('/reading-history', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const validation = readingHistorySchema.safeParse(req.body);
    
    if (!validation.success) {
      return res.status(400).json({ 
        error: 'Invalid input',
        details: validation.error.errors
      });
    }
    
    const { book_id, reading_time_minutes, completed, notes } = validation.data;
    
    // Check if book exists
    const { data: book, error: bookError } = await supabase
      .from('books')
      .select('id')
      .eq('id', book_id)
      .single();
    
    if (bookError || !book) {
      return res.status(404).json({ error: 'Book not found' });
    }
    
    // Try to update existing entry first
    const { data: existing, error: existingError } = await supabase
      .from('user_reading_history')
      .select('id, reading_time_minutes')
      .eq('user_id', userId)
      .eq('book_id', book_id)
      .single();
    
    let result;
    
    if (existing && !existingError) {
      // Update existing entry
      const { data: updated, error: updateError } = await supabase
        .from('user_reading_history')
        .update({
          reading_time_minutes: (existing.reading_time_minutes || 0) + (reading_time_minutes || 0),
          completed: completed ?? false,
          notes: notes,
          updated_at: new Date().toISOString()
        })
        .eq('id', existing.id)
        .select()
        .single();
      
      if (updateError) {
        throw updateError;
      }
      result = updated;
    } else {
      // Create new entry
      const { data: created, error: createError } = await supabase
        .from('user_reading_history')
        .insert({
          user_id: userId,
          book_id: book_id,
          reading_time_minutes: reading_time_minutes || 0,
          completed: completed || false,
          notes: notes
        })
        .select()
        .single();
      
      if (createError) {
        throw createError;
      }
      result = created;
    }
    
    res.json(result);
  } catch (error) {
    console.error('Reading history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/user/recommendations
 * Get personalized book recommendations based on user's favorites and reading history
 */
router.get('/recommendations', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { limit = 10 } = req.query;
    
    // Get user's favorite categories
    const { data: userCategories, error: categoryError } = await supabase
      .from('user_favorites')
      .select(`
        books!inner (
          categories
        )
      `)
      .eq('user_id', userId);
    
    if (categoryError) {
      console.error('Error fetching user categories:', categoryError);
    }
    
    // Extract unique categories from user's favorites
    const favoriteCategories = new Set<string>();
    userCategories?.forEach(fav => {
      fav.books.categories?.forEach((cat: string) => favoriteCategories.add(cat));
    });
    
    const categoryArray = Array.from(favoriteCategories);
    
    // Get recommendations based on categories (if user has favorites)
    let recommendationsQuery = supabase
      .from('books')
      .select(`
        id,
        title,
        subtitle,
        authors,
        cover_url,
        categories,
        publisher,
        published_year,
        popularity_rank
      `)
      .limit(Number(limit));
    
    if (categoryArray.length > 0) {
      recommendationsQuery = recommendationsQuery.overlaps('categories', categoryArray);
    }
    
    // Exclude books already in favorites or reading history
    const { data: userBooks, error: userBooksError } = await supabase
      .from('user_favorites')
      .select('book_id')
      .eq('user_id', userId);
    
    if (!userBooksError && userBooks) {
      const userBookIds = userBooks.map(ub => ub.book_id);
      if (userBookIds.length > 0) {
        recommendationsQuery = recommendationsQuery.not('id', 'in', `(${userBookIds.join(',')})`);
      }
    }
    
    const { data: recommendations, error } = await recommendationsQuery
      .order('popularity_rank', { ascending: true, nullsLast: true })
      .order('created_at', { ascending: false });
    
    if (error) {
      console.error('Error fetching recommendations:', error);
      return res.status(500).json({ error: 'Failed to fetch recommendations' });
    }
    
    res.json({
      recommendations: recommendations || [],
      based_on_categories: categoryArray
    });
  } catch (error) {
    console.error('Recommendations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;