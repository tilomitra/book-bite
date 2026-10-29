import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import path from 'path';

import bookRoutes from './routes/bookRoutes';
import summaryRoutes from './routes/summaryRoutes';
import searchRoutes from './routes/searchRoutes';
import ratingsRoutes from './routes/ratingsRoutes';
import authRoutes from './routes/authRoutes';
import userRoutes from './routes/userRoutes';
import audioRoutes from './routes/audioRoutes';
import askRoutes from './routes/askRoutes';
import { errorHandler } from './middleware/errorHandler';

dotenv.config();

const app = express();
// Behind Render's proxy: use X-Forwarded-For so rate limits are per client, not per proxy
app.set('trust proxy', 1);
const PORT = process.env.PORT || 3000;

// Security middleware. The landing page hotlinks book covers (Google Books, Apple, Open Library), so images may come from any https host.
app.use(helmet({
  contentSecurityPolicy: {
    directives: { 'img-src': ["'self'", 'data:', 'https:'] }
  }
}));

// CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:8100'],
  credentials: true,
  optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'),
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api', limiter);

// Body parsing middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// Landing page (server/public): works from src/ under tsx and from dist/ after tsc
app.use(express.static(path.join(__dirname, '../public'), { maxAge: '10m' }));

// Health check endpoint
app.get('/health', (_, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/books', bookRoutes);
app.use('/api/summaries', summaryRoutes);
app.use('/api/search', searchRoutes);
app.use('/api', ratingsRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/user', userRoutes);
app.use('/api', audioRoutes);
app.use('/api/ask', askRoutes);

// Error handling middleware
app.use(errorHandler);

// 404 handler
app.use((_, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Start server
if (process.env.NODE_ENV !== 'test') {
  const HOST = process.env.HOST || '0.0.0.0';
  app.listen(Number(PORT), HOST, () => {
    console.log(`Server running on ${HOST}:${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}

export default app;