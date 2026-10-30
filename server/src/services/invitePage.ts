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
  <link href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,300..700;1,6..72,300..700&family=Geist:wght@400;500;600&family=Courier+Prime:wght@400;700&display=swap" rel="stylesheet">
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

    <section class="card-stage" aria-label="Invite code ${code}">
      <p class="card-eyebrow">Your friend's invite code</p>
      <div class="card" data-card data-copy-code="${code}" tabindex="0" role="button" aria-label="Invite code ${code}. Press to copy.">
        <div class="face">
          <span class="hole" aria-hidden="true"></span>
          <p class="code" aria-hidden="true">${[...code].map((c) => `<span>${c}</span>`).join('')}</p>
          <p class="card-tap" data-card-tap>Tap to copy</p>
        </div>
      </div>
      <p class="card-note">Join with it and you both get 5 more books.</p>
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
