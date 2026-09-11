# ------------------------------------------------------------------------------

extends Node

# ==============================================================================
# Leaderboard — fox autoload talking to the Uralys leaderboard service
# (https://leaderboard.uralys.com). THE single transport for every board of a
# game: submit a value, read the top-N, read a rank, and read a top-N restricted
# to a list of Steam friends. Nothing is mirrored anywhere else: the in-game
# visuals live per-game, NOT here.
#
# Extended by path (like sound.gd / player-base.gd, NO class_name): a game
# declares an autoload named `Leaderboard` pointing at
# `res://addons/fox/core/leaderboard.gd`, or at its own script extending that path when
# it needs to override a hook.
#
# Reads come in two shapes: the public GETs (top / rank) and the signed POST
# read (friends_top), which carries a friend list in its body and is therefore
# authenticated exactly like a submission: same epim signature, no queue.
#
# Offline-first: submit() writes the request to a durable user:// queue (ndjson)
# BEFORE any network call, so a crash / quit / offline moment never loses a
# score. The queue is replayed at boot and drained with a capped exponential
# backoff. The local display NEVER depends on this autoload: reads are
# best-effort and fail soft through onError.
#
# Configuration: call configure({...}) once at boot to set the gameId (MANDATORY,
# there is no default) and the player identity. Every network call is a logged
# no-op until a gameId is known, so a game that forgets to configure the autoload
# reports it in its logs instead of posting scores on a board nobody owns.
#
# The signing secret is read from the ProjectSettings key
# `custom/leaderboard-secret` and from nowhere else: it is injected at export
# time and never committed, never passed through configure(), and never logged:
# not the key, not its length, not a digest of it, see _secret_fingerprint. A
# build without it ships READ-ONLY boards, see is_read_only().
#
# Hooks (virtual — override per game):
#
#   _is_valid_board(board) -> bool
#     Whether a board key designates content this game wants a ladder for.
#     Returns true by default, so the base submits every board it is given. A
#     game with player-authored or downloaded content overrides it to keep those
#     keys off the network: they have no comparable board. The guard fails
#     SILENTLY (one G.log, no error), so a stricter implementation never turns a
#     key it does not recognise into a crash.
#
# epim signature (the payload signing scheme the service expects, else
# POST /scores answers 403):
#
#   salt = sha256(secret)
#   hash = sha256(salt + '%' + JSON.stringify(bodyWithTopLevelKeysSorted))
#
# Only the TOP-LEVEL keys are sorted; nested objects keep insertion order. We
# reproduce this with a manual top-level key sort + JSON.stringify(sort_keys =
# false) so nested metadata is serialised identically on both ends. `value` is
# coerced to int (the board metric is an integer: time_ms / points) so GDScript
# and the server format the number identically.
# ==============================================================================

# Emitted when the server GRANTS a name to a profile — including from a claim
# replayed at boot, which the caller that asked for the rename is no longer
# around to hear. It is the only way the game learns the name it actually holds
# online (`Nyx` asked, `Nyx#2` granted), so the player state listens to it rather
# than to the per-call callback.
signal name_claimed(profile_uid: String, granted: String)

# ProjectSetting holding the per-game epim secret, and the ONLY source of it.
# NEVER hardcode a secret value here or anywhere in a game's source: the setting
# is injected at export time (`fox export` bakes it) and stays out of the repo.
const SECRET_SETTING: String = 'custom/leaderboard-secret'

const QUEUE_PATH: String = 'user://leaderboard-queue.ndjson'

# Pending name claims, one per profile uid. A claim is NOT a score, so it never
# enters the NDJSON score queue — but it cannot be fire-and-forget either: a
# rename that never reached the server leaves the local name and the online name
# saying two different things, silently and forever. So the intent is persisted
# here and replayed at the next boot until the server answers.
const NAME_CLAIMS_PATH: String = 'user://leaderboard-name-claims.json'

# Every environment reads the PRODUCTION leaderboard: reading a local server is
# pointless. Debug never POSTs: scores are logged instead of queued/sent (see
# submit()), so local dev exercises the real board reads without polluting it.
const HOST_RELEASE: String = 'https://leaderboard.uralys.com'

