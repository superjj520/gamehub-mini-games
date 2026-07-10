/**
 * 效果触发器 — 条件匹配 + 动作执行
 * 依赖：无
 */
const EffectEngine = (() => {
  function match(config, trigger, context = {}) {
    const { effects = [] } = config;
    return effects.filter(e => {
      if (e.trigger !== trigger) return false;
      if (e.cellType && e.cellType !== context.cellType) return false;
      return true;
    });
  }

  function execute(effect, context = {}) {
    const events = [];
    switch (effect.action) {
      case 'add_gold':     events.push('💰 +' + effect.value + ' 金币'); break;
      case 'deduct_gold':  events.push('💸 ' + effect.value + ' 金币'); break;
      case 'move':         events.push((effect.value > 0 ? '前进' : '后退') + ' ' + Math.abs(effect.value) + ' 格'); break;
      case 'skip_turns':   events.push('⏸️ 暂停 ' + effect.value + ' 回合'); break;
      case 'draw_card':    events.push('🃏 抽一张卡'); break;
      case 'swap_position':events.push('🔄 交换位置'); break;
      case 'lucky_draw':   events.push('🎰 获得抽奖机会'); break;
      case 'shop_reward':  events.push('🏪 商铺奖励'); break;
      case 'luck_bonus':   events.push('🍀 幸运奖励 +' + effect.value); break;
      default:             events.push('触发效果: ' + effect.action);
    }
    return { events };
  }

  return { match, execute };
})();
