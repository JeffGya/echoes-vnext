(() => {
  'use strict';

  const skills = [
    {key:'blade_resolve',name:'Press',family:'Break',status:'Partial',
      summary:'Follows an opening hit with a second strike so the target takes additional damage.',
      detail:'The proposal shows a separate follow-up hit after the opening strike. The preview uses illustrative damage values.',kind:'press'},
    {key:'warders_vigil',name:'Interpose',family:'Ward',status:'Active',
      summary:'Grants Guard to a threatened ally, reducing the damage they take from incoming hits while it lasts.',
      detail:'The shield belongs to the recipient and clears at the round boundary. HP stays on each actor.',kind:'ward',
      examples:[['ready','Threatened ally'],['unavailable','No threatened ally']]},
    {key:'stewards_ground',name:'Hold Ground',family:'Ward',status:'Active',
      summary:'Raises nearby allies’ morale, which can steady their displayed emotion.',
      detail:'The morale change appears on the receiving Echo. The ground stays clear of stance rings and area markers.',kind:'ground',
      examples:[['ready','Emotion changes'],['steady','Emotion stays the same']]},
    {key:'stewards_call',name:'Steady Call',family:'Root',status:'Active · Once per combat',
      summary:'Eases fear in nearby allies, making them less likely to refuse to act. Once per combat.',
      detail:'The receiving Echo’s emotion chip changes only when the displayed state changes.',kind:'call',
      examples:[['ready','Available'],['spent','Already used']]},
    {key:'rangers_mark',name:'Mark',family:'Path',status:'Active',
      summary:'Marks an enemy so Echoes are more likely to choose it for melee while the mark lasts.',
      detail:'The expiry example starts with the mark in place and fades it when the effect ends.',kind:'mark',
      examples:[['ready','Apply Mark'],['expiry','Watch Mark expire']]},
    {key:'rangers_withdraw',name:'Withdraw',family:'Veil',status:'Movement',
      summary:'Lets a surrounded Echo step out of immediate melee reach when a retreat route is available.',
      detail:'The destination stays lit through the step and clears once her feet settle. The cooldown example represents a state the current code applies in a Calling-specific branch.',kind:'withdraw',
      examples:[['ready','Committed withdrawal'],['cooldown','On cooldown']]},
    {key:'seers_sight',name:'Read Field',family:'Rite',status:'Partial',
      summary:'Reads an enemy’s approach so an ally can take a safer route around it.',
      detail:'In the proposal, Ama reads the Wanderer’s approach and Esi takes a different route. The broader field effect is still unspecified in the game.',kind:'read',
      examples:[['proposal','Proposed effect'],['current','Current behavior'],['cooldown','On cooldown']]},
    {key:'seers_reveal',name:'Reveal',family:'Rite',status:'Active · Once per combat',
      summary:'Exposes who a visible enemy is about to attack so the threatened ally can prepare.',
      detail:'The proposed effect exposes a committed attack. In the current game, Reveal increases melee targeting priority, much like Mark.',kind:'reveal',
      examples:[['proposal','Proposed effect · show attack intent'],['ready','Current effect · melee priority'],['marked','Current effect · existing Mark'],['spent','Already used']]},
    {key:'okofor_steadfast_hold',name:'Steadfast Hold',family:'Ward',status:'Authored passive',
      summary:'Lets a braced Echo hold their cell against a shove.',
      detail:'In the proposal, a shove reaches Ama, but her brace absorbs the movement and she keeps her cell.',kind:'idle'},
    {key:'aduro_iron_momentum',name:'Iron Momentum',family:'Break',status:'Authored passive',
      summary:'Primes a stronger melee hit after the Echo lands a strike.',
      detail:'In the proposal, a landed hit primes the next melee hit for bonus damage. The preview uses illustrative damage values.',kind:'momentum'},
    {key:'sum_okwanfo_shadow_step',name:'Shadow Step',family:'Veil',status:'Authored utility',
      summary:'Lets an Echo move around an enemy and reach an adjacent flank.',
      detail:'In the proposal, Ama stays visible as she steps around the Wanderer and ends within melee reach.',kind:'idle'},
    {key:'kra_soro_open_ground',name:'Open Ground',family:'Path',status:'Equipped movement bonus',
      summary:'Increases movement capacity when equipped, letting an Echo reach farther along a legal route.',
      detail:'Compare an ordinary two-cell walk with a three-cell walk in an uncapped example. Both use the same gait and destination cue.',kind:'capacity',
      examples:[['ready','Equipped · longer route'],['unequipped','Unequipped · shorter route']]},
    {key:'okomfo_spirit_sight',name:'Spirit Sight',family:'Rite',status:'Authored passive',
      summary:'Makes an enemy’s existing combat state visible so Echoes can recognize the risk of attacking it.',
      detail:'In the proposal, the Wanderer’s existing Guard becomes readable and Esi turns toward a different enemy.',kind:'idle'},
    {key:'onyamesu_steadfast_care',name:'Steadfast Care',family:'Root',status:'Authored passive',
      summary:'Eases an ally’s fear after they take a hit, helping them stay ready to act.',
      detail:'In the proposal, Esi takes damage and then regains composure. Her lost HP stays lost.',kind:'idle'}
  ];

  const byId = id => document.getElementById(id);
  const ns = 'http://www.w3.org/2000/svg';
  const {point, draw} = window.StorybookBoard;
  const {draw: drawFigure} = window.StorybookFigures;
  const gold = '#ffdc82', cream = '#fff1d4', ink = '#2b201a';
  const timeScale = 2600;
  let active = skills[1];
  let example = 'ready';
  let time = 0;
  let playing = false;
  let request;
  let lastFrame;

  function svg(parent,tag,attrs={},value) {
    const node=document.createElementNS(ns,tag);
    for(const [key,val] of Object.entries(attrs)) node.setAttribute(key,val);
    if(value!==undefined) node.textContent=value;
    parent.append(node);
    return node;
  }
  function word(parent,x,y,text,size=13) {
    return svg(parent,'text',{x,y,fill:cream,'font-size':size,'font-weight':750,'font-family':'system-ui',
      'text-anchor':'middle','paint-order':'stroke',stroke:ink,'stroke-width':3.2},text);
  }
  function diamond(parent,x,y,w,attrs) {
    svg(parent,'path',{d:`M${x-w} ${y} ${x} ${y-w/2} ${x+w} ${y} ${x} ${y+w/2}Z`,...attrs});
  }
  function buildBoard(name) {
    const root=byId(name);
    const background=svg(root,'g');
    if(name==='storybook') draw(background);
    else {
      svg(background,'rect',{width:1000,height:570,fill:'#64392d'});
      for(let col=0;col<8;col++){
        for(let row=0;row<6;row++){
          const {x,y}=point(col,row);
          diamond(background,x,y,54,{fill:(row+col)%2?'#925e48':'#895440',stroke:'#b78262','stroke-width':1});
        }
      }
    }
    return {name,ground:svg(root,'g'),figures:svg(root,'g'),cues:svg(root,'g'),observer:byId(name+'-observer')};
  }
  const boards=['storybook','tokens'].map(buildBoard);
  const cast = {
    ama:{id:'ama',name:'Ama',initial:'A',hp:16,max:20,facing:1},
    esi:{id:'esi',name:'Esi',initial:'E',hp:9,max:20,facing:1},
    dw:{id:'dw',name:'Dust Wanderer',initial:'DW',hp:11,max:17,facing:-1},
    vb:{id:'vb',name:'Vale Brute',initial:'VB',hp:15,max:15,facing:-1},
    shrine:{id:'shrine',name:'Ancestral Shrine',initial:'AS',hp:17,max:25,facing:1}
  };
  const model = (id,cell,extra={})=>({...cast[id],...point(...cell),pose:'idle',phase:0,...extra});
  const clip = n=>Math.max(0,Math.min(1,n));
  function routeMotion(path,p) {
    const last=point(...path.at(-1));
    const steps=path.length-1;
    const progress=clip((p-.21)/.65)*steps;
    const index=Math.min(steps-1,Math.floor(progress));
    const from=point(...path[index]),to=point(...path[index+1]);
    const phase=progress-index,dx=to.x-from.x,dy=to.y-from.y;
    const facing=Math.sign(dx)||1;
    const stride=Math.abs(dx);
    if(p<.21) return { ...from,pose:'gather',phase:clip((p-.10)/.11),facing,stride,rise:dy,last };
    if(p>=.86) return { ...last,pose:'settle',phase:clip((p-.86)/.14),facing,stride,rise:dy,last };
    return {x:from.x+dx*phase,y:from.y+dy*phase,pose:'walk',phase,facing,stride,rise:dy,last};
  }

  function strikeSequence(frame, ama, p, momentum) {
    const enemy=model('dw',[4,2]);
    frame.actors=[ama,enemy];
    frame.acting='ama';
    frame.proposal=true;
    frame.announce=momentum?p>=.27&&p<.39:p>=.51&&p<.74;

    // Two full strike clips, separated by a beat that shows what carries forward.
    const second=p>=.55;
    const phase=clip(second?(p-.55)/.39:(p-.04)/.43);
    const contact=second?.55+.39*.52:.04+.43*.52;
    const landed=p>=contact;
    const firstDamage=4;
    const secondDamage=momentum?6:3;
    enemy.hp=enemy.max-(second||landed?firstDamage:0)-(second&&landed?secondDamage:0);
    const lunge=Math.sin(Math.PI*phase)**3;
    Object.assign(ama,{pose:'punch',phase,reach:41,impactY:-22,x:ama.x+10*lunge,y:ama.y+6*lunge});
    if(landed && p-contact<.12) {
      const recoil=clip((p-contact)/.12);
      Object.assign(enemy,{pose:'hit',phase:recoil,x:enemy.x+4*Math.sin(Math.PI*recoil)});
      frame.impact={x:enemy.x,y:enemy.y,damage:second?secondDamage:firstDamage,phase:recoil};
    }
    if(!second && !landed) {
      frame.stage='Opening strike';
    } else if(!second || !landed) {
      frame.stage=momentum?'Iron Momentum is primed':'Press follows the opening';
      frame.outcome=momentum
        ? {name:'Attack rose',detail:'Ama’s next melee hit deals +2 damage in this example.'}
        : {name:'Follow-up queued',detail:'Ama follows the opening hit with a second strike.'};
      if(momentum) {
        ama.primed=true;
        if(p>=.39 && p<.67) frame.recipientNotice={actor:ama,text:'Attack rose',phase:clip((p-.39)/.28)};
      }
    } else {
      frame.stage=momentum?'The next hit spends Momentum':'Press lands';
      frame.outcome=momentum
        ? {name:'Momentum spent',detail:'The next hit deals 6 damage: 4 from the strike and 2 from Iron Momentum.'}
        : {name:'Follow-up landed',detail:'Press deals 3 more damage in this example. The Wanderer drops from 13 to 10 HP.'};
    }
    frame.detail=frame.stage;
  }

  function strike(frame, source, target, progress, damage) {
    const phase=clip(progress);
    const dx=target.x-source.x, dy=target.y-source.y;
    const drive=Math.sin(Math.PI*phase)**3;
    Object.assign(source,{pose:'punch',phase,facing:Math.sign(dx)||1,reach:41,
      impactY:dy*.76-42,x:source.x+dx*.2*drive,y:source.y+dy*.24*drive});
    if(phase<.52) return;
    target.hp-=damage;
    if(phase<.82) {
      const recoil=clip((phase-.52)/.30);
      Object.assign(target,{pose:'hit',phase:recoil,x:target.x+source.facing*4*Math.sin(Math.PI*recoil)});
      frame.impact={x:target.x,y:target.y,damage,phase:recoil};
    }
  }

  function revealIntent(frame, ama, esi, enemy, p) {
    frame.proposal=true;
    Object.assign(esi,model('esi',[4,2]));
    const exposed=p>=.35;
    const braced=p>=.61;
    frame.acting=p<.49?'ama':p<.73?'esi':'dw';
    frame.announce=p>=.11&&p<.35;
    Object.assign(ama,{pose:'purify',phase:clip((p-.06)/.39)});
    if(exposed && p<.73) frame.intent={source:enemy,target:esi};
    if(p>=.49 && p<.74) Object.assign(esi,{pose:'guard',phase:clip((p-.49)/.25)});
    esi.guard=braced;
    if(p>=.73) strike(frame,enemy,esi,clip((p-.73)/.25),2);
    if(exposed && p<.54) {
      frame.recipientNotice={actor:enemy,text:'Attack intent revealed',phase:clip((p-.35)/.19)};
    } else if(braced && p<.78) {
      frame.recipientNotice={actor:esi,text:'Guard gained',phase:clip((p-.61)/.17)};
    }
    frame.stage=!exposed?'Ama studies the Wanderer':!braced?'The Wanderer is about to strike Esi':
      esi.hp<9?'Esi’s Guard softens the hit':'Esi takes a separate turn to Guard';
    frame.detail=frame.stage;
    if(exposed) frame.outcome=esi.hp<9
      ? {name:'Esi was ready',detail:'The Wanderer still attacks Esi. Her Guard softens the hit to 2 damage in this example.'}
      : {name:'Attack intent revealed',detail:'Ama exposes the Wanderer’s committed target. Esi uses her own turn to Guard.'};
  }

  function proposedEffect(frame, ama, esi, enemy, p, posePhase) {
    const {key}=active;
    frame.proposal=true;
    frame.acting='ama';
    const read=p>=.44, outcome=p>=.63;
    const foundGuard=key==='okomfo_spirit_sight';
    if(key==='seers_sight') {
      Object.assign(esi,model('esi',[2,3]),routeMotion([[2,3],[2,4]],clip((p-.49)/.48)));
      Object.assign(ama,{pose:'call',phase:posePhase});
      if(read) frame.routeRead={danger:point(3,3),safe:point(2,4),progress:clip((p-.44)/.13)};
      if(p>=.58) Object.assign(enemy,routeMotion([[5,2],[4,2]],clip((p-.58)/.33)));
      if(outcome) {
        frame.acting='esi';
        if(p>=.90) frame.recipientNotice={actor:esi,text:'Safer route',phase:clip((p-.90)/.15)};
      }
      frame.stage=!read?'Ama studies the Wanderer’s approach':outcome?'Esi takes the safer route':'Ama spots the threatened lane';
      if(read) frame.outcome={name:'Approach read',detail:'The Wanderer closes on the threatened lane. Esi steps around it, outside its immediate melee reach.'};
    } else if(key==='okofor_steadfast_hold') {
      Object.assign(enemy,model('dw',[4,2]));
      const shove=clip((p-.43)/.45);
      Object.assign(enemy,{pose:'punch',phase:shove,x:enemy.x-10*Math.sin(Math.PI*shove)**3});
      Object.assign(ama,{pose:'guard',phase:clip((p-.25)/.55)});
      if(shove>=.52) {
        frame.hold={actor:ama,destination:point(2,2),force:1-clip((shove-.52)/.35)};
        if(p<.91) frame.recipientNotice={actor:ama,text:'Shove resisted',phase:clip((shove-.52)/.52)};
        frame.outcome={name:'Displacement resisted',detail:'The shove reaches Ama. Her brace absorbs the movement, so she keeps her cell.'};
      }
      frame.stage=frame.hold?'Ama holds her cell':'Ama braces against the approaching shove';
    } else if(key==='sum_okwanfo_shadow_step') {
      Object.assign(esi,model('esi',[2,3]));
      const {last,...movement}=routeMotion([[3,2],[3,3],[4,3],[5,3]],p);
      Object.assign(ama,movement);
      if(p>=.11 && p<.89) frame.destination={...last,opacity:clip((.89-p)/.10)};
      if(p>=.86) {
        frame.outcome={name:'Flank reached',detail:'Ama is now beside the Wanderer and can attack it in melee on a later action.'};
        frame.focus={actor:ama,text:'Melee in reach'};
      }
      frame.stage=p<.21?'Ama finds a route around the Wanderer':p<.86?'Ama steps around the Wanderer':'Ama reaches the flank';
    } else if(foundGuard) {
      Object.assign(enemy,model('dw',[4,2]),{guard:read});
      const brute=model('vb',[4,4]);
      Object.assign(esi,model('esi',[4,3]));
      frame.actors.push(brute);
      Object.assign(ama,{pose:'purify',phase:posePhase});
      if(read) frame.focus={actor:enemy,text:'Guard detected'};
      if(outcome) {
        frame.acting='esi';
        strike(frame,esi,brute,clip((p-.63)/.34),4);
      }
      frame.stage=outcome?'Esi turns on the unguarded Brute':read?'Ama spots the Wanderer’s Guard':'Ama reads the Wanderer';
      if(read) frame.outcome={name:'Guard detected',detail:'The Wanderer already had Guard. Esi chooses the unguarded Brute instead.'};
    } else {
      Object.assign(esi,model('esi',[4,2]),{emotion:'Pressed'});
      strike(frame,enemy,esi,clip((p-.06)/.49),3);
      frame.acting=p<.53?'dw':'ama';
      frame.announce=p>=.53 && p<.91;
      if(p>=.53) Object.assign(ama,{pose:'purify',phase:clip((p-.53)/.40)});
      if(outcome) {
        esi.emotion='Grounded';
        esi.changed=p<.87;
        Object.assign(esi,{pose:'steady',phase:clip((p-.63)/.30)});
        frame.outcome={name:'Esi’s fear eased',detail:'Esi stays at 6 HP. The support helps her regain composure and stay ready to act.'};
        if(p<.9) frame.recipientNotice={actor:esi,text:'Fear eased',phase:clip((p-.63)/.27)};
      }
      frame.stage=p<.53?'The Wanderer hits Esi':outcome?'Esi regains composure':'Ama steadies the wounded Esi';
    }
    frame.detail=frame.stage;
  }

  function scene(p) {
    const {kind}=active;
    const resolved=p>=.51;
    const posePhase=clip((p-.13)/.72);
    const valid = !['unavailable','spent','cooldown','current'].includes(example);
    const ama=model('ama',[3,2]);
    const esi=model('esi',[3,3],{hp:example==='unavailable'?16:9});
    const enemy=model('dw',[5,2]);
    const result={actors:[ama,esi,enemy],acting:null,detail:'',stage:'The Echoes wait'};
    if (!valid) {
      result.stage={unavailable:'Interpose failed · no ally needed Guard',
        spent:active.name+' was not used again · already used this combat',
        cooldown:active.name+' was not used · cooldown still active',current:{
          read:'Read Field · no confirmed field effect',
          press:'Press · no resolved follow-up hit',
          momentum:'Iron Momentum · ordinary idle',
          idle:'Current behavior · ordinary idle'
        }[kind]}[example];
      result.inactive=true;
      result.detail=result.stage;
      result.outcome=example==='unavailable'
        ? {name:'Interpose failed',detail:'Esi was outside the threatened-health threshold, so she did not receive Guard.'}
        : undefined;
      return result;
    }
    if(example==='expiry') {
      enemy.marked=p<.86;
      enemy.markOpacity=1-clip((p-.24)/.62);
      result.announce=false;
      result.stage=p<.24?'The Wanderer is still marked':enemy.marked?'Mark fades from the Wanderer':'Mark expired';
      result.detail=result.stage;
      if(p>=.86) {
        result.outcome={name:'Mark expired',detail:'Echoes no longer give the Wanderer extra priority from this Mark.'};
        result.recipientNotice={actor:enemy,text:'Mark expired',phase:clip((p-.86)/.20)};
      }
      return result;
    }
    if(kind==='press'||kind==='momentum') {
      strikeSequence(result,ama,p,kind==='momentum');
      return result;
    }
    if(kind==='reveal'&&example==='proposal') {
      revealIntent(result,ama,esi,enemy,p);
      return result;
    }
    if(kind==='read'||kind==='idle') {
      proposedEffect(result,ama,esi,enemy,p,posePhase);
      return result;
    }
    if(kind==='withdraw'||kind==='capacity') {
      const path=kind==='withdraw'?[[3,2],[2,2]]:
        [[3,2],[3,3],[2,3],...(example==='unequipped'?[]:[[2,4]])];
      if(kind==='withdraw') result.actors=[ama,model('dw',[4,2]),model('vb',[4,3])];
      else result.actors=[ama,model('dw',[5,2])];
      const {last,...frame}=routeMotion(path,p);
      Object.assign(ama,frame);
      result.acting='ama';
      if(p>=.10&&p<.98) result.destination={...last,opacity:p>.86?clip((.98-p)/.12):clip((p-.10)/.11)};
      result.stage=p<.21?'Ama gathers':p<.86?'Ama follows the committed route':'Ama settles on the destination';
      result.detail=p>=.86?(kind==='withdraw'?'Ama withdraws':'Ama reaches the destination'):'Ama moves';
      if(kind==='capacity' && example==='ready' && p>=.21 && p<.57) {
        result.recipientNotice={actor:ama,text:'Movement capacity +1',phase:clip((p-.21)/.36)};
        result.outcome={name:'Movement capacity increased',detail:'Ama can cover one more cell on this route.'};
      }
      if(kind==='capacity') result.announce=p>=.11 && p<.21;
      if(kind==='withdraw') {
        result.announce=p>=.11&&p<.86;
        if(p>=.86) result.recipientNotice={actor:ama,text:'Disengaged',phase:clip((p-.86)/.20)};
      }
      if(p>=.86) result.outcome=kind==='withdraw'
        ? {name:'Disengaged',detail:'Ama finishes outside the approach that was closing around her.'}
        : {name:'Destination reached',detail:example==='unequipped'?'Ama uses the shorter two-cell route.':'Open Ground lets Ama reach a third cell in this example.'};
      return result;
    }
    if(kind==='ward'||kind==='ground'||kind==='call') {
      result.acting='ama';
      ama.pose={ward:'interpose',ground:'steady',call:'call'}[kind];
      ama.phase=posePhase;
      ama.facing=kind==='call'?-1:1;
      if(kind==='ward') {
        Object.assign(esi,model('esi',[4,2]));
        Object.assign(enemy,model('dw',[5,2]));
        esi.guard=resolved && p<.91;
        if(resolved && p<.70) result.recipientNotice={actor:esi,text:'Guard gained',phase:clip((p-.51)/.19)};
        if(resolved&&p<.75) Object.assign(esi,{pose:'guard',phase:clip((p-.51)/.24)});
        if(p>=.70) {
          result.acting='dw';
          strike(result,enemy,esi,clip((p-.70)/.20),2);
        }
        result.stage=!resolved?'Ama braces for Esi':p>=.91?'Guard cleared at the round boundary':
          esi.hp<9?'Guard softens the Wanderer’s hit':p>=.70?'The Wanderer strikes at Esi':'Esi gains Guard';
        result.detail=result.stage;
        if(resolved) result.outcome=p<.91
          ? esi.hp<9
            ? {name:'Guard softened the hit',detail:'Esi takes 2 damage in this example. Guard lasts until the round boundary.'}
            : {name:'Esi gained Guard',detail:'Guard reduces damage from incoming hits while it lasts.'}
          : {name:'Guard cleared',detail:'The protection ended at the round boundary.'};
      } else {
        if(kind==='ground') result.actors.push(model('shrine',[4,1]));
        const changed=resolved&&example!=='steady';
        esi.emotion=changed?'Grounded':'Pressed';
        esi.changed=changed&&p<.79;
        if(changed&&p<.81) Object.assign(esi,{pose:'steady',phase:clip((p-.51)/.30)});
        result.stage=!resolved?(kind==='call'?'Ama draws breath to call':'Ama plants her feet'):
          changed?(kind==='call'?'Esi finds her composure':'Esi steadies'):'Esi’s displayed emotion stays Pressed';
        result.detail=resolved?(kind==='call'?'Ama calls to Esi':'Ama holds ground'):'Ama prepares';
        if(resolved) result.outcome=kind==='call'
          ? {name:'Esi’s fear eased',detail:'Lower fear makes fear-based refusal less likely.'}
          : {name:'Esi’s morale rose',detail:changed?'Her displayed emotion changes to Grounded.':'Her displayed emotion stays Pressed.'};
        if(resolved && p<.81) {
          result.recipientNotice={actor:esi,text:kind==='call'?'Fear eased':'Morale rose',phase:clip((p-.51)/.30)};
        }
      }
      return result;
    }
    if(kind==='mark'||kind==='reveal'){
      result.acting=p<.68?'ama':'esi';
      result.announce=p>=.11&&p<.67;
      ama.pose=kind==='mark'?'call':'purify';
      ama.phase=clip((p-.10)/.55);
      Object.assign(esi,model('esi',[5,3]));
      result.actors.push(model('vb',[6,3]));
      enemy.marked=example==='marked'||kind==='mark'&&resolved;
      enemy.reveal=kind==='reveal'&&resolved&&p<.67;
      if(resolved && p<.67) result.recipientNotice={actor:enemy,text:kind==='mark'?'Marked':'Revealed',phase:clip((p-.51)/.16)};
      if(p>=.68) {
        strike(result,esi,enemy,clip((p-.68)/.30),4);
        if(kind==='reveal' && p<.79) result.focus={actor:enemy,text:'Melee target chosen'};
      }
      result.stage=!resolved?'Ama focuses on the visible Wanderer':kind==='mark'?
        (p<.68?'Mark appears on the Wanderer':'Esi attacks the marked Wanderer'):
        (p<.68?'Reveal draws attention to the Wanderer':'Esi attacks the revealed Wanderer');
      result.detail=result.stage;
      if(resolved) result.outcome=kind==='mark'
        ? {name:'Wanderer marked',detail:'While Mark lasts, Echoes are more likely to choose the Wanderer for melee.'}
        : p<.68
          ? {name:'Wanderer revealed',detail:'The brief cue clears after the action. The targeting effect continues.'}
          : {name:'Reveal influenced Esi’s choice',detail:'Both enemies are in reach. Esi chooses the revealed Wanderer for melee in this example.'};
      return result;
    }
    return result;
  }

  function renderActor(board,actor,p) {
    const {x,y,id,hp,max}=actor;
    if(board.name==='storybook') {
      drawFigure(board.figures,{...actor,time:p*2.6});
      word(board.cues,x,y+18,actor.initial,11);
    } else {
      const enemy=id==='dw'||id==='vb';
      const lift=actor.pose==='walk'?Math.abs(Math.sin(actor.phase*2*Math.PI))*3:0;
      const fill=enemy?'#b72e32':id==='shrine'?'#89858a':'#2e63ac';
      svg(board.ground,'ellipse',{cx:x,cy:y,rx:22,ry:6,fill:'#2a2019',opacity:.35});
      if(id==='shrine') svg(board.figures,'rect',{x:x-19,y:y-43,width:38,height:38,fill,stroke:ink,'stroke-width':2.5});
      else svg(board.figures,'circle',{cx:x,cy:y-24-lift,r:19,fill,stroke:ink,'stroke-width':2.5});
      word(board.cues,x,y-19-lift,actor.initial,13);
    }
    const labelY=y-(board.name==='storybook'?80:56);
    const hpOffset=id==='shrine'?17:actor.hpOffset||0;
    svg(board.cues,'rect',{x:x+hpOffset-21,y:labelY,width:42,height:5,rx:1,fill:ink,stroke:'#efd6a6','stroke-width':.8});
    svg(board.cues,'rect',{x:x+hpOffset-20,y:labelY+1,width:40*hp/max,height:3,fill:hp/max>.5?'#84b487':'#d7ac62'});
    word(board.cues,x+hpOffset,labelY-4,`${hp}/${max}`,11);
    if(actor.guard) {
      svg(board.cues,'path',{d:'M-8-5Q0-9 8-5L7 2Q5 7 0 9Q-5 7-7 2Z',
        transform:`translate(${x+27} ${labelY+9})`,fill:'#f4d69a',stroke:ink,'stroke-width':1.7});
    }
    if(actor.marked||actor.reveal) {
      const bracketY=y-(board.name==='storybook'?36:24);
      svg(board.cues,'path',{d:'M-25-12v-7h8 M25-12v-7h-8 M-25 12v7h8 M25 12v7h-8',
        transform:`translate(${x} ${bracketY})`,fill:'none',stroke:actor.marked?gold:cream,
        'stroke-width':actor.reveal?3:2.2,'stroke-linecap':'round',opacity:actor.markOpacity??1,
        'data-result':actor.marked?'mark':'reveal'});
    }
  }

  // Each icon has its own outline so the skill can be recognized without its color.
  const signs = {
    blade_resolve: ['#f2b37d','M-8 7 1-2 7-8 7-3 1 3-8 9Z M-8 2l2 2'],
    warders_vigil: ['#f4d697','M-7-6Q0-9 7-6L6 1Q4 6 0 8Q-4 6-6 1Z M0-4v8'],
    stewards_ground: ['#e3bc82','M-8 5H8 M-6 1H6 M0-7v8 M-3-2 0 1 3-2'],
    stewards_call: ['#a9dec2','M-8 1Q-5-5-2 1Q1 7 4 1 M2-5Q7-4 8 1 M5-7Q10-5 11-1'],
    rangers_mark: ['#ffcf77','M-8-3v-5h5 M8-3v-5H3 M-8 3v5h5 M8 3v5H3 M0-2l2 2-2 2-2-2Z'],
    rangers_withdraw: ['#aee0e4','M1-7-6 0l7 7 M8-7 1 0l7 7'],
    seers_sight: ['#d7c4ef','M-8 3Q0-5 8 3 M-6 6H6 M0-8v3 M-6-6l2 2 M6-6 4-4'],
    seers_reveal: ['#fff0c5','M-9 0Q0-10 9 0Q0 10-9 0Z M0-3v6 M0-9v-2'],
    okofor_steadfast_hold: ['#e6c790','M-7-6v13 M7-6v13 M-9 7H9 M-7 1H7'],
    aduro_iron_momentum: ['#f4a67d','M-9-3 0-7-4 0 4-3 0 3 9 0 M-6 6l8-3'],
    sum_okwanfo_shadow_step: ['#b8ccdf','M-9-5Q2-5 6-9Q3-2-2 0 M-9 6Q1 8 8 2'],
    kra_soro_open_ground: ['#b6dab1','M-8 6-3 1 2 3 8-7 M3-7h5v5'],
    okomfo_spirit_sight: ['#d6b9f0','M-9 1Q0-8 9 1Q0 8-9 1Z M0-3 3 1 0 5-3 1Z M-7-6l2 1 M7-6 5-5'],
    onyamesu_steadfast_care: ['#b5e0c6','M-8 0Q-8-8 0-2Q8-8 8 0Q8 7 0 2Q-8 7-8 0Z M0-5v10']
  };

  // Short accents follow the pose or destination and disappear as the action settles.
  const accents = {
    blade_resolve:'M-11 5Q-9-7 3-10 M-9 10Q-4 2 4-1',
    warders_vigil:'M-10 7Q-12-5 0-10Q12-5 10 7',
    stewards_ground:'M-10 7H10 M-8 3H8 M-4-3 0 2 4-3',
    stewards_call:'M-3-9Q8-5 6 3 M3-11Q13-5 11 5',
    rangers_mark:'M-12-8v-5h6 M12 8v5H6',
    rangers_withdraw:'M-4-8-11 0l7 8 M5-8-2 0l7 8',
    seers_sight:'M-9-2Q0-10 9-2 M-8 3Q0-2 8 3',
    seers_reveal:'M-9-5-13-8 M0-7v-5 M9-5l4-3',
    okofor_steadfast_hold:'M-9-6v14 M9-6v14 M-11 8H11',
    aduro_iron_momentum:'M-12 5 0-2 M-7 8 9-1 M0 10 12 3',
    sum_okwanfo_shadow_step:'M-12-6Q-2-5 8-10 M-9 2Q-2 8 8 4',
    kra_soro_open_ground:'M-12 5h5 M-3 5h5 M6 5h5',
    okomfo_spirit_sight:'M-11 2Q0-11 11 2Q0 10-11 2Z',
    onyamesu_steadfast_care:'M-13 3Q-6-9 0 2Q6-9 13 3'
  };

  function drawSign(parent,x,y,scale=1) {
    const [shade,path]=signs[active.key];
    svg(parent,'path',{d:path,transform:`translate(${x} ${y}) scale(${scale})`,
      fill:'none',stroke:shade,'stroke-width':1.9,'stroke-linecap':'round','stroke-linejoin':'round'});
  }

  function feedbackLabel(cues, actor, y, text, data) {
    const width=Math.min(404,text.length*7.3+18);
    const x=Math.max(296+width/2,Math.min(708-width/2,actor.x));
    svg(cues,'rect',{x:x-width/2,y:y-13,width,height:19,rx:3,fill:'#27201d',
      stroke:data.color,'stroke-width':1,'data-feedback':data.kind,'data-actor':actor.id});
    word(cues,x,y,text,12).setAttribute('fill',data.color);
  }

  function skillFeedback(board,frame,p) {
    const {cues}=board;
    const source=frame.actors.find(actor=>actor.id==='ama');
    const ally=frame.actors.find(actor=>actor.id==='esi');
    const [shade]=signs[active.key];
    const {kind}=active;
    const inactive=frame.inactive||example==='unequipped';
    const announced=(frame.announce??(p>=.11 && p<.92)) && !inactive &&
      frame.acting==='ama' && frame.recipientNotice?.actor.id!=='ama';
    if(announced || inactive) {
      const title=inactive?{
        unavailable:'Interpose failed',spent:`${active.name} already used`,
        cooldown:`${active.name} still on cooldown`,current:`${active.name} · Current behavior`,
        unequipped:'Open Ground unequipped'
      }[example]:active.name;
      if(inactive) {
        feedbackLabel(cues,{id:'ama',x:502},182,title,{kind:'inactive',color:'#c4b6aa'});
      } else {
        feedbackLabel(cues,source,Math.min(source.y+39,428),title,{kind:'activation',color:shade});
      }
    }
    if(!announced) return;

    const burst=Math.sin(Math.PI*clip((p-.37)/.51));
    const tokenLift=board.name==='tokens'?23:43;
    const direction=source.facing;
    if(p<.68) {
      const x=source.x+direction*(22+burst*5);
      const y=source.y-tokenLift-6*burst;
      const cue=svg(cues,'g',{opacity:.67+burst*.33,'data-skill-source':active.key});
      svg(cue,'circle',{cx:x,cy:y,r:13+burst*2,fill:'#302421',stroke:shade,'stroke-width':1.1});
      drawSign(cue,x,y,1+burst*.16);
    }
    if(p>.36 && p<.78) {
      const atFeet=['ground','withdraw','capacity'].includes(kind)||active.key==='okofor_steadfast_hold';
      const x=source.x+(atFeet?0:direction*(12+burst*4));
      const y=atFeet?source.y+4:source.y-tokenLift+14;
      svg(cues,'path',{d:accents[active.key],transform:`translate(${x} ${y}) scale(${direction*(1+burst*.30)} ${1+burst*.15})`,
        fill:'none',stroke:shade,'stroke-width':2.9,'stroke-linecap':'round',opacity:burst,'data-skill-accent':active.key});
    }
    if(p<.51 || p>=.84) return;

    if(kind==='ward'||kind==='ground'||kind==='call'||active.key==='onyamesu_steadfast_care'&&p>=.63) {
      if(kind==='ground' && example==='steady') return;
      const x=ally.x-23, y=ally.y-tokenLift+5;
      const reply=svg(cues,'g',{'data-skill-recipient':ally.id});
      if(kind==='ward') {
        svg(reply,'path',{d:`M${ally.x+13} ${ally.y-66}q10-12 22-8`,fill:'none',
          stroke:shade,'stroke-width':2.6,'stroke-linecap':'round'});
      } else {
        svg(reply,'path',{d:`M${x-13} ${y+5}q12-15 26-5`,fill:'none',
          stroke:shade,'stroke-width':2.3,'stroke-linecap':'round',opacity:.8});
        drawSign(reply,x,y,.9+burst*.16);
      }
    }
    if(kind==='withdraw' || kind==='capacity') {
      const x=source.x-direction*19, y=source.y-4;
      drawSign(cues,x,y,.95+burst*.12);
    }
  }

  function paint(board,frame,p) {
    const {ground,figures,cues,observer}=board;
    for(const layer of [ground,figures,cues]) layer.replaceChildren();
    if(frame.destination) {
      const {x,y,opacity}=frame.destination;
      diamond(ground,x,y,31,{fill:'#f6cb81','fill-opacity':.15,stroke:gold,'stroke-width':2.3,opacity});
    }
    if(frame.intent) {
      const {source,target}=frame.intent;
      svg(ground,'path',{d:`M${source.x} ${source.y}L${target.x} ${target.y}`,fill:'none',
        stroke:'#f7ab87','stroke-width':2.8,'stroke-dasharray':'4 4','data-result':'attack-intent'});
      svg(ground,'ellipse',{cx:target.x,cy:target.y+4,rx:29,ry:10,fill:'none',
        stroke:'#f7ab87','stroke-width':2,'stroke-dasharray':'5 3'});
    }
    if(frame.routeRead) {
      const {danger,safe,progress}=frame.routeRead;
      diamond(ground,danger.x,danger.y,40,{fill:'#bc644e','fill-opacity':.23,stroke:'#ff9b83',
        'stroke-width':2.4,'stroke-dasharray':'4 5',opacity:progress,'data-result':'threatened-lane'});
      diamond(ground,safe.x,safe.y,31,{fill:'#afdaa5','fill-opacity':.14,stroke:'#bde5a6',
        'stroke-width':2.3,opacity:progress,'data-result':'safer-route'});
      const warning=word(cues,danger.x+9,danger.y+22,'Threatened lane',12);
      warning.setAttribute('opacity',progress);
    }
    if(frame.hold && frame.hold.force>0) {
      const {actor,destination,force}=frame.hold;
      diamond(ground,destination.x,destination.y,28,{fill:'none',stroke:'#ecac89','stroke-width':2,
        'stroke-dasharray':'4 5',opacity:force});
      svg(cues,'path',{d:`M${actor.x-34} ${actor.y-13}l-15-8 M${actor.x-40} ${actor.y-25}l-14 2
        M${actor.x-25} ${actor.y+1}l-14 6`,fill:'none',stroke:'#ffdb8d','stroke-width':2.7,
        opacity:force,'stroke-linecap':'round','data-result':'shove-resisted'});
    }
    for(const actor of [...frame.actors].sort((a,b)=>a.y-b.y)) {
      if(actor.id===frame.acting) {
        svg(ground,'ellipse',{cx:actor.x,cy:actor.y+3,rx:26,ry:8,fill:'none',stroke:gold,'stroke-width':2.5});
      }
      const stacked=frame.actors.some(other=>other.y<actor.y && actor.y-other.y<74 && Math.abs(other.x-actor.x)<23);
      renderActor(board,{...actor,hpOffset:stacked?-38:0},p);
      if(actor.primed) {
        const x=actor.x-26, y=actor.y-(board.name==='storybook'?43:25);
        svg(cues,'circle',{cx:x,cy:y,r:13,fill:'#33251e',stroke:'#f4a67d','stroke-width':1.6,'data-result':'primed'});
        drawSign(cues,x,y,.92);
      }
    }
    skillFeedback(board,frame,p);
    if(frame.focus) {
      const {actor,text}=frame.focus;
      const label=word(cues,actor.x+5,actor.y+34,text,12);
      label.setAttribute('fill','#ffe5a6');
      label.setAttribute('data-result','focus');
    }
    if(frame.recipientNotice) {
      const {actor,text,phase}=frame.recipientNotice;
      feedbackLabel(cues,actor,Math.min(actor.y+37-phase*7,426),text,{kind:'result',color:'#b9e4c9'});
    }
    if(frame.impact) {
      const {x,y,damage,phase}=frame.impact;
      const lift=board.name==='storybook'?41:25;
      const sparks=svg(cues,'g',{opacity:1-phase,transform:`translate(${x-18} ${y-lift})`});
      svg(sparks,'path',{d:'M-10-7 -4-3 M0-8 1-13 M6-5 11-11 M7 1 14 0 M6 7 11 11',
        fill:'none',stroke:'#ffe2a3','stroke-width':2.3,'stroke-linecap':'round'});
      const loss=word(cues,x+30+phase*14,y-lift-18*phase,'−'+damage,18);
      loss.setAttribute('fill','#ffa087');
      loss.setAttribute('opacity',1-phase*.85);
      loss.setAttribute('data-result','damage');
    }
    observer.replaceChildren();
    const tag=document.createElement('strong');
    tag.textContent='Observer';
    observer.append(tag,document.createTextNode(frame.detail||'The Echoes wait'));
    const recipient=frame.actors.find(actor=>actor.emotion);
    if(recipient) {
      const chip=document.createElement('span');
      chip.className='chip';
      chip.dataset.emotion=recipient.emotion;
      chip.dataset.changed=String(recipient.changed);
      chip.textContent=`${recipient.name} · ${recipient.emotion}`;
      observer.append(chip);
    }
  }

  function render() {
    const frame=scene(time);
    const classification=`${active.family} · ${active.status}${example==='proposal'?' · Proposed effect':''}`;
    if(byId('classification').textContent!==classification) byId('classification').textContent=classification;
    for(const board of boards) paint(board,frame,time);
    if(byId('stage').textContent!==frame.stage) byId('stage').textContent=frame.stage;
    byId('result').hidden=!frame.outcome;
    if(frame.outcome) {
      const heading=(frame.proposal?'Proposal · ':'')+frame.outcome.name;
      if(byId('result-name').textContent!==heading) byId('result-name').textContent=heading;
      if(byId('result-detail').textContent!==frame.outcome.detail) byId('result-detail').textContent=frame.outcome.detail;
    }
    byId('timeline').value=time;
    byId('timeline').setAttribute('aria-valuetext',frame.stage);
    byId('play').textContent=playing?'Pause':time===1?'Replay':'Play';
  }
  function pause() {
    cancelAnimationFrame(request);
    playing=false;
    lastFrame=undefined;
  }
  function tick(now) {
    if(!playing) return;
    const extended=['press','momentum','ward','reveal','mark','read','idle'].includes(active.kind);
    const duration=extended?4600:timeScale;
    if(lastFrame!==undefined) time=clip(time+Math.min(now-lastFrame,80)/duration);
    lastFrame=now;
    if(time>=1) pause();
    render();
    if(playing) request=requestAnimationFrame(tick);
  }
  function selectSkill(skill) {
    pause();
    active=skill;
    time=0;
    example=skill.examples?.[0][0]||'ready';
    for(const button of byId('skills').children) {
      button.setAttribute('aria-pressed',String(button.dataset.skill===skill.key));
    }
    byId('skill-name').textContent=skill.name;
    byId('summary').textContent=skill.summary;
    byId('detail').textContent=skill.detail;
    const defaultExamples=['idle','press','momentum'].includes(skill.kind)
      ? [['proposal','Proposed effect'],['current','Current behavior']]
      : [['ready','Skill showcase']];
    byId('state').replaceChildren(...(skill.examples||defaultExamples).map(([value,label])=>new Option(label,value)));
    render();
  }

  for(const skill of skills) {
    const button=document.createElement('button');
    button.type='button';
    button.dataset.skill=skill.key;
    button.textContent=skill.name;
    button.addEventListener('click',()=>selectSkill(skill));
    byId('skills').append(button);
  }
  byId('state').addEventListener('change',event=>{
    pause();
    example=event.currentTarget.value;
    time=0;
    render();
  });
  byId('timeline').addEventListener('input',event=>{
    pause();
    time=Number(event.currentTarget.value);
    render();
  });
  byId('play').addEventListener('click',()=>{
    if(playing) pause();
    else {
      if(time===1) time=0;
      playing=true;
      request=requestAnimationFrame(tick);
    }
    render();
  });
  selectSkill(active);
})();
