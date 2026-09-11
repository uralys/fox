// -----------------------------------------------------------------------------
// `fox --help` printed by fox itself.
//
// yargs renders a usable list, but a colourless one: it also wraps in the middle
// of words on a narrow terminal ("create gi\nt tag"), spells the script name
// after the file that was executed ("cli.js tag"), and translates its own
// headings to the system locale while every command stays in English. The
// command table below is the single source of what fox can do: yargs registers
// itself from it, and this renders it.

import { isLinkedCli } from './install-cli.js';
import { colors } from './logger.js';

// -----------------------------------------------------------------------------

// One colour per group, in the order the groups are declared. The palette only
// has to be long enough for the table in cli.js; it cycles rather than running
// out, so adding a group never prints an undefined escape.
const GROUP_COLORS = [colors.green, colors.yellow, colors.magenta, colors.blue];

const groupColor = (index) => GROUP_COLORS[index % GROUP_COLORS.length];

// -----------------------------------------------------------------------------

const MIN_WIDTH = 60;
const MAX_WIDTH = 110;
const GUTTER = 4;

const width = () => Math.min(Math.max(process.stdout.columns || 100, MIN_WIDTH), MAX_WIDTH);

// -----------------------------------------------------------------------------
// Wrapping on words, never inside one: a description is read, not parsed.

const wrap = (text, available) => {
  const lines = [''];

  for (const word of text.split(' ')) {
    const current = lines[lines.length - 1];

    if (!current) {
      lines[lines.length - 1] = word;
    } else if (current.length + 1 + word.length <= available) {
      lines[lines.length - 1] = `${current} ${word}`;
    } else {
      lines.push(word);
    }
  }

  return lines;
};

// -----------------------------------------------------------------------------

const printCommand = (name, description, column, available) => {
  const [first, ...rest] = wrap(description, available);
  const pad = ' '.repeat(column - name.length);

  // Every command name shares one colour while the group titles carry the
  // palette: the names form a single column the eye can run down, and the
  // colour is left to say where one group ends and the next starts.
  //
  // No colour on the description: `\x1b[37m` is not the terminal's own white,
  // it is the palette's white slot, and it comes out dimmed or yellowish on the
  // themes Chris uses. The default foreground is the only real white here.
  console.log(`  ${colors.blue}${colors.bold}${name}${colors.reset}${pad}${first}`);

  for (const line of rest) {
    console.log(`  ${' '.repeat(column)}${line}`);
  }
};

// -----------------------------------------------------------------------------

export const printHelp = (groups, { version, docs }) => {
  const names = groups.flatMap(({ commands }) => commands.map(([name]) => name));
  const column = names.reduce((max, name) => Math.max(max, name.length), 0) + GUTTER;
  const available = Math.max(width() - column - 2, 24);

  console.log('');
  console.log(`${colors.bold}fox${colors.reset} <command> [options]`);

  groups.forEach(({ title, commands }, index) => {
    console.log('');
    console.log(`${groupColor(index)}${colors.bold}${colors.underline}${title}${colors.reset}`);

    for (const [name, description] of commands) {
      printCommand(name, description, column, available);
    }
  });

  // The footer closes the page, it does not compete with it: grey, except the
  // one word worth stopping on. A symlinked CLI runs whatever the checkout
  // holds, so the version printed beside it is not a released one.
  const attachment = isLinkedCli() ? ` ${colors.yellow}(symlinked)` : '';

  console.log('');
  console.log(`${colors.gray}fox CLI v${version}${attachment}${colors.reset}  ${colors.gray}${docs}${colors.reset}`);
  console.log('');
};
