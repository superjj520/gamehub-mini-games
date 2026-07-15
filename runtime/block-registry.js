/**
 * Block 类型注册表 — 定义 9 种通用 Block 类型和每个游戏的默认配置
 * 依赖：无（纯数据模块）
 */
const BlockRegistry = (() => {
  const TYPES = {
    BOARD:      'board',
    COLLECTION: 'collection',
    RULE:       'rule',
    PIECE:      'piece',
    BUILDING:   'building',
    STORE:      'store',
    EFFECT:     'effect',
    PLAYER:     'player',
    THEME:      'theme',
  };

  // ─── 每种 Block 类型的编辑 Schema ───
  const SCHEMAS = {
    board: {
      label: '地图', icon: '🗺️', iconSvg: 'board',
      fields: [
        { key: 'cells',     label: '格子列表', type: 'board-editor' },
        { key: 'pathOrder', label: '路径顺序', type: 'hidden' },
      ],
      templates: [
        { name: '经典大富翁', desc: '24格环形路径', config: {} },
        { name: '自定义布局', desc: '自由拖拽搭建地图', config: {} },
      ],
    },
    collection: {
      label: '卡堆/奖池', icon: '🎲', iconSvg: 'collection',
      fields: [
        { key: 'drawMode', label: '抽选模式', type: 'select', options: ['random', 'weighted', 'sequential'], default: 'random' },
        { key: 'cards',    label: '条目列表',  type: 'card-list' },
      ],
      templates: [
        { name: "🎰 经典奖池", desc: "5档奖品+权重", config: { drawMode:"weighted", cards:[
          {id:"p1",title:"一等奖 iPhone",weight:5,effect:{gold:1000}},
          {id:"p2",title:"二等奖 耳机",weight:10,effect:{gold:500}},
          {id:"p3",title:"三等奖 优惠券",weight:25,effect:{gold:100}},
          {id:"p4",title:"四等奖 积分",weight:30,effect:{gold:50}},
          {id:"p5",title:"谢谢参与",weight:30,effect:{gold:0}},
        ]}},
        { name: "🃏 冒险卡堆", desc: "前退+金币混合", config: { drawMode:"random", cards:[
          {id:"a1",title:"发现宝藏 +200",effect:{gold:200}},
          {id:"a2",title:"遭遇陷阱 -100",effect:{gold:-100}},
          {id:"a3",title:"前进5格",effect:{move:5}},
        ]}},
      ],
    },
    rule: {
      label: '规则', icon: '📐', iconSvg: 'rule',
      fields: [
        { key: 'variables', label: '变量定义', type: 'variable-list' },
      ],
      templates: [
        { name: "💰 大富翁标准", desc: "1500金币+起点200+5圈", config: { variables:[
          {key:"initialGold",label:"初始金币",value:1500},
          {key:"startBonus",label:"起点奖励",value:200},
          {key:"maxLaps",label:"获胜圈数",value:5},
        ]}},
        { name: "⏱️ 限时挑战", desc: "60秒倒计时", config: { variables:[
          {key:"timeLimit",label:"时限(秒)",value:60},
          {key:"targetScore",label:"目标分",value:1000},
        ]}},
      ],
    },
    piece: {
      label: '棋子/实体', icon: '🧩', iconSvg: 'piece',
      fields: [
        { key: 'pieces', label: '棋子列表', type: 'piece-list' },
      ],
      templates: [
        { name: "🎨 多彩棋子", desc: "4色+emoji", config: { pieces:[
          {id:"p1",name:"红方",emoji:"🔴",color:"#EF4444",isAI:false},
          {id:"p2",name:"蓝方",emoji:"🔵",color:"#3B82F6",isAI:true},
        ]}},
      ],
    },
    building: {
      label: '建筑', icon: '🏗️', iconSvg: 'building',
      fields: [
        { key: 'buildings', label: '建筑类型', type: 'building-list' },
      ],
      templates: [
        { name: "🏘️ 住宅链", desc: "平房→别墅→城堡", config: { buildings:[
          {id:"b1",name:"平房",cost:200,level:1},
          {id:"b2",name:"别墅",cost:800,level:2},
          {id:"b3",name:"城堡",cost:3000,level:3},
        ]}},
      ],
    },
    store: {
      label: '商店', icon: '🏪', iconSvg: 'store',
      fields: [
        { key: 'currency',  label: '货币类型', type: 'text',   default: 'gold' },
        { key: 'items',     label: '商品列表', type: 'store-item-list' },
      ],
      templates: [
        { name: "🏗️ 地产商店", desc: "公寓+商场+酒店", config: { currency:"gold", items:[
          {id:"apt",name:"公寓",cost:200,effect:{rent_multiplier:2,icon:"🏠"}},
          {id:"mall",name:"商场",cost:500,effect:{rent_multiplier:5,icon:"🏬"}},
          {id:"hotel",name:"酒店",cost:1000,effect:{rent_multiplier:10,icon:"🏨"}},
        ]}},
      ],
    },
    effect: {
      label: '效果/事件', icon: '⚡', iconSvg: 'effect',
      fields: [
        { key: 'effects', label: '效果列表', type: 'effect-list' },
      ],
      templates: [
        { name: "🎯 经典事件", desc: "起点加钱+监禁跳过", config: { effects:[
          {id:"e1",trigger:"land_on",cellType:"start",action:"add_gold",value:200},
          {id:"e2",trigger:"land_on",cellType:"jail",action:"skip_turns",value:1},
          {id:"e3",trigger:"pass_start",action:"add_gold",value:200},
        ]}},
      ],
    },
    player: {
      label: '玩家设置', icon: '👥', iconSvg: 'player',
      fields: [
        { key: 'minPlayers',  label: '最少玩家', type: 'number', min: 1, max: 10, default: 2 },
        { key: 'maxPlayers',  label: '最多玩家', type: 'number', min: 1, max: 10, default: 4 },
        { key: 'initialGold', label: '初始金币', type: 'number', min: 0, max: 99999, default: 1500 },
      ],
      templates: [
        { name: "👥 双人对战", desc: "1玩家+1AI", config: { minPlayers:2, maxPlayers:2, initialGold:1500, players:[
          {id:"p1",name:"玩家",emoji:"🧑",isAI:false,color:"#7C3AED"},
          {id:"p2",name:"电脑",emoji:"🤖",isAI:true,color:"#EC4899"},
        ]}},
        { name: "👨‍👩‍👧‍👦 四人派对", desc: "1玩家+3AI", config: { minPlayers:4, maxPlayers:4, initialGold:2000, players:[
          {id:"p1",name:"你",emoji:"🧑",isAI:false,color:"#7C3AED"},
          {id:"p2",name:"小明",emoji:"🤖",isAI:true,color:"#EC4899"},
          {id:"p3",name:"小红",emoji:"🤖",isAI:true,color:"#22C55E"},
          {id:"p4",name:"小刚",emoji:"🤖",isAI:true,color:"#F59E0B"},
        ]}},
      ],
    },
    theme: {
      label: '主题', icon: '🎨',
      fields: [
        { key: 'preset',  label: '预设主题', type: 'select', options: ['暗紫','暗金','暗绿','暗蓝','经典都市','赛博朋克','童话王国'], default: '暗紫' },
        { key: 'accent',  label: '强调色',   type: 'color', default: '#7C3AED' },
        { key: 'accent2', label: '辅助色',   type: 'color', default: '#EC4899' },
        { key: 'gold',    label: '金色',     type: 'color', default: '#F5C842' },
      ],
    },
  };

  // ─── 大富翁默认 Block 配置 ───
  const MONOPOLY_DEFAULTS = [
    {
      id: 'blk_board', type: 'board', label: '地图',
      config: {
        cells: [
          { id:'c0',  x:100, y:280, type:'start',    name:'起点',   icon:'🚩', effects:{gold:200} },
          { id:'c1',  x:200, y:260, type:'property', name:'奶茶铺', icon:'🧋', price:200, rent:[50,100,200] },
          { id:'c2',  x:300, y:220, type:'chance',   name:'机会',   icon:'❓', effects:{draw:'chance'} },
          { id:'c3',  x:400, y:180, type:'property', name:'服装店', icon:'👗', price:300, rent:[80,160,320] },
          { id:'c4',  x:500, y:140, type:'jail',     name:'监禁',   icon:'🚔', effects:{skip:1} },
          { id:'c5',  x:600, y:100, type:'property', name:'美妆店', icon:'💄', price:250, rent:[60,120,240] },
          { id:'c6',  x:680, y:60,  type:'destiny',  name:'命运',   icon:'🔮', effects:{draw:'destiny'} },
          { id:'c7',  x:680, y:340, type:'property', name:'数码店', icon:'📱', price:350, rent:[90,180,360] },
          { id:'c8',  x:660, y:420, type:'shop',     name:'商铺街', icon:'🏪', effects:{shop_reward:true} },
          { id:'c9',  x:600, y:480, type:'property', name:'咖啡馆', icon:'☕', price:200, rent:[50,100,200] },
          { id:'c10', x:500, y:520, type:'chance',   name:'机会',   icon:'❓', effects:{draw:'chance'} },
          { id:'c11', x:400, y:540, type:'property', name:'餐饮店', icon:'🍜', price:400, rent:[100,200,400] },
          { id:'c12', x:300, y:540, type:'event',    name:'幸运日', icon:'🌈', effects:{gold:100} },
          { id:'c13', x:200, y:520, type:'property', name:'游戏馆', icon:'🎮', price:280, rent:[70,140,280] },
          { id:'c14', x:100, y:480, type:'destiny',  name:'命运',   icon:'🔮', effects:{draw:'destiny'} },
          { id:'c15', x:20,  y:420, type:'property', name:'健身房', icon:'🏋️', price:320, rent:[80,160,320] },
          { id:'c16', x:20,  y:340, type:'chance',   name:'机会',   icon:'❓', effects:{draw:'chance'} },
          { id:'c17', x:20,  y:260, type:'property', name:'珠宝店', icon:'💎', price:500, rent:[150,300,500] },
          { id:'c18', x:40,  y:180, type:'event',    name:'税务',   icon:'💰', effects:{gold:-100} },
          { id:'c19', x:100, y:140, type:'property', name:'黄金城', icon:'👑', price:600, rent:[200,400,600] },
          { id:'c20', x:200, y:100, type:'chance',   name:'机会',   icon:'❓', effects:{draw:'chance'} },
          { id:'c21', x:300, y:60,  type:'property', name:'银行',   icon:'🏦', price:450, rent:[120,240,480] },
          { id:'c22', x:400, y:40,  type:'destiny',  name:'命运',   icon:'🔮', effects:{draw:'destiny'} },
          { id:'c23', x:500, y:60,  type:'property', name:'庄园',   icon:'🏰', price:700, rent:[250,500,700] },
        ],
        pathOrder: ['c0','c1','c2','c3','c4','c5','c6','c23','c22','c21','c20','c19','c18','c17','c16','c15','c14','c13','c12','c11','c10','c9','c8','c7'],
      },
    },
    {
      id: 'blk_chance', type: 'collection', label: '机会卡',
      config: {
        drawMode: 'random',
        cards: [
          { id: 'c1', title: '获得 50 金币 🎉',  effect: { gold: 50 } },
          { id: 'c2', title: '前进 3 格 ➡️',      effect: { move: 3 } },
          { id: 'c3', title: '后退 2 格 ⬅️',      effect: { move: -2 } },
          { id: 'c4', title: '获得优惠券 🎫',     effect: { gold: 30, prize: '优惠券' } },
          { id: 'c5', title: '停一回合 ⏸️',       effect: { skip: 1 } },
        ],
      },
    },
    {
      id: 'blk_destiny', type: 'collection', label: '命运卡',
      config: {
        drawMode: 'random',
        cards: [
          { id: 'd1', title: '获得 100 金币 💰',   effect: { gold: 100 } },
          { id: 'd2', title: '领取神秘礼盒 🎁',     effect: { gold: 60, prize: '神秘礼盒' } },
          { id: 'd3', title: '与对手交换位置 🔄',   effect: { swap: true } },
          { id: 'd4', title: '获得抽奖机会 🎰',     effect: { gold: 80, lucky_draw: true } },
        ],
      },
    },
    {
      id: 'blk_store', type: 'store', label: '建筑商店',
      config: {
        currency: 'gold',
        items: [
          { id: 'apt',  name: '公寓', cost: 200,  effect: { rent_multiplier: 2,  icon: '🏠' } },
          { id: 'mall', name: '商场', cost: 500,  effect: { rent_multiplier: 5,  icon: '🏬' } },
          { id: 'hotel',name: '酒店', cost: 1000, effect: { rent_multiplier: 10, icon: '🏨' } },
        ],
      },
    },
    {
      id: 'blk_effects', type: 'effect', label: '事件效果',
      config: {
        effects: [
          { id: 'e1', trigger: 'land_on', cellType: 'start',    action: 'add_gold',    value: 200 },
          { id: 'e2', trigger: 'land_on', cellType: 'jail',     action: 'skip_turns',  value: 1 },
          { id: 'e3', trigger: 'land_on', cellType: 'shop',     action: 'shop_reward', value: 0 },
          { id: 'e4', trigger: 'land_on', cellType: 'event',    action: 'luck_bonus',  value: 100 },
          { id: 'e5', trigger: 'land_on', cellType: 'tax',      action: 'deduct_gold', value: -100 },
          { id: 'e6', trigger: 'pass_start',                    action: 'add_gold',    value: 200 },
        ],
      },
    },
    {
      id: 'blk_rules', type: 'rule', label: '游戏规则',
      config: {
        variables: [
          { key: 'initialGold',   label: '初始金币',      value: 1500, min: 100,  max: 10000 },
          { key: 'startBonus',    label: '经过起点奖励',   value: 200,  min: 0,    max: 1000  },
          { key: 'bankruptLimit', label: '破产线',         value: 0,    min: -500, max: 500   },
          { key: 'maxLaps',       label: '获胜圈数',       value: 5,    min: 1,    max: 20    },
          { key: 'diceMin',       label: '骰子最小值',      value: 1,    min: 1,    max: 3     },
          { key: 'diceMax',       label: '骰子最大值',      value: 6,    min: 4,    max: 12    },
        ],
      },
    },
    {
      id: 'blk_players', type: 'player', label: '玩家设置',
      config: {
        minPlayers: 2, maxPlayers: 4, initialGold: 1500,
        players: [
          { id: 'p1', name: '玩家 A', emoji: '🧑', isAI: false, color: '#7C3AED' },
          { id: 'p2', name: '玩家 B', emoji: '🤖', isAI: true,  color: '#EC4899' },
        ],
      },
    },
    {
      id: 'blk_theme', type: 'theme', label: '视觉主题',
      config: { preset: '暗紫', accent: '#7C3AED', accent2: '#EC4899', gold: '#F5C842' },
    },
  ];

  // ─── 贪吃蛇默认配置 ───
  const SNAKE_DEFAULTS = [
    { id: 'blk_grid', type: 'grid', label: '游戏区域', config: { rows: 15, cols: 15, cells: [] } },
    { id: 'blk_rules', type: 'rule', label: '游戏规则', config: { variables: [
      { key: 'speed', label: '移动速度(ms)', value: 150, min: 50, max: 500 },
      { key: 'growCount', label: '每次增长', value: 1, min: 1, max: 5 },
    ]}},
    { id: 'blk_theme', type: 'theme', label: '视觉主题', config: { preset: '暗绿' } },
  ];

  // ─── 大转盘默认配置 ───
  const WHEEL_DEFAULTS = [
    { id: 'blk_prizes', type: 'collection', label: '奖池', config: { drawMode: 'weighted', cards: [
      { id: 'p1', title: '一等奖 iPhone', weight: 5 },
      { id: 'p2', title: '二等奖 耳机', weight: 10 },
      { id: 'p3', title: '三等奖 优惠券', weight: 25 },
      { id: 'p4', title: '四等奖 积分', weight: 30 },
      { id: 'p5', title: '谢谢参与', weight: 30 },
    ]}},
    { id: 'blk_rules', type: 'rule', label: '游戏规则', config: { variables: [
      { key: 'spinCost', label: '每次消耗金币', value: 10, min: 0, max: 1000 },
    ]}},
    { id: 'blk_theme', type: 'theme', label: '视觉主题', config: { preset: '暗金' } },
  ];

  // ─── 答题游戏默认配置 ───
  const QUIZ_DEFAULTS = [
    { id: 'blk_questions', type: 'collection', label: '题库', config: { drawMode: 'random', cards: [
      { id: 'q1', title: '世界上最大的洋是？', options: ['大西洋','太平洋','印度洋','北冰洋'], answer: 1 },
      { id: 'q2', title: '光的传播速度约为？', options: ['30万km/s','3万km/s','300万km/s','3000km/s'], answer: 0 },
      { id: 'q3', title: '水的化学式是？', options: ['H₂O','CO₂','O₂','NaCl'], answer: 0 },
      { id: 'q4', title: '一年大约有多少天？', options: ['300天','365天','400天','500天'], answer: 1 },
      { id: 'q5', title: '太阳系最大的行星是？', options: ['地球','火星','木星','土星'], answer: 2 },
      { id: 'q6', title: '人体最大的器官是？', options: ['心脏','肝脏','皮肤','大脑'], answer: 2 },
      { id: 'q7', title: '中国最长的河流是？', options: ['黄河','长江','珠江','淮河'], answer: 1 },
      { id: 'q8', title: '1KB 等于多少字节？', options: ['100','512','1000','1024'], answer: 3 },
    ]}},
    { id: 'blk_rules', type: 'rule', label: '游戏规则', config: { variables: [
      { key: 'totalQuestions', label: '题目数量', value: 5, min: 1, max: 50 },
      { key: 'timePerQuestion', label: '每题时限(秒)', value: 15, min: 5, max: 60 },
      { key: 'passScore', label: '及格线(%)', value: 60, min: 0, max: 100 },
    ]}},
    { id: 'blk_theme', type: 'theme', label: '视觉主题', config: { preset: '暗蓝' } },
  ];

  // ─── 2048 默认配置 ───
  const GAME2048_DEFAULTS = [
    { id: 'blk_grid', type: 'grid', label: '游戏区域', config: { rows: 4, cols: 4, cells: [] } },
    { id: 'blk_rules', type: 'rule', label: '游戏规则', config: { variables: [
      { key: 'winValue', label: '获胜目标值', value: 2048, min: 256, max: 8192 },
    ]}},
    { id: 'blk_theme', type: 'theme', label: '视觉主题', config: { preset: '暗紫' } },
  ];

  // ─── 消消乐默认配置 ───
  const MATCH3_DEFAULTS = [
    { id: 'blk_grid', type: 'grid', label: '游戏区域', config: { rows: 8, cols: 8, cells: [] } },
    { id: 'blk_rules', type: 'rule', label: '游戏规则', config: { variables: [
      { key: 'colorCount', label: '颜色种类', value: 6, min: 3, max: 8 },
      { key: 'maxMoves', label: '最大步数', value: 30, min: 10, max: 100 },
    ]}},
    { id: 'blk_theme', type: 'theme', label: '视觉主题', config: { preset: '暗紫' } },
  ];

  // ─── 飞行棋默认配置 ───
  const FLYING_CHESS_DEFAULTS = [
    { id: 'blk_grid', type: 'grid', label: '飞行路径', config: { rows: 1, cols: 1, cells: Array.from({length:52}, function(_,i){return {index:i,type:'path',name:'格'+(i+1),icon:i%13===0?'✈️':i%7===0?'⭐':''}}) } },
    { id: 'blk_players', type: 'player', label: '玩家设置', config: { minPlayers: 2, maxPlayers: 4, initialGold: 0, players: [
      { id:'p1', name:'红队', emoji:'🔴', isAI:true, color:'#EF4444' },
      { id:'p2', name:'蓝队', emoji:'🔵', isAI:true, color:'#3B82F6' },
      { id:'p3', name:'绿队', emoji:'🟢', isAI:true, color:'#22C55E' },
      { id:'p4', name:'黄队', emoji:'🟡', isAI:true, color:'#F59E0B' },
    ]}},
    { id: 'blk_rules', type: 'rule', label: '游戏规则', config: { variables: [
      { key: 'diceMin', label: '骰子最小值', value: 1, min: 1, max: 3 },
      { key: 'diceMax', label: '骰子最大值', value: 6, min: 4, max: 12 },
    ]}},
    { id: 'blk_theme', type: 'theme', label: '视觉主题', config: { preset: '暗紫' } },
  ];

  // ─── 真心话大冒险默认配置 ───
  const TRUTH_OR_DARE_DEFAULTS = [
    { id: 'blk_truths', type: 'collection', label: '真心话牌堆', config: { drawMode: 'random', cards: [
      { id:'t1', title:'你最大的秘密是什么？', difficulty:1 },
      { id:'t2', title:'上一次哭是什么时候？', difficulty:1 },
      { id:'t3', title:'你最尴尬的经历是什么？', difficulty:2 },
      { id:'t4', title:'有没有暗恋过朋友的对象？', difficulty:3 },
      { id:'t5', title:'做过最后悔的事是什么？', difficulty:2 },
      { id:'t6', title:'你最害怕什么？', difficulty:1 },
      { id:'t7', title:'最想念的人是谁？', difficulty:1 },
      { id:'t8', title:'最想对谁说对不起？', difficulty:2 },
    ]}},
    { id: 'blk_dares', type: 'collection', label: '大冒险牌堆', config: { drawMode: 'random', cards: [
      { id:'d1', title:'学狗叫 30 秒', difficulty:2 },
      { id:'d2', title:'模仿在场一个人', difficulty:2 },
      { id:'d3', title:'打电话给第 5 个联系人说"我想你了"', difficulty:4 },
      { id:'d4', title:'闭眼转 10 圈走直线', difficulty:1 },
      { id:'d5', title:'用方言唱一首歌', difficulty:2 },
      { id:'d6', title:'表演喜怒哀乐表情', difficulty:1 },
      { id:'d7', title:'对窗外喊"我是最棒的"', difficulty:3 },
      { id:'d8', title:'单脚站立一分钟', difficulty:1 },
    ]}},
    { id: 'blk_rules', type: 'rule', label: '游戏规则', config: { variables: [
      { key: 'maxSkips', label: '最多跳过次数', value: 2, min: 0, max: 10 },
      { key: 'penaltyMode', label: '惩罚模式(none/drink/score)', value: 'none' },
    ]}},
    { id: 'blk_theme', type: 'theme', label: '视觉主题', config: { preset: '暗紫' } },
  ];

  // ─── API ───
  function getDefaults(gameType) {
    var games = {
      monopoly:       MONOPOLY_DEFAULTS,
      snake:          SNAKE_DEFAULTS,
      wheel:          WHEEL_DEFAULTS,
      quiz:           QUIZ_DEFAULTS,
      'game-2048':    GAME2048_DEFAULTS,
      match3:         MATCH3_DEFAULTS,
      'flying-chess': FLYING_CHESS_DEFAULTS,
      'truth-or-dare': TRUTH_OR_DARE_DEFAULTS,
    };
    var defaults = games[gameType];
    return defaults ? JSON.parse(JSON.stringify(defaults)) : [];
  }

  function getSchema(blockType) {
    return SCHEMAS[blockType] || null;
  }

  function getAllSchemas() {
    return { ...SCHEMAS };
  }

  function createBlock(type, overrides) {
    var overrides = overrides || {};
    var schema = SCHEMAS[type];
    if (!schema) return null;
    var id = 'blk_' + Math.random().toString(36).slice(2, 8);
    var config = {};
    for (var i = 0; i < (schema.fields || []).length; i++) {
      var field = schema.fields[i];
      if (field.default !== undefined) {
        config[field.key] = field.default;
      }
    }
    // 合并 overrides
    for (var k in overrides) {
      if (overrides.hasOwnProperty(k)) config[k] = overrides[k];
    }
    return { id: id, type: type, label: schema.label, config: config };
  }

  return { TYPES, SCHEMAS, getDefaults, getSchema, getAllSchemas, createBlock };
})();
