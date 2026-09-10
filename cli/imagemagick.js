// -----------------------------------------------------------------------------
// single entry point to ImageMagick for every `fox generate:*` command
// see docs/install.md for the system prerequisite
// -----------------------------------------------------------------------------

import shell from 'shelljs';

// -----------------------------------------------------------------------------

const BINARY = 'magick';

const INSTALL_HINT = 'ImageMagick 7 is required: brew install imagemagick';

// -----------------------------------------------------------------------------

// Wrapping is not enough: a double quote inside a file name would close the
// argument and let the rest of the name run as shell syntax.
const quote = (value) => `"${String(value).replace(/(["$`\\])/g, '\\$1')}"`;

// -----------------------------------------------------------------------------

const ensureImageMagick = (logger) => {
  if (shell.which(BINARY)) {
    return true;
  }

  logger.error(`\`${BINARY}\` not found in PATH`);
  logger.error(INSTALL_HINT);
  return false;
};

// -----------------------------------------------------------------------------

const runMagick = (args, logger) => {
  const command = [BINARY, ...args].join(' ');
  const result = shell.exec(command, { silent: true });

  if (result.code !== 0) {
    logger.error(`${BINARY} failed (code ${result.code})`);

    const details = (result.stderr || result.stdout || '').trim();
    if (details) {
      logger.error(details);
    }

    return false;
  }

  return true;
};

// -----------------------------------------------------------------------------

export { ensureImageMagick, quote, runMagick };