const REQUEST_TIMEOUT: float = 15.0
const MAX_QUEUE: int = 2000        # ring-buffer cap (drop oldest past this)
const FLUSH_INTERVAL: float = 60.0 # periodic backlog drain
const BACKOFF_BASE: float = 5.0    # first retry delay after a failure
const BACKOFF_MAX: float = 300.0   # capped exponential backoff ceiling

# HTTP verdicts a retry can never turn into a success — the entry is dropped
# instead of blocking the head of the queue (see _on_submit_completed). 403 is
# deliberately ABSENT: a build carrying a stale signing secret must keep its
# scores until a fixed build drains them.
const PERMANENT_FAILURES: Array[int] = [400, 404, 409, 413, 422]

# Same idea for a NAME CLAIM, minus 404 — and that omission is the whole point.
# On a score, 404 means "this board does not exist" and never will. On
# /players/name it means "this server does not know that route yet", i.e. the
# deploy has not happened: the most TEMPORARY verdict there is, and dropping the
# claim on it loses exactly the rename the deploy was meant to carry.
const CLAIM_PERMANENT_FAILURES: Array[int] = [400, 409, 413, 422]

# ------------------------------------------------------------------------------

# gameId in the service registry — drives the per-game signing secret. There is
# NO default: a board is owned by one game, and guessing an owner would post a
# score on someone else's ladder. It stays empty until configure() names it, and
# every network call is a logged no-op until then.
var _game_id: String = ''
var _secret: String = ''
var _host_override: String = ''

# Player identity frozen into each queued submission (steamId > itchId > deviceId
# cascade resolved server-side). Games update it via set_identity() / configure().
# A Callable provider, when set, is queried at submit time for a fresh identity
# (e.g. a Steam id that becomes available after boot).
var _identity: Dictionary = {}
var _identity_provider: Callable = Callable()

# Durable submission queue held in memory (Array of {qid, body}); each entry is
# also a line in QUEUE_PATH so it survives a crash. Sent one at a time.
var _queue: Array = []
var _dropped: int = 0
var _qseq: int = 0

var _submit_http: HTTPRequest = null
var _in_flight: bool = false
var _inflight_qid: String = ''
var _backoff: float = 0.0

var _flush_timer: Timer = null
var _retry_timer: Timer = null

# ------------------------------------------------------------------------------
# Boot — an autoload _ready() sets up the transport and replays the queue. The
# gameId / identity are not known yet here (the game calls configure() right
# after), so the first real drain happens from configure(); the periodic flush
# timer is the safety net either way.
# ------------------------------------------------------------------------------

func _ready() -> void:
  _secret = str(ProjectSettings.get_setting(SECRET_SETTING, ''))
  _load_queue()

  _submit_http = HTTPRequest.new()
  _submit_http.timeout = REQUEST_TIMEOUT
  _submit_http.use_threads = true
  _submit_http.request_completed.connect(_on_submit_completed)
  add_child(_submit_http)

  _flush_timer = Timer.new()
  _flush_timer.wait_time = FLUSH_INTERVAL
  _flush_timer.autostart = true
  _flush_timer.timeout.connect(flush)
  _flush_timer.timeout.connect(flush_name_claims)
  add_child(_flush_timer)

  _retry_timer = Timer.new()
  _retry_timer.one_shot = true
  _retry_timer.timeout.connect(flush)
  add_child(_retry_timer)

  G.log('[leaderboard] ready, pending', _queue.size())

  # Let the freshly added HTTPRequest finish its own _ready() before requesting.
  await get_tree().process_frame
  flush()

# ------------------------------------------------------------------------------
# Configuration — called once at boot by the game (after the player state is
# loaded). Names the game, optionally overrides the host, and seeds the player
# identity. Triggers a replay.
#
#   Leaderboard.configure({
#     gameId = 'my-game',
#     identity = {deviceId = Player.state.deviceId},
#     identityProvider = func(): return Player.leaderboard_identity(),
#   })
#
# `gameId` is MANDATORY: without it every call below is a logged no-op. `host` is
# optional and defaults to HOST_RELEASE. The signing secret is NOT an option: it
# comes from the SECRET_SETTING ProjectSetting alone.
# ------------------------------------------------------------------------------

