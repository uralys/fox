// -----------------------------------------------------------------------------

import chalk from 'chalk';
import chokidar from 'chokidar';
import shelljs from 'shelljs';

// -----------------------------------------------------------------------------

let currentInstance;

// -----------------------------------------------------------------------------

const restart = (godotPath, config) => {
  console.log('\n============================================================');
  console.log(`🦊 ${chalk.italic('restarting Godot')}`);
  console.log('============================================================');
  var {position} = config;

  currentInstance = shelljs.exec(`${godotPath} local-fox-runner --position ${position}`, {
    async: true
  });
};

// -----------------------------------------------------------------------------

const runGame = (godotPath, config) => {
  console.log(`⚙️  running ${chalk.blue.bold('game')}...`);

  const watcher = chokidar.watch(['**/*.gd', '**/*.tscn', '**/*.cfg']);

  watcher.on('ready', (event, path) => {
    // console.log({watchedfiles: watcher.getWatched()});
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

export default runGame;
