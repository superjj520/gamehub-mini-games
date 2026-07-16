/**
 * 贪吃蛇 — Canvas 经典游戏
 */
var SnakeGame = (function() {
  var _ctx = null, _canvas = null, _state = null, _loop = null;

  function start(gameCtx) {
    _ctx = gameCtx;
    gameCtx.container.innerHTML = '';

    _canvas = document.createElement('canvas');
    _canvas.width = 400; _canvas.height = 400;
    _canvas.style.cssText = 'display:block;margin:0 auto;border-radius:8px;background:#111;max-width:90vw;max-height:90vw;';
    gameCtx.container.appendChild(_canvas);

    _state = {snake:[{x:10,y:10},{x:9,y:10},{x:8,y:10}],dir:{x:1,y:0},food:{x:15,y:10},score:0,over:false,speed:120};
    placeFood(); draw();

    document.addEventListener('keydown',onKey);
    _loop = setInterval(tick, _state.speed);
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:ready',{game:'snake'});
  }

  function onKey(e){
    var d=_state.dir;
    if(e.key==='ArrowUp'&&d.y===0) _state.dir={x:0,y:-1};
    else if(e.key==='ArrowDown'&&d.y===0) _state.dir={x:0,y:1};
    else if(e.key==='ArrowLeft'&&d.x===0) _state.dir={x:-1,y:0};
    else if(e.key==='ArrowRight'&&d.x===0) _state.dir={x:1,y:0};
  }

  function tick(){
    if(_state.over) return;
    var head=_state.snake[0], nx=head.x+_state.dir.x, ny=head.y+_state.dir.y;
    if(nx<0||nx>=20||ny<0||ny>=20){ gameOver(); return; }
    for(var i=0;i<_state.snake.length;i++){ if(_state.snake[i].x===nx&&_state.snake[i].y===ny){gameOver();return;} }
    _state.snake.unshift({x:nx,y:ny});
    if(nx===_state.food.x&&ny===_state.food.y){ _state.score+=10; placeFood(); }
    else _state.snake.pop();
    draw();
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:state',{score:_state.score});
  }

  function placeFood(){
    var empty=[];
    for(var x=0;x<20;x++) for(var y=0;y<20;y++){
      var ok=true;
      for(var i=0;i<_state.snake.length;i++) if(_state.snake[i].x===x&&_state.snake[i].y===y){ok=false;break;}
      if(ok) empty.push({x:x,y:y});
    }
    if(empty.length) _state.food=empty[Math.floor(Math.random()*empty.length)];
  }

  function draw(){
    var ctx=_canvas.getContext('2d'), cw=_canvas.width/20;
    ctx.fillStyle='#111'; ctx.fillRect(0,0,400,400);
    ctx.fillStyle='#EF4444'; ctx.fillRect(_state.food.x*cw+1,_state.food.y*cw+1,cw-2,cw-2);
    var colors=['#22C55E','#16A34A','#15803D'];
    for(var i=0;i<_state.snake.length;i++){ ctx.fillStyle=colors[Math.min(i,colors.length-1)]; ctx.fillRect(_state.snake[i].x*cw+1,_state.snake[i].y*cw+1,cw-2,cw-2); }
  }

  function gameOver(){
    _state.over=true; if(_loop){clearInterval(_loop);_loop=null;}
    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:status','游戏结束! 得分:'+_state.score);
  }

  function destroy(){ document.removeEventListener('keydown',onKey); if(_loop)clearInterval(_loop); _ctx=null; _canvas=null; }
  return {start:start,destroy:destroy};
})();
