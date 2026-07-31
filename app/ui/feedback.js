// 统一反馈出口：中奖弹窗、Toast、错误态都从这里扩展。
(function (root) {
  root.GameHubFeedback = {
    toast: function (message, options) {
      options = options || {};
      var host = document.querySelector('[data-gh-toast-host]');
      if (!host) { host = document.createElement('div'); host.dataset.ghToastHost = ''; host.className = 'gh-toast-host'; document.body.appendChild(host); }
      var toast = document.createElement('div');
      toast.className = 'gh-toast gh-toast-' + (options.tone || 'info');
      toast.setAttribute('role', 'status'); toast.textContent = message; host.appendChild(toast);
      requestAnimationFrame(function () { toast.classList.add('is-visible'); });
      window.setTimeout(function () { toast.classList.remove('is-visible'); window.setTimeout(function () { toast.remove(); }, 220); }, options.duration || 2400);
    },
  };
}(window));
