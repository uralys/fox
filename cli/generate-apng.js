// -----------------------------------------------------------------------------
// Turn a video clip into an animated PNG.
//
// A store page wants a looping animation, and the two containers a page accepts
// are GIF and APNG. GIF quantises to 256 colours: on a neon render, whose whole
// subject is a gradient of glow around a saturated line, that quantisation is
// exactly what it destroys -- banding in the halo, dithering noise in the dark,
// and a heavier file than the truecolour original because the dither defeats
// the compressor. APNG keeps 24 bit colour plus a real alpha channel, and every
// browser has read it for years.
//
// This is a converter, not an animator: it takes frames that already exist in a
// video. Animating a STILL image (arcs crawling along a pipe, lights pulsing)
// is the `gif-creator` skill, and the two never overlap.
//
// Requires ffmpeg (brew install ffmpeg), and uses apngasm when it is there
// (brew install apngasm).
// -----------------------------------------------------------------------------

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import shell from 'shelljs';
import { apngLogger } from './logger.js';

// -----------------------------------------------------------------------------

const DEFAULTS = {
  fps: 15,
  width: 720,
  // A page animation is a loop, not a film: past a handful of seconds a reader
  // scrolls away, and the file grows linearly with what they will not watch.
  duration: 6,
};

const SOURCE_EXTENSIONS = ['.mp4', '.mov', '.webm', '.mkv', '.m4v', '.avi'];

// -----------------------------------------------------------------------------

// `--fps 12` and `--fps=12` both, because a flag typed by hand takes whichever
// shape the hand felt like.
const readOption = (params, name, fallback) => {
  const index = params.indexOf(`--${name}`);

  if (index !== -1 && params[index + 1] !== undefined) {
    return params[index + 1];
  }

  const inline = params.find((param) => param.startsWith(`--${name}=`));

  return inline ? inline.slice(name.length + 3) : fallback;
};

// Every positional argument is a source, which means the values of the value
// taking flags have to be taken out first: `--fps 12` would otherwise leave a
// `12` behind, and the command would look for a clip named `12`.
const VALUE_FLAGS = ['out', 'fps', 'width', 'duration', 'start', 'max-mb'];

const readInputs = (params) => {
  const consumed = new Set();

  VALUE_FLAGS.forEach((name) => {
    const index = params.indexOf(`--${name}`);

    if (index !== -1) {
      consumed.add(index + 1);
    }
  });

  return params
    .filter((param, index) => !param.startsWith('--') && !consumed.has(index))
    .map((param) => path.resolve(process.cwd(), param));
};

const readNumber = (params, name, fallback) => {
  const value = Number(readOption(params, name, fallback));
  return Number.isFinite(value) && value > 0 ? value : fallback;
};

// -----------------------------------------------------------------------------

const hasFfmpeg = () => {
  if (shell.which('ffmpeg')) {
    return true;
  }

  apngLogger.error('ffmpeg not found');
  apngLogger.log('Install it with: brew install ffmpeg');
  return false;
};

// -----------------------------------------------------------------------------

const sourcesFrom = (inputPath) => {
  if (!fs.statSync(inputPath).isDirectory()) {
    return [inputPath];
  }

  return fs
    .readdirSync(inputPath)
    .filter((name) => SOURCE_EXTENSIONS.includes(path.extname(name).toLowerCase()))
    .sort()
    .map((name) => path.join(inputPath, name));
};

// -----------------------------------------------------------------------------

// `-plays 0` is the APNG loop count, and 0 means forever. Without it ffmpeg
// writes a single pass and the animation freezes on its last frame after one
// play, which reads as a broken image rather than as a still.
//
// ffmpeg's APNG encoder writes every frame whole. apngasm, when it is
// installed, diffs each frame against the one before it and stores only the
// rectangle that moved, which is most of the weight on a gameplay clip whose
// background does not move: 5.60 MB down to 3.54 MB on `steam-4.mp4` at 720p
// and 12 fps, same pixels. So frames go out to PNG first, and ffmpeg's own
// muxer is the fallback rather than the plan.
const encodeWithFfmpeg = (source, target, { fps, width, duration, start }) => {
  const args = [
    ...ffmpegInput(source, { duration, start }),
    '-vf',
    JSON.stringify(`fps=${fps},scale=${width}:-1:flags=lanczos`),
    '-plays',
    '0',
    '-f',
    'apng',
    JSON.stringify(target),
  ];

  return shell.exec(`ffmpeg ${args.join(' ')}`, { silent: true }).code === 0;
};

