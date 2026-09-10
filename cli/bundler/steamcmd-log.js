// -----------------------------------------------------------------------------

// steamcmd writes a flat, chatty console log; this turns it into the fox tree.
//
// Two rules make the translation safe. Nothing is dropped except an explicit
// list of known banner lines: anything unrecognised is printed verbatim as a
// child, so a new steamcmd message or an error can never be swallowed by the
// formatter. And progress lines are not printed one by one — the last value
// reached is kept and emitted once, when the phase ends, which is the only part
// of that stream anyone reads.

const NOISE = [
  /^Redirecting stderr/,
  /^Logging directory/,
  /^\[\s*\d+%\]/,
  /^\[-+\]/,
  /^Steam Console Client/,
  /^-- type 'quit' to exit --/,
  /^Loading Steam API/,
  /^Waiting for /,
  /iopollinghelpers/,
  /^Logging in using cached credentials/,
  /^steamcmd\.sh\[/,
  /^OK\s*$/,
];

// Only a credential question is written through before its newline arrives.
// Anything else always gets one, and flushing on a mere chunk boundary would
// print the line twice — once raw, once formatted.
const PROMPT = /(steam guard|two-factor|two factor|password|passcode|code)[^\n]*:\s*$/i;

const PHASES = {
  'Preparing update...': 'prepared',
  'Building file mapping...': 'mapped',
  'Scanning content': 'scanned',
  'Uploading content...': 'uploaded',
};

const PROGRESS = /^[.\s]*([\d.]+\s*[KMG]B)\s*\((\d+)%\)\s*$/;
const LOGIN = /^Logging in user '([^']+)'.*OK\s*$/;
const BUILD_START = /^\[[^\]]*\]:\s*Starting AppID (\d+) build/;
const DEPOT = /^\[[^\]]*\]:\s*Building depot (\d+)/;
const FINISHED = /^\[[^\]]*\]:\s*Successfully finished AppID (\d+) build \(BuildID (\d+)\)/;
const FAILURE = /(^ERROR|\bFAILED\b|\bError!)/i;

// -----------------------------------------------------------------------------

const createSteamcmdLog = (logger, depots = {}) => {
  let pending = '';
  let phase = null;
  let progress = null;
  let depotIndex = 0;

  const flushPhase = () => {
    if (phase && progress) {
      logger.success(`${phase} ${progress}`);
    }

    phase = null;
    progress = null;
  };

  const handle = (line) => {
    const text = line.trimEnd();

    if (!text.trim() || NOISE.some((pattern) => pattern.test(text))) {
      return;
    }

    const progressMatch = text.match(PROGRESS);

    if (progressMatch) {
      progress = progressMatch[1];
      return;
    }

    const phaseLabel = PHASES[text.trim()];

    if (phaseLabel) {
      flushPhase();
      phase = phaseLabel;
      return;
    }

    const login = text.match(LOGIN);

    if (login) {
      logger.success(`logged in as ${login[1]}`);
      return;
    }

    const start = text.match(BUILD_START);

    if (start) {
      logger.log(`Building appId ${start[1]}`);
      return;
    }

    const depot = text.match(DEPOT);

    if (depot) {
      flushPhase();
      const folder = depots[depot[1]];
      logger.step(depotIndex, `depot ${depot[1]}${folder ? ` (${folder})` : ''}`);
      depotIndex += 1;
      return;
    }

    const finished = text.match(FINISHED);

    if (finished) {
      flushPhase();
      logger.success(`build ${finished[2]} accepted by Steam`);
      return;
    }

    flushPhase();

    if (FAILURE.test(text)) {
      logger.error(text.trim());
      return;
    }

    logger.log(text.trim());
  };

  // A credential question arrives without a newline: holding it in the buffer
  // would look like a freeze, so it is written through raw and the rest of that
  // line keeps flowing raw until its newline closes it.
  let rawTail = false;

  const push = (chunk) => {
    let text = chunk;

    if (rawTail) {
      const at = text.search(/\r?\n/);

      if (at < 0) {
        process.stdout.write(text);
        return;
      }

      process.stdout.write(`${text.slice(0, at)}\n`);
      rawTail = false;
      text = text.slice(at).replace(/^\r?\n/, '');
    }

    pending += text;

    const parts = pending.split(/\r?\n/);
    pending = parts.pop();

    parts.forEach(handle);

    if (PROMPT.test(pending)) {
      process.stdout.write(pending);
      pending = '';
      rawTail = true;
    }
  };

  const flush = () => {
    if (pending) {
      handle(pending);
    }

    pending = '';
    flushPhase();
  };

  return { push, flush };
};

// -----------------------------------------------------------------------------

export default createSteamcmdLog;
