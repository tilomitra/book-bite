import { Request, Response, NextFunction } from 'express';

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  console.error('Error:', err);

  // Default error
  let status = 500;
  let message = 'Internal server error';

  // Handle specific error types
  if (err.message.includes('not found')) {
    status = 404;
    message = err.message;
  } else if (err.message.includes('Invalid') || err.message.includes('required')) {
    status = 400;
    message = err.message;
  } else if (err.message.includes('Unauthorized') || err.message.includes('token')) {
    status = 401;
    message = err.message;
  } else if (err.message.includes('Forbidden') || err.message.includes('permission')) {
    status = 403;
    message = err.message;
  }

  res.status(status).json({
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
}