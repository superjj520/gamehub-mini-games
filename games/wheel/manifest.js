const { normalizeConfig } = require('./config.js');
const { createEngine } = require('./engine.js');
const { createPlayer } = require('./player.js');
const { createEditor } = require('./editor.js');
module.exports = { type: 'wheel', name: '大转盘', version: 1, normalizeConfig: normalizeConfig, createEngine: createEngine, createPlayer: createPlayer, createEditor: createEditor };
