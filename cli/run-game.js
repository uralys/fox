// -----------------------------------------------------------------------------

import chalk from 'chalk';
import chokidar from 'chokidar';
import shelljs from 'shelljs';
import {spawn} from 'child_process';

import keypress from 'keypress';

// -----------------------------------------------------------------------------

let childProcess = null;

// -----------------------------------------------------------------------------

const restart = (godotPath, config) => {
  shelljs.exec('clear');

  if (childProcess) {
    childProcess.kill();
  }

  start(godotPath, config);
}

// -----------------------------------------------------------------------------

const start = (godotPath, config) => {
  console.log('============================================================');
  console.log(`🦊 ${chalk.italic('restarting Godot')}`);
  console.log(`⚙️  running ${chalk.blue.bold('game')}`);
  console.log('============================================================');
  var {position, screen} = config;

  const parameters =  ['local-fox-runner'];

  if (screen) {
    parameters.push(['--screen', screen]);
  }
  else{
    parameters.push(['--position', position]);
  }

  childProcess = spawn(godotPath, parameters, {stdio: 'inherit'});

};

// -----------------------------------------------------------------------------

const runGame = (godotPath, config) => {
  keypress(process.stdin);

  process.stdin.setRawMode(true);

  const watcher = chokidar.watch(['**/*.gd', '**/*.tscn', '**/*.cfg'], {
    ignored: ['.godot/**']
  });

  watcher.on('ready', (event, path) => {
    start(godotPath, config);
  });

  watcher.on('change', (event, path) => {
    console.log('restart on change');
    restart(godotPath, config);
  });

  process.stdin.on('keypress', (ch, key) => {
    if(key.name === 'r') {
      restart(godotPath, config);
    }

    if(key.name === 'c' && key.ctrl === true) {
      console.log('🦊 bye');

      if (childProcess) {
        childProcess.kill();
      }

      process.exit(0);
    }
  });
};

// -----------------------------------------------------------------------------

export default runGame;
