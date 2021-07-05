const chokidar = require('chokidar');
const shelljs = require('shelljs');

const path = require('path');
const {cwd} = require('process');

// -----------------------------------------------------------------------------

const SRC = path.resolve(cwd(), `./src`);

let currentInstance;

// -----------------------------------------------------------------------------

const restart = () => {
  console.log('----------------------------');
  console.log('☢️  restarting Godot');
  currentInstance = shelljs.exec(
    '/Applications/Apps/Godot.app/Contents/MacOS/Godot --position 1510, 70',
    {
      async: true,
    }
  );
  console.log('----------------------------');
};

// -----------------------------------------------------------------------------

const runGodot = () => {
  const watcher = chokidar.watch(`${SRC}/*/*.gd`);

  watcher.on('ready', (event, path) => {
    restart();
  });

  watcher.on('change', (event, path) => {
    if (currentInstance) {
      shelljs.exec(`kill -9 ${currentInstance.pid}`);
    }

    shelljs.exec('clear');
    restart();
  });
};

// -----------------------------------------------------------------------------

runGodot();