const ffmpegInput = (source, { duration, start }) => [
  '-y',
  '-hide_banner',
  '-loglevel',
  'error',
  ...(start ? ['-ss', String(start)] : []),
  '-t',
  String(duration),
  '-i',
  JSON.stringify(source),
];

const encodeWithApngasm = (source, target, { fps, width, duration, start }) => {
  const frames = fs.mkdtempSync(path.join(os.tmpdir(), 'fox-apng-'));

  try {
    const extract = [
      ...ffmpegInput(source, { duration, start }),
      '-vf',
      JSON.stringify(`fps=${fps},scale=${width}:-1:flags=lanczos`),
      JSON.stringify(path.join(frames, 'f%05d.png')),
    ];

    if (shell.exec(`ffmpeg ${extract.join(' ')}`, { silent: true }).code !== 0) {
      return false;
    }

    // The frames are listed rather than globbed: apngasm reads its inputs in
    // the order it is given them, and a quoted `f*.png` would reach it
    // unexpanded while an unquoted one would break on the first odd path.
    const written = fs
      .readdirSync(frames)
      .filter((name) => name.endsWith('.png'))
      .sort()
      .map((name) => JSON.stringify(path.join(frames, name)));

    if (written.length === 0) {
      return false;
    }

    // `-l 0` is apngasm's own infinite loop, and `-F` keeps it from prompting
    // before it overwrites a file the caller asked it to write.
    const assemble = ['-F', '-o', JSON.stringify(target), ...written, '-d', String(Math.round(1000 / fps)), '-l', '0'];

    return shell.exec(`apngasm ${assemble.join(' ')}`, { silent: true }).code === 0;
  } finally {
    fs.rmSync(frames, { recursive: true, force: true });
  }
};

const convert = (source, target, settings) =>
  shell.which('apngasm') ? encodeWithApngasm(source, target, settings) : encodeWithFfmpeg(source, target, settings);

// -----------------------------------------------------------------------------

// A lossless recompression pass, when oxipng is on the machine: it rewrites the
// same pixels with better filters and a denser deflate. It is worth about 4% on
// these clips (4.03 MB down to 3.87 MB), which is never what gets a file under a
// budget on its own but is free to take before giving up resolution.
const recompress = (target) => {
  if (!shell.which('oxipng')) {
    return;
  }

  shell.exec(`oxipng -o 4 --strip safe ${JSON.stringify(target)}`, { silent: true });
};

const megabytes = (target) => fs.statSync(target).size / (1024 * 1024);

const encodeOnce = (source, target, settings) => {
  if (!convert(source, target, settings)) {
    return null;
  }

  recompress(target);

  return { weight: megabytes(target), width: settings.width };
};

// -----------------------------------------------------------------------------

// `--max-mb` exists because hosts cap what they accept: itch.io refuses an image
// over 3 MB. Resolution is the knob that gives, and it gives quadratically, so
// the next width is computed from the overshoot rather than stepped blindly:
// one or two passes reach the budget instead of five. The fps is left alone,
// because dropping frames shows on a pan and a narrower image does not.
const MIN_WIDTH = 240;
const ATTEMPTS = 5;

// ⚠️ The weight is NOT monotonic in the width. Lanczos at an awkward ratio
// leaves more high frequency noise than at a clean one, and a lossless codec
// pays for noise: 720px came out at 3.01 MB on `steam-5.mp4` where 697px came
// out at 3.31 MB. So the lightest attempt is remembered rather than the last
// one, and the search never assumes that narrower is lighter.
const fitToBudget = (source, target, settings, budget) => {
  let width = settings.width;
  let best = null;

  for (let attempt = 0; attempt < ATTEMPTS; attempt++) {
    const encoded = encodeOnce(source, target, { ...settings, width });

    if (!encoded) {
      return null;
    }

    const { weight } = encoded;

    if (!best || weight < best.weight) {
      best = { weight, width };
    }

    if (weight <= budget || width <= MIN_WIDTH) {
      return { weight, width };
    }

    // 0.97 rather than the bare ratio: the weight does not scale exactly with
    // the area, and landing just over the budget would cost a whole extra pass.
    const next = Math.max(MIN_WIDTH, Math.floor(width * Math.sqrt(budget / weight) * 0.97));

    if (next >= width) {
      return rewriteBest(source, target, settings, best, width);
    }

    apngLogger.log(`${path.basename(target)} is ${weight.toFixed(2)} MB, retrying at ${next}px`);
    width = next;
  }

  return rewriteBest(source, target, settings, best, width);
};