func configure(options: Dictionary = {}) -> void:
  if options.has('gameId'):
    _game_id = str(options['gameId'])
  if options.has('host'):
    _host_override = str(options['host'])
  if options.has('identity') and options['identity'] is Dictionary:
    set_identity(options['identity'])
  if options.has('identityProvider') and options['identityProvider'] is Callable:
    _identity_provider = options['identityProvider']

  G.log('[leaderboard] configured, game', _game_id, 'host', _host(),
    'secret', _secret_fingerprint())

  if _game_id.is_empty():
    push_warning('[leaderboard] NO gameId: every leaderboard call is a no-op. '
      + 'Pass `gameId` to configure() at boot.')

  # An export that forgot to inject the signing secret ships READ-ONLY boards
  # (reads work, no score is ever posted), and a STALE one gets 403 permission
  # denied. The missing case is caught here, loudly. The stale one is not
  # distinguishable from a log line, deliberately: telling two keys apart would
  # take a fingerprint of the key, and a symmetric key has no fingerprint that is
  # safe to print (see _secret_fingerprint). Match the `env`/`target` stamp a
  # submission carries against the key that export baked instead. Read-only is
  # DELIBERATE on the web target (see submit()) and a bug anywhere else, which is
  # why this stays a warning rather than a log.
  if _secret.is_empty():
    push_warning('[leaderboard] NO SIGNING SECRET: boards are READ-ONLY, no score '
      + 'is posted. Expected on the web target; elsewhere export with `fox export` '
      + '(it bakes the secret into the ProjectSetting).')
  flush()
  flush_name_claims()

# Whether this build can only READ the boards: it holds no signing secret, so
# submit() drops every score on the floor (see the guard there). Reads keep
# working — the ladder the player browses is unaffected.
#
# The state is invisible otherwise: the only signal is a push_warning nobody
# reads while playing. Exposing it is what lets the UI say so instead of
# silently swallowing a run.
#
# It answers on the SECRET alone, deliberately. The debug env does not post
# either, but that is a dev posture with its own log line, and surfacing it would
# paint the notice over every development session; a missing secret in a shipped
# build is the accident this is here to make visible.
func is_read_only() -> bool:
  return _secret.is_empty()

# Merge/refresh the player identity fields (steamId, steamName, itchId, itchName,
# deviceId, deviceName, playerName). Only the keys passed are updated.
func set_identity(identity: Dictionary) -> void:
  for key in identity:
    _identity[key] = identity[key]

# ------------------------------------------------------------------------------
# Hooks — virtual, overridden by the game.
# ------------------------------------------------------------------------------

# Whether `board` designates content worth a shared ladder. True by default: the
# base posts every board key it is handed. Override it to keep player-authored or
# downloaded content off the network (see the banner).
func _is_valid_board(_board: String) -> bool:
  return true

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------

# Submit a value on a board. OFFLINE-FIRST: the request is written to the durable
# queue BEFORE any network attempt, then a signed POST /scores is fired. On
# failure the entry stays queued and is retried with capped exponential backoff.
# The identity is frozen at call time (the player who earned the score).
func submit(board: String, value, metadata: Dictionary = {}) -> void:
  if not _is_configured():
    return

  if not _is_valid_board(board):
    G.log('[leaderboard] board refused by _is_valid_board, score NOT submitted:', board)
    return

  # NO SIGNING SECRET = READ-ONLY BOARDS, and that is a shipped posture, not an
  # accident: a web build's pck is downloadable in clear, so any secret baked in
  # it is public, and the secret is keyed by gameId — a web-only key would mean a
  # web-only gameId, i.e. a second ladder for the same level, which the boards
  # refuse by design. So the web build ships without one and keeps the unsigned
  # GET reads (top / rank), which is the whole leaderboard the player looks at.
  # Dropping here rather than queueing: flush() would hold these forever anyway,
  # and a ring buffer of scores that can never be sent is just disk churn.
  if _secret.is_empty():
    G.log('[leaderboard] no secret configured, read-only boards, score NOT queued:', board)
    return

  var body: Dictionary = {
    gameId = _game_id,
    boardKey = board,
    value = int(value),
  }
  var identity := _resolve_identity()
  for key in identity:
    body[key] = identity[key]
  body['metadata'] = _stamped_metadata(metadata)

  # Debug never posts: log the score that WOULD be submitted and stop here — no
  # durable queue, no network. Reads still hit production (see _host()).
  if G.ENV == G.DEBUG:
    G.log('[leaderboard] debug: score NOT posted, logged instead:', body)
    return

  _qseq += 1
  var qid := str(Time.get_unix_time_from_system()) + '-' + str(_qseq)
  _enqueue({qid = qid, body = body})
  flush()

