(() => {
  const ink = '#30201a';
  const tau = Math.PI * 2;
  const clamp = (n, min = 0, max = 1) => Math.max(min, Math.min(n, max));
  const mix = (a, b, t) => a + (b - a) * t;
  const smooth = t => t * t * (3 - 2 * t);
  const ease = (t, start, end) => smooth(clamp((t - start) / (end - start)));
  const curve = (phase, frames) => {
    for (let i = 1; i < frames.length; i++) {
      if (phase > frames[i][0]) continue;
      const previous = frames[i - 1];
      const next = frames[i];
      const t = ease(phase, previous[0], next[0]);
      return previous.slice(1).map((value, j) => mix(value, next[j + 1], t));
    }
    return frames.at(-1).slice(1);
  };
  const path = (d, fill, stroke = ink, w = 1.05) =>
    `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"/>`;
  const line = (d, stroke, w = .8) => path(d, 'none', stroke, w);
  const ellipse = (x, y, rx, ry, fill, stroke = 'none', w = 1) =>
    `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${fill}" stroke="${stroke}" stroke-width="${w}"/>`;
  const group = (transform, children, opacity = 1) =>
    `<g transform="${transform}" opacity="${opacity}">${children}</g>`;
  const point = ([x, y]) => `${x} ${y}`;
  const angle = (a, b) => Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI;
  const along = (a, b, t) => [mix(a[0], b[0], t), mix(a[1], b[1], t)];
  const twist = (p, pivot, degrees) => {
    const t = degrees * Math.PI / 180;
    const dx = p[0] - pivot[0];
    const dy = p[1] - pivot[1];
    return [pivot[0] + dx * Math.cos(t) - dy * Math.sin(t), pivot[1] + dx * Math.sin(t) + dy * Math.cos(t)];
  };

  // Each bend is solved from two articulated segments and a planted endpoint.
  function joint(a, b, first, second, side) {
    const dx = b[0] - a[0];
    const dy = b[1] - a[1];
    const distance = Math.hypot(dx, dy) || 1;
    const fitted = Math.min(distance, first + second - .05);
    const run = (first * first - second * second + fitted * fitted) / (2 * fitted);
    const rise = Math.sqrt(Math.max(.08, first * first - run * run)) * side;
    return [a[0] + (run * dx - rise * dy) / distance, a[1] + (run * dy + rise * dx) / distance];
  }

  function segment(a, b, top, bottom, fill, light, dark) {
    const length = Math.hypot(b[0] - a[0], b[1] - a[1]);
    const end = Math.max(2, length);
    return group(`translate(${point(a)}) rotate(${angle(a, b)})`, [
      path(`M-2 ${-top * .7} Q${end * .35} ${-top * 1.05} ${end} ${-bottom} Q${end + 2} ${-bottom * .5} ${end + 1} ${bottom * .7} Q${end * .35} ${top * .92} -2 ${top * .68}Z`, fill),
      path(`M1 ${top * .17} Q${end * .5} ${bottom * .12} ${end + .5} ${bottom * .35} L${end} ${bottom * .67} Q${end * .4} ${top * .68} 1 ${top * .55}Z`, dark, 'none'),
      line(`M1 ${-top * .55} Q${end * .35} ${-top * .72} ${end * .78} ${-bottom * .69}`, light, .75),
    ].join(''));
  }

  const echoBase = [0, 0, 0, 0, 0, 8, -34, -12, -32, 9, -2, -10, -3];
  const echoPoses = {
    punch: [
      [0, ...echoBase],
      [.26, -4, 2, -13, -9, 7, -12, -38, 9, -44, 9, -2, -12, -3],
      [.39, -3, 4, -16, 4, 10, -17, -35, 8, -46, 11, -2, -15, -3],
      [.52, 6, 1, 20, -10, -16, 36, -41, 1, -43, 12, -2, -16, -5],
      [.62, 7, 2, 25, 5, -19, 35, -36, 0, -41, 12, -2, -14, -5],
      [.76, 3, 3, 10, 4, 10, 17, -29, -4, -36, 12, -2, -10, -3],
      [1, ...echoBase],
    ],
    guard: [
      [0, ...echoBase],
      [.24, -1, 4, 8, 14, -3, 14, -52, 21, -46, 10, -2, -13, -3],
      [.48, -2, 6, 4, 13, 1, 15, -50, 20, -45, 12, -2, -14, -3],
      [.59, -5, 8, -9, 19, 10, 12, -49, 17, -42, 12, -2, -14, -3],
      [.75, -2, 4, 3, 10, -4, 15, -49, 19, -45, 11, -2, -14, -3],
      [1, ...echoBase],
    ],
    interpose: [
      [0, ...echoBase],
      [.19, -5, 4, -11, -17, 3, -3, -40, -22, -39, 8, -2, -11, -3],
      [.36, 4, 1, 23, -8, -24, 20, -45, -22, -42, 16, -10, -8, -2],
      [.52, 7, 7, 16, 8, -34, 23, -48, -24, -42, 18, -2, -12, -4],
      [.68, 5, 8, 11, 13, -18, 21, -49, -26, -38, 18, -2, -12, -4],
      [.80, 4, 6, 13, 10, -9, 21, -47, -21, -34, 17, -2, -11, -4],
      [1, ...echoBase],
    ],
    purify: [
      [0, ...echoBase],
      [.24, -1, 7, 12, 19, 9, 10, -34, 14, -37, 11, -2, -12, -3],
      [.40, -3, 3, -9, 8, 18, 9, -47, 14, -49, 11, -2, -12, -3],
      [.63, 6, 2, 17, 10, -17, 33, -45, 24, -53, 14, -2, -13, -3],
      [.80, 5, 3, 20, 14, -10, 31, -46, 21, -48, 14, -2, -13, -3],
      [1, ...echoBase],
    ],
    call: [
      [0, ...echoBase],
      [.20, -2, 4, -6, 3, 8, 2, -37, -12, -36, 9, -2, -11, -3],
      [.41, 1, -1, 3, -13, 0, 9, -59, -9, -34, 10, -2, -11, -3],
      [.55, 3, -1, 11, -19, -12, 21, -59, -11, -38, 10, -2, -11, -3],
      [.72, 3, 1, 9, -10, -6, 20, -51, -11, -36, 10, -2, -11, -3],
      [1, ...echoBase],
    ],
    steady: [
      [0, ...echoBase],
      [.21, -1, 1, -5, -8, 1, 9, -35, -12, -33, 9, -2, -10, -3],
      [.52, 0, 3, 3, 7, 3, 9, -29, -12, -27, 9, -2, -10, -3],
      [.74, 0, -1, 1, -3, -1, 8, -30, -12, -30, 9, -2, -10, -3],
      [1, ...echoBase],
    ],
    hit: [
      [0, ...echoBase],
      [.15, -6, 4, -21, -17, 30, -5, -42, -22, -49, 9, -2, -14, -3],
      [.32, -9, 6, -26, 15, 22, -14, -32, -24, -35, 10, -2, -19, -3],
      [.58, -5, 7, 9, 20, -11, 4, -30, -15, -24, 10, -2, -16, -3],
      [1, ...echoBase],
    ],
    defeated: [
      [0, ...echoBase],
      [.21, -7, 7, -30, -14, 36, -8, -42, -21, -37, 10, -2, -15, -3],
      [.43, -8, 16, 26, 18, 14, 11, -21, -23, -18, 13, -2, -15, -3],
      [.71, -10, 26, 72, 15, 2, 15, -6, -25, -7, 18, -2, -21, -3],
      [1, -10, 28, 79, 10, 0, 17, -5, -25, -5, 20, -2, -23, -3],
    ],
  };

  function step(phase, length, depth, height, offset) {
    const t = (phase + offset) % 1;
    if (t < .56) return [length * (.28 - t), depth, 0];
    const swing = (t - .56) / .44;
    return [length * (smooth(swing) * .56 - .28), depth - height * Math.sin(swing * Math.PI), 28 * Math.sin(swing * tau)];
  }

  function walkBlend(pose, phase) {
    if (pose === 'walk') return 1;
    if (pose === 'gather') return ease(phase, .08, 1);
    if (pose === 'settle') return 1 - ease(phase, 0, .95);
    return 0;
  }

  function echoMotion({ pose, phase, time, stride, rise, reach, impactY }) {
    const breath = Math.sin(time * 3.1);
    const values = echoPoses[pose] ? curve(phase, echoPoses[pose]) : echoBase;
    const [x, dip, lean, nod, cloth, hx, hy, fx, fy, nx, ny, ax, ay] = values;
    const drive = strikeDrive(pose, phase);
    const aim = Number.isFinite(impactY) ? clamp(impactY + 40, -27, 39) * drive : 0;
    const rest = {
      pose, phase, x, dip: dip + breath * .65 + aim * .30, lean: lean + breath * .9 + aim * .24, nod: nod + breath * 2,
      cloth: cloth + Math.sin(time * 4.9 - .6) * 4,
      nearHand: [hx + drive * (reach - 36), hy + breath + aim], farHand: [fx, fy - breath * 1.4 + aim * .25],
      nearFoot: [nx, ny], farFoot: [ax, ay], nearAnkle: 0, farAnkle: 0,
    };
    const blend = walkBlend(pose, phase);
    if (!blend) return rest;
    const cycle = pose === 'walk' ? phase : 0;
    const rhythm = Math.cos(cycle * tau);
    const bounce = Math.sin(cycle * tau * 2);
    const [sx, sy, sa] = step(cycle, stride, -2, 8.5, 0);
    const [dx, dy, da] = step(cycle, stride, -4, 7, .5);
    return {
      pose, phase,
      x: mix(rest.x, 2 + rhythm, blend), dip: mix(rest.dip, 1.5 + bounce * 1.9, blend),
      lean: mix(rest.lean, 11 + 4 * rhythm, blend), nod: mix(rest.nod, -6 - bounce * 3, blend),
      cloth: mix(rest.cloth, -18 - 11 * Math.cos(cycle * tau - .8), blend),
      nearHand: along(rest.nearHand, [3 - 12 * rhythm, -35 - 3 * rhythm], blend),
      farHand: along(rest.farHand, [-5 + 12 * rhythm, -33 + 4 * rhythm], blend),
      nearFoot: along(rest.nearFoot, [sx + 2, sy + sx * rise / stride], blend),
      farFoot: along(rest.farFoot, [dx - 2, dy + dx * rise / stride], blend),
      nearAnkle: (sa + rise * .4) * blend, farAnkle: (da + rise * .4) * blend,
    };
  }

  function strikeDrive(pose, phase) {
    return pose === 'punch' ? ease(phase, .39, .52) * (1 - ease(phase, .63, .79)) : 0;
  }

  const palettes = {
    ama: {
      skin: '#9c5f38', skinLight: '#d68b52', skinDark: '#693b2c', hair: '#29201e', curl: '#614337',
      top: '#e4c18c', topShade: '#a46a42', wrap: '#417774', warpLight: '#80a394', wrapDark: '#294c55',
      apron: '#b76539', apronLight: '#e08c52', trim: '#e1ae59', belt: '#8c4934',
    },
    esi: {
      skin: '#905339', skinLight: '#c38350', skinDark: '#643625', hair: '#2f231f', curl: '#664535',
      top: '#ebcd96', topShade: '#a67150', wrap: '#e9cda0', warpLight: '#fff0be', wrapDark: '#a98761',
      apron: '#356378', apronLight: '#6295a0', trim: '#c7864c', belt: '#9d4f37',
    },
  };

  function echoFoot(ankle, rotation, color, near) {
    return group(`translate(${point(ankle)}) rotate(${rotation})`, [
      path('M-3.2 -2.8 Q1 -3.8 3 -.3 Q6.2 -.5 9 1 Q11 2.5 8.8 3.6 L-2.9 3.5 Q-5 2.1 -3.2 -2.8Z', near ? color.skin : color.skinDark),
      path('M-3.1 1.4 Q4 2.9 9.8 2.2 L8.8 3.9 L-3.2 3.8Z', '#5a3625'),
      line('M-.6 -2.5 L1.4 1.4 M4.1 -.4 L4.7 1.9', '#50342a', 1.45),
      line('M5.4 1 Q7.2 .4 8.8 1.2', color.skinLight, .7),
    ].join(''));
  }

  function echoLeg(motion, color, near) {
    const hip = [motion.x + (near ? -4 : 3), -31 + motion.dip];
    const foot = near ? motion.nearFoot : motion.farFoot;
    const knee = joint(hip, foot, 15.8, 16.5, -1);
    return group('', [
      segment(hip, knee, 5.5, 4.6, near ? color.wrapDark : '#4d3528', color.wrap, '#493328'),
      segment(knee, foot, 4, 2.6, near ? color.skin : color.skinDark, color.skinLight, color.skinDark),
      group(`translate(${point(along(knee, foot, .67))}) rotate(${angle(knee, foot)})`, [
        path('M-2 -3.1 L2.5 -2.7 L2.7 2.8 L-2 3.2Z', color.wrapDark, ink, .65),
        line('M-.9 -2.6 L.1 2.7', color.warpLight, .65),
      ].join('')),
      echoFoot(foot, near ? motion.nearAnkle : motion.farAnkle, color, near),
    ].join(''), near ? 1 : .89);
  }

  function echoHand(wrist, elbow, color, style, near) {
    const fill = near ? color.skin : color.skinDark;
    const drawing = {
      fist: 'M-1.7 -2.1 Q.3 -4 3 -4.3 Q5.4 -4.6 6.5 -2.5 L6.9 .2 Q6 2.9 2.8 3.2 Q-.5 2.9 -1.7 1.8Z',
      open: 'M-2 -1.9 L1 -2.8 Q3 -4.6 4.3 -3.8 L3.5 -2 L7 -3.1 Q8 -3 7.3 -1.8 L5.6 -.6 L8 -.6 Q8.6 .3 7.7 .9 L5.6 1.2 L7.2 2 Q7.5 3.4 6.4 3.1 L3.1 2.4 Q.5 3.1 -2 1.7Z',
      palm: 'M-2 -2.1 L.4 -2.8 Q1 -4.6 2.4 -4.9 Q3.4 -4.4 2.3 -2.5 Q4 -3.8 5 -3.2 Q6.5 -2.8 6.8 -.3 Q6.8 2.9 4.3 3.7 Q1 3.1 -2 1.9Z',
    };
    return group(`translate(${point(wrist)}) rotate(${angle(elbow, wrist)})`, [
      path(drawing[style], fill, ink, .85),
      line(style === 'fist' ? 'M1.5 -1.8 Q3.6 -2.3 5.4 -1.4 M3.9 -.7 L5.8 0' : 'M1 -1 Q3 -.7 3.4 1.4', color.skinLight, .65),
    ].join(''));
  }

  function echoArm(shoulder, wrist, color, near, handStyle, bend) {
    const elbow = joint(shoulder, wrist, 13, 12.4, bend);
    return {
      elbow,
      drawing: group('', [
        segment(shoulder, elbow, 4, 3.2, near ? color.skin : color.skinDark, color.skinLight, color.skinDark),
        segment(elbow, wrist, 3.1, 2.35, near ? color.skin : color.skinDark, color.skinLight, color.skinDark),
        group(`translate(${point(along(shoulder, elbow, .18))}) rotate(${angle(shoulder, elbow)})`, [
          path('M-3 -4.5 L3.9 -3.7 L4 3.9 L-2.5 4.5Z', color.top, ink, .75),
          line('M2.5 -3.6 L2.8 3.5', color.trim, 1.3),
        ].join('')),
        group(`translate(${point(along(elbow, wrist, .76))}) rotate(${angle(elbow, wrist)})`, [
          path('M-1.7 -2.9 L1.8 -2.7 L2 2.7 L-1.5 3.1Z', color.trim, '#593724', .6),
          line('M0 -2.3 L.2 2.5', '#f2ca7b', .7),
        ].join('')),
        echoHand(wrist, elbow, color, handStyle, near),
      ].join(''), near ? 1 : .92),
    };
  }

  function echoHead(color, isAma) {
    const curls = isAma
      ? [[-8,-12,4.8],[-14,-13,4.3],[-16,-17,4.4],[-11,-20,5],[-6,-17,4.3],[-18,-12,3.1],[-12,-8,3.2]]
      : [[-9,-11,3.7],[-13,-13,3.4],[-12,-17,3.7],[-8,-17,3.8],[-6,-13,4]];
    return [
      curls.map(([x, y, r]) => ellipse(x, y, r, r * .87, color.hair, ink, .7)
        + line(`M${x-r*.52} ${y} q.4 ${-r*.62} ${r} ${-r*.56}`, color.curl, .75)).join(''),
      path('M-4 -11 Q1 -15 7 -10 Q9 -8 9.6 -4 L12 -.9 L9.7 .7 Q10.1 4.7 7 6.3 L4.7 6.7 L4.1 11 L-3.7 9.5 L-2.7 4 Q-7 1 -7 -4Z', color.skin),
      path('M-5 -5 Q-2 -7 .1 -6 L.6 -.8 Q1.4 3.3 4 6.4 L3.1 9 L-3.5 8.4 L-2.5 3.6 Q-7 1.9 -6.7 -2Z', color.skinDark, 'none'),
      path('M-6.8 -2 Q-10.3 -8 -4.2 -11.9 Q1.7 -16 7.1 -10.7 L8.2 -8 Q5.2 -9.8 1.7 -8.9 Q-2.6 -8.4 -4 -3.3Z', color.hair),
      line('M-5.4 -6.7 Q-1.3 -12 4.6 -10.7', isAma ? '#d59b4f' : color.curl, 1.2),
      line('M3.2 -4.2 Q5.6 -5.5 7.9 -4.1 M6.8 2.5 Q7.9 3 9.2 2.5', ink, .78),
      line('M4.7 -2.5 L7.4 -2.4', '#edd09f', .78),
      ellipse(6.6, -2.5, .74, .82, ink),
      line('M8.2 -3 L10 -.9 M2 .6 Q3.7 1.6 5.3 .8', color.skinLight, .8),
      path('M-3.3 -2.2 C-6.9 -3.7 -6.8 2 -3.5 1.7', color.skin, ink, .75),
      ellipse(-4.2, 3.1, 1.73, 2.1, 'none', '#e7b85f', .95),
    ].join('');
  }

  function echoCloth(color, isAma, motion, hip) {
    const swing = motion.cloth * .29;
    const hem = motion.pose === 'defeated' ? 1 - ease(motion.phase, .4, .78) * .42 : 1;
    const panel = `M-9 -5 Q1 -8 9 -6 Q${14+swing*.3} ${2*hem} ${15+swing} ${13*hem} L${11+swing} ${12*hem} L${6+swing} ${17*hem} L${2+swing} ${15*hem} L${-4+swing} ${18*hem} L${-7+swing} ${15*hem} L${-17+swing} ${17*hem} Q${-13+swing*.4} ${7*hem} -9 -5Z`;
    return group(`translate(${point(hip)}) rotate(${motion.lean * .42})`, [
      path(panel, color.wrap),
      path(`M-4 -5 Q${-8+swing*.4} 3 ${-14+swing} ${14*hem} L${-8+swing} ${13*hem} L${-3+swing} ${15*hem} Q${-1+swing*.3} 5 3 -6Z`, color.wrapDark, 'none'),
      path(`M4 -6 Q${6+swing*.2} 1 ${14+swing} ${11*hem} L${8+swing} ${14*hem} L${2+swing} ${16*hem} Q${4+swing*.4} 6 1 -4Z`, color.apron, ink, .75),
      path(`M5 -3 Q${9+swing*.4} 3 ${11+swing} ${10*hem} L${7+swing} ${13*hem} Q${7+swing*.3} 3 3 -4Z`, color.apronLight, 'none'),
      line(`M-7 -3 Q${-10+swing*.55} ${8*hem} ${-15+swing} ${15*hem} M1 -4 Q${-1+swing*.42} 5 ${-3+swing} ${16*hem}`, color.warpLight, 1),
      line(`M${-14+swing} ${13*hem} l2 1 m2 -2 l2 1 m3 0 l2 1 m3 -1 l2 1 m3 -2 l2 1 m3 -2 l2 1`, color.trim, .95),
      path('M-10 -7 Q1 -5 10 -9 L10 -5 Q2 -1 -10 -3Z', color.belt, ink, .85),
      line('M-8 -5 Q1 -3 9 -7', color.trim, .9),
      path(`M8 -6 Q${12+swing} 1 ${9+swing} 10 L${5+swing} 8 Q${9+swing*.4} 3 6 -4Z`, isAma ? color.wrapDark : color.belt, ink, .65),
    ].join(''));
  }

  function echoFigure(id, motion) {
    const color = palettes[id];
    const isAma = id === 'ama';
    const hip = [motion.x, -32 + motion.dip];
    const drive = strikeDrive(motion.pose, motion.phase);
    const nearShoulder = twist([hip[0] - 8 + drive * 8, hip[1] - 15], hip, motion.lean);
    const farShoulder = twist([hip[0] + 6, hip[1] - 16], hip, motion.lean);
    const head = twist([hip[0] + 2, hip[1] - 28], hip, motion.lean);
    const palms = motion.pose === 'purify' || motion.pose === 'interpose';
    const releases = motion.pose === 'steady' && motion.phase > .15 && motion.phase < .9;
    const fingers = releases || ['hit', 'defeated', 'call'].includes(motion.pose) ? 'open' : 'fist';
    const farArm = echoArm(farShoulder, motion.farHand, color, false, palms ? 'open' : fingers, 1);
    const nearArm = echoArm(nearShoulder, motion.nearHand, color, true, palms ? 'palm' : fingers, -1);
    const body = group(`translate(${point(hip)}) rotate(${motion.lean})`, [
      path('M-4 -23 L3.7 -25 L5.1 -19 L11 -15 Q12 -12 7.4 -8 L8.8 -1 Q2 3 -8 -.1 L-9 -9 Q-14 -15 -10 -17 L-4 -20Z', color.top),
      path('M-10 -15 Q-4 -10 1 -11 Q4 -5 7 -4 L8 -.5 Q3 1 -7 -1 L-9 -8Z', color.topShade, 'none'),
      path('M-8.7 -16 L-2.9 -19 Q.5 -11 9.2 -8.5 L8 -3 Q-.4 -6 -8.7 -16Z', isAma ? color.wrap : '#f4dcab', '#6f4b32', .7),
      line('M-7 -16 Q1.7 -8.3 8.6 -6.5 M-6 -13 Q1.5 -7.1 6.3 -5.7', isAma ? color.warpLight : '#b98855', .75),
      line('M-.7 -18 Q2 -16.3 4.9 -18 M-7.6 -6 Q-3.7 -6 -.8 -4', '#f2d297', .78),
    ].join(''));
    return {
      drawing: [
        echoLeg(motion, color, false), echoLeg(motion, color, true), farArm.drawing,
        echoCloth(color, isAma, motion, hip), body,
        group(`translate(${point(head)}) rotate(${motion.lean * .45 + motion.nod})`, echoHead(color, isAma)),
        nearArm.drawing,
      ].join(''),
      landmark: extend(motion.nearHand, nearArm.elbow, 5),
    };
  }

  function extend(wrist, elbow, offset) {
    const distance = Math.hypot(wrist[0] - elbow[0], wrist[1] - elbow[1]) || 1;
    return along(elbow, wrist, 1 + offset / distance);
  }

  const dustBase = [1, 0, -8, 13, -3, 12, -1, -12, -2];
  const dustPoses = {
    punch: [
      [0, ...dustBase],
      [.31, -5, -2, -33, -5, 15, 11, -1, -14, -2],
      [.43, -3, 3, -22, -21, 7, 10, -1, -14, -2],
      [.52, 7, 4, 24, 34, -6, 16, -1, -13, -2],
      [.64, 8, 6, 32, 29, 7, 17, -1, -12, -2],
      [.81, 2, 2, 6, 18, 10, 14, -1, -12, -2],
      [1, ...dustBase],
    ],
    guard: [
      [0, ...dustBase], [.27, -1, 7, -20, 9, -12, 14, -1, -12, -2],
      [.56, -5, 10, -31, 11, -13, 15, -1, -14, -2], [.78, -1, 5, -12, 14, -7, 14, -1, -14, -2],
      [1, ...dustBase],
    ],
    hit: [
      [0, ...dustBase], [.15, -8, 2, -35, -13, -9, 12, -1, -18, -2],
      [.31, -13, 7, -40, -7, 12, 13, -1, -21, -2], [.62, -5, 4, 4, 6, 13, 13, -1, -16, -2],
      [1, ...dustBase],
    ],
    defeated: [
      [0, ...dustBase], [.17, -6, 4, -30, -12, -5, 13, -1, -15, -2],
      [.44, -10, 18, -67, -13, 9, 13, -1, -19, -2], [.72, -10, 29, -77, 5, 11, 18, -1, -21, -2],
      [1, -10, 31, -79, 9, 12, 18, -1, -21, -2],
    ],
  };

  function dustFigure({ pose, phase, time, stride, rise, reach, impactY }) {
    const values = dustPoses[pose] ? curve(phase, dustPoses[pose]) : dustBase;
    const [x, dip, lean, tx, ty, nx, ny, fx, fy] = values;
    let pelvis = [x, -28 + dip + Math.sin(time * 4.2) * 1.5];
    let tilt = lean + Math.sin(time * 3.6) * 3;
    let nearFoot = [nx, ny];
    let farFoot = [fx, fy];
    let tip = [tx, -36 + ty];
    const blend = walkBlend(pose, phase);
    if (blend) {
      const cycle = pose === 'walk' ? phase : 0;
      const kick = Math.sin(cycle * tau);
      const [sx, sy] = step(cycle, stride, -1, 10, 0);
      const [dx, dy] = step(cycle, stride, -3, 8, .5);
      nearFoot = along(nearFoot, [sx + 2, sy + sx * rise / stride], blend);
      farFoot = along(farFoot, [dx - 2, dy + dx * rise / stride], blend);
      pelvis = along(pelvis, [3, -26 - Math.cos(cycle * tau * 2) * 2.8], blend);
      tilt = mix(tilt, 13 + kick * 5, blend);
      tip = along(tip, [10 + kick * 6, -30 - kick * 4], blend);
    }
    const drive = strikeDrive(pose, phase);
    const aim = Number.isFinite(impactY) ? clamp(impactY + 42, -28, 37) * drive : 0;
    tip = [tip[0] + (reach - 36) * drive, tip[1] + aim];
    pelvis[1] += aim * .28;
    const shoulder = twist([pelvis[0] + 5, pelvis[1] - 14], pelvis, tilt);
    const hinge = joint(shoulder, tip, 12, 14, -1);
    const tailCycle = pose === 'walk' ? phase * tau : 0;
    const tail = Math.sin(time * 7 - tailCycle) * 5 - tilt * .21;
    const defeated = pose === 'defeated' ? ease(phase, .38, 1) : 0;
    const spur = (foot, far) => {
      const start = [pelvis[0] + (far ? 2 : -2), pelvis[1] + (far ? 2 : 0)];
      const knee = joint(start, foot, 14, 17, far ? 1 : -1);
      return group('', [
        segment(start, knee, 4.8, 2.5, far ? '#785039' : '#a87946', '#d3a462', '#65432e'),
        path(`M${point([knee[0]-2.6,knee[1]-1])} L${point([knee[0]+1.5,knee[1]-2])} L${point([foot[0]+2.5,foot[1]+1])} L${point([foot[0]-2,foot[1]+.5])}Z`, far ? '#76543b' : '#b4834e'),
        line(`M${point(knee)} L${point(along(knee, foot, .8))}`, '#e0aa62'),
      ].join(''), far ? .86 : 1);
    };
    const body = group(`translate(${point(pelvis)}) rotate(${tilt})`, [
      path(`M1 -20 Q-9 -25 ${-19+tail} -16 Q${-27+tail} -12 ${-34+tail} -18 Q${-34+tail} -11 ${-26+tail} -10 Q${-24+tail} -5 ${-34+tail} -4 L${-21+tail} -3 L-9 -8 L6 -13Z`, '#955539'),
      line(`M-4 -18 Q-15 -17 ${-23+tail} -12 Q${-30+tail} -11 ${-32+tail} -15`, '#c98b58', 1.15),
      path(`M8 -24 Q-2 -26 -8 -16 L${-18+tail*.5} -7 L-10 -6 L${-20+tail} 0 L-9 -1 L-16 6 L-3 3 L1 8 L6 -3 L13 -8Z`, '#b28751'),
      path('M-5 -15 L4 -19 L7 -15 L-3 -9 L-14 -6Z M-6 -4 L2 -8 L5 -4 L-3 2 L-10 3Z', '#7b5337', 'none'),
      path('M3 -12 Q-3 -16 -.3 -25 L7 -34 L20 -38 L15 -33 L24 -34 L19 -30 L24 -29 L20 -25 Q22 -20 16 -15 L12 -9Z', '#c6a36a'),
      path('M15 -31 Q20 -30 21 -26 Q18 -17 12 -15 Q9 -18 11 -24Z', '#3e2a23', '#704b32', .9),
      path('M18.8 -28.6 Q18 -23 14.6 -18.6 Q15 -24 18.8 -28.6Z', '#edb95a', 'none'),
      line('M2 -22 Q5 -28 12 -31 M1 -19 Q3 -16 7 -14 M4 -14 L7 -10 M-8 -12 L-1 -16 M-9 -4 L-2 -8', '#ecd29b', .98),
      line('M9 -30 L10 -27 M4 -20 L5 -18 M-2 -12 L2 -14', '#82583b', .9),
    ].join(''));
    const tendril = [
      segment(shoulder, hinge, 3.2, 2.4, '#b0804b', '#e0b879', '#6d472c'),
      path(`M${point([hinge[0]-1,hinge[1]-2])} Q${point(along(hinge,tip,.6))} ${point(tip)} L${point([tip[0]-3,tip[1]+4])} L${point([hinge[0]+2,hinge[1]+3])}Z`, '#9e673f'),
      line(`M${point(hinge)} L${point(along(hinge,tip,.88))}`, '#d9a765'),
    ].join('');
    return {
      drawing: group('', spur(farFoot, true) + spur(nearFoot, false) + tendril + body, 1 - defeated * .26),
      landmark: tip,
    };
  }

  const bruteBase = [0, 0, 0, 19, -2, 3, -6, -15, -3, -22, -7];
  const brutePoses = {
    punch: [
      [0, ...bruteBase], [.26, -4, -3, -14, 9, -9, 1, -6, -16, -3, -22, -7],
      [.42, -4, -6, -23, 5, -26, 2, -6, -16, -3, -22, -7],
      [.52, 7, 1, 13, 35, -22, 6, -6, -17, -3, -22, -7],
      [.63, 7, 5, 19, 35, -5, 6, -6, -17, -3, -22, -7],
      [.8, 4, 4, 6, 25, -2, 5, -6, -16, -3, -22, -7], [1, ...bruteBase],
    ],
    guard: [
      [0, ...bruteBase], [.3, 2, 6, 12, 23, -2, 9, -6, -17, -3, -22, -7],
      [.57, -4, 7, 0, 23, -2, 9, -6, -18, -3, -23, -7], [1, ...bruteBase],
    ],
    hit: [
      [0, ...bruteBase], [.17, -8, -2, -17, 19, -4, 4, -6, -15, -3, -22, -7],
      [.38, -11, 6, -9, 18, -2, 3, -6, -24, -3, -26, -7],
      [.69, -5, 2, 6, 18, -2, 4, -6, -20, -3, -24, -7], [1, ...bruteBase],
    ],
    defeated: [
      [0, ...bruteBase], [.18, -6, -3, -16, 18, -6, 4, -6, -16, -3, -22, -7],
      [.42, -7, 8, 14, 24, -2, 7, -6, -22, -3, -28, -7],
      [.7, -8, 17, 29, 27, -1, 9, -5, -26, -3, -31, -7],
      [1, -7, 18, 25, 27, -1, 9, -5, -27, -3, -31, -7],
    ],
  };

  function stoneLeg(a, b, large, far) {
    const size = large ? 1 : .71;
    const elbow = joint(a, b, 12 * size, 14 * size, large ? -1 : 1);
    const fill = far ? '#87583f' : '#a96440';
    const pale = far ? '#b78457' : '#dc9f6e';
    const shade = far ? '#604230' : '#714831';
    const drawing = [
      segment(a, elbow, 7 * size, 6.6 * size, fill, pale, shade),
      segment(elbow, b, 6.2 * size, 5 * size, fill, pale, shade),
      group(`translate(${point(elbow)}) rotate(${angle(a, elbow)}) scale(${size})`, [
        path('M-8 -5 L-3 -7 L4 -5 L6 -.5 L1 4 L-5 3 L-7 1Z', fill),
        path('M-7 -4 L-2 -6 L3 -4 L.4 -2 L-5 -1Z', pale, 'none'),
        line('M-3 0 L-1 1 L-2 3', shade, .82),
      ].join('')),
      group(`translate(${point(b)}) scale(${size})`, [
        path('M-5 -6 L1 -7 L5 -4 L8 -1 L7 3 L-5 3 L-8 .4Z', fill),
        path('M-5 1 L1 .4 L5 -.8 L7 -.1 L6.5 3 L-5 3Z', shade, 'none'),
        line('M-3 -4 L1 -5.5 L4 -3.5 M-3 -.1 L-4 2 M1 -.5 L1 2 M4 -1 L5 2', pale, .8),
      ].join('')),
    ].join('');
    return drawing;
  }

  function bruteFigure({ pose, phase, time, stride, rise, reach, impactY }) {
    const values = brutePoses[pose] ? curve(phase, brutePoses[pose]) : bruteBase;
    const [x, dip, lean, nx, ny, fx, fy, rx, ry, bx, by] = values;
    let body = [x, -25 + dip + Math.sin(time * 2.7) * 1.05];
    let tilt = lean;
    let nearFront = [nx, ny];
    let farFront = [fx, fy];
    let nearRear = [rx, ry];
    let farRear = [bx, by];
    const blend = walkBlend(pose, phase);
    if (blend) {
      const cycle = pose === 'walk' ? phase : 0;
      const foot = (offset, restX, depth, lift) => {
        const [sx, sy] = step(cycle, stride, depth, lift, offset);
        return [restX + sx, sy + sx * rise / stride];
      };
      nearFront = along(nearFront, foot(0, 17, -2, 7), blend);
      farFront = along(farFront, foot(.5, 6, -6, 5), blend);
      nearRear = along(nearRear, foot(.66, -13, -3, 5), blend);
      farRear = along(farRear, foot(.16, -19, -7, 6), blend);
      body = along(body, [Math.sin(cycle * tau) * 2, -25 + Math.cos(cycle * tau * 2) * 2], blend);
      tilt = mix(tilt, Math.sin(cycle * tau) * 8, blend);
    }
    const drive = strikeDrive(pose, phase);
    const aim = Number.isFinite(impactY) ? clamp(impactY + 23, -32, 20) * drive : 0;
    nearFront = [nearFront[0] + (reach - 36) * drive, nearFront[1] + aim];
    body[1] += aim * .46;
    const at = (dx, dy) => twist([body[0] + dx, body[1] + dy], body, tilt);
    const warmth = pose === 'defeated' ? 1 - ease(phase, .25, .93) : .89 + Math.sin(time * 4) * .11;
    const carapace = group(`translate(${point(body)}) rotate(${tilt})`, [
      path('M-27 -2 L-24 -10 L-18 -14 L-13 -15 L-10 -18 L4 -19 L13 -15 L21 -9 L23 -2 L17 7 L11 10 L-4 9 L-11 7 L-19 8 L-25 5Z', '#81543c'),
      path('M-24 -5 L-18 -13 L-10 -15 L-2 -13 L-6 -8 L-15 -5 L-22 -2Z M-14 0 L-8 -4 L-3 -2 L-7 2 L-15 4Z', '#a7724b', ink, .7),
      path('M-5 -11 L1 -17 L12 -16 L17 -11 L17 -3 L11 2 L2 1 L-4 -4Z', '#3f2c23'),
      group('', [
        path('M5 -5 Q10 -3 14 -8 Q14 -3 11 -.8 Q7 1 5 -5Z', '#b86c38', 'none'),
        line('M6 -4 Q11 -2 13 -6', '#f1bc60', 1.25),
      ].join(''), warmth),
      path('M-12 -10 L-5 -22 L7 -26 L15 -24 L14 -18 L10 -11 L3 -7 L-2 -7 L-7 -3 L-11 -5Z', '#b87249'),
      path('M-9 -12 L-4 -21 L6 -24 L13 -23 L6 -19 L1 -15 L-5 -13Z', '#df9a63', 'none'),
      path('M10 -12 L16 -13 L22 -9 L24 -4 L21 0 L13 -1 L11 -4Z', '#a76c48'),
      path('M13 -10 L17 -11 L22 -8 L23 -5 L18 -6 L14 -5Z', '#d09160', 'none'),
      line('M-7 -11 L-2 -14 L1 -13 L5 -16 M-3 -22 L-1 -18 M9 -24 L8 -21 M-20 -6 L-16 -8 M-17 4 L-11 1 M17 -5 L18 -2', '#6e4834', 1),
      line('M-4 -20 L1 -21 M1 -17 L5 -20 M-21 -8 L-16 -11 M14 -8 L17 -10', '#efb578', .8),
    ].join(''));
    return {
      drawing: [
        stoneLeg(at(-15, -1), farRear, false, true),
        stoneLeg(at(8, -3), farFront, true, true),
        stoneLeg(at(-18, 0), nearRear, false, false),
        carapace,
        stoneLeg(at(13, -3), nearFront, true, false),
      ].join(''),
      landmark: [nearFront[0] + 7, nearFront[1] - 1],
    };
  }

  function shrineFigure({ state, time }) {
    const purified = state === 'purified';
    const destroyed = state === 'destroyed';
    const tremble = Math.sin(time * 5.3);
    const hem = Math.sin(time * 3.8) * 1.8;
    const plinth = [
      path('M-31 -2 L-19 -11 L17 -11 L34 -2 L24 7 L-18 9Z', '#7f6348'),
      path('M-31 -2 L-18 -7 L18 -8 L34 -2 L20 3 L-16 5Z', '#b39768'),
      line('M-18 5 L-18 9 M20 3 L24 7 M-18 -7 L-12 -4 L-14 .5 M14 -6 L10 -3', '#705339', .92),
      path('M-29 -2 L-23 -6 L-18 -4 L-20 0 L-26 2Z M24 1 L27 -3 L32 -.5 L31 3 L25 4Z', '#9a7857', ink, .7),
    ].join('');
    if (destroyed) {
      return {
        drawing: plinth + [
          path('M-26 -2 L-26 -18 L-21 -23 L-18 -16 L-16 -20 L-17 -2Z', '#8f5433'),
          line('M-23 -16 L-23 -4 M-20 -13 L-21 -9', '#c78b51', 1),
          path('M2 0 L25 -21 L31 -20 L28 -16 L30 -13 L12 3Z', '#8c5234'),
          line('M8 0 L24 -13 M19 -13 L25 -18', '#d18f51', 1),
          path('M-24 -7 L-12 -14 L-4 -11 L3 -10 L7 -5 L14 -3 L6 3 L-9 2 L-14 4Z', '#b29a72'),
          line('M-19 -6 L-13 -9 L-8 -7 L-4 -8 L3 -5 L6 -6', '#854d37', 1.7),
          path('M-6 -4 L-5 -14 L2 -18 L9 -15 L5 -9 L8 -8 L9 -3 L1 1Z M12 -4 L17 -11 L19 -7 L24 -6 L24 -2Z', '#a75637'),
          line('M-4 -8 L0 -12 L3 -9 L5 -10 M14 -6 L19 -4', '#d38a52'),
          path('M-1 -3 L2 -7 L4 -4 L4 -1Z M-15 -5 L-12 -9 L-10 -6Z', '#8f583e', ink, .65),
        ].join(''),
        landmark: [0, -15],
      };
    }
    const post = group('', [
      path('M-3 0 L-3 -53 L-.2 -56 L4 -53 L3 -1Z', '#996540'),
      path('M-.5 -53 L.4 -1 L3 -1 L4 -53 L2 -54Z', '#654634', 'none'),
      line('M-2 -50 L-2 -3 M1 -49 L1 -45 M0 -36 L0 -24 M0 -14 L0 -11', '#cc975b', .85),
      line('M-4 -46 Q0 -43 4 -46 M-4 -43 Q0 -40 4 -43 M-4 -12 Q0 -9 4 -12 M-4 -9 Q0 -6 4 -9', '#cf9a50', 1.8),
    ].join(''));
    const roof = [
      path(`M-24 -52 Q-4 -46 26 -59 L29 -53 Q17 -43 1 ${-39+hem*.3} Q-11 -38 -25 -46Z`, '#c39c64'),
      path(`M-26 -48 Q-8 -38 27 -56 Q23 -41 25 -40 L20 -39 L18 -35 L14 -36 L11 -33 L7 -34 L3 ${-31+hem} L-1 ${-33+hem} L-7 ${-30+hem} L-11 ${-33+hem} L-16 ${-31+hem} L-18 -35 L-22 -34Z`, purified ? '#f2d29a' : '#e4bf89'),
      path(`M-24 -42 Q-4 -35 23 -49 L20 -44 Q-2 -34 -23 -39Z`, purified ? '#7e945c' : '#a75d41', 'none'),
      line(`M-22 -39 Q-1 -34 23 -47 M-19 -36 L-19 ${-32+hem} M-12 -35 L-12 ${-31+hem} M-5 -33 L-5 ${-30+hem} M2 -34 L2 ${-31+hem} M9 -36 L9 -33 M16 -39 L16 -36 M22 -42 L22 -39`, '#e7a95e', .86),
      line('M-20 -50 Q0 -45 25 -57', '#f1ce95', 1),
    ].join('');
    const glow = purified ? '#edb85c' : '#985f50';
    const jar = [
      path('M-9 -22 Q-7 -19 -9 -17 Q-15 -13 -13 -7 Q-12 -2 -3 -1 Q9 -1 12 -7 Q14 -13 8 -18 L8 -22Z', '#a85b37'),
      path('M-10 -15 Q-5 -13 10 -17 L12 -13 Q4 -9 -12 -11Z', '#ce9055', 'none'),
      path('M-12 -9 Q-1 -6 12 -11 L11 -6 Q4 -.5 -10 -4Z', '#783f30', 'none'),
      ellipse(-.5, -22.2, 9, 3, '#bd7d4d', ink, .9),
      ellipse(-.5, -22.5, 6.6, 1.8, '#4d342c'),
      line('M-9 -12 L-5 -9 L-1 -14 L4 -10 L8 -14', '#e8a766', 1.15),
      ellipse(14, -2, 6, 2.6, '#a66e42', ink, .75),
      ellipse(14, -2.5, 4.4, 1.4, '#5d4335'),
    ].join('');
    const movement = purified ? [
      ellipse(0, -23, 9 + tremble * 2, 2.2, glow, 'none', 0),
      line(`M-5 -23 Q${-8+tremble*3} -27 -3 -32 M1 -23 Q${5+tremble*3} -27 3 -35`, '#edc271', 1.25),
      ellipse(3 + tremble * 2, -36, 1, 1.4, '#f5d285'),
    ].join('') : [
      line(`M2 -23 Q${5+tremble*2} -26 1 -29 Q${-2+tremble*3} -31 2 -34`, glow, 1.45),
      ellipse(2 + tremble * 2, -35, .8, 1.1, '#7f594f'),
    ].join('');
    return {
      drawing: plinth + group('translate(25 -3)', post) + jar + movement + roof + group('translate(-24 1) scale(-1 1)', post),
      landmark: [0, -24],
    };
  }

  function settings(options) {
    return {
      ...options,
      pose: options.pose || 'idle',
      phase: clamp(options.phase ?? 0),
      time: options.time ?? 0,
      stride: clamp(options.stride ?? 54, 25, 72),
      rise: options.rise ?? 0,
      reach: clamp(options.reach ?? 36, 28, 47),
    };
  }

  function figure(options) {
    const motion = settings(options);
    if (motion.id === 'dw') return dustFigure(motion);
    if (motion.id === 'vb') return bruteFigure(motion);
    if (motion.id === 'shrine') return shrineFigure(motion);
    return echoFigure(motion.id, echoMotion(motion));
  }

  window.StorybookFigures = {
    draw(parent, options) {
      const { id, x, y, facing = 1 } = options;
      const { drawing } = figure(options);
      const direction = id === 'shrine' ? 1 : facing;
      parent.insertAdjacentHTML('beforeend', group(`translate(${x} ${y}) scale(${direction} 1)`, drawing));
    },
    landmark(options) {
      const { id, x, y, facing = 1 } = options;
      const { landmark: [localX, localY] } = figure(options);
      return { x: x + localX * (id === 'shrine' ? 1 : facing), y: y + localY };
    },
  };
})();
