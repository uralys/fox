# 📋 listing builds: is what ships what I exported?

`fox ls` answers one question, store by store: **is the build that ships the one sitting in my export folder?**

Neither half can answer it alone. The store knows a build number and a channel, but nothing about what those bytes contain; the export folder knows a version, but not whether the store ever shipped it. So both sides are read and confronted.

```sh
fox ls          # every store declared under publish
fox ls:steam    # the Steam half only
fox ls:itch     # the itch.io half only
```

Every env declared under `publish.<store>.envs` in `fox.config.json` is listed, so a project shipping a demo next to the game gets both.

## ls:steam — against the Steam Deck

The confrontation is on the **PCK**: the payload itself, identical across platforms unlike the executable.

```txt
●  Fox v1.16.1 ls:steam
├─ Faraday Corridors — project.godot is 0.23.0
●  Local STEAM DEMO — appId 4873710 — export/demo/steam/
│  ┌──────────────────────────────────────────────────────────────────┐
│  │ windows: 0.23.0 DEMO — exported 2026-09-03 19:25 645fd7567aba    │
│  │ linux: 0.23.0 DEMO — exported 2026-09-03 19:25 f33d253d3199      │
│  │ macos: faraday-corridors-demo.zip — archive not read             │
│  │ steam deck: build 25107059 on "staging" — 0.23.0 DEMO f33d253d3199 │
│  └──────────────────────────────────────────────────────────────────┘
├─ ✓  demo: the deck runs the exact export/demo/steam/linux payload (0.23.0)
```

It warns about:

- the depots disagree on the version, or the export is behind `project.godot`
- the branch **requested** differs from the branch **mounted** (Steam needs a restart)
- `buildid` differs from `TargetBuildID` — an update is pending on the Deck
- the Deck PCK is not the local `linux` one, with both short sha256 shown

The Deck is optional: it is a listing, never a gate. An unreachable Deck prints one info line and the local half is reported on its own.

```txt
●  SteamDeck deck@steamdeck.local not connected — local builds only (…)
```

The host defaults to `deck@steamdeck.local` over `ssh` in batch mode. Override it per project:

```json
{
  "ls": {
    "host": "deck@steamdeck.local",
    "timeout": 8
  }
}
```

## ls:itch — against the itch.io page

`butler status --json` gives, for each channel, the build that is live on the page.

```txt
●  Fox v1.16.1 ls:itch
├─ Faraday Corridors — project.godot is 0.23.0
●  Local ITCH.IO DEMO — uralys/faraday-corridors — export/demo/itch/
│  ┌─────────────────────────────────────────────────────────────────────────────┐
│  │ windows-demo: windows/ 0.23.0 DEMO — exported 2026-09-07 12:13 8689bc0714d9 │
│  │   live: build #1955545 — 0.23.0 — pushed 2026-09-07 12:43                   │
│  │ html5-demo: web/ 0.23.0 DEMO — exported 2026-09-07 12:13 a94eb0dd250a       │
│  │   live: build #1955548 — 0.23.0 — pushed 2026-09-07 12:43                   │
│  └─────────────────────────────────────────────────────────────────────────────┘
●  itch ✓  demo: uralys/faraday-corridors is live in 0.23.0 on all 4 channels
```

Here the confrontation is on the **version**, not on a hash: butler stores a build as a diff against its parent and never exposes the bytes it reassembled, so there is no equivalent of the Deck's PCK sha. What it does expose is the `userVersion` `fox publish` stamped on the push — itself read from the payload — so it still says whether the page carries these exact bytes' release.

It warns about:

- the channels disagree on the version, or the export is behind `project.godot`
- a declared channel that has **never been pushed**
- a live build still `processing` or `failed` rather than `completed`
- a channel live in a version other than the one in the local folder

A channel live on the page but no longer declared in `fox.config.json` is named too, as information: an old push leaves one behind, and nothing here removes it.

itch is optional the same way. No `butler`, or a `butler` that cannot reach the API, prints one info line and the local half is reported on its own.

```txt
●  itch uralys/faraday-corridors not read — local builds only (butler not found — …)
```
