# ▶️ running your game

```sh
fox run:editor   # open Godot Editor on your main scene
fox run:game     # run the game, watching your files
```

## hot reload

`fox run:game` watches your project files (`.gd`, `.tscn`, `.cfg`, `.json`, `.yml`) and hot reloads the current scene when a change is detected.

Instead of killing and restarting the Godot process, it writes a `.hot-reload` trigger file. The `HotReload` autoload inside Godot detects this file and calls `Router.reloadCurrentScene()`, which re-instantiates the current scene without closing the window.

### setup

Add `HotReload` to your project's `[autoload]` section in `project.godot`:

```ini
[autoload]

HotReload="*res://addons/fox/autoloads/hot-reload.gd"
```

Add `.hot-reload` and `.nav-state` to your `.gitignore`.

### ignoring folders

`.worktrees/` and `.godot/` are always ignored. To skip additional folders (tooling, generated data, sub-projects), list them in `run:game.ignored` of your `fox.config.json`:

```json
{
  "run:game": {
    "ignored": ["solutions"]
  }
}
```

### limitations

In standalone mode, GDScript files are compiled on load. Hot reload works well for data changes (JSON, resources) and `.tscn` scenes. For `.gd` script changes, the scene is re-instantiated but scripts in memory may not update — use `r` for a full restart in that case.

## navigation state (NavState)

The Router persists a typed `NavState` (`addons/fox/core/nav-state.gd`) to `.nav-state` (JSON). It stores the current scene path and a `path` array representing nested sub-view segments — similar to outlets in Ember.js or React Router.

On hot reload or full restart (`r`), the app restores the last visited scene and navigates to the exact sub-view.

**NavState JSON example:**

```json
{"scene_path":"res://src/screens/storybook.tscn","path":["Focal Blur"]}
```

**Router API:**

- `Router.getNavPath() -> Array` — read the current path segments
- `Router.setNavPath(path: Array)` — update and persist the path
- `Router.restoreOrDefault(defaultAction: Callable)` — restore nav state on startup, or call default

**Scene pattern — each scene reads/writes its own path segments:**

```gdscript
func onOpen(options = {}):
    var navPath = Router.getNavPath()
    if not navPath.is_empty():
        selectedEntry = navPath[0]        # restore from navPath
    else:
        selectedEntry = __.GetOr('default', 'entry', options)  # normal nav
    Router.setNavPath([selectedEntry])

func _onSubViewSelected(name: String):
    Router.setNavPath([selectedEntry, name])  # nested sub-view
```

**Startup (main.gd) — use `restoreOrDefault` in debug mode:**

```gdscript
func run():
    Router.restoreOrDefault(func(): Router.openHome())
```

## shortcuts

- `r` — full restart (kills and relaunches Godot, useful when hot reload is not enough)
- `ctrl + c` — stop the game
