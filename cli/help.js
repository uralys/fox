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

  // No colour on the description: `\x1b[37m` is not the terminal's own white,
  // it is the palette's white slot, and it comes out dimmed or yellowish on the
  // themes Chris uses. The default foreground is the only real white here.
  console.log(`  ${colors.cyan}${colors.bold}${name}${colors.reset}${pad}${first}`);

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

  for (const { title, commands } of groups) {
    console.log('');
    console.log(`${colors.cyan}${colors.bold}${title}${colors.reset}`);

    for (const [name, description] of commands) {
      printCommand(name, description, column, available);
    }
  }

  const attachment = isLinkedCli() ? ' (symlinked)' : '';

  console.log('');
  console.log(
    `${colors.magenta}${colors.bold}fox CLI v${version}${attachment}${colors.reset}  ${colors.cyan}${docs}${colors.reset}`,
  );
  console.log('');
};
