# 📌 pinning a version: upgrade and link

A game mounts the Fox runtime at `res://addons/fox` in one of two ways, and
these two commands switch between them. Both reimport the project when they are
done: a freshly mounted addon carries no `.import` sidecar, since those are
generated per project and never travel with a release, so Godot could not load
it until the import ran. Pass `--no-import` to skip that step.

```sh
fox upgrade             # pin addons/fox to the latest release
fox upgrade 2.1.0       # or to a given one (the `v` prefix is optional)
fox upgrade --no-import # leave the reimport to you
fox upgrade --no-cli    # leave the `fox` executable alone
fox link                # follow ../fox instead, live
fox link ../../fox      # or a checkout somewhere else
```

The reimport is also skipped, with a warning and without failing the command,
when Godot cannot be resolved: mounting the addon on a machine that only builds
is a legitimate thing to do.

## upgrade

`fox upgrade` **deletes** `addons/fox` before laying the new version down, so a
file dropped between two versions leaves with it. Reinstalling by hand, or
through the Godot Asset Library, only writes over what the new version happens
to contain, and the leftovers pile up.

It refuses to run on a linked mount, because replacing a link with a pinned copy
is rarely what someone typing `upgrade` expects: pass `--yes` to mean it.

## link

`fox link` is the mount to develop Fox itself against a game, and belongs to
[contributing](../contributing.md). It records the link relative to the game when
given a relative path, so it survives being committed and cloned elsewhere, and
absolute when given an absolute one. A linked game rides your working tree, so
the version in `plugin.cfg` is no longer a released one: the boot line says
`[🦊 Fox] 2.0.0 (symlinked)` to keep a build log honest.

## the executable follows the mount

Fox ships through two channels, and pinning only one of them protects a game by
half. The runtime under `addons/fox` is copied into the game and frozen; the
`fox` executable is installed once per machine, so an unpinned CLI reaches every
game at once.

`fox upgrade` therefore installs the CLI of the version it pins, from the same
git tag the addon comes from, and `fox link` runs `npm link` on the checkout.
`--no-cli` skips it, and a failed install is reported without failing the
command.

An addon already on the target version does **not** end the command: the two
halves are checked separately, and a symlinked or outdated executable is pinned
on its own, without downloading or reimporting anything.

```txt
│  ┌───────────────────────────────────────┐
│  │ mount: pinned                         │
│  │ installed: 2.2.0                      │
│  │ cli: 2.2.0 (symlinked, not a release) │
│  │ target: 2.2.0                         │
│  └───────────────────────────────────────┘
└─ addons/fox is already 2.2.0, upgrading the CLI alone
```

⚠️ The executable is **global, one per machine**, while a mount is per project:
the last command run owns it. Two projects on different versions cannot each
keep their own `fox`, so the header warns when the running CLI and the mounted
addon disagree:

```txt
🦊 addons/fox 1.9.0
● fox ls
├─ ⚠  this CLI is v2.0.2: run `fox upgrade` to match the addon
```

A `fox` earlier in your `PATH` than the one npm writes would shadow it, and the
upgrade would look like it did nothing: the hand written symlink the install
guide used to recommend is exactly that case, and `fox upgrade` names it when it
finds it.

## the mount line every command opens on

Every command opens on the mount it is about to work with. The version on that
line is the one the GAME runs; the CLI's own is a `fox --version` away, and
printing both put the same number twice whenever they agreed.

```txt
🦊 addons/fox 2.0.2
● fox ls
```

Only a linked mount is spelled out, with the word the game prints at boot: a
pinned copy is the normal case, while a linked one follows a checkout rather
than a release, so the version beside it is whatever that tree holds.

```txt
🦊 addons/fox 2.0.2 (symlinked)
● fox ls
```

A game still on the flat mount predates `plugin.cfg`, so there is no version to
read and saying so is the useful part. A project with no mount at all gets no
line at all: the error that follows already names what is missing.

```txt
🦊 fox (legacy mount)
● fox ls
```

## the release notice

Nothing in a healthy command says a newer Fox is out, so every command ends by
comparing the mounted version with the latest release, and prints one box when
the game is behind:

```txt
┌─────────────────────────────────────────────────────────────────────────────┐
│ addons/fox is 1.9.0, and 2.0.2 is out                                       │
│                                                                             │
│ run `fox upgrade` to pin it, or `fox upgrade --no-import` to reimport later │
└─────────────────────────────────────────────────────────────────────────────┘
```

The answer is **cached**, once for the machine, in `.fox/latest-release.json`
inside your home directory: GitHub is asked at most once every six hours, so
the commands in between touch nothing but the disk. That cache is shared by
every game on the machine, and `fox upgrade` refreshes it as it runs.

`fox` alone and `fox --help` are the exception: they print the command table and
nothing else, so they skip the cache and ask GitHub on the spot, then print the
box under the table. Those two get five seconds instead of two, since there is
no command output waiting behind them.

The check never delays a command and never fails one: it gives GitHub two
seconds, and a call that does not answer is cached as an attempt, so a machine
offline for an afternoon does not pay that timeout on every command. A failed
check keeps reporting the last release it knew about.

It stays quiet in every case but a pinned mount strictly behind a release: a
linked mount follows your checkout and is supposed to differ from any release.
Set `FOX_NO_UPGRADE_CHECK=1` to silence it altogether: a CI job pins its version
on purpose and has no use for a line telling it to move.
