const chokidar = require('chokidar');
const shelljs = require('shelljs');

// -----------------------------------------------------------------------------

let currentInstance;

// -----------------------------------------------------------------------------

const restart = () => {
  console.log('----------------------------');
  console.log('🦊 restarting Godot');
  currentInstance = shelljs.exec(
    '/Applications/Apps/Godot.app/Contents/MacOS/Godot --position 3200,70',
    // '/Applications/Apps/Godot.app/Contents/MacOS/Godot --position 1520,70',
    {
      async: true,
    }
  );
  console.log('----------------------------');
};

// -----------------------------------------------------------------------------

const runGodot = () => {
  const watcher = chokidar.watch(['**/*.gd', '**/*.tscn']);

  console.log('🦊 starting Godot Editor');
  shelljs.exec(
    '/Applications/Apps/Godot.app/Contents/MacOS/Godot -e --windowed --resolution 2980x2220 --position 50,170',
    {
      async: true,
    }
  );

  watcher.on('ready', (event, path) => {
    restart();
  });

  watcher.on('change', (event, path) => {
    shelljs.exec('clear');

    if (currentInstance) {
      shelljs.exec(`kill -9 ${currentInstance.pid}`);
    }

    restart();
  });
};

// -----------------------------------------------------------------------------

runGodot();
