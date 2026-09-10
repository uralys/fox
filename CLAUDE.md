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

## Every release ends with a `## changelog` section

**A release describes what it brings, then lists what was merged to bring it.**
The narrative sections come first, the changelog closes the notes, and it is
never optional.

What the section holds, in this order:

- **the merged pull requests**, one line each, number and title, as
  `- #13 improved versioning`. A release that incorporates pull requests
  **must** list every one of them: a reader looking for the review that carried
  a change should not have to walk the git log to find it;
- when no pull request was merged and the work landed straight on `main`, say
  so in one line and list the commits instead;
- the issues the release closes, linked;
- a `**Full changelog:**` line pointing at the GitHub compare view between the
  previous tag and this one.

Gathering the list:

```sh
git log --format='%h %s' <previous tag>..<this tag>
GH_TOKEN=$GH_URALYS_TOKEN gh pr list --repo uralys/fox --state merged \
  --json number,title,mergedAt --jq '.[] | "\(.number) | \(.mergedAt) | \(.title)"'
```

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
