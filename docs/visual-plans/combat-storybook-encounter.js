/* Authored animation playback for the Actors and Objects study. */
(() => {
  'use strict';

  const board = window.StorybookBoard;
  const figures = window.StorybookFigures;
  const byId = name => document.getElementById('storybook-' + name);
  const svgNS = 'http://www.w3.org/2000/svg';
  const stage = byId('stage');
  const groundCues = document.createElementNS(svgNS,'g');
  byId('map').after(groundCues);
  const actorLayer = byId('actors');
  const cues = byId('cues');
  const cast = {
    esi: {name:'Esi', side:'party', hp:20, emotion:'Grounded', cell:[0,4], facing:1},
    ama: {name:'Ama', side:'party', hp:9, max:20, emotion:'Grounded', cell:[1,5], facing:1},
    dw: {name:'Dust Wanderer', side:'enemy', hp:17, cell:[7,3], facing:-1},
    vb: {name:'Vale Brute', side:'enemy', hp:15, cell:[7,0], facing:-1},
    shrine: {name:'Ancestral Shrine', side:'objective', hp:25, cell:[6,1]}
  };
  const order = ['esi','ama','dw','vb'];
  const point = cell => board.point(...cell);
  const clamp = value => Math.min(1, Math.max(0, value));
  const mix = (start,end,p) => start+(end-start)*p;
  const smooth = p => p*p*(3-2*p);
  const sign = (a,b) => Math.sign(b.x-a.x) || 1;
  const rounded = seconds => {
    const s = Math.floor(seconds);
    return Math.floor(s/60) + ':' + String(s%60).padStart(2,'0');
  };
  function svg(parent, tag, attributes, value) {
    const node = document.createElementNS(svgNS, tag);
    for (const [key, v] of Object.entries(attributes)) node.setAttribute(key, v);
    if (value !== undefined) node.textContent = value;
    parent.append(node);
    return node;
  }

  const beats = [];
  let duration = 0;
  function beat(label, length, data = {}) {
    beats.push({label, start:duration, length, ...data});
    duration += length;
  }
  function walk(id, path, label, {enter = false, length = .65, chapter = false} = {}) {
    const destination = enter ? null : path.at(-1);
    if (destination) beat(label,.20,{actor:id,pose:'gather',destination,gatherToward:path[0],chapter});
    for (const [i, cell] of path.entries()) {
      beat(label,length,{actor:id,to:cell,pose:'walk',enter:enter && i===0,destination});
    }
    if (destination) beat(label,.16,{actor:id,pose:'settle',destination});
  }
  function punch(actor,target,damage,label,extra = {}) {
    beat(label,1.14,{actor,target,damage,pose:'punch',contact:.52,...extra});
  }

  beat('Arrival at the Ancestral Shrine',.45,{chapter:true});
  walk('esi',[[0,4],[1,4],[2,4]],'Esi enters the field',{enter:true});
  walk('ama',[[1,5],[2,5],[3,5]],'Ama enters the field',{enter:true});
  walk('dw',[[7,3],[6,3],[5,3]],'Dust Wanderer enters the field',{enter:true});
  walk('vb',[[7,0],[7,1]],'Vale Brute enters the field',{enter:true,length:.78});
  beat('The two sides size each other up',.65);
  walk('esi',[[3,4],[4,4],[5,4]],'Esi steps into reach',{chapter:true});
  beat('Esi guards',.84,{actor:'esi',pose:'guard',grant:'esi',contact:.52,chapter:true});
  walk('ama',[[3,4],[3,3],[4,3]],'Ama closes on Dust Wanderer');
  punch('ama','dw',6,'Ama strikes Dust Wanderer',{chapter:true});
  punch('dw','esi',2,'Esi’s Guard softens the hit',{blocked:true,emotion:'Pressed',chapter:true,result:'Strikes Esi’s Guard'});
  punch('vb','shrine',3,'Vale Brute strikes the Shrine',{chapter:true});
  beat('Round 1 · The Shrine drains',1.3,{target:'shrine',damage:5,contact:.28,drain:true,chapter:true});
  beat('Round 2',.5,{round:2});
  beat('Esi uses Warder’s Vigil on Ama',1.28,{actor:'esi',target:'ama',pose:'interpose',grant:'ama',contact:.52,chapter:true,result:'Guards Ama · Warder’s Vigil'});
  walk('ama',[[4,2],[5,2]],'Ama approaches the Shrine');
  beat('Ama purifies the Shrine',1.68,{actor:'ama',target:'shrine',pose:'purify',purifies:true,contact:.63,chapter:true});
  punch('dw','ama',0,'Dust Wanderer hits Ama’s Guard',{blocked:true,chapter:true,result:'Strikes Ama’s Guard'});
  walk('vb',[[7,2],[6,2]],'Vale Brute steps away from the Shrine',{length:.8});
  punch('vb','ama',2,'Vale Brute strikes Ama',{blocked:true,emotion:'Strained'});
  beat('Round 2 · Purify slows the Shrine’s drain',1.34,{target:'shrine',damage:2,contact:.28,drain:true,chapter:true});
  beat('Round 3',.5,{round:3});
  walk('esi',[[4,4],[4,3]],'Esi closes on Dust Wanderer');
  punch('esi','dw',11,'Esi defeats Dust Wanderer',{chapter:true});
  beat('Ama uses Steward’s Call',1.28,{actor:'ama',target:'esi',pose:'call',emotion:'Grounded',contact:.55,chapter:true});
  punch('vb','ama',3,'Vale Brute strikes Ama');
  beat('Round 3 · Purify wears off',1.28,{target:'shrine',damage:7,contact:.28,drain:true,expires:true,chapter:true});
  beat('Round 4',.5,{round:4});
  walk('esi',[[5,4],[6,4],[6,3]],'Esi moves around Vale Brute');
  punch('esi','vb',7,'Esi strikes Vale Brute');
  punch('ama','vb',8,'Ama defeats Vale Brute',{chapter:true});
  beat('The Shrine survives',2.0,{victory:true,chapter:true});

  function snapshot(t) {
    const actors = Object.fromEntries(Object.entries(cast).map(([id, model]) => [
      id,{...model,id,max:model.max ?? model.hp,visible:id==='shrine',pose:'idle',phase:0,guard:false}
    ]));
    let round = 1;
    let purified = false;
    const results = {};
    const effects = [];
    const changes = {};
    let current;
    let phase = 0;

    for (const step of beats) {
      if (step.start > t) break;
      current = step;
      phase = t >= step.start+step.length ? 1 : clamp((t-step.start)/step.length);
      const source = actors[step.actor];
      const target = actors[step.target];
      const contactAt = step.contact === undefined ? null : step.start+step.length*step.contact;
      if (step.round) {
        round = step.round;
        for (const actor of Object.values(actors)) actor.guard = false;
        for (const id of Object.keys(results)) delete results[id];
      }
      if (step.gatherToward) {
        const from = point(source.cell);
        const to = point(step.gatherToward);
        source.facing = sign(from,to);
        source.stride = Math.abs(to.x-from.x);
        source.rise = to.y-from.y;
      }
      if (step.to) {
        const from = point(source.cell);
        const to = point(step.to);
        if (step.enter) {
          from.x += to.x < 500 ? -46 : 46;
          from.y -= 23;
          source.visible = true;
        }
        source.facing = sign(from,to);
        source.stride = Math.abs(to.x-from.x);
        source.rise = to.y-from.y;
        if (phase < 1) {
          source.offset = {x:mix(from.x,to.x,phase),y:mix(from.y,to.y,phase)};
          source.opacity = step.enter ? smooth(phase) : 1;
        } else {
          source.cell = step.to;
        }
      } else if (source && target) {
        source.facing = sign(point(source.cell),point(target.cell));
      }
      if (source && !step.enter && (contactAt === null || t >= contactAt)) {
        results[source.id] = step.result || step.label;
      }
      if (phase < 1 && source) {
        source.pose = step.pose;
        source.phase = phase;
      }
      if (contactAt === null || t < contactAt) continue;
      const age = t-contactAt;
      if (step.grant) {
        const recipient = actors[step.grant];
        recipient.guard = true;
        if (age < .45) {
          recipient.shieldEntry = clamp(age/.45);
          if (step.grant !== step.actor) {
            recipient.pose = 'guard';
            recipient.phase = clamp(age/.45);
          }
        }
      }
      if (step.purifies) purified = true;
      if (step.expires) purified = false;
      if (step.emotion && target.emotion !== step.emotion) {
        target.emotion = step.emotion;
        changes[target.id] = age < .7;
        if (step.pose === 'call' && age < .55) {
          target.pose = 'steady';
          target.phase = clamp(age/.55);
        }
      }
      if (step.damage === undefined) continue;
      target.hp = Math.max(0,target.hp-step.damage);
      if (age < .82) {
        const facing = source ? sign(point(source.cell),point(target.cell)) : 1;
        effects.push({source,target,age,damage:step.damage,blocked:step.blocked,drain:step.drain,facing});
        if (target.side !== 'objective' && target.hp > 0) {
          target.pose = 'hit';
          target.phase = clamp(age/.42);
          target.recoil = facing * (step.blocked ? 3 : 8)*Math.sin(Math.PI*target.phase);
        }
        if (step.blocked) target.shieldImpact = {age,facing};
      }
      if (!target.hp) {
        target.pose = 'defeated';
        target.phase = clamp(age/.68);
      }
    }
    const focus = current.round || current.victory || current.enter ? null : current.actor;
    return {actors,round,purified,current,phase,results,effects,changes,focus};
  }

  function actorFrame(actor, view, t) {
    const p = actor.offset || point(actor.cell);
    let x = p.x + (actor.recoil || 0);
    let y = p.y;
    let impactY;
    if (actor.pose === 'punch') {
      const target = view.actors[view.current.target];
      const end = point(target.cell);
      const lunge = Math.sin(Math.PI * actor.phase)**3;
      x += (end.x-p.x)*.20*lunge;
      y += (end.y-p.y)*.24*lunge;
      const torso = target.id === 'shrine' ? 24 : target.id === 'vb' ? 28 : 43;
      impactY = end.y - p.y - (end.y-p.y)*.24 - torso;
    }
    return {
      id:actor.id,x,y,pose:actor.pose,phase:actor.phase,facing:actor.facing,time:t,
      stride:actor.stride || 54,rise:actor.rise || 0,reach:41,impactY,
      state:actor.id==='shrine'?(view.purified?'purified':'draining'):undefined
    };
  }

  function shield(parent, x, y, actor) {
    const impact = actor.shieldImpact;
    const crack = impact && impact.age < .32;
    const kick = crack ? impact.facing*11*Math.sin(Math.PI*clamp(impact.age/.32)) : 0;
    const lift = 1-(actor.shieldEntry ?? 1);
    const badge = svg(parent,'g',{transform:`translate(${x+28+kick},${y-68+lift*10})`,opacity:1-lift*.85,'data-cue':'guard'});
    svg(badge,'path',{d:'M-8 -6 Q0 -10 8 -6 L7 2 Q5 7 0 9 Q-5 7 -7 2Z',fill:'#f0d394',stroke:'#3a2822','stroke-width':2});
    if (crack) svg(badge,'path',{d:'M2 -7 -3 -1 2 1 -2 7',fill:'none',stroke:'#723e31','stroke-width':1.7});
  }

  function word(parent,x,y,value,fill,size) {
    return svg(parent,'text',{x,y,fill,'text-anchor':'middle','font-family':'system-ui,sans-serif',
      'font-size':size,'font-weight':740,'paint-order':'stroke',stroke:'#2b1f1c','stroke-width':3.3,'stroke-linejoin':'round'},value);
  }

  function renderCues(t, view, frames) {
    const layers = Object.values(view.actors).filter(actor=>actor.visible);
    const targets = view.current.pose === 'punch' || view.current.pose === 'purify' ? view.current.target : null;
    for (const actor of layers) {
      const frame = frames[actor.id];
      const {x,y} = frame;
      if (actor.hp > 0) {
        const hpY = y-(actor.id==='shrine'?64:83);
        const sameColumn = layers.some(other => other !== actor && Math.abs(frames[other.id].x-x)<38 &&
          y-70<frames[other.id].y && frames[other.id].y<y-25);
        const slotX = x+(sameColumn?(actor.side==='enemy'?46:-46):0);
        const health = svg(cues,'g',{opacity:actor.opacity ?? (actor.id==='shrine'?smooth(clamp(t/.40)):1),'data-cue':'health'});
        const ratio=actor.hp/actor.max;
        if (ratio <= .25) {
          svg(health,'rect',{x:slotX-24,y:hpY-2,width:48,height:10,rx:2.5,fill:'none',
            stroke:'#f0846f','stroke-width':2,opacity:.45+.25*Math.sin(t*4)});
        }
        svg(health,'rect',{x:slotX-22,y:hpY,width:44,height:6,rx:1.5,fill:'#281f19',stroke:'#e4c38a','stroke-width':.8});
        svg(health,'rect',{x:slotX-21,y:hpY+1,width:42*ratio,height:4,rx:1,fill:ratio>.5?'#70a576':ratio>.25?'#d3ad5e':'#e17363'});
        word(health,slotX,hpY-4,`${actor.hp}/${actor.max}`,'#fff0cc',11);
        const initials = actor.name.split(' ').map(part=>part[0]).join('');
        const label = word(cues,x,y+17,initials,actor.side==='enemy'?'#f7a195':'#fff0cc',10);
        label.setAttribute('opacity',actor.opacity ?? (actor.id==='shrine'?smooth(clamp(t/.40)):1));
      }
      if (actor.guard && actor.hp) shield(cues,x,y,actor);
      if (actor.id===targets && view.phase<view.current.contact && actor.hp) {
        svg(cues,'path',{d:'M-29 -38 v-9 h8 M29 -38 v-9 h-8 M-29 -12 v9 h8 M29 -12 v9 h-8',
          transform:`translate(${x},${y})`,fill:'none',stroke:'#fff0cc','stroke-width':2,'data-cue':'target'});
      }
    }
    for (const effect of view.effects) {
      const {age,target,source,damage,drain,blocked,facing} = effect;
      const p = frames[target.id];
      if (source && age < .30) {
        const sourceFrame = frames[source.id];
        const atContact = actorFrame({...source,pose:'punch',phase:view.current.contact ?? .52},view,t);
        const hit = figures.landmark?.(atContact);
        const x = hit?.x ?? (sourceFrame.x+p.x)*.5;
        const y = hit?.y ?? p.y-34;
        const burst = svg(cues,'g',{transform:`translate(${x},${y}) scale(${.66+age*2.3})`,
          opacity:1-age/.30,fill:'none',stroke:blocked?'#fff0bd':'#ffce86','stroke-width':2.7,'stroke-linecap':'round'});
        svg(burst,'path',{d:'M-16 -8 -5 -4 M4 -5 12 -13 M6 1 19 -1 M4 7 12 13 M-4 5 -12 11'});
      }
      if (damage > 0) {
        const delta = word(cues,p.x+facing*(24+age*38),p.y-(drain?46:55)-age*31,'−'+damage,'#ff8d79',17);
        delta.setAttribute('opacity',Math.min(1,(.82-age)*4));
      }
    }
    if (view.current.purifies && view.phase > .40 && view.phase < .88) {
      const a=frames[view.current.actor], b=frames.shrine;
      const start=figures.landmark?.(a) || {x:a.x+22,y:a.y-40};
      const end=figures.landmark?.(b) || {x:b.x,y:b.y-26};
      const progress=clamp((view.phase-.40)/.23);
      const x=mix(start.x,end.x,progress);
      const y=mix(start.y,end.y,progress);
      const light=svg(cues,'g',{opacity:Math.sin(Math.PI*clamp((view.phase-.40)/.48))*.9});
      svg(light,'path',{d:`M${start.x} ${start.y} Q${(start.x+x)*.5} ${Math.min(start.y,y)-17} ${x} ${y}`,
        fill:'none',stroke:'#ffdb82','stroke-width':3,'stroke-linecap':'round'});
      svg(light,'circle',{cx:x,cy:y,r:4,fill:'#fff2b5'});
    }
  }

  const play = byId('play');
  const restart = byId('restart');
  const speed = byId('speed');
  const scrub = byId('scrub');
  const jump = byId('jump');
  const observer = byId('observer');
  const chapters = beats.filter(step=>step.chapter);
  let time = 0;
  let playing = false;
  let previousFrame = null;
  let selected = null;
  let frameRequest = null;

  const rows = Object.fromEntries(order.map(id => {
    const row = document.createElement('div');
    row.className = 'storybook-observer-row';
    row.dataset.side = cast[id].side;
    const name = document.createElement('button');
    name.type = 'button';
    name.className = 'storybook-name';
    name.textContent = cast[id].name;
    name.addEventListener('click', () => inspect(id));
    const emotion = document.createElement('span');
    emotion.className = 'storybook-emotion';
    const action = document.createElement('span');
    action.className = 'storybook-action';
    row.append(name,emotion,action);
    observer.append(row);
    return [id,{row,name,emotion,action}];
  }));

  function setText(element, text) {
    if (element && element.textContent !== text) element.textContent = text;
  }
  function inspect(id) {
    selected = selected === id ? null : id;
    render();
  }
  function updateHUD(view) {
    const {actors, focus, current, results, changes, round} = view;
    setText(byId('objective'),current.victory?'Shrine protected':view.purified?'Protect the Shrine · Drain slowed':'Protect the Ancestral Shrine');
    setText(byId('round'),`Round ${round}`);
    setText(byId('moment'),current.label);
    setText(byId('time'),`${rounded(time)} / ${rounded(duration)}`);
    if (Math.abs(Number(scrub.value)-time)>.009) scrub.value = time;
    scrub.setAttribute('aria-valuetext',`${rounded(time)} · ${current.label}`);
    for (const [id, nodes] of Object.entries(rows)) {
      const actor = actors[id];
      nodes.row.dataset.active = String(id === focus);
      nodes.row.dataset.selected = String(id === selected);
      nodes.row.dataset.defeated = String(!actor.hp);
      nodes.row.dataset.damaged = String(view.effects.some(hit => hit.target.id === id && hit.damage > 0 && hit.age < .34));
      nodes.name.setAttribute('aria-pressed',String(id === selected));
      nodes.emotion.hidden = !actor.emotion;
      nodes.emotion.dataset.emotion = actor.emotion?.toLowerCase() || '';
      nodes.emotion.dataset.changed = String(Boolean(changes[id]));
      setText(nodes.emotion,actor.emotion || '');
      setText(nodes.action,id === focus || id === selected ? (results[id] || '') : '');
    }
    let chapter = chapters.length-1;
    while (chapters[chapter].start > time) chapter--;
    if (jump.selectedIndex !== chapter) jump.selectedIndex = chapter;
  }

  function render() {
    const view = snapshot(time);
    const frames = Object.fromEntries(Object.values(view.actors).map(actor=>[actor.id,actorFrame(actor,view,time)]));
    groundCues.replaceChildren();
    if (view.current.destination) {
      const {x,y} = point(view.current.destination);
      const opacity = view.current.pose==='gather' ? smooth(view.phase) : view.current.pose==='settle' ? 1-view.phase : 1;
      svg(groundCues,'path',{d:'M-34 0 0-17 34 0 0 17Z',transform:`translate(${x},${y})`,
        fill:'#f4cb80','fill-opacity':.14,stroke:'#ffe4a4','stroke-width':2,opacity,'data-cue':'destination'});
    }
    actorLayer.replaceChildren();
    cues.replaceChildren();
    for (const actor of Object.values(view.actors).sort((a,b)=>frames[a.id].y-frames[b.id].y)) {
      if (!actor.visible) continue;
      const frame = frames[actor.id];
      const {x,y} = frame;
      const group = svg(actorLayer,'g',{'data-actor':actor.id,'data-defeated':!actor.hp,
        opacity:actor.opacity ?? (actor.id==='shrine'?smooth(clamp(time/.40)):1)});
      if (actor.id === view.focus || actor.id === selected) {
        svg(group,'ellipse',{cx:x,cy:y+2,rx:28,ry:9,fill:'none',stroke:actor.id===view.focus?'#ffda75':'#a4daf4','stroke-width':2.5});
      }
      figures.draw(group,frame);
      if (actor.id !== 'shrine' && actor.hp > 0) {
        const region = svg(group,'rect',{x:x-27,y:y-65,width:54,height:68,fill:'transparent'});
        region.style.cursor = 'pointer';
      }
    }
    renderCues(time,view,frames);
    updateHUD(view);
  }

  function setPlaying(next) {
    playing = next;
    previousFrame = null;
    stage.classList.toggle('storybook-motion-paused',!playing);
    setText(play,playing?'Pause':time>=duration?'Replay':'Play');
    if (frameRequest !== null) cancelAnimationFrame(frameRequest);
    frameRequest = playing ? requestAnimationFrame(tick) : null;
  }
  function tick(now) {
    frameRequest = null;
    if (!playing) return;
    if (previousFrame !== null) time = Math.min(duration,time+Math.min((now-previousFrame)/1000,.08)*Number(speed.value));
    previousFrame = now;
    render();
    if (time < duration) frameRequest = requestAnimationFrame(tick);
    else setPlaying(false);
  }
  function seek(to) {
    time = Math.max(0,Math.min(duration,to));
    previousFrame = null;
    render();
    if (!playing) setText(play,time>=duration?'Replay':'Play');
  }

  board.draw(byId('map'));
  scrub.max = String(duration);
  jump.replaceChildren(...chapters.map(step=>new Option(step.label,step.start)));
  play.addEventListener('click',() => {
    if (time >= duration) seek(0);
    setPlaying(!playing);
  });
  restart.addEventListener('click',() => {
    setPlaying(false);
    seek(0);
  });
  scrub.addEventListener('input',() => {
    setPlaying(false);
    seek(Number(scrub.value));
  });
  jump.addEventListener('change',() => {
    setPlaying(false);
    seek(Number(jump.value));
  });
  actorLayer.addEventListener('click',event => {
    const hit = event.target.closest('[data-actor]');
    if (hit?.dataset.defeated === 'true') return;
    const id = hit?.dataset.actor;
    if (order.includes(id)) inspect(id);
  });
  setPlaying(false);
  render();
})();
