/* 合成猫 · 网页试玩版
 * 玩法与 iOS 原生版一致：拖动瞄准 → 松手掉落 → 同级合成 → 越线判负。
 * 纯前端、零依赖、完全离线（首次加载后无需网络），成绩保存在 localStorage。
 * 猫脸由 Canvas 程序化绘制，视觉与 iOS 版 CatTextureFactory 保持同一套参数。
 */
(function () {
  'use strict';

  // ---------- 数据 ----------

  var LEVELS = [
    { name: '奶猫崽', r: 13,   score: 1,   top: '#FFF7D6', bottom: '#FFD98A' },
    { name: '棉花糖', r: 17.5, score: 3,   top: '#FFE4EF', bottom: '#FFAFCC' },
    { name: '布丁',   r: 23,   score: 6,   top: '#FFEBCB', bottom: '#FFC07A' },
    { name: '橘子',   r: 29.5, score: 10,  top: '#FFD9B8', bottom: '#FF9E5E' },
    { name: '狸花',   r: 37,   score: 15,  top: '#EDE6D2', bottom: '#BFAE82' },
    { name: '奶牛',   r: 45.5, score: 21,  top: '#FFFFFF', bottom: '#C9CFD6' },
    { name: '三花',   r: 55,   score: 28,  top: '#FFE1B8', bottom: '#E08A5B' },
    { name: '蓝胖子', r: 65.5, score: 36,  top: '#DCE8F5', bottom: '#8FA9C4' },
    { name: '布偶',   r: 77,   score: 45,  top: '#F5E8F9', bottom: '#C9A7DC' },
    { name: '缅因',   r: 89,   score: 55,  top: '#E7DDCB', bottom: '#9C8B6E' },
    { name: '猫王',   r: 102,  score: 120, top: '#FFEBAE', bottom: '#E0B23C' }
  ];

  var SPAWN_WEIGHTS = [0.34, 0.27, 0.20, 0.12, 0.07];

  var CONFIG = {
    gravity: 2800,        // px/s²，按"约 0.6 秒落到底"标定
    dropCooldown: 420,    // ms
    gracePeriod: 1000,    // ms，新猫宽限期
    overflowLimit: 1600,  // ms，越线持续多久判负
    kingBonus: 300,
    restitution: 0.12,
    subStep: 1 / 120,
    solverIterations: 4
  };

  var ASPECT = 0.62;      // 场地 宽/高

  // ---------- DOM ----------

  var canvas = document.getElementById('game');
  var ctx = canvas.getContext('2d');
  var nextCanvas = document.getElementById('nextCanvas');
  var nextCtx = nextCanvas.getContext('2d');
  var elScore = document.getElementById('score');
  var elBest = document.getElementById('best');
  var elNextName = document.getElementById('nextName');
  var overlay = document.getElementById('overlay');
  var elFinal = document.getElementById('finalScore');
  var elTopCat = document.getElementById('topCat');
  var elNewBest = document.getElementById('newBest');
  var btnSound = document.getElementById('btnSound');

  // ---------- 状态 ----------

  var state = {
    cats: [], particles: [], floaters: [],
    score: 0, best: 0, next: 0, topLevel: 0,
    over: false, previewX: 0, lastDrop: -99999,
    width: 360, height: 581, dpr: 1,
    dropY: 48, dangerY: 138
  };

  var accumulator = 0;
  var lastTime = 0;

  function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }

  function pickSpawnLevel() {
    var total = 0, i;
    for (i = 0; i < SPAWN_WEIGHTS.length; i++) total += SPAWN_WEIGHTS[i];
    var roll = Math.random() * total;
    for (i = 0; i < SPAWN_WEIGHTS.length; i++) {
      roll -= SPAWN_WEIGHTS[i];
      if (roll <= 0) return i;
    }
    return 0;
  }

  function makeCat(level, x, y) {
    return {
      level: level,
      r: LEVELS[level].r,
      x: x, y: y,
      vx: 0, vy: 0,
      spawn: performance.now(),
      scale: 0.35,
      overflow: 0
    };
  }

  // ---------- 尺寸 ----------

  function resize() {
    var stage = canvas.parentElement;
    var cssW = Math.max(240, stage.clientWidth || 360);
    var cssH = Math.round(cssW / ASPECT);
    var dpr = Math.min(window.devicePixelRatio || 1, 3);
    canvas.width = Math.round(cssW * dpr);
    canvas.height = Math.round(cssH * dpr);
    canvas.style.height = cssH + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    state.width = cssW;
    state.height = cssH;
    state.dpr = dpr;
    state.dropY = 48;
    state.dangerY = 138;
    state.previewX = clamp(state.previewX || cssW / 2, 0, cssW);
  }

  // ---------- 音效（WebAudio 合成，无素材） ----------

  var audioCtx = null;
  var soundOn = false;

  function ensureAudio() {
    if (!audioCtx) {
      var AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      audioCtx = new AC();
    }
    if (audioCtx.state === 'suspended') audioCtx.resume();
    return audioCtx;
  }

  function tone(opts) {
    if (!soundOn) return;
    var ac = ensureAudio();
    if (!ac) return;
    var now = ac.currentTime;
    var osc = ac.createOscillator();
    var gain = ac.createGain();
    osc.type = opts.type || 'sine';
    osc.frequency.setValueAtTime(opts.f0, now);
    osc.frequency.linearRampToValueAtTime(opts.f1, now + opts.dur);
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.linearRampToValueAtTime(opts.peak || 0.16, now + Math.min(0.03, opts.dur * 0.25));
    gain.gain.exponentialRampToValueAtTime(0.0001, now + opts.dur);
    osc.connect(gain);
    gain.connect(ac.destination);
    osc.start(now);
    osc.stop(now + opts.dur + 0.02);
  }

  function sound(kind, level) {
    if (!soundOn) return;
    if (kind === 'drop') {
      tone({ f0: 540, f1: 280, dur: 0.11, peak: 0.12 });
    } else if (kind === 'merge') {
      var base = 620 - Math.min(level, 10) * 34;
      tone({ f0: base * 0.78, f1: base * 1.24, dur: 0.18, peak: 0.14 });
      window.setTimeout(function () {
        tone({ f0: base * 1.24, f1: base * 0.95, dur: 0.24, peak: 0.12 });
      }, 170);
    } else if (kind === 'clash') {
      tone({ f0: 300, f1: 920, dur: 0.28, peak: 0.16 });
    } else if (kind === 'over') {
      tone({ f0: 420, f1: 180, dur: 0.7, type: 'triangle', peak: 0.14 });
    }
  }

  // ---------- 游戏流程 ----------

  function restart() {
    state.cats = [];
    state.particles = [];
    state.floaters = [];
    state.score = 0;
    state.topLevel = 0;
    state.over = false;
    state.lastDrop = -99999;
    state.next = pickSpawnLevel();
    state.previewX = state.width / 2;
    overlay.classList.remove('show');
    elScore.textContent = '0';
    renderNext();
  }

  function drop(x) {
    var now = performance.now();
    if (state.over || now - state.lastDrop < CONFIG.dropCooldown) return;
    state.lastDrop = now;
    var r = LEVELS[state.next].r;
    var cx = clamp(x, r + 2, Math.max(r + 2, state.width - r - 2));
    state.cats.push(makeCat(state.next, cx, state.dropY));
    sound('drop');
    state.next = pickSpawnLevel();
    renderNext();
  }

  function stepPhysics(dt) {
    var i, j, c;
    var g = CONFIG.gravity;
    for (i = 0; i < state.cats.length; i++) {
      c = state.cats[i];
      c.vy += g * dt;
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      if (c.scale < 1) c.scale = Math.min(1, c.scale + dt * 6);
    }

    var iter, a, b, dx, dy, dist, min, nx, ny, overlap, ma, mb, mt, rvx, rvy, vn, imp;
    for (iter = 0; iter < CONFIG.solverIterations; iter++) {
      for (i = 0; i < state.cats.length; i++) {
        a = state.cats[i];
        for (j = i + 1; j < state.cats.length; j++) {
          b = state.cats[j];
          dx = b.x - a.x;
          dy = b.y - a.y;
          dist = Math.sqrt(dx * dx + dy * dy) || 0.01;
          min = a.r + b.r;
          if (dist >= min) continue;
          nx = dx / dist;
          ny = dy / dist;
          overlap = min - dist;
          ma = a.r * a.r;
          mb = b.r * b.r;
          mt = ma + mb;
          a.x -= nx * overlap * (mb / mt);
          a.y -= ny * overlap * (mb / mt);
          b.x += nx * overlap * (ma / mt);
          b.y += ny * overlap * (ma / mt);
          rvx = b.vx - a.vx;
          rvy = b.vy - a.vy;
          vn = rvx * nx + rvy * ny;
          if (vn < 0) {
            imp = -(1 + CONFIG.restitution) * vn / (1 / ma + 1 / mb);
            a.vx -= imp * nx / ma;
            a.vy -= imp * ny / ma;
            b.vx += imp * nx / mb;
            b.vy += imp * ny / mb;
          }
        }
      }

      for (i = 0; i < state.cats.length; i++) {
        c = state.cats[i];
        if (c.x < c.r) { c.x = c.r; c.vx = -c.vx * 0.2; }
        if (c.x > state.width - c.r) { c.x = state.width - c.r; c.vx = -c.vx * 0.2; }
        if (c.y > state.height - c.r) {
          c.y = state.height - c.r;
          c.vy = -c.vy * 0.1;
          c.vx *= 0.86;
        }
      }
    }
  }

  function resolveMerges() {
    if (state.cats.length < 2) return;
    var used = {};
    var remove = {};
    var born = [];
    var i, j, a, b, dx, dy, dist;

    for (i = 0; i < state.cats.length; i++) {
      if (used[i]) continue;
      a = state.cats[i];
      for (j = i + 1; j < state.cats.length; j++) {
        if (used[j]) continue;
        b = state.cats[j];
        if (a.level !== b.level) continue;
        dx = b.x - a.x;
        dy = b.y - a.y;
        dist = Math.sqrt(dx * dx + dy * dy);
        if (dist > a.r + b.r - 0.5) continue;

        used[i] = true;
        used[j] = true;
        remove[i] = true;
        remove[j] = true;

        var mx = (a.x + b.x) / 2;
        var my = (a.y + b.y) / 2;

        if (a.level < LEVELS.length - 1) {
          var nextLevel = a.level + 1;
          var gained = LEVELS[nextLevel].score;
          state.score += gained;
          state.topLevel = Math.max(state.topLevel, nextLevel);
          born.push(makeCat(nextLevel, mx, my));
          burst(mx, my, nextLevel, false);
          floatText(mx, my, '+' + gained);
          sound('merge', nextLevel);
        } else {
          state.score += CONFIG.kingBonus;
          burst(mx, my, a.level, true);
          floatText(mx, my, '+' + CONFIG.kingBonus);
          sound('clash');
        }
        elScore.textContent = String(state.score);
        break;
      }
    }

    if (Object.keys(remove).length) {
      var kept = [];
      for (i = 0; i < state.cats.length; i++) {
        if (!remove[i]) kept.push(state.cats[i]);
      }
      state.cats = kept.concat(born);
    }
  }

  function checkOverflow(dtMs) {
    var now = performance.now();
    for (var i = 0; i < state.cats.length; i++) {
      var c = state.cats[i];
      var settled = now - c.spawn > CONFIG.gracePeriod;
      if (settled && c.y - c.r < state.dangerY) {
        c.overflow += dtMs;
        if (c.overflow >= CONFIG.overflowLimit) {
          endGame();
          return;
        }
      } else {
        c.overflow = 0;
      }
    }
  }

  function endGame() {
    if (state.over) return;
    state.over = true;
    sound('over');
    elFinal.textContent = String(state.score);
    elTopCat.textContent = '最大猫咪：' + LEVELS[state.topLevel].name;
    var isNewBest = state.score > state.best;
    if (isNewBest) {
      state.best = state.score;
      elBest.textContent = String(state.best);
      try { localStorage.setItem('catmerge.best', String(state.best)); } catch (e) {}
    }
    elNewBest.style.display = isNewBest && state.score > 0 ? 'block' : 'none';
    overlay.classList.add('show');
  }

  // ---------- 特效 ----------

  function burst(x, y, level, isClash) {
    var n = isClash ? 20 : 10;
    var r = LEVELS[level].r;
    for (var i = 0; i < n; i++) {
      var angle = (i / n) * Math.PI * 2 + Math.PI / 4;
      var speed = (isClash ? 300 : 200) * (0.6 + Math.random() * 0.6);
      state.particles.push({
        x: x, y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 0.42, ttl: 0.42,
        r: r * 0.1,
        color: LEVELS[level].bottom
      });
    }
  }

  function floatText(x, y, text) {
    state.floaters.push({ x: x, y: y, text: text, life: 0.7, ttl: 0.7 });
  }

  function updateEffects(dt) {
    var i, p;
    for (i = state.particles.length - 1; i >= 0; i--) {
      p = state.particles[i];
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 600 * dt;
      if (p.life <= 0) state.particles.splice(i, 1);
    }
    for (i = state.floaters.length - 1; i >= 0; i--) {
      var f = state.floaters[i];
      f.life -= dt;
      f.y -= 66 * dt;
      if (f.life <= 0) state.floaters.splice(i, 1);
    }
  }

  // ---------- 绘制 ----------

  function drawCat(g, x, y, r, level, alpha, scale) {
    var spec = LEVELS[level];
    var headR = r * 0.80 * (scale || 1);
    var cy = y + r * 0.08 * (scale || 1);
    g.save();
    g.globalAlpha = alpha === undefined ? 1 : alpha;

    drawEar(g, x, cy, headR, 145, spec);
    drawEar(g, x, cy, headR, 35, spec);

    var grad = g.createLinearGradient(x - headR, cy - headR, x, cy + headR);
    grad.addColorStop(0, spec.top);
    grad.addColorStop(1, spec.bottom);
    g.beginPath();
    g.arc(x, cy, headR, 0, Math.PI * 2);
    g.fillStyle = grad;
    g.fill();
    g.strokeStyle = 'rgba(92,68,51,0.28)';
    g.lineWidth = Math.max(1, headR * 0.055);
    g.stroke();

    drawFace(g, x, cy, headR, level);
    g.restore();
  }

  function drawEar(g, cx, cy, R, degAngle, spec) {
    var rad = degAngle * Math.PI / 180;
    var spread = 0.30;
    var base = R * 0.98;
    var tipLen = R * 1.42;
    var p1x = cx + Math.cos(rad - spread) * base;
    var p1y = cy - Math.sin(rad - spread) * base;
    var p2x = cx + Math.cos(rad + spread) * base;
    var p2y = cy - Math.sin(rad + spread) * base;
    var tx = cx + Math.cos(rad) * tipLen;
    var ty = cy - Math.sin(rad) * tipLen;

    g.beginPath();
    g.moveTo(p1x, p1y);
    g.lineTo(tx, ty);
    g.lineTo(p2x, p2y);
    g.closePath();
    g.fillStyle = spec.bottom;
    g.fill();
    g.strokeStyle = 'rgba(92,68,51,0.28)';
    g.lineWidth = Math.max(1, R * 0.05);
    g.stroke();

    g.beginPath();
    g.moveTo(p1x * 0.2 + tx * 0.8, p1y * 0.2 + ty * 0.8);
    g.lineTo(tx, ty);
    g.lineTo(p2x * 0.2 + tx * 0.8, p2y * 0.2 + ty * 0.8);
    g.closePath();
    g.fillStyle = 'rgba(255,179,199,0.75)';
    g.fill();
  }

  function drawFace(g, cx, cy, R, level) {
    var detail = R > 18;
    var eyeW = R * 0.20, eyeH = R * 0.30, eyeDX = R * 0.38;
    var eyeY = cy - R * 0.02;

    [-eyeDX, eyeDX].forEach(function (dx) {
      g.beginPath();
      g.ellipse(cx + dx, eyeY, eyeW / 2, eyeH / 2, 0, 0, Math.PI * 2);
      g.fillStyle = '#3B2B22';
      g.fill();
      g.beginPath();
      g.ellipse(cx + dx - eyeW * 0.1, eyeY - eyeH * 0.16, eyeW * 0.17, eyeH * 0.12, 0, 0, Math.PI * 2);
      g.fillStyle = 'rgba(255,255,255,0.9)';
      g.fill();
    });

    var blushW = R * 0.26, blushH = R * 0.16;
    [-R * 0.62, R * 0.62].forEach(function (dx) {
      g.beginPath();
      g.ellipse(cx + dx, cy + R * 0.24, blushW / 2, blushH / 2, 0, 0, Math.PI * 2);
      g.fillStyle = 'rgba(255,143,168,0.42)';
      g.fill();
    });

    var noseY = cy + R * 0.34;
    var noseSize = R * 0.10;
    g.beginPath();
    g.ellipse(cx, noseY, noseSize / 2, noseSize * 0.4, 0, 0, Math.PI * 2);
    g.fillStyle = '#E4758C';
    g.fill();

    g.strokeStyle = 'rgba(59,43,34,0.85)';
    g.lineWidth = Math.max(1, R * 0.045);
    g.lineCap = 'round';
    var mw = R * 0.18;
    [-1, 1].forEach(function (sign) {
      g.beginPath();
      g.moveTo(cx + sign * mw * 0.15, noseY + noseSize);
      g.quadraticCurveTo(cx + sign * mw * 0.6, noseY + noseSize * 1.9,
                         cx + sign * mw, noseY + noseSize * 0.5);
      g.stroke();
    });

    if (!detail) return;

    g.strokeStyle = 'rgba(59,43,34,0.35)';
    g.lineWidth = Math.max(0.8, R * 0.032);
    [-1, 1].forEach(function (sign) {
      for (var k = 0; k < 2; k++) {
        var off = k * R * 0.14;
        g.beginPath();
        g.moveTo(cx + sign * R * 0.34, cy + R * 0.30 + off);
        g.lineTo(cx + sign * R * 1.05, cy + R * 0.18 + off * 1.6);
        g.stroke();
      }
    });

    if (level === LEVELS.length - 1) {
      var crownW = R * 0.52, crownH = R * 0.30;
      var ox = cx - crownW / 2, oy = cy - R * 1.02;
      g.beginPath();
      g.moveTo(ox, oy + crownH);
      g.lineTo(ox + crownW * 0.18, oy);
      g.lineTo(ox + crownW * 0.5, oy + crownH * 0.55);
      g.lineTo(ox + crownW * 0.82, oy);
      g.lineTo(ox + crownW, oy + crownH);
      g.closePath();
      g.fillStyle = '#FFD34D';
      g.fill();
      g.strokeStyle = 'rgba(184,134,11,0.6)';
      g.lineWidth = Math.max(1, R * 0.04);
      g.stroke();
    }
  }

  function render() {
    var g = ctx;
    g.clearRect(0, 0, state.width, state.height);

    // 警戒线
    g.save();
    g.setLineDash([8, 6]);
    g.strokeStyle = 'rgba(228,117,140,0.45)';
    g.lineWidth = 2;
    g.beginPath();
    g.moveTo(8, state.dangerY);
    g.lineTo(state.width - 8, state.dangerY);
    g.stroke();
    g.restore();

    var i;
    for (i = 0; i < state.cats.length; i++) {
      var c = state.cats[i];
      drawCat(g, c.x, c.y, c.r, c.level, 1, c.scale);
    }

    for (i = 0; i < state.particles.length; i++) {
      var p = state.particles[i];
      var a = Math.max(0, p.life / p.ttl);
      g.globalAlpha = a;
      g.beginPath();
      g.arc(p.x, p.y, p.r * (0.4 + a * 0.6), 0, Math.PI * 2);
      g.fillStyle = p.color;
      g.fill();
    }
    g.globalAlpha = 1;

    for (i = 0; i < state.floaters.length; i++) {
      var f = state.floaters[i];
      g.globalAlpha = Math.max(0, f.life / f.ttl);
      g.fillStyle = '#E4758C';
      g.font = '600 20px -apple-system, system-ui, sans-serif';
      g.textAlign = 'center';
      g.fillText(f.text, f.x, f.y);
    }
    g.globalAlpha = 1;

    if (!state.over) {
      var pr = LEVELS[state.next].r;
      var px = clamp(state.previewX, pr + 2, Math.max(pr + 2, state.width - pr - 2));
      drawCat(g, px, state.dropY, pr, state.next, 0.82, 1);
    }
  }

  function renderNext() {
    var size = nextCanvas.width;
    nextCtx.clearRect(0, 0, size, size);
    drawCat(nextCtx, size / 2, size / 2, size / 2 / 1.05, state.next, 1, 0.82);
    elNextName.textContent = LEVELS[state.next].name;
  }

  // ---------- 主循环 ----------

  function frame(now) {
    if (!lastTime) lastTime = now;
    var dtMs = Math.min(now - lastTime, 50);
    lastTime = now;

    if (!state.over) {
      accumulator += dtMs / 1000;
      var guard = 0;
      while (accumulator >= CONFIG.subStep && guard < 8) {
        stepPhysics(CONFIG.subStep);
        accumulator -= CONFIG.subStep;
        guard++;
      }
      resolveMerges();
      checkOverflow(dtMs);
    }
    updateEffects(dtMs / 1000);
    render();
    window.requestAnimationFrame(frame);
  }

  // ---------- 输入 ----------

  function pointerX(evt) {
    var rect = canvas.getBoundingClientRect();
    return (evt.clientX - rect.left) * (state.width / rect.width);
  }

  canvas.addEventListener('pointerdown', function (e) {
    if (state.over) return;
    canvas.setPointerCapture(e.pointerId);
    state.previewX = pointerX(e);
  });
  canvas.addEventListener('pointermove', function (e) {
    if (state.over) return;
    state.previewX = pointerX(e);
  });
  canvas.addEventListener('pointerup', function (e) {
    if (state.over) return;
    state.previewX = pointerX(e);
    drop(state.previewX);
  });
  canvas.addEventListener('pointercancel', function () {});

  window.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowLeft') { state.previewX = clamp(state.previewX - 16, 0, state.width); }
    else if (e.key === 'ArrowRight') { state.previewX = clamp(state.previewX + 16, 0, state.width); }
    else if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); drop(state.previewX); }
  });

  btnSound.addEventListener('click', function () {
    soundOn = !soundOn;
    btnSound.textContent = soundOn ? '♪' : '✕';
    btnSound.style.opacity = soundOn ? '1' : '0.45';
    if (soundOn) { ensureAudio(); sound('drop'); }
  });
  btnSound.style.opacity = '0.45';

  document.getElementById('btnRestart').addEventListener('click', restart);
  document.getElementById('btnAgain').addEventListener('click', restart);
  document.getElementById('btnClose').addEventListener('click', function () {
    overlay.classList.remove('show');
  });

  window.addEventListener('resize', function () {
    resize();
    renderNext();
  });

  // ---------- 启动 ----------

  try {
    var saved = localStorage.getItem('catmerge.best');
    state.best = saved ? parseInt(saved, 10) || 0 : 0;
  } catch (e) {
    state.best = 0;
  }
  elBest.textContent = String(state.best);

  resize();
  restart();
  window.requestAnimationFrame(frame);
})();
