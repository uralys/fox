// -----------------------------------------------------------------------------

const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  underline: '\x1b[4m',
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

// Box widths are measured on what the terminal SHOWS: an ANSI sequence costs
// bytes but no columns, so counting it would push every right border out by the
// length of the colour codes on that line.
const ANSI = /\x1b\[[0-9;]*m/g;
const ANSI_TOKEN = /(\x1b\[[0-9;]*m)/;
const visibleLength = (text) => text.replace(ANSI, '').length;

// -----------------------------------------------------------------------------
// Every line is cut to the terminal before it is printed: a line wider than the
// terminal is wrapped by the terminal itself, at column 0, so a box border or a
// tree gutter lands in the left margin of the next row and the frame breaks.
// Piped output has no width to read, hence the conventional 80 columns.

const DEFAULT_COLUMNS = 80;
const MIN_TEXT_WIDTH = 20;

const terminalColumns = () => {
  const columns = process.stdout.columns || Number.parseInt(process.env.COLUMNS, 10);
  return columns > 0 ? columns : DEFAULT_COLUMNS;
};

// The last column is left empty: a terminal that wraps eagerly would otherwise
// push the newline onto an empty extra row.
const availableWidth = (used) => Math.max(MIN_TEXT_WIDTH, terminalColumns() - used - 1);

// Word wrap that keeps the colours: a sequence still open at a break is closed
// at the end of the row and reopened on the next one, so a border printed after
// the text never inherits it. A word longer than the whole width is split.
const wrapText = (text, width, indent = '') => {
  if (visibleLength(text) <= width) {
    return [text];
  }

  const rows = [];
  let row = '';
  let rowLength = 0;
  let pending = '';
  let active = '';

  const breakRow = () => {
    rows.push(active ? `${row}${colors.reset}` : row);
    row = `${indent}${active}`;
    rowLength = indent.length;
    pending = '';
  };

  const place = (word) => {
    if (rowLength + pending.length + word.length <= width) {
      row += `${pending}${word}`;
      rowLength += pending.length + word.length;
      pending = '';
      return;
    }

    if (rowLength > indent.length) {
      breakRow();
      place(word);
      return;
    }

    const chars = Array.from(word);
    let head = '';

    while (chars.length && rowLength + head.length + chars[0].length <= width) {
      head += chars.shift();
    }

    row += head;
    rowLength += head.length;
    breakRow();

    if (chars.length) {
      place(chars.join(''));
    }
  };

  for (const part of text.split(ANSI_TOKEN)) {
    if (ANSI_TOKEN.test(part)) {
      row += part;
      active = part === colors.reset ? '' : `${active}${part}`;
      continue;
    }

    for (const word of part.split(/( +)/)) {
      if (!word) {
        continue;
      }

      if (word.startsWith(' ')) {
        pending += word;
        continue;
      }

      place(word);
    }
  }

  rows.push(row);
  return rows;
};

// A wrapped box row keeps the indentation of its line, plus two spaces, so a
// continuation never reads as a new entry.
const wrapBoxLine = (line, width) => {
  const lead = line.replace(ANSI, '').match(/^ */)[0];
  return wrapText(line, width, `${lead}  `);
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

const createLogger = ({ name, color }) => {
  const c = colors[color] || colors.cyan;
  const r = colors.reset;

  let started = false;

  const gutter = (symbol) => `${c}${symbol}${r}`;
  const tag = `${c}${name}${r}`;

  // The logger name belongs to the `●` line that opens the tree: every child
  // below it is already qualified by that header, so repeating the tag on each
  // one only pushes the message right. A child-level call arriving first still
  // opens the tree, tag included — nothing can end up orphaned under no header.
  // A message too long for the terminal continues under itself, behind a `│`
  // that keeps the tree connected, instead of wrapping back to column 0.
  const print = (head, message, continued = SYMBOLS.pipe) => {
    const indent = visibleLength(head);
    const [first, ...rest] = wrapText(message, availableWidth(indent));

    console.log(`${head}${first}`);

    for (const row of rest) {
      console.log(`${gutter(continued)}${' '.repeat(indent - 1)}${row}`);
    }
  };

  const emit = (symbol, decoration, message) => {
    if (!started) {
      started = true;
      print(`${gutter(SYMBOLS.parent)} ${tag} ${decoration}`, message);
      return;
    }

    print(`${gutter(symbol)} ${decoration}`, message);
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
    print(`${gutter(SYMBOLS.close)} ${colors.green}${SYMBOLS.success}${r}  ${prefix}`, message, ' ');
    started = false;
  };

  const data = (obj) => {
    // `│  │ ` before the text and ` │` after it: 7 columns of frame.
    const textWidth = availableWidth(7);

    const rows = Object.entries(obj)
      .flatMap(([key, value]) => `${key}: ${formatValue(value)}`.split('\n'))
      .flatMap((line) => wrapBoxLine(line, textWidth));

    const width = rows.reduce((max, row) => Math.max(max, visibleLength(row)), 0) + 2;
    const pipe = `${c}${SYMBOLS.pipe}${r}`;

    console.log(`${pipe}  ┌${'─'.repeat(width)}┐`);

    for (const row of rows) {
      const padding = width - visibleLength(row) - 1;
      console.log(`${pipe}  │ ${row}${' '.repeat(Math.max(0, padding))}│`);
    }

    console.log(`${pipe}  └${'─'.repeat(width)}┘`);
  };

  const reset = () => {
    started = false;
  };

  return { log, step, success, successCompact, warn, error, done, data, reset };
};

// -----------------------------------------------------------------------------
// A standalone box, outside any logger tree: used by the lines that comment on
// the whole command rather than on one of its steps (the tag gap closing a
// listing, a new release waiting to be pinned). Colour carries the verdict.

const logBox = (lines, color = colors.white) => {
  // `│ ` before the text and ` │` after it: 4 columns of frame.
  const rows = lines.flatMap((line) => wrapBoxLine(line, availableWidth(4)));
  const width = rows.reduce((max, row) => Math.max(max, visibleLength(row)), 0) + 2;
  const edge = (left, right) => `${color}${left}${'─'.repeat(width)}${right}${colors.reset}`;
  const bar = `${color}${SYMBOLS.pipe}${colors.reset}`;

  console.log('');
  console.log(edge('┌', '┐'));

  for (const row of rows) {
    const padding = width - visibleLength(row) - 1;
    console.log(`${bar} ${row}${' '.repeat(Math.max(0, padding))}${bar}`);
  }

  console.log(edge('└', '┘'));
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

// Lowercase, unlike every other tag: this one opens on the command that was
// typed, right under the 🦊 line naming the mount, and `fox ls` is what the
// reader ran. The others name a component (`Godot`, `Switch`), not a command.
const foxLogger = createLogger({ name: 'fox', color: 'cyan' });
const godotLogger = createLogger({ name: 'Godot', color: 'yellow' });
const switchLogger = createLogger({ name: 'Switch', color: 'blue' });
const presetLogger = createLogger({ name: 'Preset', color: 'magenta' });
const iconsLogger = createLogger({ name: 'Icons', color: 'green' });
const splashLogger = createLogger({ name: 'Splash', color: 'green' });
const screenshotsLogger = createLogger({ name: 'Screenshots', color: 'green' });
const apngLogger = createLogger({ name: 'APNG', color: 'green' });
const versionLogger = createLogger({ name: 'Version', color: 'blue' });
const upgradeLogger = createLogger({ name: 'Upgrade', color: 'magenta' });
const linkLogger = createLogger({ name: 'Link', color: 'magenta' });
const presetsLogger = createLogger({ name: 'Presets', color: 'gray' });
const hooksLogger = createLogger({ name: 'Hooks', color: 'blue' });

// -----------------------------------------------------------------------------

export {
  apngLogger,
  colors,
  createLogger,
  foxLogger,
  godotLogger,
  hooksLogger,
  iconsLogger,
  linkLogger,
  logBox,
  logHeader,
  presetLogger,
  presetsLogger,
  screenshotsLogger,
  splashLogger,
  switchLogger,
  upgradeLogger,
  versionLogger,
};
