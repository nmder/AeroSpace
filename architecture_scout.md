# Code Context

## Files Retrieved
1. `Package.swift` (lines 1-80) - package/products/targets/dependencies.
2. `Sources/AeroSpaceApp/AeroSpaceApp.swift` (lines 1-21) - SwiftUI app entry point calls AppBundle bootstrap.
3. `Sources/AppBundle/initAppBundle.swift` (lines 1-112) - app startup sequence, server args, initial config/refresh/server/observers.
4. `Sources/AppBundle/config/Config.swift` (lines 1-75) - global `config`, `defaultConfig`, core config shape.
5. `Sources/AppBundle/config/parseConfig.swift` (lines 1-220) - TOML read/parse pipeline and root config parser map.
6. `Sources/AppBundle/config/ConfigFile.swift` (lines 1-29) - custom config discovery order.
7. `Sources/AppBundle/config/ConfigFileWatcher.swift` (lines 1-40) - auto-reload file watcher and debounce.
8. `Sources/Cli/_main.swift` (lines 1-160) - CLI client parses args, connects to app server, special-cases subscribe.
9. `Sources/AppBundle/server.swift` (lines 1-113) - Unix socket server parses requests and wraps command execution in sessions.
10. `Sources/Common/cmdArgs/parseCmdArgs.swift` (lines 1-94) - command args protocol/parser metadata.
11. `Sources/Common/cmdArgs/cmdArgsManifest.swift` (lines 1-140) - `CmdKind` registry and subcommand parser mapping.
12. `Sources/AppBundle/command/Command.swift` (lines 1-35) - command protocol and convenience runner.
13. `Sources/AppBundle/command/parseCommand.swift` (lines 1-25) - shell string/list command parsing bridge.
14. `Sources/AppBundle/command/cmdManifest.swift` (lines 1-112) - maps parsed `CmdArgs` to concrete `Command` implementations.
15. `Sources/AppBundle/shell/Shell.swift` (lines 1-160) - shell AST/execution, command entry points, post-command refresh.
16. `Sources/AppBundle/layout/refresh.swift` (lines 1-206) - heavy/light refresh sessions, model refresh, layout scheduling.
17. `Sources/AppBundle/layout/layoutRecursive.swift` (lines 1-160) - recursive layout algorithm for workspaces/containers/windows.
18. `Sources/AppBundle/tree/TreeNode.swift` (lines 1-158) - base tree node, parent/children/MRU/binding/weights.
19. `Sources/AppBundle/tree/Window.swift` (lines 1-75) - abstract window node and AX operations interface.
20. `Sources/AppBundle/tree/Workspace.swift` (lines 1-198) - workspace registry, monitor visibility assignment, GC.
21. `Sources/AppBundle/tree/MacWindow.swift` (lines 1-260) - concrete window registration, binding, GC, AX forwarding.
22. `Sources/AppBundle/tree/MacApp.swift` (lines 1-240) - per-app AX thread/subscriptions/window AX access/focus/frame APIs.
23. `Sources/AppBundle/GlobalObserver.swift` (lines 1-75) - NSWorkspace/global mouse observers triggering refresh sessions.
24. `Sources/AppBundle/util/accessibility.swift` (lines 1-220) - Accessibility permission loop and AX attribute wrappers.
25. `Sources/AppBundle/util/AxSubscription.swift` (lines 1-59) - AXObserver subscription lifecycle.
26. `Sources/AppBundleTests/testUtil.swift` (lines 1-92) - test workspace reset and command helpers.
27. `Sources/AppBundleTests/tree/TestWindow.swift` (lines 1-44) - test window stub overriding AX methods.
28. `generate.sh` (lines 1-61) - generated version/hash/CLI description/Xcode project pipeline.
29. `Sources/Common/cmdHelpGenerated.swift` (lines 1-120) - generated command help from docs.

