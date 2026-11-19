/* Brain Max - frontend ES5, fala com o backend nativo (Objective-C) via ponte brainmax:// */
'use strict';

/* Ponte JS -> ObjC: envia 'acao' + parametros para o WebView; o ObjC responde via _bmCb */
function bridge(acao, params, cb) {
  window._bmCb = cb || function(){};
  var ifr = document.createElement('iframe');
  ifr.style.display = 'none';
  ifr.setAttribute('src', 'brainmax://' + acao + '?' + encodeURIComponent(JSON.stringify(params || {})));
  document.body.appendChild(ifr);
  setTimeout(function(){ if (ifr.parentNode) ifr.parentNode.removeChild(ifr); }, 50);
}

var PROVIDERS = ['OpenRouter','9Router','AMD Token Lab','NVIDIA Build','Groq','Personalizado'];
var state = {
  dark:false, side:true, keyId:null, model:null, chatId:null,
  keys:[], chats:[], pending:[]
};
function $(id){ return document.getElementById(id); }
function esc(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
function curKey(){ for(var i=0;i<state.keys.length;i++) if(state.keys[i].id===state.keyId) return state.keys[i]; return null; }
function curModel(){ var k=curKey(); if(!k) return null; for(var i=0;i<k.models.length;i++) if(k.models[i].id===state.model) return k.models[i]; return null; }
function curChat(){ for(var i=0;i<state.chats.length;i++) if(state.chats[i].id===state.chatId) return state.chats[i]; return null; }

function renderTop(){
  var k=curKey(), m=curModel();
  $('mName').textContent = m ? m.id : 'Selecione um modelo';
  $('mProv').textContent = k ? k.name : '';
  $('attach').className = 'attach' + (m && m.vision ? '' : ' off');
  $('hint').textContent = '';
}
function renderMsgs(){
  var c = curChat(), h='';
  if (!c || !c.msgs || !c.msgs.length) { $('msgs').innerHTML='<div class="empty"><h2>Como posso ajudar?</h2>Escolha um modelo no topo e comece a conversar.</div>'; return; }
  for (var i=0;i<c.msgs.length;i++){
    var x=c.msgs[i];
    h += '<div class="m '+x.r+'"><div class="bub">'+(x.img?'<img src="'+x.img+'">':'')+esc(x.t)+'</div></div>';
  }
  $('msgs').innerHTML = '<div class="wrap">'+h+'</div>';
  $('msgs').scrollTop = $('msgs').scrollHeight;
}
function renderList(){
  var h='', last='';
  for (var i=0;i<state.chats.length;i++){
    var c=state.chats[i];
    if (c.date!==last){ h+='<div class="grp">'+esc(c.date)+'</div>'; last=c.date; }
    h += '<div class="ci'+(c.id===state.chatId?' sel':'')+'" data-open="'+c.id+'"><div class="t"><b>'+esc(c.title)+'</b><small>'+esc(c.model)+'</small></div><button class="del" data-del="'+c.id+'">&#128465;</button></div>';
  }
  $('list').innerHTML = h;
  $('side').className = 'side' + (state.side ? '' : ' hide');
}
function renderChips(){
  var h='';
  for (var i=0;i<state.pending.length;i++) h += '<span class="chip">&#128247; '+esc(state.pending[i].name)+'<u data-rm="'+i+'">&#10005;</u></span>';
  $('chips').innerHTML = h;
  $('chips').style.display = h ? 'block' : 'none';
}
function renderModelPop(){
  var h='';
  for (var i=0;i<state.keys.length;i++){
    var k=state.keys[i];
    h += '<div class="pg">'+esc(k.name)+' &middot; '+esc(k.prov)+'</div>';
    for (var j=0;j<k.models.length;j++){
      var m=k.models[j], sel=(k.id===state.keyId&&m.id===state.model);
      h += '<button class="mi'+(sel?' sel':'')+'" data-k="'+k.id+'" data-m="'+esc(m.id)+'"><span>'+esc(m.id)+'</span>'+(m.vision?'<em class="tag img">imagem</em>':'')+(sel?'<em class="tag">&#10003;</em>':'')+'</button>';
    }
  }
  $('popModel').innerHTML = h || '<div class="pg">Nenhuma chave adicionada.</div>';
}
function renderKeys(){
  var h='';
  for (var i=0;i<state.keys.length;i++){
    var k=state.keys[i];
    h += '<div class="kr"><div class="t"><b>'+esc(k.name)+'</b><small>'+esc(k.prov)+' &middot; '+k.models.length+' modelos</small></div><button class="del" data-delkey="'+k.id+'">Excluir</button></div>';
  }
  $('keyList').innerHTML = h || '<div class="found">Nenhuma chave ainda.</div>';
}
function renderAll(){ renderTop(); renderMsgs(); renderList(); renderChips(); renderKeys(); }

function dateLabel(ts){
  if (!ts) return 'Hoje';
  var now=new Date(), d=new Date(ts);
  var diff=Math.floor((now-d)/86400000);
  if (diff<=0) return 'Hoje';
  if (diff===1) return 'Ontem';
  return 'Há '+diff+' dias';
}

function loadAll(){
  bridge('keys', {}, function(res){
    if (res && res.keys) state.keys = res.keys;
    bridge('chats', {}, function(res2){
      if (res2 && res2.chats) state.chats = res2.chats;
      if (!state.keyId && state.keys.length){ state.keyId = state.keys[0].id; if (state.keys[0].models.length) state.model = state.keys[0].models[0].id; }
      if (!state.chatId && state.chats.length) state.chatId = state.chats[0].id;
      renderAll();
    });
  });
}

function saveChat(c){ bridge('chatsave', { chat: c }, function(){}); }

function openChat(id){
  state.chatId = id;
  bridge('chatget', { id: id }, function(res){
    if (res && res.chat){
      state.keyId = res.chat.keyId;
      state.model = res.chat.model;
      for (var i=0;i<state.chats.length;i++) if (state.chats[i].id===id) state.chats[i].msgs = res.chat.msgs;
    }
    renderAll();
  });
}
function newChat(){
  var id = Date.now();
  var c = { id:id, title:'Nova conversa', date:'Hoje', keyId:state.keyId, model:state.model, msgs:[], created:Date.now() };
  state.chats.unshift(c);
  state.chatId = id;
  saveChat(c);
  renderAll();
}

function sendMessage(){
  var t = $('inp').value.replace(/\s+$/,'');
  if (!t && !state.pending.length) return;
  var k = curKey(), m = curModel();
  if (!k || !m){ $('hint').textContent = 'Escolha um modelo no topo.'; return; }
  var c = curChat();
  if (!c){ newChat(); c = curChat(); }
  if (!c.msgs) c.msgs = [];
  if (c.msgs.length === 0) c.title = (t.slice(0,32) || 'Imagem');
  c.keyId = state.keyId; c.model = state.model;
  c.date = dateLabel(c.created || Date.now());

  var imgData = null;
  if (state.pending.length && m.vision){ imgData = state.pending[0].dataUrl; }
  else if (state.pending.length && !m.vision){ $('hint').textContent = 'Este modelo nao aceita imagens.'; }

  c.msgs.push({ r:'u', t:t, img: imgData ? 'data:image/jpeg;base64,'+imgData : null });
  state.pending = [];
  $('inp').value = ''; $('inp').style.height = '42px';
  renderMsgs(); renderList(); renderChips();

  var hist = [];
  for (var i=0;i<c.msgs.length;i++){
    var mm = c.msgs[i];
    hist.push({ role: (mm.r==='a'?'assistant':'user'), content: mm.t || '' });
  }

  $('hint').textContent = 'aguardando...';
  var payload = { keyId: state.keyId, model: state.model, messages: hist };
  if (imgData) payload.imageBase64 = imgData;
  bridge('chat', payload, function(res){
    if (res && res.error){ $('hint').textContent = res.error; renderMsgs(); return; }
    if (res && res.reply){
      c.msgs.push({ r:'a', t:res.reply });
      $('hint').textContent = '';
      saveChat(c);
      renderMsgs(); renderList();
    } else {
      $('hint').textContent = 'Falha ao responder.';
    }
  });
}

document.addEventListener('click',function(e){
  var t = e.target, d;
  while (t && t!==document && !(t.getAttribute && (t.getAttribute('data-open')||t.getAttribute('data-del')||t.getAttribute('data-delkey')||t.getAttribute('data-rm')||t.getAttribute('data-m')))){ t = t.parentNode; }
  if (!t || t===document) return;
  if (d=t.getAttribute('data-del')){
    d=parseInt(d,10);
    state.chats = state.chats.filter(function(c){return c.id!==d;});
    if (state.chatId===d) state.chatId = state.chats.length ? state.chats[0].id : null;
    bridge('chatdel', { id: d }, function(){});
    renderAll(); return;
  }
  if (d=t.getAttribute('data-open')){ openChat(parseInt(d,10)); return; }
  if (d=t.getAttribute('data-delkey')){
    d=parseInt(d,10);
    state.keys = state.keys.filter(function(k){return k.id!==d;});
    if (state.keyId===d){
      state.keyId = state.keys.length ? state.keys[0].id : null;
      state.model = (state.keyId && state.keys[0].models.length) ? state.keys[0].models[0].id : null;
    }
    bridge('keydel', { id: d }, function(){});
    renderAll(); return;
  }
  if (d=t.getAttribute('data-rm')){ state.pending.splice(parseInt(d,10),1); renderChips(); return; }
  if (t.getAttribute('data-m')){
    state.keyId = parseInt(t.getAttribute('data-k'),10);
    state.model = t.getAttribute('data-m');
    $('ovModel').className = 'ov';
    renderTop();
  }
});

$('modelBtn').onclick = function(){ renderModelPop(); $('ovModel').className = 'ov show'; };
$('ovModel').onclick = function(e){ if (e.target===$('ovModel')) $('ovModel').className='ov'; };
$('keysBtn').onclick = function(){ renderKeys(); $('ovKeys').className = 'ov show'; };
$('fClose').onclick = function(){ $('ovKeys').className = 'ov'; };
$('ovKeys').onclick = function(e){ if (e.target===$('ovKeys')) $('ovKeys').className='ov'; };
$('themeBtn').onclick = function(){ state.dark=!state.dark; document.body.className = state.dark?'dark':''; $('themeBtn').innerHTML = state.dark?'&#9728;':'&#9790;'; };
$('histBtn').onclick = function(){ state.side=!state.side; $('histBtn').className = 'ibtn'+(state.side?' on':''); renderList(); };
$('newChat').onclick = newChat;
$('send').onclick = sendMessage;
$('inp').onkeydown = function(e){ if (e.keyCode===13 && !e.shiftKey){ e.preventDefault(); sendMessage(); } };
$('inp').oninput = function(){ this.style.height='42px'; this.style.height=Math.min(this.scrollHeight,140)+'px'; };

$('attach').onclick = function(){
  var m = curModel();
  if (!m || !m.vision){ $('hint').textContent = 'Este modelo nao aceita imagens.'; return; }
  var fi = document.createElement('input');
  fi.type = 'file';
  fi.accept = 'image/*';
  fi.onchange = function(){
    var f = fi.files && fi.files[0];
    if (!f) return;
    var fr = new FileReader();
    fr.onload = function(){
      var dataUrl = fr.result;
      reduceImage(dataUrl, function(base64){
        state.pending.push({ name: f.name || 'foto', dataUrl: base64 });
        renderChips();
      });
    };
    fr.readAsDataURL(f);
  };
  fi.click();
};

function reduceImage(dataUrl, cb){
  var img = new Image();
  img.onload = function(){
    var max = 900, w = img.width, h = img.height;
    if (w > max || h > max){ var ratio = Math.min(max/w, max/h); w = Math.round(w*ratio); h = Math.round(h*ratio); }
    var cv = document.createElement('canvas');
    cv.width = w; cv.height = h;
    var ctx = cv.getContext('2d');
    ctx.drawImage(img, 0, 0, w, h);
    try { cb(cv.toDataURL('image/jpeg', 0.6).replace('data:image/jpeg;base64,','')); }
    catch (e) { cb(dataUrl.replace('data:image/jpeg;base64,','')); }
  };
  img.onerror = function(){ cb(dataUrl.replace('data:image/jpeg;base64,','')); };
  img.src = dataUrl;
}

$('fAdd').onclick = function(){
  var key = $('fKey').value;
  if (!key){ $('found').textContent = 'Cole a chave de API.'; return; }
  var prov = $('fProv').value, custom = null;
  if (prov === 'Personalizado'){
    var url = $('fUrl').value, cn = $('fCName').value;
    if (!url || !cn){ $('found').textContent = 'Informe o nome e a URL base.'; return; }
    var man = $('fManual').value ? $('fManual').value.split(',') : [];
    custom = { url: url, manual: man };
    prov = cn;
  }
  var name = $('fName').value || prov;
  $('found').textContent = 'Buscando modelos...';
  bridge('models', { prov: prov, key: key, custom: custom }, function(res){
    var models = (res && res.models) ? res.models : [];
    if (res && res.error){ $('found').textContent = res.error; return; }
    bridge('keyadd', { prov: prov, name: name, key: key, custom: custom }, function(res2){
      if (res2 && res2.id){
        state.keys.push({ id: res2.id, prov: res2.prov, name: res2.name, models: models });
        var h = 'Encontrados '+models.length+' modelos: ';
        for (var i=0;i<models.length;i++) h += '<span class="tag'+(models[i].vision?' img':'')+'">'+esc(models[i].id)+'</span>';
        $('found').innerHTML = h;
        $('fKey').value = ''; $('fName').value = '';
        if (!state.keyId){ state.keyId = res2.id; if (models.length) state.model = models[0].id; }
        renderKeys(); renderModelPop(); renderTop();
      } else {
        $('found').textContent = (res2 && res2.error) ? res2.error : 'Falha ao salvar.';
      }
    });
  });
};

(function(){
  var h='';
  for (var i=0;i<PROVIDERS.length;i++) h += '<option>'+PROVIDERS[i]+'</option>';
  $('fProv').innerHTML = h;
  $('fProv').onchange = function(){ $('customBox').style.display = this.value==='Personalizado'?'block':'none'; };
})();

/* Callback chamado pelo ObjC com o JSON de resposta de cada ponte */
window._bmCb = function(json){ };
loadAll();