// The budget was missed, so what stays on disk is the lightest attempt, not
// whichever one the search happened to stop on.
const rewriteBest = (source, target, settings, best, width) => {
  if (!best || best.width === width) {
    return { weight: megabytes(target), width };
  }

  return encodeOnce(source, target, { ...settings, width: best.width }) ?? best;
};

// -----------------------------------------------------------------------------

const generateApng = (params) => {
  const inputs = readInputs(params);

  if (inputs.length === 0) {
    apngLogger.error('Missing source argument');
    apngLogger.log(
      'Usage: fox generate:apng <clip.mp4 …|folder> [--out <folder>] [--fps 15] [--width 720] [--duration 6] [--start 0] [--max-mb 3]',
    );
    return false;
  }

  if (!hasFfmpeg()) {
    return false;
  }

  const missing = inputs.find((input) => !fs.existsSync(input));

  if (missing) {
    apngLogger.error(`Source not found: ${missing}`);
    return false;
  }

  const sources = inputs.flatMap(sourcesFrom);

  if (sources.length === 0) {
    apngLogger.error(`No video file in ${inputs.join(', ')}`);
    apngLogger.log(`Looking for: ${SOURCE_EXTENSIONS.join(', ')}`);
    return false;
  }

  const settings = {
    fps: readNumber(params, 'fps', DEFAULTS.fps),
    width: readNumber(params, 'width', DEFAULTS.width),
    duration: readNumber(params, 'duration', DEFAULTS.duration),
    start: readOption(params, 'start', null),
  };

  // 0 is not a budget, it is the absence of one: `--max-mb` off means the
  // requested width is kept whatever the file weighs.
  const budget = Number(readOption(params, 'max-mb', 0));

  // No `--out`: the animation lands beside the clip it comes from, which is
  // where someone converting one file expects to find it. A shell glob hands
  // over a list of files, and they all share a folder, so the first one names
  // the destination for all of them.
  const [first] = inputs;
  const beside = fs.statSync(first).isDirectory() ? first : path.dirname(first);
  const outputPath = path.resolve(process.cwd(), readOption(params, 'out', beside));

  if (!fs.existsSync(outputPath)) {
    shell.mkdir('-p', outputPath);
    apngLogger.successCompact(`Created ${outputPath}`);
  }

  apngLogger.log('Converting clips to animated PNG');
  apngLogger.data({ output: outputPath, ...settings, ...(budget > 0 ? { maxMB: budget } : {}) });

  apngLogger.step(1, `Encoding ${sources.length} clip${sources.length > 1 ? 's' : ''}`);

  let count = 0;

  for (const source of sources) {
    const name = `${path.basename(source, path.extname(source))}.png`;
    const target = path.join(outputPath, name);

    const encoded = budget > 0 ? fitToBudget(source, target, settings, budget) : encodeOnce(source, target, settings);

    if (!encoded) {
      apngLogger.error(`Aborting: ffmpeg could not encode ${path.basename(source)}`);
      return false;
    }

    const { weight, width } = encoded;
    const resized = width === settings.width ? '' : `, ${width}px`;

    if (budget > 0 && weight > budget) {
      apngLogger.warn(`${name} is ${weight.toFixed(2)} MB, still over the ${budget} MB budget at ${width}px`);
    } else {
      apngLogger.successCompact(`${path.basename(source)} → ${name} (${weight.toFixed(2)} MB${resized})`);
    }

    count++;
  }

  apngLogger.done(`${count} animated PNG${count > 1 ? 's' : ''} generated`);
  return true;
};

// -----------------------------------------------------------------------------

export default generateApng;
