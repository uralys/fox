// -----------------------------------------------------------------------------

import chokidar from 'chokidar';
import shelljs from 'shelljs';
import {spawn} from 'child_process';

import keypress from 'keypress';
import {godotLogger, foxLogger} from './logger.js';

// -----------------------------------------------------------------------------

let childProcess = null;

// -----------------------------------------------------------------------------

const restart = (godotPath, params, config) => {
  shelljs.exec('clear');

  if (childProcess) {
    childProcess.kill();
  }

  start(godotPath, params, config);
}

// -----------------------------------------------------------------------------

const start = (godotPath, params, config) => {
  godotLogger.reset();
  godotLogger.log('Starting game');
  var {position, screen} = config;

  const parameters = [...params];

  if (screen) {
    parameters.push(['--screen', screen]);
  }
  else{
    parameters.push(['--position', position]);
  }

  childProcess = spawn(godotPath, parameters, {stdio: 'inherit'});

};

// -----------------------------------------------------------------------------

const runGame = (godotPath, params, config) => {
  keypress(process.stdin);

  process.stdin.setRawMode(true);

  const watcher = chokidar.watch('.', {
    ignored: (path, stats) => {
      if (!stats) return false; // Si stats est null (par exemple au démarrage), ne pas ignorer

      const validExtensions = ['.gd', '.tscn', '.cfg', '.json', '.yml'];
      const isWantedFile = validExtensions.some(ext => path.endsWith(ext));

      const isInGodotFolder = path.includes('.godot/');

      return stats.isFile() && (!isWantedFile || isInGodotFolder);
    }
  });

  godotLogger.data({
    position: config.position || config.screen,
    watching: '.gd .tscn .cfg .json .yml',
    keys: 'r = reload, ctrl+c = exit',
  });

  start(godotPath, params, config);

  watcher.on('change', (path, stats) => {
    restart(godotPath, params, config);
  });

  process.stdin.on('keypress', (ch, key) => {
    if(!key) {
      return
    }

    if(key.name === 'r') {
      restart(godotPath, params, config);
    }

    if(key.name === 'c' && key.ctrl === true) {
      foxLogger.done('bye!');

      if (childProcess) {
        childProcess.kill();
      }

      process.exit(0);
    }
  });
};

// -----------------------------------------------------------------------------

export default runGame;
