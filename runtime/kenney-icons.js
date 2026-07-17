/**
 * Kenney Icons Helper — CC0 图标映射
 * 来源: kenney.nl Board Game Icons (250 SVG)
 * 用法: KI('crown') → <img src="assets/kenney/board-game-icons/Vector/Icons/crown_b.svg">
 */
var KI = (function() {
  var BASE = 'assets/kenney/board-game-icons/';
  var MAP = {
    // 奖品/成就
    crown:    'Vector/Icons/crown_b.svg',
    award:    'Vector/Icons/award.svg',
    star:     'Vector/Icons/star.svg',
    dollar:   'Vector/Icons/dollar.svg',
    // 卡牌
    card:     'Vector/Icons/card_outline.svg',
    cardFlip: 'Vector/Icons/card_flip.svg',
    cardAdd:  'Vector/Icons/card_add.svg',
    cardRemove: 'Vector/Icons/card_remove.svg',
    // 骰子
    dice:     'PNG/Dice/dieRed1.png',
    dice2:    'PNG/Dice/dieRed2.png',
    dice3:    'PNG/Dice/dieRed3.png',
    dice4:    'PNG/Dice/dieRed4.png',
    dice5:    'PNG/Dice/dieRed5.png',
    dice6:    'PNG/Dice/dieRed6.png',
    // 箭头/操作
    spin:     'Vector/Icons/arrow_rotate.svg',
    clockwise:'Vector/Icons/arrow_clockwise.svg',
    right:    'Vector/Icons/arrow_right.svg',
    // 通用
    book:     'Vector/Icons/book_closed.svg',
    campfire: 'Vector/Icons/campfire.svg',
  };

  function img(name, size) {
    var src = MAP[name];
    if (!src) return '<span style="font-size:'+(size||20)+'px">?</span>';
    var s = size || 20;
    return '<img src="'+BASE+src+'" style="width:'+s+'px;height:'+s+'px;vertical-align:middle" onerror="this.style.display=\'none\'">';
  }

  function el(name, size) {
    var src = MAP[name];
    if (!src) return null;
    var img = document.createElement('img');
    img.src = BASE + src;
    img.style.cssText = 'width:'+(size||20)+'px;height:'+(size||20)+'px;vertical-align:middle';
    img.onerror = function(){ this.style.display='none'; };
    return img;
  }

  return { img: img, el: el };
})();
