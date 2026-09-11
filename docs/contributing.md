# 🛠️ working on Fox itself

> This page is for contributors who develop **Fox** and open pull requests on
> this repository. A game consuming a released Fox never needs any of it:
> installing the CLI is one `npm install -g`, described in
> [the CLI reference](./cli.md#installing-the-executable).

## the checkout

```sh
git clone https://github.com/uralys/fox
cd fox
npm install
```

## running your checkout as the `fox` executable

The published way to install the CLI takes it from a git tag, which is exactly
what you do not want while editing `cli/`. Link the checkout instead, so the
global `fox` runs your working tree:

```sh
npm link          # from the fox checkout
```

`fox link` does it for you as it mounts the addon, see below.

A `fox` sitting earlier in your `PATH` shadows the one npm writes, and every
`fox upgrade` afterwards looks like it did nothing. The hand written symlink
this guide used to recommend (`ln -s .../cli/cli.js /usr/local/bin/fox`) is
exactly that case: remove it, the commands name it when they find it.

On Windows, without npm, a function in your PowerShell profile (`$PROFILE`) does
the same job:

```powershell
function fox { node "C:\Users\chris\Projects\uralys\gamedev\fox\cli\cli.js" @args }
```

## the linked mount: following your checkout from a game

A game normally pins a copy of the runtime under `addons/fox`. To develop Fox
against a real game, mount your checkout there instead: `res://addons/fox`
always reflects the tree you are editing.

Clone this repo next to `your-game`, then:

```sh
cd your-game
fox link ../fox     # or, without the CLI:
ln -s ../../fox/addons/fox addons/fox
```

The `ln -s` target is relative to the `addons` folder holding it, hence the two
`..` levels.

A linked game rides your working tree, so the version its `plugin.cfg` declares
is whatever that checkout happens to hold rather than a released one: the boot
line says `[🦊 Fox] 2.0.0 (symlinked)` to keep a build log honest. It is
deliberately unsuited to shipping. Going back to a released version is
`fox upgrade`, which replaces the link with a real folder: see
[pinning a version](./cli/versioning.md).

### Windows / WSL

On WSL, `ln -s` creates a Linux symlink that Godot (running as a native Windows
app) cannot resolve. You must use a Windows NTFS junction instead:

```sh
cmd.exe /c "mklink /J C:\path\to\your-game\addons\fox C:\path\to\fox\addons\fox"
```

> **Note:** To use [check-projects](https://github.com/uralys/check-projects) on WSL, symlink your `/mnt/c/` repos into your Linux home:
>
> ```sh
> ln -s /mnt/c/Users/chris/Projects/uralys/gamedev/fox ~/Projects/uralys/gamedev/fox
> ln -s /mnt/c/Users/chris/Projects/uralys/gamedev/your-game ~/Projects/uralys/gamedev/your-game
> ```

## lint

The CLI sources under `cli/` are linted and formatted with
[Biome](https://biomejs.dev/), configured in `biome.json` at the root of the
repository. Check the sources without touching them:

```sh
npm run lint
```

Apply the fixes Biome can apply on its own (formatting included):

```sh
npm run lint:fix
```

## language

Everything attached to this repository is written in **English**: code,
comments, commit messages, pull requests, issues and their comments, releases
and docs.
