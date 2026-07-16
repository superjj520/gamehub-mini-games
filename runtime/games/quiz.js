/**
 * 答题 — 题库随机抽取，即时反馈
 */
var QuizGame = (function() {
  var _ctx = null, _state = null, _el = null;

  function start(gameCtx) {
    _ctx = gameCtx;
    var questions = getQuestions(gameCtx);
    if(!questions.length) questions = [{title:'1+1=?',options:['1','2','3','4'],answer:1},{title:'水的化学式?',options:['H₂O','CO₂','O₂','NaCl'],answer:0},{title:'太阳系最大行星?',options:['地球','火星','木星','土星'],answer:2}];

    _state = {questions:shuffle(questions.slice()),current:0,score:0,total:Math.min(questions.length,10),answered:false};
    gameCtx.container.innerHTML = '';

    _el = document.createElement('div');
    _el.style.cssText = 'max-width:400px;margin:20px auto;padding:16px;';
    gameCtx.container.appendChild(_el);
    renderQuestion();
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:ready',{game:'quiz'});
  }

  function getQuestions(ctx){
    var blocks = (ctx&&ctx.config&&ctx.config.blocks)||[];
    for(var i=0;i<blocks.length;i++){ if(blocks[i].type==='collection') return blocks[i].config.cards||[]; }
    return [];
  }

  function shuffle(a){ for(var i=a.length-1;i>0;i--){var j=Math.floor(Math.random()*(i+1));var t=a[i];a[i]=a[j];a[j]=t;} return a; }

  function renderQuestion(){
    if(_state.current>=_state.total){ showResult(); return; }
    var q=_state.questions[_state.current];
    _state.answered=false;
    var html='<div style="font-size:11px;color:var(--muted);margin-bottom:4px">第'+
      (_state.current+1)+'/'+_state.total+'题 · 得分:'+_state.score+'</div>'+
      '<div style="font-size:16px;font-weight:700;margin-bottom:16px">'+q.title+'</div>';
    var opts = q.options||[];
    var letters=['A','B','C','D'];
    for(var i=0;i<opts.length;i++){
      html+='<div class="quiz-opt" data-idx="'+i+'" style="padding:12px 14px;margin-bottom:6px;background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:8px;cursor:pointer;font-size:13px;transition:all 0.15s">'+letters[i]+'. '+opts[i]+'</div>';
    }
    _el.innerHTML = html;

    _el.querySelectorAll('.quiz-opt').forEach(function(opt){
      opt.addEventListener('click',function(){
        if(_state.answered) return;
        _state.answered=true;
        var idx=parseInt(this.dataset.idx);
        var correct=idx===q.answer;
        if(correct){ this.style.background='rgba(34,197,94,0.15)'; this.style.borderColor='#22C55E'; _state.score+=10; }
        else { this.style.background='rgba(239,68,68,0.15)'; this.style.borderColor='#EF4444'; _el.querySelector('.quiz-opt[data-idx="'+q.answer+'"]').style.background='rgba(34,197,94,0.15)'; _el.querySelector('.quiz-opt[data-idx="'+q.answer+'"]').style.borderColor='#22C55E'; }
        if(_ctx&&_ctx.engine) _ctx.engine.emit('game:state',{score:_state.score,total:_state.total,current:_state.current+1});
        setTimeout(function(){ _state.current++; renderQuestion(); },800);
      });
    });
  }

  function showResult(){
    _el.innerHTML = '<div style="text-align:center;padding:40px 20px"><div style="font-size:40px;margin-bottom:10px">'+
      (_state.score>=_state.total*6?'🏆':_state.score>=_state.total*3?'👍':'💪')+'</div>'+
      '<div style="font-size:20px;font-weight:700;margin-bottom:8px">得分: '+_state.score+'/'+(_state.total*10)+'</div>'+
      '<div style="font-size:13px;color:var(--muted)">共答'+_state.total+'题</div></div>';
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:status','答题结束! 得分:'+_state.score);
  }

  function destroy(){ _ctx=null; _el=null; }
  return {start:start,destroy:destroy};
})();
