// -----------------------------------------------------------------------------
// `fox --help` printed by fox itself.
//
// yargs renders a usable list, but a colourless one: it also wraps in the middle
// of words on a narrow terminal ("create gi\nt tag"), spells the script name
// after the file that was executed ("cli.js tag"), and translates its own
// headings to the system locale while every command stays in English. The
// command table below is the single source of what fox can do: yargs registers
// itself from it, and this renders it.

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

  console.log(`  ${colors.green}${colors.bold}${name}${colors.reset}${pad}${colors.gray}${first}${colors.reset}`);

  for (const line of rest) {
    console.log(`  ${' '.repeat(column)}${colors.gray}${line}${colors.reset}`);
  }
};

// -----------------------------------------------------------------------------

export const printHelp = (groups, { version, docs }) => {
  const names = groups.flatMap(({ commands }) => commands.map(([name]) => name));
  const column = names.reduce((max, name) => Math.max(max, name.length), 0) + GUTTER;
  const available = Math.max(width() - column - 2, 24);

  console.log('');
  console.log(`${colors.bold}${colors.white}fox${colors.reset} <command> [options]`);

  for (const { title, commands } of groups) {
    console.log('');
    console.log(`${colors.cyan}${colors.bold}${title}${colors.reset}`);

    for (const [name, description] of commands) {
      printCommand(name, description, column, available);
    }
  }

  console.log('');
  console.log(`${colors.gray}fox CLI v${version}${colors.reset}  ${colors.blue}${docs}${colors.reset}`);
  console.log('');
};
