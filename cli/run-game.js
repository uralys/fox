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
  var {position, screen} = config;

  const command = `${godotPath} local-fox-runner ${screen ? `--screen ${screen}` : `--position ${position}`}`;

  currentInstance = shelljs.exec(command, {
    async: true
  });
};

// -----------------------------------------------------------------------------

const runGame = (godotPath, config) => {
  console.log(`⚙️  running ${chalk.blue.bold('game')}...`);

  const watcher = chokidar.watch(['**/*.gd', '**/*.tscn', '**/*.cfg'], {
    ignored: ['.godot/**']
  });

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

export default runGame;