# Stamps the BUILD a run came from onto its metadata, so the board can be read
# analytically (`metadata->>'env' = 'demo'`) without ever being split in two.
#
# The board is deliberately COMMON to every build of a game: a time on a level is
# the same time whoever produced it, and two ladders for one level would make
# every rank a lie. `env` is what lets a demo player be counted against a
# full-game player afterwards, and nothing else changes.
#
# It is stamped HERE rather than at the call site so no future caller can forget
# it, and it is frozen with the rest of the body: a submission replayed from the
# queue months later still names the build that actually played the run. The
# caller's own keys keep their insertion order — only a trailing key is added,
# which the epim canonicalisation preserves.
#
# `platform` is what makes a browser run RECOGNISABLE after the fact, and it is
# the one field the other two cannot stand in for: a web run and a downloadable
# demo can share `env=demo` AND the same target. A web build's pck is public, so
# whatever key signs it is public too; the board keeps those scores rather than
# refusing them, and this stamp is what would let them be masked in bulk should
# an abuse ever show up (`metadata->>'platform' = 'Web'`). Read from the baked
# `bundle/platform` rather than from `OS.has_feature('web')`: the same field
# names every other platform too, so the board stays readable by build.
func _stamped_metadata(metadata: Dictionary) -> Dictionary:
  var stamped := metadata.duplicate(true)
  stamped['env'] = str(G.ENV)
  stamped['target'] = str(G.TARGET)
  stamped['platform'] = str(G.PLATFORM)
  return stamped

# Best-effort top-N read (public GET). onComplete receives the entries Array
# ([{rank, playerId, playerName, value, updatedAt}, ...]); onError receives
# (result, code, body) so the caller can fall back to a local display.
func top(board: String, n: int, onComplete: Callable, onError := Callable()) -> void:
  if not _is_configured():
    _fail_soft(onError)
    return
  var url := _host() + '/leaderboard/' + _game_id.uri_encode() + '/' + board.uri_encode() + '?n=' + str(n)
  _fetch(url, func(parsed): onComplete.call(parsed.get('entries', [])), onError)

# Best-effort rank read (public GET). onComplete receives the parsed result
# Dictionary ({rank, total, value, gameId, boardKey}); onError receives
# (result, code, body).
func rank(board: String, value, onComplete: Callable, onError := Callable()) -> void:
  if not _is_configured():
    _fail_soft(onError)
    return
  var url := _host() + '/rank/' + _game_id.uri_encode() + '/' + board.uri_encode() + '/' + str(int(value))
  _fetch(url, func(parsed): onComplete.call(parsed), onError)

# Best-effort top-N read RESTRICTED to a list of Steam friends (signed POST, the
# server needs the friend list in a body — a GET could not carry it). onComplete
# receives the entries Array, ranked WITHIN the friend subset (rank 1 is the best
# friend on this board, not the world leader); onError receives (result, code,
# body).
#
# This is a READ: it is deliberately kept OUT of the durable NDJSON queue. A
# missed friend board is a blank panel the player can retry, never a lost score,
# so there is nothing to replay at the next boot. Only submit() is queued.
#
# G.ENV == G.DEBUG does NOT short-circuit here: the debug guard covers the POST
# of a SCORE (submit / flush), and reads always hit production, exactly like
# top() and rank().
func friends_top(
  board: String,
  steam_ids: Array,
  n: int,
  onComplete: Callable,
  onError := Callable()
) -> void:
  if steam_ids.is_empty():
    onComplete.call([])
    return
  if not _is_configured():
    _fail_soft(onError)
    return
  if _secret.is_empty():
    G.log('[leaderboard] no secret configured, friends read skipped')
    _fail_soft(onError)
    return

  var url := _host() + '/leaderboard/' + _game_id.uri_encode() + '/' \
    + board.uri_encode() + '/friends'
  var body: Dictionary = {
    gameId = _game_id,
    boardKey = board,
    steamIds = steam_ids,
    n = int(n),
  }
  _post_signed(url, body, func(parsed): onComplete.call(parsed.get('entries', [])), onError)

