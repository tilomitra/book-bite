// Hero book mosaic: ~500 covers drawn in one instanced WebGL2 call (plus one for their shadows).
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
  layout(location = 0) in vec2 aCorner;   // -0.5..0.5
  layout(location = 1) in vec4 aInst;     // column, row, atlas slot, random
  uniform mat4 uViewProj, uPlane;
  uniform vec2 uGrid, uSpacing, uSize, uMouse, uClearC, uClearH;
  uniform float uTime, uIntro, uShadow, uAspect, uMouseOn, uClear;
  out vec2 vUv; out vec2 vBox; out float vSlot; out float vAlpha; out vec3 vN; out vec3 vWorld; out float vLift; out float vHover;

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

    vec3 local;
    float up = max(lift, 0.);
    if (uShadow > .5) {
      // Contact shadow on the table: grows, softens and slides away as the cover lifts
      float grow = 1. + up * .3;
      vBox = size * .5 * grow;
      vec2 p = aCorner * size * grow * 1.6;
      vUv = p;
      local = vec3(p + vec2(.06, -.16) * up + vec2(.02, -.05), 0.);
    } else {
      vUv = aCorner + .5;
      vBox = size * .5;
      local = R * vec3(aCorner * size, 0.) + vec3(0., 0., max(lift, -3.));
    }
    vec4 world = uPlane * vec4(vec3(x, y, 0.) + local, 1.);
    gl_Position = uViewProj * world;
    vN = mat3(uPlane) * (R * vec3(0., 0., 1.));
    vWorld = world.xyz;
    vSlot = aInst.z;
    vAlpha = smoothstep(0., .25, ip) * edge * (1. - clearing);
    vLift = lift;
    vHover = hover;
  }`;

  const FRAG = `#version 300 es
  precision highp float;
  in vec2 vUv; in vec2 vBox; in float vSlot; in float vAlpha; in vec3 vN; in vec3 vWorld; in float vLift; in float vHover;
  uniform sampler2D uAtlas;
  uniform vec2 uAtlasGrid, uSize;
  uniform vec3 uBg, uCam, uLight;
  uniform float uShadow, uFogNear, uFogFar, uTime;
  out vec4 o;

  float sdRound(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.)) + min(max(q.x, q.y), 0.) - r; }

  void main() {
    if (uShadow > .5) {
      float up = max(vLift, 0.);
      float blur = .05 + up * .22;
      float sd = sdRound(vUv, vBox, .05);
      float a = 1. - smoothstep(-blur, blur, sd);
      a *= vAlpha * .3 / (1. + up * 1.6);
      o = vec4(vec3(.12, .08, .06) * a, a);
      return;
    }
    vec2 p = (vUv - .5) * vBox * 2.;
    float sd = sdRound(p, vBox, .03);
    float aa = fwidth(sd) * 1.2;
    float a = (1. - smoothstep(-aa, aa, sd)) * vAlpha;
    if (a < .004) discard;

    vec2 slot = vec2(mod(vSlot, uAtlasGrid.x), floor(vSlot / uAtlasGrid.x));
    vec2 uv = clamp(vec2(vUv.x, 1. - vUv.y), .004, .996);
    vec3 c = texture(uAtlas, (slot + uv) / uAtlasGrid).rgb;

    // Spine: a shaded hinge with a thin highlight, like a real hardcover
    c *= mix(.72, 1., smoothstep(0., .06, vUv.x));
    c += .12 * exp(-pow((vUv.x - .075) * 70., 2.));
    c *= 1. - .25 * exp(-pow((vUv.x - .095) * 90., 2.));

    // Light: soft diffuse, a glossy highlight that moves with the cover's tilt, and a sheen sweep on hover
    vec3 N = normalize(vN);
    vec3 V = normalize(uCam - vWorld);
    vec3 Hh = normalize(uLight + V);
    float diff = .86 + .14 * max(dot(N, uLight), 0.);
    float spec = pow(max(dot(N, Hh), 0.), 90.) * .4;
    float band = (vUv.x * .8 + (1. - vUv.y) * .6) - (vHover * 1.6 - .2);
    float sheen = exp(-band * band * 18.) * .16 * vHover;
    c = c * diff + spec + sheen;
    c += .05 * (1. - smoothstep(0., .015, -sd)); // bright paper edge

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
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  const quad = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, quad);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-.5, -.5, .5, -.5, -.5, .5, .5, .5]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
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
    gl.bindVertexArray(vao);

    // Shadows first, flat on the table; then the covers with depth so lifted ones sit on top
    gl.disable(gl.DEPTH_TEST);
    gl.depthMask(false);
    gl.uniform1f(U.uShadow, 1);
    gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, COLS * ROWS);
    gl.enable(gl.DEPTH_TEST);
    gl.depthMask(true);
    gl.uniform1f(U.uShadow, 0);
    gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, COLS * ROWS);
  }
  requestAnimationFrame(frame);
})();
