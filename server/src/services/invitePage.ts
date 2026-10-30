/**
 * The page an invite link opens (`/invite/): who it's from isn't known, so it says what the
 * friend gets, shows the code to copy, and links to the app. "Open BookBite" uses the app's URL scheme,
 * which works once the app is installed. Styles in public/invite.css, the copy button in public/invite.js
 * (the CSP blocks inline scripts).
 */
export function appDownloadUrl(): string {
  return process.env.APP_STORE_URL || 'https://testflight.apple.com/join/BOOKBITE';
}

/** Bars of a pretend barcode, fixed per code: thin and thick strokes from the code's characters */
export function barcode(code: string): string {
  const bars: string[] = [];
  for (const ch of code + code.split('').reverse().join('')) {
    const n = ch.charCodeAt(0);
    for (let bit = 0; bit < 4; bit++) {
      const wide = (n >> bit) & 1;
      bars.push(`<i style="width:${wide ? 3 : 1}px"></i>`);
    }
  }
  return bars.join('');
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
      <div class="card" data-card tabindex="0" role="button" aria-label="Library card with invite code ${code}. Press to turn over.">
        <div class="face front">
          <span class="hole" aria-hidden="true"></span>
          <header class="card-head">
            <div>
              <p class="card-brand">BookBite</p>
              <p class="card-sub">Public Library · Borrower's Card</p>
            </div>
            <span class="seal" aria-hidden="true">B</span>
          </header>
          <p class="field-label">Invite No.</p>
          <p class="code" aria-hidden="true">${[...code].map((c) => `<span>${c}</span>`).join('')}</p>
          <div class="fields">
            <p><span class="field-label">Good for</span><span class="typed">5 free books</span></p>
            <p><span class="field-label">Plus</span><span class="typed">5 for your friend</span></p>
          </div>
          <div class="barcode" aria-hidden="true">${barcode(code)}</div>
        </div>
        <div class="face back" aria-hidden="true">
          <p class="back-title">Date due</p>
          <div class="due">${[0, 1, 2, 3, 4, 5].map((i) => `<span>${i === 0 ? '<b class="stamp">JOINED<br>+5</b>' : ''}</span>`).join('')}</div>
          <p class="back-note">Each friend who joins with this card earns a stamp: 5 books for them, 5 for you.</p>
        </div>
      </div>
      <p class="card-hint">Drag to tilt · tap to turn over</p>
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
