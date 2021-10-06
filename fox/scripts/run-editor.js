const shelljs = require('shelljs');

// -----------------------------------------------------------------------------

const runEditor = () => {
  console.log('----------------------------');
  console.log('🦊 starting Godot Editor');
  shelljs.exec(
    '/Applications/Apps/Godot.app/Contents/MacOS/Godot -e --windowed --resolution 2980x2220 --position 50,170',
    {
      async: true,
    }
  );
  console.log('----------------------------');
};

// -----------------------------------------------------------------------------

runEditor();
