// -----------------------------------------------------------------------------

import fs from 'fs';

import {foxLogger} from './logger.js';

// -----------------------------------------------------------------------------

const DEFAULT_PATHS = {
  darwin: '/Applications/Apps/Godot.app/Contents/MacOS/Godot',
  win32: 'C:\\Program Files\\Godot\\Godot.exe',
  wsl: '/mnt/c/Program Files/Godot/Godot.exe',
  linux: 'godot'
};

// -----------------------------------------------------------------------------

const isWSL = () => {
  try {
    const version = fs.readFileSync('/proc/version', 'utf8');
    return version.toLowerCase().includes('microsoft');
  } catch {
    return false;
  }
};

// -----------------------------------------------------------------------------

const detectPlatform = () => {
  const platform = process.platform;

  if (platform === 'darwin') return 'darwin';
  if (platform === 'win32') return 'win32';
  if (platform === 'linux' && isWSL()) return 'wsl';

  return 'linux';
};

// -----------------------------------------------------------------------------

const resolveGodotPath = (configPath) => {
  const platform = detectPlatform();

  if (configPath) {
    if (fs.existsSync(configPath)) {
      return configPath;
    }

    foxLogger.error(`Godot not found at: ${configPath}`);
    foxLogger.log('Override core.godot in your fox.config.json');
    return null;
  }

  const godotPath = DEFAULT_PATHS[platform];
  foxLogger.log(`Platform: ${platform}`);
  foxLogger.log(`Godot: ${godotPath}`);

  if (platform === 'linux') {
    return godotPath;
  }

  if (!fs.existsSync(godotPath)) {
    foxLogger.error(`Godot not found at: ${godotPath}`);
    foxLogger.log('Install Godot or set core.godot in your fox.config.json');
    return null;
  }

  return godotPath;
};

// -----------------------------------------------------------------------------

export default resolveGodotPath;
