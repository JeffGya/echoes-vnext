(() => {
  'use strict';

  const svgNamespace = 'http://www.w3.org/2000/svg';
  const halfTileWidth = 54;
  const halfTileHeight = 27;
  const columns = 8;
  const rows = 6;
  const ink = '#452f26';
  const slab = 'M119 304 L140 292 162 284 175 273 213 258 234 243 272 227 298 209 325 199 351 182 379 173 406 155 433 145 446 139 468 150 494 161 515 173 541 184 562 198 600 214 618 225 648 237 678 254 709 266 725 278 752 289 781 306 813 320 834 334 857 345 882 358 861 371 838 380 810 397 788 406 761 422 737 433 709 449 683 460 654 478 631 486 598 504 575 514 554 524 533 516 503 501 483 488 450 475 427 460 398 450 375 436 347 423 322 410 294 399 270 384 245 374 219 358 194 348 174 335 151 327 130 314 Z';

  let boardCount = 0;

  function point(col, row) {
    return {
      x: 446 + halfTileWidth * (col - row),
      y: 170 + halfTileHeight * (col + row),
    };
  }

  function add(parent, tag, attributes = {}) {
    const node = document.createElementNS(svgNamespace, tag);
    for (const [name, value] of Object.entries(attributes)) {
      node.setAttribute(name, value);
    }
    parent.append(node);
    return node;
  }

  function path(parent, d, fill, attributes = {}) {
    return add(parent, 'path', { d, fill, ...attributes });
  }

  function ellipse(parent, cx, cy, rx, ry, fill, opacity = 1) {
    return add(parent, 'ellipse', { cx, cy, rx, ry, fill, opacity });
  }

  function line(parent, d, stroke, width = 1, opacity = 1) {
    return path(parent, d, 'none', {
      stroke, 'stroke-width': width, opacity, 'stroke-linecap': 'round',
      'stroke-linejoin': 'round',
    });
  }

  function gradient(defs, tag, id, stops, attributes = {}) {
    const paint = add(defs, tag, { id, ...attributes });
    for (const [offset, color, opacity = 1] of stops) {
      add(paint, 'stop', { offset, 'stop-color': color, 'stop-opacity': opacity });
    }
    return `url(#${id})`;
  }

  function paintSupplies(scene, id) {
    const defs = add(scene, 'defs');
    const backdrop = gradient(defs, 'radialGradient', `${id}-backdrop`, [
      ['0%', '#584431'], ['53%', '#3e3026'], ['100%', '#251c18'],
    ], { cx: '45%', cy: '43%', r: '71%' });
    const ravine = gradient(defs, 'linearGradient', `${id}-ravine`, [
      ['0%', '#332822', .06], ['46%', '#222527', .87], ['100%', '#25201d', .3],
    ], { x1: '0%', y1: '0%', x2: '22%', y2: '100%' });
    const clay = gradient(defs, 'linearGradient', `${id}-clay`, [
      ['0%', '#e1ae73'], ['58%', '#bc8756'], ['100%', '#a76943'],
    ], { x1: '0%', y1: '0%', x2: '18%', y2: '100%' });
    const light = gradient(defs, 'radialGradient', `${id}-light`, [
      ['0%', '#ffdb9d', .23], ['59%', '#ecc087', .05], ['100%', '#5e3826', .18],
    ], { cx: '36%', cy: '26%', r: '79%' });
    const grain = add(defs, 'pattern', {
      id: `${id}-grain`, width: 41, height: 29, patternUnits: 'userSpaceOnUse',
    });
    path(grain, 'M3 2l2 1m11 0h1m10 5l2-1m8 7h2M8 12l2 1m8 3 2-1m12 8 1-1m-27 1 3-1m14 5h2', 'none', {
      stroke: '#f8d3a4', 'stroke-width': .7, opacity: .28,
    });
    path(grain, 'M7 3l1 1m14 4h1m15-4 2 1m-29 13 2-1m10 3h2m13 5-1 1m-26 2h1', 'none', {
      stroke: '#2f231b', 'stroke-width': .8, opacity: .28,
    });
    const clip = add(defs, 'clipPath', { id: `${id}-slab` });
    path(clip, slab, '#fff');

    const style = add(scene, 'style');
    style.textContent = `
      .storybook-board .vale-fronds {
        transform-box: view-box;
        transform-origin: 0 0;
        animation: vale-board-sway var(--vale-sway, 5s) ease-in-out var(--vale-delay, 0s) infinite;
      }
      .storybook-board .vale-dust {
        animation: vale-board-drift var(--vale-drift) linear var(--vale-delay) infinite;
      }
      .storybook-motion-paused .storybook-board .vale-fronds,
      .storybook-motion-paused .storybook-board .vale-dust,
      .storybook-board.storybook-motion-paused .vale-fronds,
      .storybook-board.storybook-motion-paused .vale-dust {
        animation-play-state: paused;
      }
      @keyframes vale-board-sway {
        0%, 100% { transform: rotate(-1deg); }
        44% { transform: rotate(3deg); }
        68% { transform: rotate(1deg); }
      }
      @keyframes vale-board-drift {
        0% { opacity: 0; transform: translate(0, 0); }
        22% { opacity: .49; }
        74% { opacity: .32; }
        100% { opacity: 0; transform: translate(43px, -11px); }
      }
      @media (prefers-reduced-motion: reduce) {
        .storybook-board .vale-fronds, .storybook-board .vale-dust { animation: none; }
      }
    `;

    return { backdrop, ravine, clay, light, grain: `url(#${id}-grain)`, clip: `url(#${id}-slab)` };
  }

  function drawSurround(scene, paint) {
    add(scene, 'rect', { width: 1000, height: 570, fill: paint.backdrop });
    path(scene, 'M0 227 60 190 98 184 136 151 172 149 203 125 249 127 289 109 339 113 380 90 417 94 470 119 506 117 565 151 600 149 669 185 707 187 774 224 810 223 861 253 908 255 961 293 1000 299 V480 H0Z', '#80634a', { opacity: .12 });
    path(scene, 'M0 267 59 221 125 222 161 198 207 199 250 168 302 164 365 186 415 181 465 204 500 198 544 222 588 209 638 231 692 214 753 234 805 214 845 220 900 197 961 223 1000 215 V505 H0Z', '#6d4c36', { opacity: .28 });
    path(scene, 'M0 321 C141 280 237 365 352 383 C526 429 637 356 756 342 C853 331 909 311 1000 329 V570 H0Z', paint.ravine);
    path(scene, 'M45 432l56-5 41 7 55 21-62-11-39 2Z M678 520l64-39 53-5 60-30-57 43-45 4Z M794 548l56-26 61-2 48-18-43 28-63 1Z', '#6a5a46', { opacity: .19 });
    add(scene, 'rect', { width: 1000, height: 570, fill: paint.grain, opacity: .47 });
  }

  function drawCliffs(scene) {
    const rocks = add(scene, 'g', { 'stroke-linejoin': 'round' });
    path(rocks, 'M119 304 554 524 882 358 872 396 841 407 815 428 770 446 742 465 712 477 685 494 647 504 622 524 590 534 551 561 516 547 491 530 453 517 428 505 382 485 359 468 324 454 301 437 271 428 250 413 220 399 189 381 160 371 131 350 123 335Z', '#473c35', { stroke: '#342923', 'stroke-width': 2 });
    const faces = [
      [120,307,22,19], [145,323,26,33], [174,336,38,29], [212,354,24,45],
      [240,369,32,37], [274,386,26,43], [304,399,30,47], [339,417,23,40],
      [364,430,32,43], [397,445,32,46], [429,462,28,44], [464,479,26,43],
      [497,497,29,39], [529,511,25,38], [554,524,31,33], [589,505,31,28],
      [625,486,23,35], [653,477,27,25], [684,459,23,32], [711,446,22,29],
      [739,433,28,34], [770,416,30,26], [806,399,25,27], [835,382,24,22], [860,369,18,23],
    ];
    const pigments = ['#a16d45', '#795c46', '#8f6347', '#6f5949', '#a67852', '#76553d'];
    faces.forEach(([x, y, width, height], index) => {
      const slope = index < 14 ? .49 : -.49;
      const farY = y + width * slope;
      path(rocks, `M${x} ${y} l${width} ${width * slope} -3 ${height - 5} -${width - 7} ${-width * slope + 5}Z`, pigments[index % pigments.length], { stroke: '#4a382e', 'stroke-width': .8 });
      path(rocks, `M${x + 1} ${y + 2} l${width - 4} ${width * slope} -3 10 -${width - 12} ${-width * slope + 3}Z`, '#d39660', { opacity: .51 });
      path(rocks, `M${x + width * .64} ${y + 6 + width * .64 * slope} l${width * .31} ${width * .31 * slope} -3 ${height - 12} -${width * .26} ${-width * .26 * slope}Z`, '#3e3a36', { opacity: .47 });
      line(rocks, `M${x + width * .37} ${y + 4 + width * .37 * slope} l-2 9 2 6-3 7 M${x + width - 4} ${farY + height - 12} l-8 ${-4 * slope} -3 3`, '#302721', .9, .6);
    });
  }

  function drawClay(scene, paint) {
    path(scene, slab, paint.clay, { stroke: '#523529', 'stroke-width': 2.5 });
    const floor = add(scene, 'g', { 'clip-path': paint.clip });
    const colors = ['#d6a16a', '#c99865', '#ce925d', '#c99260', '#d2a16b', '#c38856'];
    const wash = ['#f4c58b', '#a96d45', '#e2ad73', '#b88152', '#e7b57a'];
    let seed = 1807;
    const sample = () => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      return seed / 4294967296;
    };
    for (let row = 0; row < rows; row += 1) {
      for (let col = 0; col < columns; col += 1) {
        const { x, y } = point(col, row);
        path(floor, `M${x} ${y - halfTileHeight} l${halfTileWidth} ${halfTileHeight} -${halfTileWidth} ${halfTileHeight} -${halfTileWidth} -${halfTileHeight} Z`,
          colors[Math.floor(sample() * colors.length)], { opacity: .67 });
        for (let index = 0; index < 9; index += 1) {
          const across = (sample() - .5) * 76;
          const down = (sample() - .5) * (37 - Math.abs(across) * .48);
          const width = 4 + sample() * 18;
          const height = 1 + sample() * 5;
          path(floor, `M${(x + across).toFixed(1)} ${(y + down).toFixed(1)} q${width * .37} ${-height} ${width} ${-height * .29} l-${width * .22} ${height} -${width * .42} ${height * .25}Z`,
            wash[Math.floor(sample() * wash.length)], { opacity: .15 + sample() * .18 });
        }
      }
    }
    add(floor, 'rect', { width: 1000, height: 570, fill: paint.light });
    add(floor, 'rect', { width: 1000, height: 570, fill: paint.grain, opacity: .68 });

    // Only the painted joins wander. Tile centers keep the exact 2:1 projection.
    for (let col = 0; col <= columns; col += 1) {
      const { x, y } = point(col - .5, -.5);
      line(floor, `M${x} ${y} q-136 67 -324 162`, '#775034', 1.15, .36);
      line(floor, `M${x + 1} ${y + 1} q-136 67 -324 162`, '#f4c893', .9, .54);
    }
    for (let row = 0; row <= rows; row += 1) {
      const { x, y } = point(-.5, row - .5);
      line(floor, `M${x} ${y} q197 96 432 216`, '#775034', 1.15, .36);
      line(floor, `M${x - 1} ${y + 1} q197 96 432 216`, '#f4c893', .9, .54);
    }
    path(floor, slab, 'none', { stroke: '#f4c58b', 'stroke-width': 4, opacity: .37 });
  }

  function drawStones(scene, x, y, scale = 1) {
    const group = add(scene, 'g', {
      transform: `translate(${x} ${y}) scale(${scale})`,
      stroke: ink, 'stroke-width': 1.1, 'stroke-linejoin': 'round',
    });
    ellipse(group, -2, 1, 35, 9, '#634732', .24);
    path(group, 'M-27-2 -23-24 -13-33 7-30 15-18 17 1 4 7 -13 6Z', '#8d674a');
    path(group, 'M-23-24 -13-33 7-30 15-18 -1-16 -14-20Z', '#d29c67');
    path(group, 'M-23-24 -14-20 -16 5 -27-2Z M-1-16 15-18 17 1 4 7Z', '#685242');
    path(group, 'M3 7 7-7 18-13 32-8 36 3 25 10 13 11Z', '#92704f');
    path(group, 'M7-7 18-13 32-8 24-4 13-3Z', '#bd8b5e');
    path(group, 'M24-4 32-8 36 3 25 10Z', '#6e5240');
    line(group, 'M-12-26l7-2 5 1m-6 12-3 6 2 8m26-4 4 1m-48 8 7 2', '#5e422e', .9, .71);
  }

  function drawPebbles(scene) {
    const deposits = [
      [160,301,1], [218,267,1], [242,346,1.2], [294,383,1], [337,196,.85],
      [407,163,1], [465,173,1.2], [488,214,.7], [532,188,1.15], [561,235,.75],
      [631,255,.85], [670,264,1.05], [719,295,1.1], [792,330,1.1], [822,360,1],
      [812,380,1.2], [673,446,.9], [610,474,.9], [567,492,1.1], [466,472,1.12],
      [392,437,1], [361,419,.9], [323,400,.8],
    ];
    for (const [x, y, scale] of deposits) {
      const group = add(scene, 'g', { transform: `translate(${x} ${y}) scale(${scale})`, opacity: .76 });
      path(group, 'M-13 0 -8-5 0-5 5-1 2 3 -7 4Z M8 4 11 1 17 1 19 4 15 7Z M-18 5l4-2 3 2-3 2Z', '#7b583e');
      path(group, 'M-13 0 -8-5 0-5 5-1 -2 1 -8 2Z M8 4 11 1 17 1 19 4 13 5Z', '#dfad76');
      line(group, 'M-6-10l4-2m12 1 6 1m-5 12 3 1', '#865e3d', .7, .6);
    }
  }

  function drawPlant(scene, x, y, scale, color, delay) {
    const group = add(scene, 'g', { transform: `translate(${x} ${y}) scale(${scale})` });
    ellipse(group, 2, 3, 19, 4, '#4f3f2e', .34);
    const leaves = add(group, 'g', {
      class: 'vale-fronds', style: `--vale-delay:${delay}s;--vale-sway:${5 - delay * .41}s`,
    });
    path(leaves, 'M1 2Q-5-14-23-22 -23-11-14-8L-4 3Q-13-18-11-35 -2-29 0-18L2-2Q0-21 14-35 15-23 11-17L4 0Q14-19 26-17 23-10 16-7L7 2Q15-5 23-2 20 5 1 5Z',
      color, { stroke: '#4a3929', 'stroke-width': 1.1, 'stroke-linejoin': 'round' });
    line(leaves, 'M0 1Q-7-11-17-16 M3 0Q5-19 12-29 M8 0l11-12 M1 1 -7-27', '#d6ae70', .8, .61);
    path(leaves, 'M-5 2Q-16-9-24-4 -20 4-10 5L3 5Q7-5 15-6 15 1 6 6Z', '#6a6741', { stroke: '#52432f', 'stroke-width': .7 });
  }

  function drawTree(scene) {
    const tree = add(scene, 'g', { transform: 'translate(247 237)' });
    ellipse(tree, 12, 7, 65, 13, '#57402c', .33);
    const bark = { stroke: '#3e2c24', 'stroke-width': 1.8, 'stroke-linejoin': 'round' };
    path(tree, 'M-41 17C-24 8-31 2-11-9 -7-25 2-38 4-49 4-61-13-67-31-69L-36-77Q-9-79 9-62 19-83 17-98L26-98Q33-77 25-61 40-81 69-90L74-88Q56-76 49-67 63-72 82-71L86-66Q69-64 53-58 34-51 26-38 17-24 15-12 21-8 36-6L49 1 46 6 18 3 8 10 -2 14 -21 9 -35 23Z', '#96633e', bark);
    path(tree, 'M-27 14C-18 0-8-3-3-20 6-39 12-49 17-64 24-75 26-85 23-95L27-95Q33-76 24-56 33-67 45-72 59-81 70-87 61-77 48-68 40-57 29-50 15-33 7-11L10 1 -6 10 -15 5Z', '#bd8250');
    path(tree, 'M-18 7Q-8-9-5-22 1-36 8-47 2-63-13-67L-27-70 -21-74Q4-71 14-58 10-40 3-26L-3-2Z', '#69472f');
    line(tree, 'M-26 12q21-15 25-29 7-20 20-32m-8 34q6-12 13-20m-40-34q14 1 22 9m40-7 15-8m-54 73 10-2 17 4', '#e0a969', 1.5, .75);
    line(tree, 'M-16 3q15-17 20-35m3 24 4-9m18-39 9-8M-4-51l-6-6', '#593b2b', 1.2, .89);

    const canopy = add(tree, 'g', { transform: 'translate(16 -61)' });
    const crown = add(canopy, 'g', { class: 'vale-fronds', style: '--vale-delay:-1.3s;--vale-sway:8s' });
    const outline = { stroke: '#403627', 'stroke-width': 1.25, 'stroke-linejoin': 'round' };
    path(crown, 'M-98-8 -90-18 -77-20 -71-29 -54-28 -43-42 -28-42 -22-48 -7-48 0-60 19-59 29-65 48-59 53-52 71-54 87-45 96-35 114-33 125-20 121-12 109-11 99-3 85-4 76 2 56-1 43 5 27 0 14 5 1-3 -18 3 -32-6 -53-2 -65-7 -85-4Z', '#5f5d3e', outline);
    path(crown, 'M-105-14 -90-28 -76-29 -68-37 -52-34 -41-43 -20-45 -7-38 8-42 25-32 18-23 1-20 -13-26 -23-19 -45-24 -59-16 -73-20 -87-11Z', '#85764a', outline);
    path(crown, 'M-18-43 -6-58 8-59 17-68 39-67 46-60 63-62 75-54 85-51 95-41 89-33 67-34 59-27 43-32 31-28 17-35 7-34 -7-38Z', '#ab874d', outline);
    path(crown, 'M52-32 64-42 79-42 88-47 101-42 105-34 121-32 133-25 139-15 128-10 115-14 106-8 91-14 78-10 64-15 56-12 44-20Z', '#8b7949', outline);
    path(crown, 'M-88-24 -78-29 -67-28 -60-34 -51-29 -65-23Z M-40-37 -22-42 -12-39 -24-33 -35-31Z M8-55 16-62 31-63 38-56 25-54 17-49Z M45-56 58-59 71-52 60-47 50-49Z M92-39 104-34 112-34 126-25 111-24 105-28 95-27Z', '#c49a53', { opacity: .8 });
    path(crown, 'M-89-11l20-9 15 4 10-5 15 4-18 7-17-1-8 4Z M-27-7l13-9 19 6 16-6 12 9-17 5-14-5-14 5Z M37-16l15-9 12 6 13-5 15 7-11 10-16-4-15 4Z', '#405049', { opacity: .78 });
    line(crown, 'M-78-25l7-2m19-4 9-1m21-6 7 2m33-21 7-1m22 13 9 3m31-9 7 2m14 13 9 3m-70 2-9 3m-55-4 8-1', '#dec084', 1.3, .5);
  }

  function drawBridge(scene) {
    const ledge = add(scene, 'g', { stroke: '#3c2c24', 'stroke-width': 1.4, 'stroke-linejoin': 'round' });
    path(ledge, 'M890 482 901 507 932 526 973 536 1000 534V483L961 472 929 473Z', '#625246');
    path(ledge, 'M888 480 905 466 924 464 940 452 969 458 989 455 1000 460V503L974 502 953 494 934 498 911 489Z', '#b78455');
    path(ledge, 'M900 474 919 469 929 470 941 458 967 463 989 460 1000 465 984 471 961 470 952 478 925 475 911 482Z', '#d4a16b', { stroke: 'none' });
    line(ledge, 'M915 490l5 16m14-7 4 16m17-17 4 23m20-17 1 25m-31-58 13 2m10-3 17 5', '#69533f', 1.4);

    const bridge = add(scene, 'g', { 'stroke-linejoin': 'round', 'stroke-linecap': 'round' });
    path(bridge, 'M754 411Q808 468 900 493L929 478Q831 453 779 399Z', '#4b3629', { stroke: '#342820', 'stroke-width': 2 });
    for (let plank = 0; plank < 13; plank += 1) {
      const t = plank / 13;
      const x = 755 + t * 148;
      const y = 410 + t * (113 - 31 * t);
      path(bridge, `M${x} ${y}l23-12 11 6-24 13Z`, plank % 3 === 0 ? '#bc8a55' : '#a47347', { stroke: '#523827', 'stroke-width': 1 });
      line(bridge, `M${x + 7} ${y + 2}l17-10`, '#ddaf71', .8, .68);
    }
    line(bridge, 'M755 411Q817 474 902 494 M778 399Q840 459 926 480', '#382922', 4);
    line(bridge, 'M755 410Q817 473 902 493 M778 398Q840 458 926 479', '#b88a55', 2.1);

    const stakes = [[755,410,27], [778,398,26], [902,493,23], [926,480,24]];
    for (const [x, y, height] of stakes) {
      path(bridge, `M${x - 3} ${y}v-${height}l7-3 4 3v${height}l-5 4Z`, '#805939', { stroke: '#4a3528', 'stroke-width': 1.3 });
      path(bridge, `M${x - 3} ${y - height}l7-3 4 3-5 3Z`, '#d5a574');
      line(bridge, `M${x - 4} ${y - height + 8}q8 4 13-1m-13 5q8 4 13-1`, '#d3a266', 2.15);
    }
    const rails = 'M756 392Q808 451 903 477 M779 380Q834 439 927 462';
    line(bridge, rails, '#543a28', 3.8);
    line(bridge, rails, '#bd915d', 1.8);
    line(bridge, 'M779 414v13m24 4v14m25 1v15m25-4v15m25-6v15m-78-79v13m24 5v14m25 1v14m25-2v15m25-7v15', '#ae7e50', 1.15, .88);
  }

  function drawRoots(scene) {
    for (const [x, y, scale] of [[175,332,.9], [293,391,.96], [420,454,.76], [841,378,.83]]) {
      const roots = add(scene, 'g', { transform: `translate(${x} ${y}) scale(${scale})` });
      const sweep = 'M-10-4Q3-10 8-1 11 9 4 20 -1 30-1 46 M7 3Q21 7 16 22 11 33 15 42 M6 7Q1 14-8 18-17 23-16 32';
      line(roots, sweep, '#49372b', 4);
      line(roots, sweep, '#9c784e', 2.1);
      line(roots, 'M4 22q4 8-1 15m14-17 6 8 1 8m-31-16-4 7m19-27 10 2', '#c39461', 1.15, .85);
    }
  }

  function drawDust(scene) {
    for (const [x, y, size, delay] of [[176,245,1.1,-5], [237,290,1.4,-2], [337,205,1.1,-6], [511,169,1.6,-2], [659,266,1,-8], [757,320,1.3,-3], [823,431,1.2,-1], [584,529,1.1,-5], [442,490,1.4,-7]]) {
      const speck = add(scene, 'g', {
        class: 'vale-dust', opacity: .23,
        style: `--vale-delay:${delay}s;--vale-drift:${9 + size}s`,
      });
      ellipse(speck, x, y, size * 1.8, size * .7, '#eed3a7');
      ellipse(speck, x + 12, y - 7, size * .65, size * .48, '#f2d4a7');
      ellipse(speck, x - 12, y - 2, size * .68, size * .48, '#e4b986');
    }
  }

  function draw(svgGroup) {
    const scene = add(svgGroup, 'g', {
      class: 'storybook-board', 'aria-hidden': 'true', 'pointer-events': 'none',
    });
    const paint = paintSupplies(scene, `storybook-vale-${++boardCount}`);
    drawSurround(scene, paint);
    drawCliffs(scene);
    drawClay(scene, paint);
    drawPebbles(scene);
    drawRoots(scene);
    drawBridge(scene);
    drawStones(scene, 164, 289, .83);
    drawStones(scene, 211, 266, .66);
    drawStones(scene, 357, 185, .67);
    drawStones(scene, 549, 197, .59);
    drawStones(scene, 661, 249, .7);
    drawStones(scene, 786, 317, .83);
    drawStones(scene, 906, 472, .46);
    drawPlant(scene, 158, 320, .59, '#827248', -.6);
    drawPlant(scene, 179, 277, .56, '#9e623e', -2.9);
    drawPlant(scene, 278, 224, .82, '#746b43', -4.1);
    drawTree(scene);
    drawPlant(scene, 329, 206, .77, '#9d663e', -3.7);
    drawPlant(scene, 578, 212, .7, '#877449', -1.2);
    drawPlant(scene, 691, 259, .85, '#a16a44', -3.2);
    drawPlant(scene, 713, 282, .57, '#87774b', -1.9);
    drawPlant(scene, 813, 330, .62, '#7e6b42', -2.6);
    drawPlant(scene, 841, 359, .54, '#ae7047', -1.4);
    drawPlant(scene, 276, 379, .62, '#9e623d', -3.2);
    drawPlant(scene, 386, 438, .48, '#867348', -1.8);
    drawPlant(scene, 492, 491, .53, '#8c774d', -4.7);
    drawPlant(scene, 981, 473, .8, '#817145', -1.9);
    drawDust(scene);
  }

  window.StorybookBoard = { point, draw };
})();
