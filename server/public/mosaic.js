// Hero book mosaic: ~600 hardcover books (boxes with cover, spine, page edges) drawn in one instanced WebGL2 call (plus one for their shadows).
// Covers come from a same-origin atlas (covers-atlas.webp) because the original cover hosts don't send CORS headers.
(() => {
  const canvas = document.querySelector('[data-gl]');
  const hero = document.querySelector('[data-hero]');
  const ATLAS = window.BB_ATLAS;
  if (!canvas || !hero || !ATLAS) return;
  const gl = canvas.getContext('webgl2', { antialias: true, alpha: true, premultipliedAlpha: true, powerPreference: 'high-performance' });
  if (!gl) { hero.classList.add('no-gl'); return; }
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const VERT = `#version 300 es
  precision highp float;
  layout(location = 0) in vec4 aVert;     // box corner (-0.5..0.5) and face: 0 cover, 1 back, 2 fore-edge, 3 spine, 4 head, 5 tail
  layout(location = 1) in vec4 aInst;     // column, row, atlas slot, random
  uniform mat4 uViewProj, uPlane;
  uniform vec2 uGrid, uSpacing, uSize, uMouse, uClearC, uClearH;
  uniform float uTime, uIntro, uShadow, uAspect, uMouseOn, uClear;
  out vec2 vUv; out vec2 vBox; out float vSlot; out float vAlpha; out vec3 vN; out vec3 vWorld; out float vLift; out float vHover;
  out vec3 vP; flat out int vFace; out float vThick;

  const vec3 NORMALS[6] = vec3[6](vec3(0., 0., 1.), vec3(0., 0., -1.), vec3(1., 0., 0.), vec3(-1., 0., 0.), vec3(0., 1., 0.), vec3(0., -1., 0.));

  float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
  mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1., 0., 0., 0., c, s, 0., -s, c); }
  mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0., -s, 0., 1., 0., s, 0., c); }

  void main() {
    float col = aInst.x, row = aInst.y, rnd = aInst.w;
    // Each column drifts at its own speed, alternating direction, and wraps around
    float H = uGrid.y * uSpacing.y;
    float speed = (mod(col, 2.) < 1. ? 1. : -1.) * (0.12 + hash(col) * 0.1);
    float y0 = (row - (uGrid.y - 1.) * .5) * uSpacing.y + hash(col + 7.) * uSpacing.y;
    float y = mod(y0 + uTime * speed + H * .5, H) - H * .5;
    float x = (col - (uGrid.x - 1.) * .5) * uSpacing.x;

    // Where this cover lands on screen decides how it reacts to the pointer and the headline
    vec4 c = uViewProj * uPlane * vec4(x, y, 0., 1.);
    vec2 ndc = c.xy / c.w;
    vec2 dm = (ndc - uMouse) * vec2(uAspect, 1.);
    float hover = smoothstep(.62, 0., length(dm)) * uMouseOn;
    // Clearing: covers under the headline sink away and fade (box measured from the DOM, in NDC)
    vec2 q = abs(ndc - uClearC) - uClearH;
    float dBox = length(max(q, 0.)) + min(max(q.x, q.y), 0.);
    float clearing = smoothstep(.3, .02, dBox) * uClear;
    float edge = smoothstep(H * .5, H * .5 - uSpacing.y * 2., abs(y));

    // Intro: covers drop onto the table from the centre outwards, tumbling slightly
    float delay = length(vec2(col - (uGrid.x - 1.) * .5, row - (uGrid.y - 1.) * .5)) * .045 + rnd * .3;
    float ip = clamp((uIntro - delay) / 1.4, 0., 1.);
    float e = 1. - pow(1. - ip, 4.);

    float wave = sin(uTime * .8 + x * .45 + y * .35) * .05;
    float lift = .06 + wave + hover * hover * 1.4 * (1. - clearing) - clearing * 1.2 + (1. - e) * 6.;
    vec2 dir = length(dm) > 1e-4 ? normalize(dm) : vec2(0.);
    mat3 R = rotY(-dir.x * hover * .5 + (1. - e) * (rnd - .5) * 2.4) * rotX(dir.y * hover * .5 + (1. - e) * 1.1);
    vec2 size = uSize * (1. + hover * .1);
    // Page count varies from book to book
    float thick = .13 + hash(aInst.z + 3.) * .12;

    vec3 local;
    float up = max(lift, 0.);
    int face = int(aVert.w + .5);
    if (uShadow > .5) {
      // Shadow on the table: cast down and right, away from the light, further for thicker books;
      // it grows, softens and slides away as the book lifts. vThick carries the softness.
      float grow = 1. + up * .3;
      vBox = size * .5 * grow - .03;
      vec2 p = aVert.xy * (size * grow + .6 + up);
      vUv = p;
      vThick = .05 + thick * .45;
      local = vec3(p + vec2(.06, -.16) * up + vec2(.3, -.6) * thick, 0.);
    } else {
      // A closed book lying on the table, cover up; it turns about its middle
      vUv = aVert.xy + .5;
      vBox = size * .5;
      vec3 b = vec3(aVert.xy * size, aVert.z * thick);
      local = R * b + vec3(0., 0., thick * .5 + max(lift, -3.) - .06);
    }
    vec4 world = uPlane * vec4(vec3(x, y, 0.) + local, 1.);
    gl_Position = uViewProj * world;
    vN = mat3(uPlane) * (R * NORMALS[face]);
    vP = aVert.xyz;
    vFace = face;
    if (uShadow < .5) vThick = thick;
    vWorld = world.xyz;
    vSlot = aInst.z;
    vAlpha = smoothstep(0., .25, ip) * edge * (1. - clearing);
    vLift = lift;
    vHover = hover;
  }`;

  const FRAG = `#version 300 es
  precision highp float;
  in vec2 vUv; in vec2 vBox; in float vSlot; in float vAlpha; in vec3 vN; in vec3 vWorld; in float vLift; in float vHover;
  in vec3 vP; flat in int vFace; in float vThick;
  uniform sampler2D uAtlas;
  uniform vec2 uAtlasGrid, uSize;
  uniform vec3 uBg, uCam, uLight;
  uniform float uShadow, uFogNear, uFogFar, uTime;
  out vec4 o;

  float sdRound(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.)) + min(max(q.x, q.y), 0.) - r; }
  float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

  vec2 slotUv(vec2 uv) {
    vec2 slot = vec2(mod(vSlot, uAtlasGrid.x), floor(vSlot / uAtlasGrid.x));
    return (slot + clamp(vec2(uv.x, 1. - uv.y), .004, .996)) / uAtlasGrid;
  }
  vec3 cover(vec2 uv) { return texture(uAtlas, slotUv(uv)).rgb; }
  // The cover's overall colour, from a small mip level (bookcloth for the back and spine)
  vec3 coverAvg() { return textureLod(uAtlas, slotUv(vec2(.5)), 6.).rgb; }

  // Edge of the book: boards top and bottom, the page block between them, slightly recessed.
  // s runs across the thickness (0 back, 1 cover), a along the edge; edgeUv is where the cover's own edge is.
  vec3 bookEdge(float s, float a, vec2 edgeUv, float spineEnd) {
    float board = .02 / vThick;
    vec3 cloth = coverAvg();
    if (s > 1. - board) return cover(edgeUv) * .8;
    if (s < board) return cloth * .6;
    if (spineEnd > 0.) return cloth * .7; // the spine's cloth wraps around the head and tail
    // Pages: warm paper, a grain of individual sheets, shadowed under the boards' overhang
    float sheet = hash(floor(s * vThick * 900.)) * .5 + hash(floor(s * vThick * 260.)) * .5;
    vec3 c = vec3(.99, .97, .92) * (.9 + .1 * sheet);
    float inset = min(s - board, 1. - board - s) * vThick;
    c *= mix(.72, 1., smoothstep(0., .022, inset));
    c *= .96 + .04 * sin(a * 3.1416); // a soft bow along the edge
    return c;
  }

  void main() {
    if (uShadow > .5) {
      float up = max(vLift, 0.);
      float blur = vThick + up * .22;
      float sd = sdRound(vUv, vBox, .05);
      float a = 1. - smoothstep(-blur, blur, sd);
      a *= vAlpha * .3 / (1. + up * 1.6);
      o = vec4(vec3(.12, .08, .06) * a, a);
      return;
    }
    float a = vAlpha;
    if (a < .004) discard;

    vec3 P = vP + .5;            // 0..1 across width, height, thickness
    float spineW = .035 / vBox.x; // share of the width the spine's cloth wraps onto the cover
    vec3 c;
    float gloss = 1.;
    if (vFace == 0) {
      c = cover(P.xy);
      // Hinge: the groove where the cover board meets the spine, with a thin highlight
      c *= mix(.72, 1., smoothstep(0., .06, P.x));
      c += .12 * exp(-pow((P.x - .075) * 70., 2.));
      c *= 1. - .25 * exp(-pow((P.x - .095) * 90., 2.));
      // Board edges catch a little light
      vec2 e = min(P.xy, 1. - P.xy) * vBox * 2.;
      c += .05 * (1. - smoothstep(0., .012, min(e.x, e.y)));
    } else if (vFace == 1) {
      c = coverAvg() * .6;
      gloss = .3;
    } else if (vFace == 3) {
      // Spine: the cover's left edge wrapped round a rounded back
      c = mix(cover(vec2(.012, P.y)), cover(vec2(.03, P.y)), .5);
      float bow = sin(P.z * 3.1416);
      c *= .7 + .3 * bow;
      c += .06 * pow(bow, 8.);
      c *= mix(.75, 1., smoothstep(0., .03, min(P.y, 1. - P.y))); // headbands
      gloss = .6;
    } else if (vFace == 2) {
      c = bookEdge(P.z, P.y, vec2(.995, P.y), 0.);
      gloss = 0.;
    } else {
      float y = vFace == 4 ? .995 : .005;
      c = bookEdge(P.z, P.x, vec2(P.x, y), step(P.x, spineW));
      gloss = 0.;
    }
    // Soft contact darkening near the table on the sides
    if (vFace > 1) c *= mix(.8, 1., smoothstep(0., .5, P.z));

    // Light: diffuse that shades the sides apart from the cover, a glossy highlight that moves with the tilt, and a sheen sweep on hover
    vec3 N = normalize(vN);
    vec3 V = normalize(uCam - vWorld);
    vec3 Hh = normalize(uLight + V);
    float diff = (gloss > 0. ? .58 : .74) + .42 * max(dot(N, uLight), 0.); // paper edges scatter more light
    float spec = pow(max(dot(N, Hh), 0.), 90.) * .4 * gloss;
    float sheen = 0.;
    if (vFace == 0) {
      float band = (P.x * .8 + (1. - P.y) * .6) - (vHover * 1.6 - .2);
      sheen = exp(-band * band * 18.) * .16 * vHover;
    }
    c = c * diff + spec + sheen;

    float fog = smoothstep(uFogNear, uFogFar, length(uCam - vWorld));
    c = mix(c, uBg, fog * .9);
    o = vec4(c * a, a);
  }`;

  function compile(type, src) {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
    return s;
  }
  const prog = gl.createProgram();
  try {
    gl.attachShader(prog, compile(gl.VERTEX_SHADER, VERT));
    gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, FRAG));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
  } catch (err) {
    console.warn('Mosaic disabled:', err);
    hero.classList.add('no-gl');
    return;
  }
  gl.useProgram(prog);
  const U = {};
  for (let i = 0; i < gl.getProgramParameter(prog, gl.ACTIVE_UNIFORMS); i++) {
    const name = gl.getActiveUniform(prog, i).name;
    U[name] = gl.getUniformLocation(prog, name);
  }

  /* ---------- Geometry ---------- */
  const COLS = 28, ROWS = 22;
  const SLOTS = (window.BB_BOOKS || []).length || ATLAS.cols * ATLAS.rows;
  // Each book is a box: per face a normal n and two edges u, v with u × v = n, so every face winds counter-clockwise from outside
  const FACES = [
    [[0, 0, 1], [1, 0, 0], [0, 1, 0]],   // cover
    [[0, 0, -1], [1, 0, 0], [0, -1, 0]], // back
    [[1, 0, 0], [0, 1, 0], [0, 0, 1]],   // fore-edge
    [[-1, 0, 0], [0, 0, 1], [0, 1, 0]],  // spine
    [[0, 1, 0], [0, 0, 1], [1, 0, 0]],   // head
    [[0, -1, 0], [1, 0, 0], [0, 0, 1]],  // tail
  ];
  const boxVerts = [], boxIdx = [];
  FACES.forEach(([n, u, v], f) => {
    [[-1, -1], [1, -1], [1, 1], [-1, 1]].forEach(([a, b]) => {
      boxVerts.push(...[0, 1, 2].map((k) => (n[k] + a * u[k] + b * v[k]) * .5), f);
    });
    boxIdx.push(f * 4, f * 4 + 1, f * 4 + 2, f * 4, f * 4 + 2, f * 4 + 3);
  });
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(boxVerts), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 4, gl.FLOAT, false, 0, 0);
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(boxIdx), gl.STATIC_DRAW);
  const inst = new Float32Array(COLS * ROWS * 4);
  // Columns slide past each other, so any two neighbouring columns can line up at any offset.
  // Even and odd columns draw from separate halves of the atlas, so a cover never sits next to itself.
  const half = Math.floor(SLOTS / 2);
  for (let r = 0, i = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++, i++) {
      inst.set([c, r, (c % 2) * half + ((r * 7 + c * 13) % half), Math.random()], i * 4);
    }
  }
  const instBuf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, instBuf);
  gl.bufferData(gl.ARRAY_BUFFER, inst, gl.STATIC_DRAW);
  gl.enableVertexAttribArray(1);
  gl.vertexAttribPointer(1, 4, gl.FLOAT, false, 0, 0);
  gl.vertexAttribDivisor(1, 1);

  // Shadows are flat quads on the table, sharing the instance data
  const shadowVao = gl.createVertexArray();
  gl.bindVertexArray(shadowVao);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-.5, -.5, 0, 0, .5, -.5, 0, 0, -.5, .5, 0, 0, .5, .5, 0, 0]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 4, gl.FLOAT, false, 0, 0);
  gl.bindBuffer(gl.ARRAY_BUFFER, instBuf);
  gl.enableVertexAttribArray(1);
  gl.vertexAttribPointer(1, 4, gl.FLOAT, false, 0, 0);
  gl.vertexAttribDivisor(1, 1);

  /* ---------- Atlas ---------- */
  let ready = false, introStart = 0;
  const tex = gl.createTexture();
  const img = new Image();
  img.decoding = 'async';
  img.onload = () => {
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
    gl.generateMipmap(gl.TEXTURE_2D);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    // Anisotropic filtering keeps covers on the far, steeply tilted rows sharp
    const aniso = gl.getExtension('EXT_texture_filter_anisotropic');
    if (aniso) gl.texParameterf(gl.TEXTURE_2D, aniso.TEXTURE_MAX_ANISOTROPY_EXT, Math.min(8, gl.getParameter(aniso.MAX_TEXTURE_MAX_ANISOTROPY_EXT)));
    ready = true;
    introStart = performance.now();
    hero.classList.add('gl-ready');
  };
  img.src = ATLAS.src;

  /* ---------- Matrices (column-major) ---------- */
  const perspective = (fovy, aspect, near, far) => {
    const f = 1 / Math.tan(fovy / 2), nf = 1 / (near - far);
    return new Float32Array([f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, (far + near) * nf, -1, 0, 0, 2 * far * near * nf, 0]);
  };
  const multiply = (a, b) => {
    const o = new Float32Array(16);
    for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
      let s = 0;
      for (let k = 0; k < 4; k++) s += a[k * 4 + j] * b[i * 4 + k];
      o[i * 4 + j] = s;
    }
    return o;
  };
  const translate = (x, y, z) => new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1]);
  const rotX = (a) => { const c = Math.cos(a), s = Math.sin(a); return new Float32Array([1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1]); };
  const rotZ = (a) => { const c = Math.cos(a), s = Math.sin(a); return new Float32Array([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]); };

  /* ---------- Input ---------- */
  const mouse = { x: 0, y: 0, tx: 0, ty: 0, on: 0, ton: 0, last: -1e9 };
  const finePointer = matchMedia('(pointer: fine)').matches;
  hero.addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse') return;
    const r = canvas.getBoundingClientRect();
    mouse.tx = ((e.clientX - r.left) / r.width) * 2 - 1;
    mouse.ty = 1 - ((e.clientY - r.top) / r.height) * 2;
    mouse.last = performance.now();
  });
  hero.addEventListener('pointerleave', () => { mouse.last = -1e9; });

  /* ---------- Clearing box: the headline block, in NDC ---------- */
  const copy = document.querySelector('.hero-center');
  const clearBox = { cx: 0, cy: 0, hx: .5, hy: .4 };
  function measureClearing() {
    if (!copy) return;
    const c = canvas.getBoundingClientRect();
    // Union of the text blocks themselves (not the padded container)
    const rects = [...copy.children].map((el) => el.getBoundingClientRect());
    const r = { left: Math.min(...rects.map((x) => x.left)), right: Math.max(...rects.map((x) => x.right)), top: Math.min(...rects.map((x) => x.top)), bottom: Math.max(...rects.map((x) => x.bottom)) };
    const toX = (px) => ((px - c.left) / c.width) * 2 - 1;
    const toY = (py) => 1 - ((py - c.top) / c.height) * 2;
    const x0 = toX(r.left), x1 = toX(r.right), y0 = toY(r.bottom), y1 = toY(r.top);
    Object.assign(clearBox, { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, hx: Math.abs(x1 - x0) / 2, hy: Math.abs(y1 - y0) / 2 });
  }
  addEventListener('resize', measureClearing);
  document.fonts?.ready.then(measureClearing);
  measureClearing();

  /* ---------- Render ---------- */
  const BG = [0.961, 0.961, 0.969]; // --bg, in linear-ish terms close enough for fog
  let width = 0, height = 0, visible = true;
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; }).observe(hero);

  function resize() {
    const dpr = Math.min(devicePixelRatio || 1, 2);
    const w = Math.round(canvas.clientWidth * dpr), h = Math.round(canvas.clientHeight * dpr);
    if (w !== width || h !== height) { width = canvas.width = w; height = canvas.height = h; }
  }

  const start = performance.now();
  function frame(now) {
    requestAnimationFrame(frame);
    if (!visible || !ready) return;
    resize();
    const t = reduceMotion ? 0 : (now - start) / 1000;
    const intro = reduceMotion ? 10 : (now - introStart) / 1000;
    const aspect = width / height;

    // Pointer, or a slow wandering path when there is none (touch, idle)
    const idle = !finePointer || now - mouse.last > 2500;
    if (idle && !reduceMotion) {
      mouse.tx = Math.sin(t * .31) * .7;
      mouse.ty = Math.sin(t * .47 + 1.3) * .55;
      mouse.ton = .75;
    } else {
      mouse.ton = reduceMotion ? 0 : 1;
    }
    const k = idle ? .02 : .1;
    mouse.x += (mouse.tx - mouse.x) * k;
    mouse.y += (mouse.ty - mouse.y) * k;
    mouse.on += (mouse.ton - mouse.on) * .05;

    // Scroll tips the table back and lifts it out of view
    const scroll = Math.min(1, Math.max(0, scrollY / Math.max(1, hero.offsetHeight)));
    const dist = Math.max(15, 6.4 / (2 * Math.tan(0.26) * aspect));
    const proj = perspective(0.52, aspect, 1, 80);
    const view = translate(0, 0, -dist);
    const viewProj = multiply(proj, view);
    const plane = multiply(translate(0, scroll * 4, 0), multiply(rotZ(0.2), rotX(-0.58 - scroll * 0.35)));

    gl.viewport(0, 0, width, height);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

    gl.uniformMatrix4fv(U.uViewProj, false, viewProj);
    gl.uniformMatrix4fv(U.uPlane, false, plane);
    gl.uniform2f(U.uGrid, COLS, ROWS);
    gl.uniform2f(U.uSpacing, 1.18, 1.62);
    gl.uniform2f(U.uSize, 0.92, 1.38);
    gl.uniform2f(U.uMouse, mouse.x, mouse.y);
    gl.uniform1f(U.uTime, t);
    gl.uniform1f(U.uIntro, intro);
    gl.uniform1f(U.uAspect, aspect);
    gl.uniform1f(U.uMouseOn, mouse.on);
    // The headline drifts up and fades as you scroll; the clearing follows it and closes behind it
    const fade = Math.max(0, 1 - scroll * 3.5);
    if (copy) { copy.style.opacity = fade; copy.style.transform = `translateY(${-scroll * 120}px)`; }
    measureClearing();
    gl.uniform1f(U.uClear, fade);
    gl.uniform2f(U.uClearC, clearBox.cx, clearBox.cy);
    gl.uniform2f(U.uClearH, clearBox.hx, clearBox.hy);
    gl.uniform2f(U.uAtlasGrid, ATLAS.cols, ATLAS.rows);
    gl.uniform3f(U.uBg, ...BG);
    gl.uniform3f(U.uCam, 0, 0, dist);
    const L = [-0.35, 0.55, 1], ln = Math.hypot(...L);
    gl.uniform3f(U.uLight, L[0] / ln, L[1] / ln, L[2] / ln);
    gl.uniform1f(U.uFogNear, dist + 1);
    gl.uniform1f(U.uFogFar, dist + 16);
    gl.uniform1i(U.uAtlas, 0);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, tex);

    // Shadows first, flat on the table; then the books with depth (back faces culled) so lifted ones sit on top
    gl.bindVertexArray(shadowVao);
    gl.disable(gl.DEPTH_TEST);
    gl.disable(gl.CULL_FACE);
    gl.depthMask(false);
    gl.uniform1f(U.uShadow, 1);
    gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, COLS * ROWS);
    gl.bindVertexArray(vao);
    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.depthMask(true);
    gl.uniform1f(U.uShadow, 0);
    gl.drawElementsInstanced(gl.TRIANGLES, 36, gl.UNSIGNED_SHORT, 0, COLS * ROWS);
  }
  requestAnimationFrame(frame);
})();
