/**
 * Block 类型注册表 — 定义 9 种通用 Block 类型和每个游戏的默认配置
 * 依赖：无（纯数据模块）
 */
const BlockRegistry = (() => {
  const TYPES = {
    GRID:       'grid',
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
    grid: {
      label: '棋盘', icon: '🗺️',
      fields: [
        { key: 'rows',    label: '行数',   type: 'number', min: 5, max: 15, default: 7 },
        { key: 'cols',    label: '列数',   type: 'number', min: 5, max: 15, default: 7 },
        { key: 'cells',   label: '格子列表', type: 'cell-list' },
      ],
    },
    collection: {
      label: '卡堆/奖池', icon: '🎲',
      fields: [
        { key: 'drawMode', label: '抽选模式', type: 'select', options: ['random', 'weighted', 'sequential'], default: 'random' },
        { key: 'cards',    label: '条目列表',  type: 'card-list' },
      ],
    },
    rule: {
      label: '规则', icon: '📐',
      fields: [
        { key: 'variables', label: '变量定义', type: 'variable-list' },
      ],
    },
    piece: {
      label: '棋子/实体', icon: '🧩',
      fields: [
        { key: 'pieces', label: '棋子列表', type: 'piece-list' },
      ],
    },
    building: {
      label: '建筑', icon: '🏗️',
      fields: [
        { key: 'buildings', label: '建筑类型', type: 'building-list' },
      ],
    },
    store: {
      label: '商店', icon: '🏪',
      fields: [
        { key: 'currency',  label: '货币类型', type: 'text',   default: 'gold' },
        { key: 'items',     label: '商品列表', type: 'store-item-list' },
      ],
    },
    effect: {
      label: '效果/事件', icon: '⚡',
      fields: [
        { key: 'effects', label: '效果列表', type: 'effect-list' },
      ],
    },
    player: {
      label: '玩家设置', icon: '👥',
      fields: [
        { key: 'minPlayers',  label: '最少玩家', type: 'number', min: 1, max: 10, default: 2 },
        { key: 'maxPlayers',  label: '最多玩家', type: 'number', min: 1, max: 10, default: 4 },
        { key: 'initialGold', label: '初始金币', type: 'number', min: 0, max: 99999, default: 1500 },
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
      id: 'blk_board', type: 'grid', label: '棋盘',
      config: {
        rows: 7, cols: 7,
        cells: [
          { index: 0,  type: 'start',    name: '起点',     icon: '🚩', effect: { gold: 200 } },
          { index: 1,  type: 'property', name: '奶茶铺',   icon: '🧋', price: 200,  rent: [50, 100, 200] },
          { index: 2,  type: 'chance',   name: '机会',     icon: '❓', effect: { draw: 'chance' } },
          { index: 3,  type: 'property', name: '服装店',   icon: '👗', price: 300,  rent: [80, 160, 320] },
          { index: 4,  type: 'jail',     name: '监禁',     icon: '🚔', effect: { skip: 1 } },
          { index: 5,  type: 'property', name: '美妆店',   icon: '💄', price: 250,  rent: [60, 120, 240] },
          { index: 6,  type: 'destiny',  name: '命运',     icon: '🔮', effect: { draw: 'destiny' } },
          { index: 7,  type: 'property', name: '数码店',   icon: '📱', price: 350,  rent: [90, 180, 360] },
          { index: 8,  type: 'shop',     name: '商铺街',   icon: '🏪', effect: { shop_reward: true } },
          { index: 9,  type: 'property', name: '咖啡馆',   icon: '☕', price: 200,  rent: [50, 100, 200] },
          { index: 10, type: 'chance',   name: '机会',     icon: '❓', effect: { draw: 'chance' } },
          { index: 11, type: 'property', name: '餐饮店',   icon: '🍜', price: 400,  rent: [100, 200, 400] },
          { index: 12, type: 'event',    name: '幸运日',   icon: '🌈', effect: { gold: 100 } },
          { index: 13, type: 'property', name: '游戏馆',   icon: '🎮', price: 280,  rent: [70, 140, 280] },
          { index: 14, type: 'destiny',  name: '命运',     icon: '🔮', effect: { draw: 'destiny' } },
          { index: 15, type: 'property', name: '健身房',   icon: '🏋️', price: 320,  rent: [80, 160, 320] },
          { index: 16, type: 'chance',   name: '机会',     icon: '❓', effect: { draw: 'chance' } },
          { index: 17, type: 'property', name: '珠宝店',   icon: '💎', price: 500,  rent: [150, 300, 500] },
          { index: 18, type: 'event',    name: '税务',     icon: '💰', effect: { gold: -100 } },
          { index: 19, type: 'property', name: '黄金城',   icon: '👑', price: 600,  rent: [200, 400, 600] },
          { index: 20, type: 'chance',   name: '机会',     icon: '❓', effect: { draw: 'chance' } },
          { index: 21, type: 'property', name: '银行',     icon: '🏦', price: 450,  rent: [120, 240, 480] },
          { index: 22, type: 'destiny',  name: '命运',     icon: '🔮', effect: { draw: 'destiny' } },
          { index: 23, type: 'property', name: '庄园',     icon: '🏰', price: 700,  rent: [250, 500, 700] },
        ],
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

  // ─── API ───
  function getDefaults(gameType) {
    const defaults = { monopoly: JSON.parse(JSON.stringify(MONOPOLY_DEFAULTS)) };
    return defaults[gameType] || [];
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