# Claim (or rename to) the display name of the ACTIVE profile, and propagate it
# to every score that profile already holds.
#
# The answer is authoritative: names are unique for the whole game, so a taken
# name comes back SUFFIXED (`Nyx` → `Nyx#2`). onComplete receives that granted
# name — persist it, never the text the player typed.
#
# The intent is persisted before the call and replayed at the next boot until the
# server answers: a rename lost to a dead network would otherwise leave the local
# name and the online name disagreeing with nothing to notice it. Re-claiming a
# name one already holds is idempotent server-side, so a replay never climbs a
# suffix.
func claim_name(
  name: String,
  profile_uid: String = '',
  onComplete := Callable(),
  onError := Callable()
) -> void:
  var clean := name.strip_edges()
  if clean.is_empty():
    return
  if not _is_configured():
    return

  # A rename can target a slot that is NOT the one being played, so the caller
  # names the profile; only a claim for the current player leaves it out.
  var uid := profile_uid if not profile_uid.is_empty() \
    else str(_resolve_identity().get('profileUid', ''))
  if uid.is_empty():
    G.log('[leaderboard] no profile uid, name NOT claimed:', clean)
    return

  # Debug never posts (same rule as a score): the local name is granted as typed.
  if G.ENV == G.DEBUG:
    G.log('[leaderboard] debug: name NOT claimed, logged instead:', clean)
    if onComplete.is_valid():
      onComplete.call(clean)
    return

  _remember_claim(uid, clean)
  _send_claim(uid, clean, onComplete, onError)

# ------------------------------------------------------------------------------
# Name claims — a tiny persisted map {profileUid: requestedName}, drained at boot
# and after every configure(). Unlike the score queue it holds ONE entry per
# profile: a second rename simply replaces the pending one, since only the last
# name asked for matters.
# ------------------------------------------------------------------------------

func _send_claim(
  profile_uid: String,
  name: String,
  onComplete := Callable(),
  onError := Callable()
) -> void:
  if _secret.is_empty():
    G.log('[leaderboard] no secret configured, name claim held:', name)
    _fail_soft(onError)
    return

  var identity := _resolve_identity()
  # A claim without a platform identifier is answered 400 — and 400 DESTROYS the
  # intent, so a claim fired before configure() gave us the identity provider
  # would silently lose the rename. It is held instead, and the flush that
  # follows configure() sends it for real.
  if not _has_platform_identity(identity):
    G.log('[leaderboard] no identity yet, name claim held:', name)
    _fail_soft(onError)
    return

  var body: Dictionary = {gameId = _game_id}
  for key in identity:
    body[key] = identity[key]
  # The claim targets the profile the intent was recorded FOR, which a replay at
  # boot may well not be the active one, and carries the name being asked for,
  # which a rename makes differ from the name that profile still holds locally.
  body['profileUid'] = profile_uid
  body['playerName'] = name
  # The BUILD this player is on. The registry keeps it twice — once as the build
  # they arrived through, once as the one they are on now — which is what makes
  # "how many demo players" a question about people rather than about runs: a
  # profile that never finished a level has no score row at all.
  body['env'] = str(G.ENV)

  var on_ok := func(parsed):
    var granted := str(parsed.get('name', name))
    _forget_claim(profile_uid)
    name_claimed.emit(profile_uid, granted)
    G.log('[leaderboard] name granted', granted,
      'scores renamed', parsed.get('updatedScores', 0),
      'adopted', parsed.get('adoptedScores', 0))
    if onComplete.is_valid():
      onComplete.call(granted)

  var on_ko := func(result, code, response):
    G.log('[leaderboard] name claim failed for', name, 'result', result,
      'code', code, _parse_response(response))
    # A verdict no retry can change (a name the server refuses outright) must not
    # be replayed at every boot forever. A 404 is NOT one of them here: it says
    # the route is not deployed yet, and the claim must survive to be replayed
    # once it is — see CLAIM_PERMANENT_FAILURES.
    if code in CLAIM_PERMANENT_FAILURES:
      _forget_claim(profile_uid)
    if onError.is_valid():
      onError.call(result, code, response)

  _post_signed(_host() + '/players/name', body, on_ok, on_ko)