## Key Code
- Startup entry: `AeroSpaceApp.init()` calls `initAppBundle()` (`Sources/AeroSpaceApp/AeroSpaceApp.swift:6-13`).
- Bootstrap order (`Sources/AppBundle/initAppBundle.swift:5-32`): init termination/server args, wait for Accessibility permission, bootstrap default config, reload user config, apply workspace-monitor assignments, start socket server, init global observers, create/focus initial workspace, run complete refresh, smart startup layout, run `after-startup-command`.
- Config globals: `defaultConfigUrl`, `defaultConfig`, mutable `@MainActor var config`, `Config` fields (`Sources/AppBundle/config/Config.swift:6-75`). Config discovery checks `--config-path`, then `~/.aerospace.toml`, then `$XDG_CONFIG_HOME/aerospace/aerospace.toml` (`ConfigFile.swift:1-29`).
- Command path: CLI/App config strings -> `parseCmdArgs`/`parseCommand` -> `CmdArgs.toCommand()` -> concrete `Command.run()` -> `Shell.run()`. `Shell.run()` resets closed-window cache when needed and calls `refreshModel_nonCancellable()` after each command (`Shell.swift:93-118`).
- Server path: CLI sends `ClientRequest`; `server.swift` handles protocol handshake, parse, `RunSessionGuard`, then `runLightSession(.socketServer(...))` around command execution (`server.swift:31-113`).
- Tree model: `TreeNode` owns children, weak parent, MRU stack, layout rects, adaptive weights and bind/unbind (`TreeNode.swift:4-158`). `Workspace` is a root-like node with global name registry and monitor visibility maps (`Workspace.swift:4-140`). `Window` is abstract; `MacWindow` implements AX-backed operations via `MacApp`.
- Refresh/layout lifecycle: heavy session updates native focus, refreshes model, discovers/gc apps/windows, GC monitors, normalizes layout reason, and lays out workspaces (`refresh.swift:23-56`). Light sessions wrap commands/events, refresh before/after body, layout, sync focus to macOS, then schedule a heavy refresh (`refresh.swift:58-89`). `layoutRecursive` applies tiles/accordion geometry and uses `setAxFrame` for real windows (`layoutRecursive.swift:1-160`).
- AX integration: app waits for AX permission (`accessibility.swift:1-23`). Each `MacApp` gets a dedicated `Thread`/CFRunLoop, creates `AXUIElementCreateApplication`, subscribes to window created/focused notifications, and uses `ThreadGuardedValue` plus `RunLoopJob` for AX calls (`MacApp.swift:47-103`). `AxSubscription` owns `AXObserver` notifications and unregisters in deinit (`AxSubscription.swift:4-59`).
- Tests: `AppBundleTests` mirrors command/config/shell/tree areas. Tests use `TestApp`/`TestWindow` stubs instead of real AX and reset global workspace/config state in `setUpWorkspacesForTests()`.
- Generated code: `generate.sh` writes `versionGenerated.swift`, `gitHashGenerated.swift`, `Cli/subcommandDescriptionsGenerated.swift`; `script/generate-cmd-help.sh` writes `Common/cmdHelpGenerated.swift` from `docs/aerospace-*.adoc`.

## Architecture
AeroSpace is split into SwiftPM targets: `Common` (shared command args/models/protocol types), `AppBundle` (window manager app logic), `AeroSpaceApp` (SwiftUI app wrapper), `Cli` (Unix-socket client), `PrivateApi` (C bridge for private AX/window APIs), and `AppBundleTests`.

Runtime flow: SwiftUI app initializes `AppBundle`; `AppBundle` waits for Accessibility, loads config, starts the Unix socket server and observers, builds the workspace/window model from AX, then manages layout. External `aerospace` CLI invocations are lightweight clients: they parse enough to validate, connect to the app server, and send raw args/stdin/env-derived window/workspace context. The app server is authoritative for actual command execution.

The model is a mutable `@MainActor` tree. Workspaces contain a root tiling container, floating container, and unconventional macOS state containers. Windows are tree leaves. `MacApp` owns AX state per running app and `MacWindow` bridges tree windows to AX operations. Refresh sessions reconcile native AX state into this tree, normalize it, and run layout. Commands mutate this model and are always followed by model refresh/layout through `Shell.run()` and/or `runLightSession()`.

Event sources are: socket commands, config hotkeys/callbacks, AX notifications, NSWorkspace notifications, global mouse events, config file watcher. Most enter either `runLightSession` (interactive/command work) or `scheduleCancellableCompleteRefreshSession`/`runHeavyCompleteRefreshSession` (eventual full reconciliation).

## Start Here
Start with `Sources/AppBundle/initAppBundle.swift`: it shows the whole startup/config/server/observer/initial-refresh sequence and points to the major subsystems that documentation should explain next.

## Supervisor coordination
No supervisor decision needed. Progress file update was attempted but blocked because `/Users/<username>/.pi/...` is outside the permitted working directory for this tool session.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Created a documentation scout report only, at architecture_scout.md, covering the requested startup/config, command, tree/workspace/window, refresh/layout, macOS Accessibility, tests, and generated-code areas."
    }
  ],
  "changedFiles": [
    "architecture_scout.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "ls .",
      "result": "passed",
      "summary": "Listed repository root."
    },
    {
      "command": "find/grep/read targeted source files",
      "result": "passed",
      "summary": "Inspected source, tests, generated-code scripts, and key architecture files."
    },
    {
      "command": "nl -ba selected files | sed -n ...",
      "result": "passed",
      "summary": "Collected exact line references for key files."
    },
    {
      "command": "git status --short",
      "result": "passed",
      "summary": "No output before writing report; working tree had no pre-existing short-status entries."
    }
  ],
  "validationOutput": [
    "architecture_scout.md written successfully."
  ],
  "residualRisks": [
    "Progress file update was blocked by tool filesystem restrictions outside the working directory."
  ],
  "noStagedFiles": true,
  "diffSummary": "Added architecture_scout.md with concise repository architecture notes.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "No tests were run because this was a documentation scouting task."
}
```
