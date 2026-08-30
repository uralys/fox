// -----------------------------------------------------------------------------

const colors = {
  reset: '\x1b[0m',
  cyan: '\x1b[36m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  green: '\x1b[32m',
  magenta: '\x1b[35m',
  red: '\x1b[31m',
  gray: '\x1b[90m',
  white: '\x1b[37m',
};

// -----------------------------------------------------------------------------

const SYMBOLS = {
  parent: '●',
  child: '├─',
  close: '└─',
  pipe: '│',
  success: '✓',
  warn: '⚠',
  error: '✗',
  gear: '⚙',
};

// -----------------------------------------------------------------------------

const formatValue = (value, indent = 4) => {
  if (value === null || value === undefined) {
    return String(value);
  }

  if (typeof value === 'object') {
    const pad = ' '.repeat(indent);
    const entries = Object.entries(value);
    const lines = entries.map(([k, v]) => `${pad}${k}: ${formatValue(v, indent + 2)}`);
    return `{\n${lines.join('\n')}\n${' '.repeat(indent - 2)}}`;
  }

  return String(value);
};

// -----------------------------------------------------------------------------

const createLogger = ({name, color}) => {
  const c = colors[color] || colors.cyan;
  const r = colors.reset;

  let started = false;

  const gutter = (symbol) => `${c}${symbol}${r}`;
  const tag = `${c}${name}${r}`;

  // The logger name belongs to the `●` line that opens the tree: every child
  // below it is already qualified by that header, so repeating the tag on each
  // one only pushes the message right. A child-level call arriving first still
  // opens the tree, tag included — nothing can end up orphaned under no header.
  const emit = (symbol, decoration, message) => {
    if (!started) {
      started = true;
      console.log(`${gutter(SYMBOLS.parent)} ${tag} ${decoration}${message}`);
      return;
    }

    console.log(`${gutter(symbol)} ${decoration}${message}`);
  };

  const log = (message) => {
    emit(SYMBOLS.child, '', message);
  };

  const step = (index, message) => {
    emit(SYMBOLS.child, `[${index}] `, message);
  };

  const success = (message) => {
    emit(SYMBOLS.child, `${colors.green}${SYMBOLS.success}${r}  `, message);
  };

  const successCompact = success;

  const warn = (message) => {
    emit(SYMBOLS.child, `${colors.yellow}${SYMBOLS.warn}${r}  `, message);
  };

  const error = (message) => {
    emit(SYMBOLS.child, `${colors.red}${SYMBOLS.error}${r}  `, message);
  };

  // `done` always closes with `└─`, even when it opens the tree on its own: a
  // closing line rendered as a header would read as the start of a new section.
  const done = (message) => {
    const prefix = started ? '' : `${tag} `;
    console.log(`${gutter(SYMBOLS.close)} ${colors.green}${SYMBOLS.success}${r}  ${prefix}${message}`);
    started = false;
  };

  const data = (obj) => {
    const entries = Object.entries(obj);
    const lines = entries.map(([key, value]) => {
      const formatted = formatValue(value);
      return `${key}: ${formatted}`;
    });

    const maxLen = lines.reduce((max, line) => {
      const plainLines = line.split('\n');
      const longest = plainLines.reduce((m, l) => Math.max(m, l.length), 0);
      return Math.max(max, longest);
    }, 0);

    const width = maxLen + 2;
    const pipe = `${c}${SYMBOLS.pipe}${r}`;

    console.log(`${pipe}  ┌${'─'.repeat(width)}┐`);

    for (const line of lines) {
      const subLines = line.split('\n');
      for (const subLine of subLines) {
        const padding = width - subLine.length - 1;
        console.log(`${pipe}  │ ${subLine}${' '.repeat(Math.max(0, padding))}│`);
      }
    }

    console.log(`${pipe}  └${'─'.repeat(width)}┘`);
  };

  const reset = () => {
    started = false;
  };

  return {log, step, success, successCompact, warn, error, done, data, reset};
};

// -----------------------------------------------------------------------------

const logHeader = (title) => {
  console.log('');
  console.log(`${colors.white}═══════════════════════════════════════════${colors.reset}`);
  console.log(`${colors.white}  ${title}${colors.reset}`);
  console.log(`${colors.white}═══════════════════════════════════════════${colors.reset}`);
  console.log('');
};

// -----------------------------------------------------------------------------

const foxLogger = createLogger({name: 'Fox', color: 'cyan'});
const godotLogger = createLogger({name: 'Godot', color: 'yellow'});
const switchLogger = createLogger({name: 'Switch', color: 'blue'});
const presetLogger = createLogger({name: 'Preset', color: 'magenta'});
const iconsLogger = createLogger({name: 'Icons', color: 'green'});
const splashLogger = createLogger({name: 'Splash', color: 'green'});
const screenshotsLogger = createLogger({name: 'Screenshots', color: 'green'});
const versionLogger = createLogger({name: 'Version', color: 'blue'});
const presetsLogger = createLogger({name: 'Presets', color: 'gray'});

// -----------------------------------------------------------------------------

export {
  colors,
  createLogger,
  logHeader,
  foxLogger,
  godotLogger,
  switchLogger,
  presetLogger,
  iconsLogger,
  splashLogger,
  screenshotsLogger,
  versionLogger,
  presetsLogger,
};
