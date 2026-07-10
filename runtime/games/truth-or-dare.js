/**
 * 真心话大冒险 — 卡牌抽取 + 惩罚机制
 * 依赖：CollectionManager, RuleEngine, EffectEngine
 */
const TruthOrDareGame = (() => {
  var ctx = null, state = null;

  function start(gameCtx) {
    ctx = gameCtx;
    var truthBlock = findBlockByLabel('collection', '真心话');
    var dareBlock = findBlockByLabel('collection', '大冒险');
    var ruleBlock = findBlock('rule');
    var ruleCfg = getRuleVars(ruleBlock);

    state = {
      truths: truthBlock ? truthBlock.config.cards : DEFAULT_TRUTHS,
      dares: dareBlock ? dareBlock.config.cards : DEFAULT_DARES,
      currentCard: null,
      mode: null, // 'truth' or 'dare'
      skipCount: 0,
      maxSkips: ruleCfg.maxSkips || 2,
      penaltyMode: ruleCfg.penaltyMode || 'none',
      gameStarted: false,
      history: [],
    };

    renderUI();
    emitStatus('🤝 真心话还是大冒险？');
  }

  var DEFAULT_TRUTHS = [
    { id:'t1', title:'你最大的秘密是什么？', difficulty:1 },
    { id:'t2', title:'上一次哭是什么时候？', difficulty:1 },
    { id:'t3', title:'你最尴尬的经历是什么？', difficulty:2 },
    { id:'t4', title:'有没有暗恋过朋友的对象？', difficulty:3 },
    { id:'t5', title:'做过最后悔的事是什么？', difficulty:2 },
    { id:'t6', title:'你最害怕什么？', difficulty:1 },
    { id:'t7', title:'有过作弊经历吗？', difficulty:2 },
    { id:'t8', title:'最想念的人是谁？', difficulty:1 },
  ];

  var DEFAULT_DARES = [
    { id:'d1', title:'学狗叫 30 秒', difficulty:2 },
    { id:'d2', title:'模仿在场一个人到对方猜出是谁', difficulty:2 },
    { id:'d3', title:'打电话给通讯录第 5 个人说"我想你了"', difficulty:4 },
    { id:'d4', title:'闭眼原地转 10 圈然后走直线', difficulty:1 },
    { id:'d5', title:'用方言唱一首歌', difficulty:2 },
    { id:'d6', title:'表演喜怒哀乐四种表情', difficulty:1 },
    { id:'d7', title:'对着窗外大喊"我是最棒的"', difficulty:3 },
    { id:'d8', title:'单脚站立一分钟', difficulty:1 },
  ];

  function pickTruth() {
    if (state.truths.length === 0) { emitStatus('😅 真心话卡牌用完了，请换大冒险'); return; }
    var result = CollectionManager.draw({ drawMode: 'random', cards: state.truths });
    state.mode = 'truth';
    state.currentCard = result.card;
    state.history.push({ mode: 'truth', card: result.card });
    renderCard();
  }

  function pickDare() {
    if (state.dares.length === 0) { emitStatus('😅 大冒险卡牌用完了，请换真心话'); return; }
    var result = CollectionManager.draw({ drawMode: 'random', cards: state.dares });
    state.mode = 'dare';
    state.currentCard = result.card;
    state.history.push({ mode: 'dare', card: result.card });
    renderCard();
  }

  function skip() {
    if (state.skipCount < state.maxSkips) {
      state.skipCount++;
      emitStatus('⏭️ 跳过 (' + state.skipCount + '/' + state.maxSkips + ')');
      renderUI();
    } else {
      emitStatus('❌ 已达跳过上限！必须完成挑战');
      if (state.penaltyMode !== 'none') applyPenalty();
    }
  }

  function applyPenalty() {
    emitStatus('⚠️ 惩罚生效: ' + (state.penaltyMode === 'drink' ? '罚酒一杯' : '积分扣除'));
  }

  function renderCard() {
    if (!state.currentCard) return;
    var container = ctx.container;
    container.innerHTML = '';
    var modeLabel = state.mode === 'truth' ? '💬 真心话' : '🎯 大冒险';
    var modeColor = state.mode === 'truth' ? 'var(--accent)' : 'var(--accent2)';
    var difficulty = state.currentCard.difficulty || 1;
    var stars = '';
    for (var d = 0; d < difficulty; d++) stars += '🔥';

    var card = document.createElement('div');
    card.style.cssText = 'text-align:center;padding:32px 24px;';
    card.innerHTML = '<div style="font-size:14px;color:' + modeColor + ';margin-bottom:8px">' + modeLabel + '</div>' +
      '<div style="font-size:24px;font-weight:800;margin-bottom:12px;line-height:1.4">' + state.currentCard.title + '</div>' +
      '<div style="font-size:14px;color:var(--muted);margin-bottom:24px">' + stars + '</div>' +
      '<button id="tdNext" style="padding:10px 24px;border-radius:10px;border:none;background:linear-gradient(135deg,var(--accent),var(--accent2));color:white;font-size:14px;font-weight:700;cursor:pointer;font-family:inherit;">下一个挑战者 →</button>';

    container.appendChild(card);
    document.getElementById('tdNext').onclick = function() {
      state.currentCard = null;
      state.mode = null;
      renderUI();
    };
    emitState();
  }

  function renderUI() {
    ctx.container.innerHTML = '';

    var panel = document.createElement('div');
    panel.style.cssText = 'text-align:center;padding:32px 20px;';

    panel.innerHTML = '<div style="font-size:48px;margin-bottom:16px">🤝</div>' +
      '<div style="font-size:18px;font-weight:700;margin-bottom:8px">真心话大冒险</div>' +
      '<div style="font-size:13px;color:var(--muted);margin-bottom:24px">跳过 ' + state.skipCount + '/' + state.maxSkips + '</div>' +
      '<div style="display:flex;gap:12px;justify-content:center;flex-wrap:wrap;">' +
      '<button id="tdTruth" style="padding:16px 32px;border-radius:12px;border:none;background:var(--accent);color:white;font-size:16px;font-weight:700;cursor:pointer;font-family:inherit;">💬 真心话</button>' +
      '<button id="tdDare"  style="padding:16px 32px;border-radius:12px;border:none;background:var(--accent2);color:white;font-size:16px;font-weight:700;cursor:pointer;font-family:inherit;">🎯 大冒险</button>' +
      '</div>' +
      '<button id="tdSkip" style="margin-top:12px;padding:8px 16px;border-radius:8px;border:1px solid var(--border);background:transparent;color:var(--muted);font-size:13px;cursor:pointer;font-family:inherit;">⏭️ 跳过</button>';

    if (state.history.length > 0) {
      var hist = '<div style="margin-top:24px;font-size:11px;color:var(--muted);text-align:left;max-width:300px;margin-left:auto;margin-right:auto;">';
      hist += '<div style="font-weight:700;margin-bottom:6px;">📋 游戏记录</div>';
      for (var i = 0; i < state.history.length; i++) {
        var h = state.history[i];
        hist += '<div style="padding:2px 0">' + (h.mode === 'truth' ? '💬' : '🎯') + ' ' + h.card.title.slice(0, 20) + (h.card.title.length > 20 ? '...' : '') + '</div>';
      }
      hist += '</div>';
      panel.innerHTML += hist;
    }

    ctx.container.appendChild(panel);

    document.getElementById('tdTruth').onclick = pickTruth;
    document.getElementById('tdDare').onclick = pickDare;
    document.getElementById('tdSkip').onclick = skip;
  }

  function getRuleVars(block) { var v = {}; if (block) (block.config.variables || []).forEach(function(x) { v[x.key] = x.value; }); return v; }
  function findBlock(type) { var b = ctx.config.blocks || []; for (var i = 0; i < b.length; i++) if (b[i].type === type) return b[i]; return null; }
  function findBlockByLabel(type, label) { var b = ctx.config.blocks || []; for (var i = 0; i < b.length; i++) if (b[i].type === type && b[i].label.indexOf(label) !== -1) return b[i]; return null; }
  function emitState() { if (ctx && ctx.engine) ctx.engine.emit('game:state', state); }
  function emitStatus(msg) { if (ctx && ctx.engine) ctx.engine.emit('game:status', msg); }
  function getState() { return state; }
  return { start, getState, pickTruth, pickDare, skip };
})();
