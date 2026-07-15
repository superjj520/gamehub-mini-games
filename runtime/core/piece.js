/**
 * 实体控制器 — 棋子 DOM 创建/定位/动画移动
 * 依赖：无
 */
const PieceController = (() => {
  function createPieceEl(player, index) {
    const el = document.createElement('div');
    el.id = 'gh-piece-' + index;
    el.className = 'gh-piece';
    el.style.cssText = [
      'position:absolute;width:28px;height:28px;border-radius:50%;',
      'background:' + player.color + ';border:2px solid white;',
      'box-shadow:0 2px 8px rgba(0,0,0,0.5);z-index:10;',
      'transition:top 0.3s cubic-bezier(.4,1.3,.6,1),left 0.3s cubic-bezier(.4,1.3,.6,1);',
      'display:flex;align-items:center;justify-content:center;font-size:12px;',
      'pointer-events:none;',
    ].join('');
    el.textContent = player.emoji || '🎮';
    return el;
  }

  function placePiece(pieceEl, position, offsetX, offsetY) {
    offsetX = offsetX || 0;
    offsetY = offsetY || 0;
    pieceEl.style.transition = 'none';
    pieceEl.style.top  = (position.y - 12 + offsetY) + 'px';
    pieceEl.style.left = (position.x - 12 + offsetX) + 'px';
    // 强制回流后恢复动画
    pieceEl.offsetHeight;
    pieceEl.style.transition = 'top 0.3s cubic-bezier(.4,1.3,.6,1),left 0.3s cubic-bezier(.4,1.3,.6,1)';
  }

  function animatePiece(pieceEl, targetPos, duration, offsetX, offsetY) {
    duration = duration || 300;
    offsetX = offsetX || 0;
    offsetY = offsetY || 0;
    return new Promise(function(resolve) {
      pieceEl.style.transition = 'top ' + duration + 'ms cubic-bezier(.4,1.3,.6,1),left ' + duration + 'ms cubic-bezier(.4,1.3,.6,1)';
      pieceEl.style.top  = (targetPos.y - 12 + offsetY) + 'px';
      pieceEl.style.left = (targetPos.x - 12 + offsetX) + 'px';
      setTimeout(resolve, duration + 50);
    });
  }

  function removePiece(pieceEl) {
    if (pieceEl && pieceEl.parentNode) {
      pieceEl.parentNode.removeChild(pieceEl);
    }
  }

  return { createPieceEl, placePiece, animatePiece, removePiece };
})();