# Replay the claims a previous session could not deliver. Silent: the player is
# not waiting on it, the local name is already the one they asked for.
func flush_name_claims() -> void:
  if G.ENV == G.DEBUG or _secret.is_empty() or _game_id.is_empty():
    return
  var claims := _load_claims()
  for profile_uid in claims.keys():
    _send_claim(str(profile_uid), str(claims[profile_uid]))

func _has_platform_identity(identity: Dictionary) -> bool:
  for key in ['steamId', 'itchId', 'deviceId']:
    if not str(identity.get(key, '')).is_empty():
      return true
  return false

func _remember_claim(profile_uid: String, name: String) -> void:
  var claims := _load_claims()
  claims[profile_uid] = name
  _write_claims(claims)

func _forget_claim(profile_uid: String) -> void:
  var claims := _load_claims()
  if not claims.has(profile_uid):
    return
  claims.erase(profile_uid)
  _write_claims(claims)

func _load_claims() -> Dictionary:
  if not FileAccess.file_exists(NAME_CLAIMS_PATH):
    return {}
  var file := FileAccess.open(NAME_CLAIMS_PATH, FileAccess.READ)
  if file == null:
    return {}
  var content := file.get_as_text()
  file.close()
  var json := JSON.new()
  if json.parse(content) == OK and json.data is Dictionary:
    return json.data
  return {}

func _write_claims(claims: Dictionary) -> void:
  var file := FileAccess.open(NAME_CLAIMS_PATH, FileAccess.WRITE)
  if file == null:
    return
  file.store_string(JSON.stringify(claims, '', false))
  file.close()

# ------------------------------------------------------------------------------
# Submit queue draining — one entry in flight at a time; purge on success, capped
# backoff on failure. Safe to call from any trigger (submit, boot, timer, retry).
# ------------------------------------------------------------------------------

func flush() -> void:
  # Debug never posts (scores are logged at submit time); a leftover queue from
  # a prior non-debug run stays put rather than draining to production.
  if G.ENV == G.DEBUG:
    return
  if _submit_http == null or _in_flight or _queue.is_empty():
    return
  if _game_id.is_empty():
    G.log('[leaderboard] no gameId configured, holding', _queue.size(), 'submission(s)')
    return
  if _secret.is_empty():
    G.log('[leaderboard] no secret configured, holding', _queue.size(), 'submission(s)')
    return

  var entry: Dictionary = _queue[0]
  var body: Dictionary = entry.get('body', {})
  var signed := _signed_body(body)

  var err := _submit_http.request(
    _host() + '/scores',
    ['Content-Type: application/json'],
    HTTPClient.METHOD_POST,
    JSON.stringify(signed, '', false)
  )
  if err != OK:
    G.log('[leaderboard] request start failed', err)
    _schedule_retry()
    return
  _in_flight = true
  _inflight_qid = str(entry.get('qid', ''))

func _on_submit_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
  _in_flight = false

  if result != OK or code < 200 or code >= 300:
    G.log('[leaderboard] submit failed result', result, 'code', code,
      _parse_response(body))
    # A verdict the server will never change (malformed body, board that does not
    # exist) must DROP the entry: the queue is drained head-first, so one such
    # submission holds every score behind it hostage forever. A score queued by an
    # older build for a board that was since removed answers 404 board not found,
    # and that alone once froze a hundred real runs on a handheld. Everything
    # else — network failure, 403 (a build may yet ship the right secret), 429,
    # 5xx — stays queued and retried.
    if code in PERMANENT_FAILURES:
      G.log('[leaderboard] permanent failure, dropping submission', _inflight_qid)
      _purge(_inflight_qid)
      _inflight_qid = ''
      _backoff = 0.0
      if not _queue.is_empty():
        call_deferred('flush')
      return
    _schedule_retry()
    return

  var parsed := _parse_response(body)
  if not bool(parsed.get('ok', false)):
    G.log('[leaderboard] server not ok', parsed)
    _schedule_retry()
    return

  _purge(_inflight_qid)
  _inflight_qid = ''
  _backoff = 0.0

  # Drain the rest of the backlog right away.
  if not _queue.is_empty():
    call_deferred('flush')

