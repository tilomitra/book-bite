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

  const errMessage = err?.message || '';

  // Handle specific error types
  if (errMessage.includes('invalid input syntax for type uuid')) {
    status = 400;
    message = 'Invalid id';
  } else if (errMessage.includes('not found')) {
    status = 404;
    message = errMessage;
  } else if (errMessage.includes('Invalid') || errMessage.includes('required')) {
    status = 400;
    message = errMessage;
  } else if (errMessage.includes('Unauthorized') || errMessage.includes('jwt')) {
    status = 401;
    message = errMessage;
  } else if (errMessage.includes('Forbidden') || errMessage.includes('permission')) {
    status = 403;
    message = errMessage;
  }

  res.status(status).json({
    error: message,
    ...(process.env.DEBUG_ERRORS === 'true' && { stack: err?.stack })
  });
}