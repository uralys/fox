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

## A release title is a version and a date

**The title of a GitHub release carries the version and its publication date,
nothing else:** `1.19.1 (September 10, 2026)`. No `v` prefix, the month spelled
out in US English, the same shape React uses for its own releases.

The short editorial label that used to sit in the title now opens the notes as
their first heading:

```markdown
# Desktop export presets

Desktop presets stop rewriting the folder `fox publish` uploads...
```

**Why:** the releases page then reads as a chronology, answering which version
shipped when at a glance, while the summary of the work stays visible the moment
the notes are opened. Every release published before 2026-09-10 was migrated to
this format, so the list is homogeneous.

## Every release ends with a `## changelog` section

**A release describes what it brings, then lists what was merged to bring it.**
The narrative sections come first, the changelog closes the notes, and it is
never optional.

What the section holds, and nothing more:

- **the merged pull requests**, one linked line each, as
  `- [#13 improved versioning](https://github.com/uralys/fox/pull/13)`. A
  release that incorporates pull requests **must** list every one of them: a
  reader looking for the review that carried a change should not have to walk
  the git log to find it;
- when no pull request was merged and the work landed straight on `main`, one
  line saying so;
- the issues the release closes, linked;
- a `**Full changelog:**` line pointing at the GitHub compare view.

⛔ **Commits are never listed.** A changelog that transcribes the git log is
noise: the compare link already holds every commit, in full, for whoever needs
that level of detail.

The compare view runs from the **previous release**, never from the previous
tag. Fox carries four times more tags than releases, and anything landed
between two releases would otherwise appear in no changelog at all.

Gathering the list:

```sh
GH_TOKEN=$GH_URALYS_TOKEN gh pr list --repo uralys/fox --state merged \
  --json number,title,mergeCommit --jq '.[] | [.number, .mergeCommit.oid, .title] | @tsv'
```

A pull request belongs to the first release that contains its merge commit,
which is an **ancestry** question, not a date one: `git merge-base --is-ancestor
<mergeCommit> <tag>`. Fox has already shipped a pull request merged months
before the release that first carried it, because a maintenance line kept
running beside `main`.

**Why:** the notes explain the intent, the changelog gives the provenance. Six
months later, the only way back to the discussion behind a change is the pull
request number, and a release that hides it makes its own history unreadable.

## Godot and Blender binaries

Both resolved by `fox` itself, see the folder-wide
[CLAUDE.md](/Users/chris/Projects/uralys/gamedev/CLAUDE.md).

## Verification runs stay headless

No game window may appear or steal the focus while Chris is working. Probe the
**state** through a `--script` harness, never the pixels. `fox run:game` and
`fox run:editor` are reserved for his explicit request.
