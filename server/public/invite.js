// Invite page: the library card is a 3D object you can tilt; tapping it copies the code.
const card = document.querySelector('[data-card]');
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (card) {
  let dragging = false;
  let moved = false;
  let start = 0;

  const tilt = (x, y) => {
    // x, y in -1...1 from the card's centre
    card.style.setProperty('--ry', `${x * 16}deg`);
    card.style.setProperty('--rx', `${-y * 12}deg`);
    card.style.setProperty('--gx', `${50 + x * 40}%`);
    card.style.setProperty('--gy', `${40 + y * 40}%`);
  };

  const fromEvent = (event) => {
    const rect = card.getBoundingClientRect();
    return [
      Math.max(-1, Math.min(1, ((event.clientX - rect.left) / rect.width) * 2 - 1)),
      Math.max(-1, Math.min(1, ((event.clientY - rect.top) / rect.height) * 2 - 1)),
    ];
  };

  if (!reduceMotion) {
    card.addEventListener('pointermove', (event) => {
      if (event.pointerType === 'mouse' || dragging) {
        if (dragging && Math.abs(event.clientX - start) > 6) moved = true;
        card.classList.add('is-tilting');
        tilt(...fromEvent(event));
      }
    });
    card.addEventListener('pointerdown', (event) => {
      dragging = true;
      moved = false;
      start = event.clientX;
      card.setPointerCapture(event.pointerId);
      tilt(...fromEvent(event));
    });
    const release = () => {
      dragging = false;
      card.classList.remove('is-tilting');
      tilt(0, 0);
    };
    card.addEventListener('pointerup', release);
    card.addEventListener('pointercancel', release);
    card.addEventListener('pointerleave', (event) => { if (event.pointerType === 'mouse') release(); });

    // A slow idle float, so the card reads as an object before anyone touches it
    const float = (time) => {
      if (!card.classList.contains('is-tilting') && !dragging) {
        const t = time / 1000;
        tilt(Math.sin(t * 0.7) * 0.25, Math.cos(t * 0.9) * 0.2);
      }
      requestAnimationFrame(float);
    };
    setTimeout(() => requestAnimationFrame(float), 900);
  }

  const copy = async () => {
    const label = card.querySelector('[data-card-tap]');
    try {
      await navigator.clipboard.writeText(card.dataset.copyCode);
      label.textContent = 'Copied';
    } catch {
      label.textContent = card.dataset.copyCode;
    }
  };
  card.addEventListener('click', () => { if (!moved) copy(); });
  card.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      copy();
    }
  });
}
