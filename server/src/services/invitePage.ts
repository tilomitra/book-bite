/**
 * The page an invite link opens (`/invite/): who it's from isn't known, so it says what the
 * friend gets, shows the code to copy, and links to the app. "Open BookBite" uses the app's URL scheme,
 * which works once the app is installed. Styles in public/invite.css, the copy button in public/invite.js
 * (the CSP blocks inline scripts).
 */
export function appDownloadUrl(): string {
  return process.env.APP_STORE_URL || 'https://testflight.apple.com/join/BOOKBITE';
}

/** `code` must already be a normalized invite code (letters and digits only), so it needs no escaping */
export function invitePage(code: string): string {
  const download = appDownloadUrl().replace(/&/g, '&amp;').replace(/"/g, '&quot;');
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>5 free books · BookBite</title>
  <meta name="description" content="A friend gave you 5 free book summaries on BookBite. Use code ${code}.">
  <meta property="og:title" content="A friend gave you 5 books on BookBite">
  <meta property="og:description" content="Key ideas from the best non-fiction, in 15 minutes. Use code ${code}.">
  <meta property="og:image" content="/icon.png">
  <meta name="theme-color" content="#f7f2e8">
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,300..700;1,6..72,300..700&family=Geist:wght@400;500;600&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/invite.css">
</head>
<body>
  <main class="invite">
    <a class="brand" href="/" aria-label="BookBite home">
      <img src="/icon.png" alt="" width="40" height="40">
    </a>
    <p class="eyebrow">An invitation</p>
    <h1>A friend gave you <em>5&nbsp;books.</em></h1>
    <p class="dek">BookBite gives you the key ideas of the best non-fiction in 15 minutes. Read or listen, then ask how they apply to your own life.</p>

    <section class="card" aria-label="Your invite code">
      <p class="card-label">Library card</p>
      <p class="code" id="code">${code}</p>
      <button class="copy" type="button" data-copy="${code}">Copy code</button>
      <p class="card-note">You both get 5 more books when you join with it.</p>
    </section>

    <ol class="steps">
      <li><a class="button" href="${download}" rel="noopener">Get BookBite</a></li>
      <li><span>Create your account.</span></li>
      <li><span>Enter the code in Library, or <a href="bookbite://invite/${code}">tap here</a> once the app is installed.</span></li>
    </ol>
  </main>
  <script src="/invite.js"></script>
</body>
</html>
`;
}
