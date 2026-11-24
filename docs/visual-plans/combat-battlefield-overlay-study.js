(() => {
  'use strict';

  const id = name => document.getElementById(name);
  const {point, draw} = window.StorybookBoard;
  const {draw: drawFigure} = window.StorybookFigures;
  const ns = 'http://www.w3.org/2000/svg';
  const cream = '#fff2d5', gold = '#ffdb8d', ink = '#2b201a';
  const layers = ['ground','figures','foreground','cues','known-cells'];
  const views = {
    footprint: [['field','Board view'],['route','Committed route']],
    reach: [['quiet','Board view'],['inspect','Inspect Dust Wanderer']],
    intel: [['lead','Lead only'],['survey','Terrain and objective confirmed']],
    overlap: [['all','All cues at once'],['ordered','Cues in action order'],['impact','Impact only']]
  };
  const positions = {
    ama:[4,2], esi:[5,3], dw:[5,2], vb:[6,2], shrine:[6,1]
  };
  const at = cell => point(...cell);
  const actorPoint = actor => at(positions[actor]);
  let mode = 'footprint';
  let variant;
  let animation = 0;

  function add(parent, tag, attrs, value) {
    const el = document.createElementNS(ns,tag);
    for (const [key,val] of Object.entries(attrs)) el.setAttribute(key,val);
    if (value !== undefined) el.textContent = value;
    id(parent).append(el);
    return el;
  }
  function label(layer, x, y, value, color = cream, size = 15) {
    return add(layer,'text',{x,y,fill:color,'text-anchor':'middle','font-family':'system-ui',
      'font-size':size,'font-weight':750,'paint-order':'stroke',stroke:ink,'stroke-width':4,
      'stroke-linejoin':'round'},value);
  }
  function diamond(layer, cell, width, style) {
    const {x,y} = at(cell), h = width/2;
    return add(layer,'path',{d:`M${x-width},${y} ${x},${y-h} ${x+width},${y} ${x},${y+h}Z`,...style});
  }
  function caption(title, text) {
    if (id('read-title').textContent !== title) id('read-title').textContent = title;
    if (id('read').textContent !== text) id('read').textContent = text;
  }
  function figure(actor, args = {}) {
    drawFigure(id('figures'),{id:actor,...actorPoint(actor),time:0,facing:actor==='dw' || actor==='vb'?-1:1,...args});
  }
  function ring(actor, color) {
    const {x,y} = actorPoint(actor);
    add('ground','ellipse',{cx:x,cy:y+3,rx:29,ry:9,fill:'none',stroke:color,'stroke-width':2.8});
  }
  function brackets(actor, color, yOffset = 0) {
    const {x,y} = actorPoint(actor);
    add('cues','path',{d:'M-34 -38v-9h9 M34 -38v-9h-9 M-34 -16v9h9 M34 -16v9h-9',
      transform:`translate(${x} ${y+yOffset})`,fill:'none',stroke:color,'stroke-width':2.8});
  }

  function obstacle() {
    const cell = [3,2];
    diamond('ground',cell,42,{fill:'#513d30','fill-opacity':.35,stroke:'#654b37','stroke-width':1.5});
    const {x,y} = at(cell);
    add('figures','path',{d:'M-32 4 -28-11 -17-26 2-30 23-21 33-6 24 7 0 12Z',
      transform:`translate(${x} ${y})`,fill:'#92684d',stroke:ink,'stroke-width':2});
    add('figures','path',{d:'M-27-11 -17-26 2-30 23-21 10-13 -5-15 -11-8Z M-5-14 2-5 0 10 14 7 17-7 25-18 10-12Z',
      transform:`translate(${x} ${y})`,fill:'#cca078',stroke:'#74513a','stroke-width':1.4});
  }
  function footprint() {
    const start=[2,2], end=[4,2];
    if (variant==='route') {
      const route = [start,[2,3],[3,3],[4,3],end].map(cell=>at(cell));
      add('ground','polyline',{points:route.map(({x,y})=>`${x},${y}`).join(' '),
        fill:'none',stroke:'#f9e1ac','stroke-width':2.5,'stroke-dasharray':'3 8','stroke-linecap':'round'});
      diamond('ground',end,35,{fill:'#ffd389','fill-opacity':.2,stroke:gold,'stroke-width':2.5});
    }
    figure('ama',{...at(start)});
    obstacle();
    figure('dw',{...at([2,1])});
    figure('shrine');
    caption('The rock outcrop occupies one cell',
      variant==='route'?'Ama’s committed route skirts the outcrop. The single bright diamond is her destination.':
        'The raised stone and its base show where the path is blocked. The figure behind it stays readable.');
  }
  function reach() {
    figure('ama',{...at([4,3])});
    figure('esi',{...at([3,3])});
    figure('dw');
    for (const [cell,name] of [[[4,3],'Ama'],[[3,3],'Esi'],[positions.dw,'Dust Wanderer']]) {
      const {x,y} = at(cell);
      label('cues',x,y+19,name,cream,13);
    }
    if (variant==='inspect') {
      ring('dw','#b8e0ef');
      diamond('ground',[4,3],40,{fill:'#ffda99','fill-opacity':.18,stroke:gold,'stroke-width':2.5});
      const a=at([4,3]), b=actorPoint('dw');
      add('ground','path',{d:`M${a.x},${a.y}L${b.x},${b.y}`,stroke:gold,'stroke-width':2,'stroke-dasharray':'3 6'});
      caption('Ama is within the Wanderer’s melee reach','The inspected relationship marks Ama’s cell. Esi is farther away. The cue describes reach and does not predict the Wanderer’s target.');
    } else caption('Reach stays quiet during combat','Inspect the Wanderer to show the immediate reach relationship.');
  }
  function intel() {
    const known = variant==='lead'?[[1,3],[1,4],[2,3],[2,4],[3,4]]:
      [[1,3],[1,4],[2,2],[2,3],[2,4],[3,2],[3,3],[3,4],[4,2],[4,3],[5,2],[6,1]];
    for (const cell of known) diamond('known-cells',cell,54,{fill:'black'});
    add('foreground','rect',{width:1000,height:570,fill:'#29221f',mask:'url(#intel-mask)'});
    if (variant==='survey') {
      obstacle();
      const {x,y} = at([4,3]);
      diamond('ground',[4,3],34,{fill:'#6f4833','fill-opacity':.60,stroke:'#f7b36d','stroke-width':2});
      add('ground','path',{d:'M-10 4q-3-5 3-9-1 5 3 6 4-6 2-12 10 9 7 14 5-3 6-6 4 8-4 11-11 4-17-4Z',transform:`translate(${x} ${y})`,fill:'#ffc486',stroke:ink,'stroke-width':1.3});
      figure('shrine');
      label('cues',x,y+27,'Burning Ground',cream,15);
      const shrine = actorPoint('shrine');
      label('cues',shrine.x,shrine.y-72,'Ancestral Shrine');
      caption('The scout confirmed the Shrine and Burning Ground','The briefing shows both discoveries and the terrain the party has seen. The rest of the field stays blank.');
    } else caption('The party has a lead on a Shrine','Only the surveyed approach is visible. Its objective location and hazards are still unknown.');
  }

  function health(actor, hp, max, offset = 0) {
    const {x,y} = actorPoint(actor);
    add('cues','rect',{x:x-25+offset,y:y-81,width:50,height:7,rx:2,fill:ink,stroke:'#f7d79c','stroke-width':1});
    add('cues','rect',{x:x-24+offset,y:y-80,width:48*hp/max,height:5,rx:1,fill:hp/max>.5?'#82b18b':'#df9f55'});
    label('cues',x+offset,y-85,`${hp}/${max}`,cream,14);
    label('cues',x,y+17,{ama:'A',dw:'DW',esi:'E',vb:'VB',shrine:'AS'}[actor],cream,12);
  }
  function shield(actor, impact) {
    const {x,y} = actorPoint(actor);
    const shift = impact ? 10 : 0;
    add('cues','path',{d:'M-9-6 Q0-11 9-6 L8 3 Q5 8 0 11 Q-5 8-8 3Z',
      transform:`translate(${x+29+shift} ${y-67})`,fill:'#f2d69c',stroke:ink,'stroke-width':2});
    if (impact) add('cues','path',{d:'M2-7 -3-1 3 2 -2 8',
      transform:`translate(${x+29+shift} ${y-67})`,fill:'none',stroke:'#794635','stroke-width':2});
  }
  function overlap(phase) {
    const all = variant==='all', hit=all || phase>=.52 && phase<.82, after=all || phase>=.52;
    const attack = Math.min(1,phase);
    figure('shrine');
    const drive = Math.sin(Math.PI*attack)**3;
    const ama = actorPoint('ama');
    figure('ama',{pose:'punch',phase:attack,reach:41,impactY:-22,x:ama.x+11*drive,y:ama.y+6*drive});
    figure('dw',{pose:hit?'hit':'idle',phase:Math.max(0,(phase-.52)/.30)});
    figure('vb');
    figure('esi',{facing:-1});
    ring('ama',gold);
    for (const [actor,hp,max,offset] of [
      ['ama',12,20,0],['dw',after?9:11,17,0],['esi',17,20,all?-16:-48],['vb',15,15,6],['shrine',17,25,5]
    ]) health(actor,hp,max,offset);

    shield('dw',hit);
    const dw=actorPoint('dw'), esi=actorPoint('esi');
    if (all || phase<.52) brackets('dw',cream);
    if (all) brackets('dw','#ebb072',-7);
    if (!all && phase>=.82 && variant==='ordered') brackets('dw','#ebb072');
    if (all || phase<.52 || phase>=.82) {
      add('ground','ellipse',{cx:esi.x,cy:esi.y+2,rx:29,ry:8,fill:'none',stroke:'#b7dce2','stroke-width':2,'stroke-dasharray':'3 4',opacity:all?1:.52});
    }
    if (hit) {
      label('cues',dw.x+38,dw.y-43-Math.max(0,phase-.52)*34,'−2','#ff9a83',22);
      add('cues','path',{d:'M-10-7 -3-1 M-12 3 -5 3 M1-8 4-14 M1 7 7 12',
        transform:`translate(${dw.x-8} ${dw.y-42})`,fill:'none',stroke:gold,'stroke-width':2.5,'stroke-linecap':'round'});
    }
    if (all || phase>=.82 && variant==='ordered') {
      const bark = '“Stay with me.”';
      const text = all ? bark : bark.slice(0,Math.ceil((phase-.82)/.18*bark.length));
      label('cues',all?dw.x+8:ama.x-38,all?dw.y-72:ama.y-115,text,cream,14);
    }
    id('observer-action').textContent = after ? 'Ama · Struck Dust Wanderer' : 'Ama';
    if (all) caption('All cues at once','A bark, two outlines, Guard, stance, HP and damage compete for the same moment.');
    else if (variant==='impact') caption('Impact only','The Wanderer’s shield cracks briefly and its health drops from 11 to 9.');
    else caption('Cues in action order','The target bracket leads into the strike. Guard and damage take over at contact. The persistent Mark and Ama’s bark are clear afterward.');
  }

  function render(phase = variant==='impact' || variant==='all' ? .58 : 0) {
    for (const layer of layers) id(layer).replaceChildren();
    id('observer').hidden=mode!=='overlap';
    id('replay').hidden=mode!=='overlap' || variant!=='ordered';
    if (mode==='footprint') footprint();
    if (mode==='reach') reach();
    if (mode==='intel') intel();
    if (mode==='overlap') overlap(phase);
  }
  function setMode(next) {
    cancelAnimationFrame(animation);
    mode=next;
    for (const button of document.querySelectorAll('[data-mode]')) {
      button.setAttribute('aria-pressed',String(button.dataset.mode===mode));
    }
    id('variant').replaceChildren(...views[mode].map(([value,title])=>new Option(title,value)));
    variant=views[mode][0][0];
    id('variant-label').textContent=mode==='intel'?'Intel available':mode==='overlap'?'Cue timing':'View';
    render();
  }
  for (const button of document.querySelectorAll('[data-mode]')) {
    button.addEventListener('click',()=>setMode(button.dataset.mode));
  }
  id('variant').addEventListener('change',event=>{
    cancelAnimationFrame(animation);
    variant=event.target.value;
    render();
  });
  id('replay').addEventListener('click',()=>{
    cancelAnimationFrame(animation);
    let start;
    function frame(now) {
      start ??= now;
      const phase=Math.min(1,(now-start)/1900);
      render(phase);
      if (phase<1) animation=requestAnimationFrame(frame);
    }
    animation=requestAnimationFrame(frame);
  });
  draw(id('terrain'));
  setMode(mode);
})();
