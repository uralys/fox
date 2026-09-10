# Leaderboard

`Leaderboard` is an autoload (`fox/core/leaderboard.gd`): the single transport
between a game and the Uralys leaderboard service at
`https://leaderboard.uralys.com`. It submits a value on a board, reads a top-N,
reads a rank, and reads a top-N restricted to a list of Steam friends.

It holds no visuals: the in-game ladder, panels and strips stay in the game. It
holds no local mirror either, apart from the offline queue described below.

Register it in your project's `[autoload]` section. A game may point the autoload
straight at the fox script, or extend it by path to override a hook:

```ini
[autoload]

Leaderboard="*res://fox/core/leaderboard.gd"
```

```gdscript
# src/core/leaderboard.gd: extend the fox base to override a hook
extends 'res://fox/core/leaderboard.gd'

func _is_valid_board(board: String) -> bool:
    return not board.begins_with('mine-')
```

- [`configure(options)`](#configureoptions): name the game, seed the identity
- [`submit(board, value, metadata)`](#submitboard-value-metadata--):
  queued, offline-first
- [`top(board, n, onComplete, onError)`](#topboard-n-oncomplete-onerror):
  public read
- [`rank(board, value, onComplete, onError)`](#rankboard-value-oncomplete-onerror):
  public read
- [`friends_top(...)`](#friends_topboard-steam_ids-n-oncomplete-onerror):
  signed read, Steam friends only
- [`claim_name(...)`](#claim_namename-profile_uid---oncomplete-onerror):
  display name, and the `name_claimed` signal
- [`is_read_only()`](#is_read_only): whether this build can post at all
- [`_is_valid_board(board)`](#_is_valid_boardboard): the game's override point
- [The offline queue](#the-offline-queue): ndjson, replayed at boot, backoff
- [The signing secret](#the-signing-secret): where it comes from, and only from
- [The epim signature](#the-epim-signature): the scheme both ends reproduce

## `configure(options)`

Called once at boot, after the player state is loaded. It names the game, seeds
the player identity, and replays whatever the previous session could not deliver.

```gdscript
func _ready():
    Leaderboard.configure({
        gameId = 'my-game',
        identity = {deviceId = Player.state.deviceId},
        identityProvider = func(): return Player.leaderboard_identity(),
    })
```

| key | required | meaning |
| --- | --- | --- |
| `gameId` | **yes** | the game's id in the service registry |
| `host` | no | overrides the service host, public one by default |
| `identity` | no | Dictionary merged into the player identity |
| `identityProvider` | no | `Callable` queried at call time for an identity |

`gameId` is **mandatory and has no default**: a board belongs to one game, and
guessing an owner would post a score on someone else's ladder. Until `configure()`
names it, every call below is a no-op that says so in the logs, and `configure()`
raises a warning of its own when the key is missing.

The identity fields the service understands are `steamId`, `steamName`, `itchId`,
`itchName`, `deviceId`, `deviceName`, `playerName` and `profileUid`. Pass what the
platform gives you: the service resolves the player from the first identifier it
finds. `identityProvider` exists for an identifier that only becomes available
after boot, a Steam id for instance: it is queried at submit time and wins over
the static `identity`.

`set_identity(identity)` merges more fields later on, updating only the keys
passed.

## `submit(board, value, metadata = {})`

Records `value` on `board` for the current player. `value` is coerced to `int`:
the board metric is an integer, a time in milliseconds or a number of points.

```gdscript
Leaderboard.submit('chapter-1-level-3', time_ms, {deaths = deaths})
```

The call is **offline-first**: the request is written to a durable queue before
any network attempt, so a crash, a quit or a dead network never loses a score.
See [the offline queue](#the-offline-queue).

Three guards drop a submission on the floor, each with one log line and no error:

- the game was never configured, so there is no `gameId`,
- [`_is_valid_board(board)`](#_is_valid_boardboard) refused the key,
- the build carries no signing secret, so its boards are read-only.

The metadata is stamped with the build the run came from (`env`, `target`,
`platform`) before being queued, so a board can be read analytically without ever
being split in two: one level keeps one ladder whatever build produced the time.
The stamp is frozen with the rest of the payload, so a submission replayed months
later still names the build that actually played the run.

## `top(board, n, onComplete, onError)`

Best-effort read of the first `n` entries, unsigned public GET. `onComplete`
receives the entries `Array`, each entry carrying `rank`, `playerId`,
`playerName`, `value` and `updatedAt`. `onError` receives `(result, code, body)`.

```gdscript
Leaderboard.top('chapter-1-level-3', 10,
    func(entries): _render_ladder(entries),
    func(_result, _code, _body): _render_local_times())
```

Reads never queue and never retry: a missed read is a panel the player can open
again, so failing soft into a local display is the whole contract.

## `rank(board, value, onComplete, onError)`

Best-effort read of where `value` would land on `board`, unsigned public GET.
`onComplete` receives the parsed Dictionary (`rank`, `total`, `value`, `gameId`,
`boardKey`); `onError` receives `(result, code, body)`.

```gdscript
Leaderboard.rank('chapter-1-level-3', time_ms,
    func(result): _show_rank(result.rank, result.total))
```

## `friends_top(board, steam_ids, n, onComplete, onError)`

Best-effort top-N restricted to a list of Steam friends. `onComplete` receives
the entries `Array`, ranked **within the friend subset**: rank 1 is the best
friend on that board, not the world leader.

```gdscript
Leaderboard.friends_top('chapter-1-level-3', Steam.get_friend_ids(), 10,
    func(entries): _render_friends(entries))
```

It is a signed POST rather than a GET, because the friend list travels in the
body and a GET could not carry it. It is a **read** all the same: it stays out of
the offline queue, and a build with no signing secret skips it through `onError`
rather than queueing anything.

An empty `steam_ids` calls `onComplete` with an empty Array without touching the
network.

## `claim_name(name, profile_uid = '', onComplete, onError)`

Claims, or renames to, the display name of a profile, and propagates it to every
score that profile already holds.

```gdscript
Leaderboard.claim_name(typed_name, Player.state.profileUid,
    func(granted): Player.set_player_name(granted))
```

The answer is **authoritative**: names are unique per game, so a taken name comes
back suffixed (`Nyx` asked, `Nyx#2` granted). Persist the granted name, never the
text the player typed.

`profile_uid` names the profile being renamed, which is not always the one being
played: a claim for the current player may leave it out, and the identity's
`profileUid` is used instead.

The intent is persisted before the call and replayed at the next boot until the
server answers, so a rename lost to a dead network cannot leave the local name
and the online name disagreeing forever. Re-claiming a name one already holds is
idempotent, so a replay never climbs a suffix.

### `name_claimed(profile_uid, granted)`

Emitted whenever the server **grants** a name, including from a claim replayed at
boot, whose original caller is long gone. It is the only way the game learns the
name it actually holds online, so the player state should listen to the signal
rather than to the per-call callback:

```gdscript
func _ready():
    Leaderboard.name_claimed.connect(_on_name_claimed)

func _on_name_claimed(profile_uid: String, granted: String):
    Player.rename_profile(profile_uid, granted)
```

## `is_read_only()`

`true` when this build holds no signing secret: its boards can be read but never
written, and `submit()` drops every score. It is the deliberate posture of a web
build, and an accident anywhere else.

```gdscript
if Leaderboard.is_read_only():
    _show_notice('Scores are not recorded in this build.')
```

Expose it in the UI rather than letting a run be swallowed in silence: without
it, the only trace is a warning nobody reads while playing.

## `_is_valid_board(board)`

Virtual hook, returns `true` by default: the base posts every board key it is
handed. Override it in a game where some content deserves no shared ladder,
player-authored levels or downloaded ones for instance, so their keys never reach
the network.

```gdscript
# src/core/leaderboard.gd
extends 'res://fox/core/leaderboard.gd'

# Only shipped campaign levels have a comparable board: a level the player
# authored or downloaded is keyed 'mine-<slug>' / 'ugc-<id>' and stays local.
func _is_valid_board(board: String) -> bool:
    return not (board.begins_with('mine-') or board.begins_with('ugc-'))
```

The refusal is silent by design: one log line, no error, no callback. An override
that stops recognising a key therefore mutes a score instead of crashing a run.

## The offline queue

`submit()` writes its payload to `user://leaderboard-queue.ndjson` **before** any
network call, one JSON object per line, then fires the request. The file is read
back at boot, so a score earned offline, or during a crash, is sent at the next
launch.

How it drains:

- one submission in flight at a time, head of the queue first,
- an entry is removed only once the server confirms it,
- on failure, a capped exponential backoff retries it (5 s doubling up to 5 min),
  and a periodic timer drains the backlog every minute,
- verdicts no retry can change (`400`, `404`, `409`, `413`, `422`) drop the
  entry, because a head that can never succeed would hold every score behind it
  hostage. `403` is deliberately excluded: a build carrying a stale secret keeps
  its scores until a fixed build drains them,
- past 2000 entries the oldest are dropped, ring-buffer style.

Name claims are persisted separately in
`user://leaderboard-name-claims.json`, one entry per profile: a second rename
replaces the pending one, since only the last name asked for matters.

In the `debug` env nothing is ever posted: a score is logged instead of queued,
and a name is granted locally as typed. Reads still hit the service, so local
development exercises the real boards without polluting them.

## The signing secret

Writes are signed with a per-game key read from the `ProjectSettings` key
`custom/leaderboard-secret`, and from nowhere else. It is not a `configure()`
option, and a game must never hold it in its source.

> ⚠️ Only ever write the **name** of the key, never a value. The per-env values
> live in a gitignored `secret.<env>.cfg`, merged into `override.cfg` by
> `fox switch` and baked into the exported build by `fox export`: see
> [Exporting](../exporting/export.md). Nothing about it is committed, and a
> **web** build is exported without it on purpose, since the pck of an HTML5
> build is downloaded by every visitor and readable with a text editor. A build
> without the key ships read-only boards, which is exactly what
> [`is_read_only()`](#is_read_only) reports.

Nothing derived from the key is ever logged, not even a digest of it. The logs
say `<set>` or `<none>` and stop there. The key is symmetric, so any stable
fingerprint of it would let someone holding the log confirm a guessed key
offline, without ever calling the service; printing its length would narrow that
search further. When a build is answered `403`, the build is identified by the
`env`, `target` and `platform` stamp every submission carries, and by the game
and host on the same log line.

## The epim signature

Every write, a queued score, a friends read and a name claim, carries an `epim`
field the service verifies. The scheme:

```txt
salt = sha256(secret)
epim = sha256(salt + '%' + json(payload with its TOP-LEVEL keys sorted))
```

Only the top-level keys are sorted. Nested objects keep their insertion order, so
the metadata a game passes is serialised identically on both ends.

Two details of the GDScript side are what make the hash reproducible, and each
one alone is enough to be answered `403` forever:

- keys are rebuilt as `String`, because a Dictionary literal written
  `{gameId = ...}` creates `StringName` keys whose sort compares pointers rather
  than text,
- integral floats are folded back to `int`, because JSON parsing turns every
  number into a float and a replayed submission would otherwise sign `1385.0`
  where the service hashes `1385`.

Both are handled inside the autoload: a game has nothing to do about them.
