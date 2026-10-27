// slides.html#3 shows slide 3 alone (for rendering); no hash shows all slides stacked.
const n = location.hash.slice(1);
const slide = n && document.getElementById('s' + n);
if (slide) slide.classList.add('on'); else document.body.classList.add('all');
