/**
 * 真心话大冒险 — 卡牌抽取
 */
var TruthOrDareGame = (function() {
  var _ctx = null, _el = null, _truths = [], _dares = [];

  function start(gameCtx) {
    _ctx = gameCtx;
    var blocks = gameCtx.config.blocks||[];
    for(var i=0;i<blocks.length;i++){
      var b=blocks[i];
      if(b.type==='collection'){
        if(b.label.indexOf('真心话')>=0) _truths = b.config.cards||[];
        else if(b.label.indexOf('大冒险')>=0) _dares = b.config.cards||[];
        else { _truths = (b.config.cards||[]).slice(0, Math.ceil((b.config.cards||[]).length/2)); _dares = (b.config.cards||[]).slice(Math.ceil((b.config.cards||[]).length/2)); }
      }
    }
    if(!_truths.length) _truths = [{title:'你最大的秘密是什么?'},{title:'上一次哭是什么时候?'},{title:'最尴尬的经历?'}];
    if(!_dares.length) _dares = [{title:'学动物叫30秒'},{title:'闭眼转10圈走直线'},{title:'用方言唱一首歌'}];

    gameCtx.container.innerHTML = '';
    _el = document.createElement('div');
    _el.style.cssText = 'max-width:360px;margin:20px auto;text-align:center;';
    gameCtx.container.appendChild(_el);

    render();
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:ready',{game:'truth-or-dare'});
  }

  function render(card){
    var html = '<div style="margin-bottom:20px">'+
      '<button onclick="TruthOrDareGame.pickTruth()" style="padding:14px 28px;margin:6px;border-radius:10px;border:none;background:#7C3AED;color:white;font-size:15px;font-weight:700;cursor:pointer">💬 真心话</button>'+
      '<button onclick="TruthOrDareGame.pickDare()" style="padding:14px 28px;margin:6px;border-radius:10px;border:none;background:#EC4899;color:white;font-size:15px;font-weight:700;cursor:pointer">🎯 大冒险</button>'+
      '</div>';
    if(card){
      html += '<div style="padding:20px;background:rgba(255,255,255,0.05);border-radius:12px;border:1px solid var(--border);font-size:18px;font-weight:600;line-height:1.6;margin-top:10px;animation:fadeIn 0.3s">'+
        '<div style="font-size:40px;margin-bottom:12px">'+card.icon+'</div>'+card.title+'</div>';
    }
    _el.innerHTML = html;
  }

  function pickTruth(){
    var card = _truths[Math.floor(Math.random()*_truths.length)];
    card.icon = card.icon||'💬';
    render(card);
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:status','真心话: '+card.title);
  }

  function pickDare(){
    var card = _dares[Math.floor(Math.random()*_dares.length)];
    card.icon = card.icon||'🎯';
    render(card);
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:status','大冒险: '+card.title);
  }

  function destroy(){ _ctx=null; _el=null; }
  return {start:start,pickTruth:pickTruth,pickDare:pickDare,destroy:destroy};
})();
