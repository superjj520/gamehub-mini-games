/**
 * 2048 — 方向键滑动合并
 * 参考: gabrielecirulli/2048 (MIT)
 */
var Game2048 = (function() {
  var _ctx = null, _state = null, _boardEl = null;

  function start(gameCtx) {
    _ctx = gameCtx;
    var size = 4;
    var blocks = gameCtx.config.blocks||[];
    for(var i=0;i<blocks.length;i++){ if(blocks[i].type==='rule'){var v=blocks[i].config.variables||[];for(var j=0;j<v.length;j++){if(v[j].key==='winValue') size=v[j].value===8192?5:4;}} }

    _state = {grid:emptyGrid(size),score:0,gameOver:false,winValue:blocks.length>0?2048:2048};
    addRandom(); addRandom();

    gameCtx.container.innerHTML = '';
    _boardEl = document.createElement('div');
    _boardEl.style.cssText = 'display:grid;grid-template-columns:repeat('+size+',1fr);gap:6px;width:min(320px,90vw);margin:20px auto;padding:8px;background:rgba(255,255,255,0.05);border-radius:12px;';
    gameCtx.container.appendChild(_boardEl);
    render();

    document.addEventListener('keydown',onKey);
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:ready',{game:'2048'});
  }

  function emptyGrid(s){ var g=[]; for(var i=0;i<s;i++){g[i]=[];for(var j=0;j<s;j++)g[i][j]=0;} return g; }
  function addRandom(){
    var empty=[];
    for(var i=0;i<_state.grid.length;i++) for(var j=0;j<_state.grid[i].length;j++) if(_state.grid[i][j]===0) empty.push({r:i,c:j});
    if(empty.length){ var p=empty[Math.floor(Math.random()*empty.length)]; _state.grid[p.r][p.c]=Math.random()<0.9?2:4; }
  }

  function onKey(e){
    if(_state.gameOver) return;
    var moved=false, dir=0;
    if(e.key==='ArrowUp') dir=0; else if(e.key==='ArrowRight') dir=1; else if(e.key==='ArrowDown') dir=2; else if(e.key==='ArrowLeft') dir=3; else return;
    e.preventDefault();
    var old=JSON.stringify(_state.grid);
    for(var r=0;r<4;r++){ var line=extractLine(dir,r); var merged=mergeLine(line); setLine(dir,r,merged); }
    if(JSON.stringify(_state.grid)!==old){ moved=true; addRandom(); render(); SoundFX.play('tick'); try{navigator.vibrate(5);}catch(e){} }
    if(isGameOver()){ _state.gameOver=true; SoundFX.play('fail'); if(_ctx&&_ctx.engine) _ctx.engine.emit('game:status','游戏结束! 得分:'+_state.score); }
    if(_state.score>0 && _state.score%128===0){ try{if(typeof confetti!=='undefined') confetti({particleCount:30,spread:60,origin:{y:.7},disableForReducedMotion:true});}catch(e){} }
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:state',{score:_state.score,gameOver:_state.gameOver});
  }

  function extractLine(d,r){
    var line=[],s=_state.grid.length;
    for(var i=0;i<s;i++){ if(d===0)line.push(_state.grid[i][r]); else if(d===1)line.push(_state.grid[r][s-1-i]); else if(d===2)line.push(_state.grid[s-1-i][r]); else line.push(_state.grid[r][i]); }
    return line;
  }
  function setLine(d,r,line){
    var s=_state.grid.length;
    for(var i=0;i<s;i++){ var v=line[i]||0; if(d===0)_state.grid[i][r]=v; else if(d===1)_state.grid[r][s-1-i]=v; else if(d===2)_state.grid[s-1-i][r]=v; else _state.grid[r][i]=v; }
  }
  function mergeLine(line){
    var arr=line.filter(function(v){return v!==0;}), merged=[];
    for(var i=0;i<arr.length;i++){
      if(i<arr.length-1&&arr[i]===arr[i+1]){ merged.push(arr[i]*2); _state.score+=arr[i]*2; i++; }
      else merged.push(arr[i]);
    }
    while(merged.length<line.length) merged.push(0);
    return merged;
  }

  function isGameOver(){
    for(var i=0;i<_state.grid.length;i++) for(var j=0;j<_state.grid[i].length;j++){
      if(_state.grid[i][j]===0) return false;
      if(j<_state.grid[i].length-1&&_state.grid[i][j]===_state.grid[i][j+1]) return false;
      if(i<_state.grid.length-1&&_state.grid[i][j]===_state.grid[i+1][j]) return false;
    }
    return true;
  }

  function render(){
    if(!_boardEl) return;
    var colors={'2':'#EEE4DA','4':'#EDE0C8','8':'#F2B179','16':'#F59563','32':'#F67C5F','64':'#F65E3B','128':'#EDCF72','256':'#EDCC61','512':'#EDC850','1024':'#EDC53F','2048':'#EDC22E','4096':'#3C3A32','8192':'#3C3A32'};
    var html='';
    for(var i=0;i<_state.grid.length;i++) for(var j=0;j<_state.grid[i].length;j++){
      var v=_state.grid[i][j];
      html+='<div style="aspect-ratio:1;display:flex;align-items:center;justify-content:center;border-radius:8px;font-size:'+(v>512?'18px':'22px')+';font-weight:700;background:'+(v?colors[v]||'#3C3A32':'rgba(255,255,255,0.05)')+';color:'+(v>4?'#fff':'#776E65')+'">'+(v||'')+'</div>';
    }
    _boardEl.innerHTML = html;
  }

  function destroy(){ document.removeEventListener('keydown',onKey); _ctx=null; _boardEl=null; }
  return {start:start,destroy:destroy};
})();
