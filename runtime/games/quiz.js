/**
 * 答题游戏 — 题库随机抽取，计时计分
 * 依赖：CollectionManager, RuleEngine
 */
const QuizGame = (() => {
  var ctx = null, state = null;

  function start(gameCtx) {
    ctx = gameCtx;
    var collBlock = findBlock('collection');
    var ruleBlock = findBlock('rule');
    var ruleCfg = getRuleVars(ruleBlock);
    var questions = collBlock ? (collBlock.config.cards || []) : [];

    state = {
      questions: shuffle(questions.slice()),
      currentIndex: 0,
      score: 0,
      correctCount: 0,
      totalQuestions: ruleCfg.totalQuestions || Math.min(10, questions.length),
      timePerQuestion: ruleCfg.timePerQuestion || 15,
      passScore: ruleCfg.passScore || 60,
      gameOver: false,
      timerId: null,
      timeLeft: 0,
    };

    if (state.questions.length === 0) {
      state.questions = [
        { id:'q1', title:'世界上最大的洋是？', options:['大西洋','太平洋','印度洋','北冰洋'], answer:1 },
        { id:'q2', title:'1+1等于几？', options:['1','2','3','4'], answer:1 },
        { id:'q3', title:'中国的首都是？', options:['上海','广州','北京','深圳'], answer:2 },
        { id:'q4', title:'水的化学式是？', options:['H₂O','CO₂','O₂','N₂'], answer:0 },
        { id:'q5', title:'一年有多少天？', options:['300','365','400','500'], answer:1 },
      ];
      state.totalQuestions = Math.min(state.totalQuestions, 5);
    }

    renderQuestion();
  }

  function renderQuestion() {
    if (state.currentIndex >= state.totalQuestions || state.currentIndex >= state.questions.length) {
      endGame();
      return;
    }
    var q = state.questions[state.currentIndex];
    state.timeLeft = state.timePerQuestion;
    var container = ctx.container;
    container.innerHTML = '';

    var card = document.createElement('div');
    card.style.cssText = 'padding:24px;text-align:center;';
    card.innerHTML = '<div style="font-size:12px;color:var(--muted);margin-bottom:8px">第 ' + (state.currentIndex+1) + '/' + state.totalQuestions + ' 题 · 得分:' + state.score + '</div>' +
      '<div style="font-size:18px;font-weight:700;margin-bottom:20px">' + q.title + '</div>' +
      '<div style="font-size:13px;color:var(--gold);margin-bottom:16px" id="quizTimer">⏱ ' + state.timeLeft + 's</div>' +
      '<div id="quizOptions"></div>';

    container.appendChild(card);

    var optsDiv = document.getElementById('quizOptions');
    var options = q.options || [];
    for (var i = 0; i < options.length; i++) {
      var btn = document.createElement('button');
      btn.textContent = options[i];
      btn.style.cssText = 'display:block;width:100%;padding:12px;margin-bottom:8px;border-radius:10px;border:1px solid var(--border);background:var(--card);color:var(--text);font-size:14px;cursor:pointer;font-family:inherit;transition:all 0.2s;';
      btn.onmouseenter = function() { this.style.borderColor = 'var(--accent)'; };
      btn.onmouseleave = function() { this.style.borderColor = 'var(--border)'; };
      (function(idx) {
        btn.onclick = function() { answer(idx); };
      })(i);
      optsDiv.appendChild(btn);
    }

    startTimer();
  }

  function startTimer() {
    clearInterval(state.timerId);
    var timerEl = document.getElementById('quizTimer');
    state.timerId = setInterval(function() {
      state.timeLeft--;
      if (timerEl) timerEl.textContent = '⏱ ' + state.timeLeft + 's';
      if (state.timeLeft <= 0) {
        clearInterval(state.timerId);
        answer(-1);
      }
    }, 1000);
  }

  function answer(idx) {
    clearInterval(state.timerId);
    var q = state.questions[state.currentIndex];
    var correct = idx === q.answer;
    if (correct) {
      state.score += 10;
      state.correctCount++;
      emitStatus('✅ 正确！');
    } else {
      emitStatus('❌ 错误！答案是: ' + q.options[q.answer]);
    }
    state.currentIndex++;
    emitState();
    setTimeout(function() { renderQuestion(); }, 1500);
  }

  function endGame() {
    state.gameOver = true;
    clearInterval(state.timerId);
    var pass = state.score >= (state.totalQuestions * 10 * state.passScore / 100);
    emitStatus('🏁 答题结束！' + state.correctCount + '/' + state.totalQuestions + ' 得分:' + state.score + (pass ? ' ✅ 通过' : ''));
    emitState();
  }

  function shuffle(arr) { for (var i = arr.length - 1; i > 0; i--) { var j = Math.floor(Math.random() * (i+1)); var t = arr[i]; arr[i] = arr[j]; arr[j] = t; } return arr; }

  function getRuleVars(block) {
    var vars = {};
    if (!block) return vars;
    (block.config.variables || []).forEach(function(v) { vars[v.key] = v.value; });
    return vars;
  }

  function findBlock(type) {
    var blocks = ctx.config.blocks || [];
    for (var i = 0; i < blocks.length; i++) { if (blocks[i].type === type) return blocks[i]; }
    return null;
  }

  function emitState() { if (ctx && ctx.engine) ctx.engine.emit('game:state', state); }
  function emitStatus(msg) { if (ctx && ctx.engine) ctx.engine.emit('game:status', msg); }

  function getState() { return state; }
  return { start, getState };
})();
