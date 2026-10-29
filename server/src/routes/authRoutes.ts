import express from 'express';
import { authenticate } from '../middleware/auth';
import { supabase } from '../config/supabase';
import { z } from 'zod';

const router = express.Router();

// Validation schemas
const updateProfileSchema = z.object({
  display_name: z.string().min(1).max(100).optional(),
  bio: z.string().max(500).optional(),
  favorite_categories: z.array(z.string()).optional(),
  reading_goal: z.number().int().positive().optional()
});

/**
 * GET /api/auth/profile
 * Get the current user's profile
 */
router.get('/profile', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get user profile from the user_profiles table
    const { data: profile, error } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .single();
    
    if (error) {
      console.error('Error fetching user profile:', error);
      return res.status(500).json({ error: 'Failed to fetch profile' });
    }
    
    return res.json(profile);
  } catch (error) {
    console.error('Profile fetch error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * PUT /api/auth/profile
 * Update the current user's profile
 */
router.put('/profile', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const validation = updateProfileSchema.safeParse(req.body);
    
    if (!validation.success) {
      return res.status(400).json({ 
        error: 'Invalid input',
        details: validation.error.errors
      });
    }
    
    const updates = validation.data;
    
    // Update user profile
    const { data: profile, error } = await supabase
      .from('user_profiles')
      .update({
        ...updates,
        updated_at: new Date().toISOString()
      })
      .eq('id', userId)
      .select()
      .single();
    
    if (error) {
      console.error('Error updating user profile:', error);
      return res.status(500).json({ error: 'Failed to update profile' });
    }
    
    return res.json(profile);
  } catch (error) {
    console.error('Profile update error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/auth/stats
 * Get user reading statistics
 */
router.get('/stats', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get reading statistics
    const [favoritesResult, historyResult] = await Promise.all([
      supabase
        .from('user_favorites')
        .select('id')
        .eq('user_id', userId),
      supabase
        .from('user_reading_history')
        .select('id, reading_time_minutes')
        .eq('user_id', userId)
    ]);
    
    const favoriteCount = favoritesResult.data?.length || 0;
    const booksRead = historyResult.data?.length || 0;
    const totalReadingTime = historyResult.data?.reduce(
      (sum, entry) => sum + (entry.reading_time_minutes || 0), 
      0
    ) || 0;
    
    return res.json({
      books_read: booksRead,
      favorite_books: favoriteCount,
      total_reading_time_minutes: totalReadingTime
    });
  } catch (error) {
    console.error('Stats fetch error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * DELETE /api/auth/account
 * Deletes the user from Supabase Auth. Their profile, favorites and reading history are removed
 * with it (ON DELETE CASCADE on auth.users). Required by App Store guideline 5.1.1(v).
 */
router.delete('/account', authenticate, async (req, res) => {
  try {
    const { error } = await supabase.auth.admin.deleteUser(req.user.id);

    if (error) {
      console.error('Error deleting account:', error);
      return res.status(500).json({ error: 'Failed to delete account' });
    }

    return res.json({ message: 'Account deleted' });
  } catch (error) {
    console.error('Account deletion error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;