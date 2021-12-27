// -----------------------------------------------------------------------------

const chalk = require('chalk');
const chokidar = require('chokidar');
const shelljs = require('shelljs');

// -----------------------------------------------------------------------------

let currentInstance;

// -----------------------------------------------------------------------------

const restart = (config) => {
  console.log('----------------------------');
  console.log('🦊 restarting Godot');
  var {godotPath, position} = config;

  currentInstance = shelljs.exec(`${godotPath} --position ${position}`, {
    async: true
  });
  console.log('----------------------------');
};

// -----------------------------------------------------------------------------

const runGodot = (config) => {
  const watcher = chokidar.watch(['**/*.gd', '**/*.tscn']);

  watcher.on('ready', (event, path) => {
    restart(config);
  });

  watcher.on('change', (event, path) => {
    shelljs.exec('clear');

    if (currentInstance) {
      shelljs.exec(`kill -9 ${currentInstance.pid}`);
    }

    restart(config);
  });
};

// -----------------------------------------------------------------------------

const runGame = (config) => {
  console.log(`---> running ${chalk.blue.bold('game')}...`);
  runGodot(config);
};

// -----------------------------------------------------------------------------

module.exports = runGame;
