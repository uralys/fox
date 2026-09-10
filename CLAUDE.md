# Fox

The `fox` CLI drives the Godot projects of this folder. Conventions shared by
every project of `gamedev/` live in
[../CLAUDE.md](/Users/chris/Projects/uralys/gamedev/CLAUDE.md); this file only
carries what is specific to the `fox` repository itself.

## ⛔ CRITICAL RULE: everything on this repo is written in English

**Every artefact attached to this repository is written in English. No French,
anywhere, ever.** This is not limited to source code: it covers everything a
reader may open from GitHub.

Concerned, without exception:

- source code: names, comments, log strings, error messages;
- commit messages, subject **and** body;
- pull request titles, descriptions and comments;
- issue titles, bodies and **comments**, including delivery reports;
- release titles and release notes;
- documentation under `docs/`, `readme.md`, and this file;
- any report, checklist or note committed to the repo.

**Why:** `fox` is a public repository of the uralys organisation, read by people
who do not speak French. A French comment on an issue makes the delivery
unreadable to them, and it stands out against the English history around it.

**How to apply:** before posting anything to GitHub (`gh issue comment`,
`gh pr create`, `gh release create`) or writing a commit message, check that the
body is in English. A conversation held in French with Chris does **not** make
the artefact French: the language of the discussion and the language of the repo
are two different things.

The only French that remains legitimate is the conversation with Chris in the
terminal.

## Godot and Blender binaries

Both resolved by `fox` itself, see the folder-wide
[CLAUDE.md](/Users/chris/Projects/uralys/gamedev/CLAUDE.md).

## Verification runs stay headless

No game window may appear or steal the focus while Chris is working. Probe the
**state** through a `--script` harness, never the pixels. `fox run:game` and
`fox run:editor` are reserved for his explicit request.
