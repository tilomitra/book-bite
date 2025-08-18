# Deployment Guide for Render.com

## Prerequisites

1. **Render.com Account**: Sign up at [render.com](https://render.com)
2. **GitHub Repository**: Your code should be in a GitHub repository
3. **External Services**:
   - Supabase account for PostgreSQL database
   - Redis service (Render Redis add-on or external)
   - Google Books API key
   - OpenAI API key

## Deployment Steps

### 1. Prepare Your Repository

Ensure your repository contains:
- `render.yaml` (deployment configuration)
- `package.json` with proper build and start scripts
- TypeScript configuration (`tsconfig.json`)

### 2. Create Redis Service (Optional)

If you need Redis for job queues:
1. Go to Render Dashboard → Create → Redis
2. Choose a plan (free tier available)
3. Note the Redis URL for environment variables

### 3. Deploy Web Service

1. Go to Render Dashboard → Create → Web Service
2. Connect your GitHub repository
3. Configure the service:
   - **Name**: bookbite-server
   - **Environment**: Node
   - **Region**: Choose closest to your users
   - **Branch**: main (or your default branch)
   - **Root Directory**: server (since your server code is in /server folder)
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm start`

### 4. Set Environment Variables

In your Render service settings, add these environment variables:

#### Required Variables:
```
NODE_ENV=production
PORT=10000
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your_supabase_service_key
GOOGLE_BOOKS_API_KEY=your_google_books_api_key
OPENAI_API_KEY=sk-your_openai_api_key
```

#### Optional Variables:
```
REDIS_URL=redis://your-redis-url:6379
CORS_ORIGIN=https://your-domain.com
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

### 5. Configure CORS

Update the `CORS_ORIGIN` environment variable with your actual domains:
- For iOS app: Add your app's domain if it makes web requests
- For web apps: Add your frontend domains
- For development: Use `*` (not recommended for production)

### 6. Health Check

The server includes a health check endpoint at `/health` that Render will use to monitor your service.

### 7. Monitor Deployment

1. Watch the build logs in Render dashboard
2. Verify the service starts successfully
3. Test the health endpoint: `https://your-service.onrender.com/health`
4. Test API endpoints: `https://your-service.onrender.com/api/books`

## Post-Deployment

### Database Setup

1. Ensure your Supabase database schema is up to date
2. Run any necessary data population scripts locally pointing to production DB
3. Verify database connectivity from the deployed service

### iOS App Configuration

Update your iOS app's server URL to point to your Render service:
```swift
// In AppConfiguration.swift
static let serverURL = "https://your-service.onrender.com"
```

### Monitoring

- Use Render's built-in metrics and logs
- Monitor API response times and error rates
- Set up alerts for service downtime

## Troubleshooting

### Common Issues:

1. **Build Failures**: Check build logs for missing dependencies or TypeScript errors
2. **Startup Errors**: Verify environment variables are set correctly
3. **Database Connection**: Ensure Supabase URL and key are valid
4. **CORS Errors**: Update CORS_ORIGIN with correct domains
5. **Memory Issues**: Consider upgrading to a paid plan for better performance

### Useful Commands:

```bash
# View logs
render logs --service=your-service-id

# Restart service
render restart --service=your-service-id
```

## Cost Optimization

- **Free Tier**: Render provides 750 hours/month free (enough for one service)
- **Sleep Mode**: Free services sleep after 15 minutes of inactivity
- **Scaling**: Consider upgrading to paid plans for production workloads

## Security Notes

- Keep API keys secure in environment variables
- Use HTTPS only in production
- Implement proper rate limiting
- Monitor for unusual traffic patterns
- Regular security updates for dependencies