func _schedule_retry() -> void:
  _backoff = BACKOFF_BASE if _backoff <= 0.0 else min(_backoff * 2.0, BACKOFF_MAX)
  _retry_timer.start(_backoff)
  G.log('[leaderboard] retry in', _backoff, 's, pending', _queue.size())

# ------------------------------------------------------------------------------
# epim signing — sort ONLY the top-level keys, serialise with sort_keys = false
# (nested order preserved), then hash. The returned body carries the epim field
# for POSTing.
# ------------------------------------------------------------------------------

func _signed_body(body: Dictionary) -> Dictionary:
  var ordered := _sort_top_level(_canonical(body))
  var canonical := JSON.stringify(ordered, '', false)
  var salt := _secret.sha256_text()
  ordered['epim'] = (salt + '%' + canonical).sha256_text()
  return ordered

# Says only WHETHER this build holds a signing key, never anything derived from
# it. The key is symmetric, so ANY deterministic digest of it printed in a log
# is an offline verification oracle: a candidate is confirmed by hashing it and
# comparing, with no request to the service and no rate limit in the way. A
# length is the same oracle, pre-pruned. Telling two builds apart is already
# answered by the env, target and platform stamp _stamped_metadata carries, and
# by the game and host printed on this very log line, so nothing is lost here.
func _secret_fingerprint() -> String:
  return '<none>' if _secret.is_empty() else '<set>'

func _sort_top_level(body: Dictionary) -> Dictionary:
  var keys := body.keys()
  keys.sort()
  var ordered := {}
  for key in keys:
    ordered[key] = body[key]
  return ordered

# Puts a payload in the ONE shape both ends can hash identically. Two GDScript
# details made the signature unreproducible server-side, and each one alone was
# enough to answer 403 permission denied forever:
#
#   1. a Dictionary literal written `{gameId = ...}` builds STRINGNAME keys, and
#      `<` on a StringName compares internal POINTERS — so `keys.sort()` returned
#      an arbitrary order and a FRESH submission signed an unsorted canonical.
#   2. `JSON.parse_string()` turns every number into a float, so a submission
#      REPLAYED from the durable queue signed `"value":1385.0` while the server
#      hashed the same body as `"value":1385`.
#
# Folding integral floats back to int is not a lossy shortcut: JavaScript prints
# 1385.0 as `1385` too, so this IS the server's own reading of the number.
#
# Nested key ORDER is deliberately untouched (the server re-serialises nested
# objects in wire order); only the top level is sorted, by _sort_top_level.
func _canonical(value: Variant) -> Variant:
  if value is Dictionary:
    var ordered := {}
    for key in value:
      ordered[String(key)] = _canonical(value[key])
    return ordered
  if value is Array:
    var items := []
    for item in value:
      items.append(_canonical(item))
    return items
  if value is float and is_finite(value) and value == floor(value) \
    and absf(value) < 9007199254740992.0:
    return int(value)
  return value

# ------------------------------------------------------------------------------
# Identity
# ------------------------------------------------------------------------------

func _resolve_identity() -> Dictionary:
  if _identity_provider.is_valid():
    var provided = _identity_provider.call()
    if provided is Dictionary:
      return provided
  return _identity

# ------------------------------------------------------------------------------
# Read helper — ephemeral HTTPRequest freed on completion (reads may overlap).
# ------------------------------------------------------------------------------

func _fetch(url: String, onComplete: Callable, onError: Callable) -> void:
  var http := HTTPRequest.new()
  http.timeout = REQUEST_TIMEOUT
  http.use_threads = true
  add_child(http)

  var handler := func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
    http.queue_free()
    if result != OK or code < 200 or code >= 300:
      G.log('[leaderboard] read failed', url, 'result', result, 'code', code)
      if onError.is_valid():
        onError.call(result, code, body)
      return
    var parsed := _parse_response(body)
    if not bool(parsed.get('ok', false)):
      G.log('[leaderboard] read not ok', url, parsed)
      if onError.is_valid():
        onError.call(result, code, body)
      return
    onComplete.call(parsed)

  http.request_completed.connect(handler)
  var err := http.request(url, ['Content-Type: application/json'], HTTPClient.METHOD_GET)
  if err != OK:
    G.log('[leaderboard] read request start failed', url, err)
    http.queue_free()
    if onError.is_valid():
      onError.call(err, 0, PackedByteArray())

