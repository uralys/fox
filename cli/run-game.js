// -----------------------------------------------------------------------------

const chalk = require('chalk');
const chokidar = require('chokidar');
const shelljs = require('shelljs');

// -----------------------------------------------------------------------------

let currentInstance;

// -----------------------------------------------------------------------------

const restart = (godotPath, config) => {
  console.log('----------------------------');
  console.log(`🦊 ${chalk.italic('restarting Godot')}`);
  var {position} = config;

  currentInstance = shelljs.exec(`${godotPath} --position ${position}`, {
    async: true
  });
  console.log('----------------------------');
};

// -----------------------------------------------------------------------------

const runGame = (godotPath, config) => {
  console.log(`⚙️  running ${chalk.blue.bold('game')}...`);
  const watcher = chokidar.watch(['**/*.gd', '**/*.tscn', '**/*.cfg']);

  watcher.on('ready', (event, path) => {
    restart(godotPath, config);
  });

  watcher.on('change', (event, path) => {
    shelljs.exec('clear');

    if (currentInstance) {
      shelljs.exec(`kill -9 ${currentInstance.pid}`);
    }

    restart(godotPath, config);
  });
};

// -----------------------------------------------------------------------------

module.exports = runGame;
