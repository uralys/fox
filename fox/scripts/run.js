const chokidar = require('chokidar');
const shelljs = require('shelljs');

// -----------------------------------------------------------------------------

let currentInstance;

// -----------------------------------------------------------------------------

const restart = () => {
  console.log('----------------------------');
  console.log('☢️  restarting Godot');
  currentInstance = shelljs.exec(
    '/Applications/Apps/Godot.app/Contents/MacOS/Godot --position 1510,70',
    {
      async: true,
    }
  );
  console.log('----------------------------');
};

// -----------------------------------------------------------------------------

const runGodot = () => {
  const watcher = chokidar.watch(`**/*.gd`);

  console.log('☢️  starting Godot Editor');
  shelljs.exec(
    '/Applications/Apps/Godot.app/Contents/MacOS/Godot -e --windowed --resolution 2580x1720 --position 50,170',
    {
      async: true,
    }
  );

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