# Signed POST — same ephemeral-HTTPRequest lifecycle as _fetch, but the payload
# goes through _signed_body so the server accepts it (an unsigned request is
# answered 403). Carries the friends read AND the name claim; the SCORE queue has
# its own long-lived request, because only a score is replayed forever.
func _post_signed(url: String, body: Dictionary, onComplete: Callable, onError: Callable) -> void:
  var http := HTTPRequest.new()
  http.timeout = REQUEST_TIMEOUT
  http.use_threads = true
  add_child(http)

  var handler := func(result: int, code: int, _headers: PackedStringArray, response: PackedByteArray):
    http.queue_free()
    if result != OK or code < 200 or code >= 300:
      G.log('[leaderboard] signed read failed', url, 'result', result, 'code', code)
      if onError.is_valid():
        onError.call(result, code, response)
      return
    var parsed := _parse_response(response)
    if not bool(parsed.get('ok', false)):
      G.log('[leaderboard] signed read not ok', url, parsed)
      if onError.is_valid():
        onError.call(result, code, response)
      return
    onComplete.call(parsed)

  http.request_completed.connect(handler)
  var err := http.request(
    url,
    ['Content-Type: application/json'],
    HTTPClient.METHOD_POST,
    JSON.stringify(_signed_body(body), '', false)
  )
  if err != OK:
    G.log('[leaderboard] signed read request start failed', url, err)
    http.queue_free()
    if onError.is_valid():
      onError.call(err, 0, PackedByteArray())

func _parse_response(body: PackedByteArray) -> Dictionary:
  var json := JSON.new()
  if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary:
    return json.data
  return {}

# ------------------------------------------------------------------------------
# Queue persistence — append-only NDJSON, full rewrite only on purge / overflow.
# ------------------------------------------------------------------------------

func _enqueue(entry: Dictionary) -> void:
  _queue.append(entry)
  if _queue.size() > MAX_QUEUE:
    var overflow: int = _queue.size() - MAX_QUEUE
    _queue = _queue.slice(overflow)
    _dropped += overflow
    G.log('[leaderboard] queue cap', MAX_QUEUE, 'reached, dropped oldest',
      overflow, 'total dropped', _dropped)
    _rewrite_queue()
  else:
    _append_line(entry)

func _append_line(entry: Dictionary) -> void:
  var file := FileAccess.open(QUEUE_PATH, FileAccess.READ_WRITE) \
    if FileAccess.file_exists(QUEUE_PATH) \
    else FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
  if file == null:
    return
  file.seek_end()
  file.store_line(JSON.stringify(entry, '', false))
  file.close()

func _rewrite_queue() -> void:
  var file := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
  if file == null:
    return
  for entry in _queue:
    file.store_line(JSON.stringify(entry, '', false))
  file.close()

func _load_queue() -> void:
  _queue = []
  if not FileAccess.file_exists(QUEUE_PATH):
    return
  var file := FileAccess.open(QUEUE_PATH, FileAccess.READ)
  if file == null:
    return
  while not file.eof_reached():
    var line := file.get_line()
    if line.strip_edges().is_empty():
      continue
    var json := JSON.new()
    if json.parse(line) == OK and json.data is Dictionary:
      _queue.append(json.data)
  file.close()

func _purge(qid: String) -> void:
  if qid.is_empty():
    return
  var kept: Array = []
  for entry in _queue:
    if str(entry.get('qid', '')) == qid:
      continue
    kept.append(entry)
  _queue = kept
  _rewrite_queue()

# ------------------------------------------------------------------------------

# Every network call goes through this guard: without a gameId there is no board
# to talk to, so the call becomes a logged no-op rather than a request the server
# would reject anyway.
func _is_configured() -> bool:
  if _game_id.is_empty():
    G.log('[leaderboard] no gameId configured, call ignored: '
      + 'pass `gameId` to Leaderboard.configure() at boot')
    return false
  return true

# Best-effort reads fail soft: the caller falls back to a local display.
func _fail_soft(onError: Callable) -> void:
  if onError.is_valid():
    onError.call(FAILED, 0, PackedByteArray())

func _host() -> String:
  if not _host_override.is_empty():
    return _host_override
  return HOST_RELEASE
