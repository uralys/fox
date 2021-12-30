// -----------------------------------------------------------------------------

const chalk = require('chalk');
const chokidar = require('chokidar');
const shelljs = require('shelljs');

// -----------------------------------------------------------------------------

let currentInstance;

// -----------------------------------------------------------------------------

const restart = (config) => {
  console.log('----------------------------');
  console.log(`🦊 ${chalk.italic('restarting Godot')}`);
  var {godotPath, position} = config;

  currentInstance = shelljs.exec(`${godotPath} --position ${position}`, {
    async: true
  });
  console.log('----------------------------');
};

// -----------------------------------------------------------------------------

const runGame = (config) => {
  console.log(`---> running ${chalk.blue.bold('game')}...`);
  const watcher = chokidar.watch(['**/*.gd', '**/*.tscn', '**/*.cfg']);

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

module.exports = runGame;
