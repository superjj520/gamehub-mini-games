// 轻量事件总线：模块之间只通过事件沟通，不直接互相操作 DOM。
(function (root) {
  function EventBus() { this.listeners = new Map(); }
  EventBus.prototype.on = function (name, handler) {
    if (!this.listeners.has(name)) this.listeners.set(name, new Set());
    this.listeners.get(name).add(handler);
    return function () { return this.off(name, handler); }.bind(this);
  };
  EventBus.prototype.off = function (name, handler) { var set = this.listeners.get(name); if (set) set.delete(handler); };
  EventBus.prototype.emit = function (name, payload) { var set = this.listeners.get(name); if (set) set.forEach(function (handler) { handler(payload || {}); }); };
  EventBus.prototype.clear = function () { this.listeners.clear(); };
  var events = new EventBus();
  root.GameHubEventBus = {
    EventBus: EventBus,
    events: events,
    on: function (name, handler) { return events.on(name, handler); },
    off: function (name, handler) { return events.off(name, handler); },
    emit: function (name, payload) { return events.emit(name, payload); },
  };
}(window));
