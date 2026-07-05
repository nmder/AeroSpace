# Code Context

## Files Retrieved
1. `Sources/Common/cmdArgs/ArgParser.swift` (lines 1-82) - generic parser building blocks, common positional/flag helpers, enum parsing.
2. `Sources/Common/cmdArgs/cmdArgsManifest.swift` (lines 1-137) - `CmdKind` list and subcommand-to-args-parser registration.
3. `Sources/Common/cmdArgs/parseCmdArgs.swift` (lines 1-75) - `CmdArgs`, `CmdParser`, static help/info, common state (`--window-id`, `--workspace`, stdin flag).
4. `Sources/Common/cmdArgs/parseSpecificCmdArgs.swift` (lines 1-69) - core flag/positional parsing loop, `-h/--help`, duplicates, conflicts, mandatory pos args.
5. `Sources/Common/cmdArgs/SubArgParser.swift` (lines 1-34) - reusable flag parser helpers (`windowIdSubArgParser`, `workspaceSubArgParser`, bool/single-value flags).
6. `Sources/Common/cmdArgs/subcommandParsers.swift` (lines 1-18) - parser type erasure and `SubCommandParser` wrappers.
7. `Sources/AppBundle/command/Command.swift` (lines 1-34) - server-side command protocol and execution wrapper.
8. `Sources/AppBundle/command/parseCommand.swift` (lines 1-35) - shell lex/parse integration, `exec-and-forget` special case, args-to-command bridge.
9. `Sources/AppBundle/command/cmdManifest.swift` (lines 1-111) - `CmdArgs.toCommand()` mapping from parsed args to concrete command implementations.
10. `Sources/Common/cmdArgs/impl/FocusMonitorCmdArgs.swift` (lines 1-60) - representative command args definition with flags, positional parser, post-parse validation.
11. `Sources/AppBundle/command/impl/FocusMonitorCommand.swift` (lines 1-62) - representative command execution implementation.
12. `Sources/AppBundle/config/Config.swift` (lines 1-77) - config model, defaults, global config state, config version.
13. `Sources/AppBundle/config/parseConfig.swift` (lines 1-220) - config reader, diagnostics, parser registry, command parsing inside config callbacks/bindings.
14. `Sources/AppBundle/config/Mode.swift` (lines 1-34) - mode and binding table parsing entry point.
15. `Sources/Common/cmdHelpGenerated.swift` (lines 1-80) - generated command help constants consumed by `CmdParser.info.help`.
16. `script/generate-cmd-help.sh` (lines 1-31) - extracts `tag::synopsis` blocks from docs into generated Swift help constants.
17. `generate.sh` (lines 1-66) - top-level generation: command help, CLI subcommand descriptions, version/git hash, xcodeproj.
18. `dev-docs/architecture.md` (lines 1-68) - high-level client/server flow and command checklist.
19. `Sources/AppBundleTests/command/FocusMonitorCommandTest.swift` (lines 1-29) - representative parse tests.
20. `Sources/AppBundleTests/command/ConfigCommandTest.swift` (lines 1-200) - config command parse/execution tests.
21. `Sources/AppBundleTests/config/ConfigTest.swift` (lines 1-220) - config parser tests for defaults, errors, modes, TOML types.

## Key Code

- Command args are shared in `Sources/Common/cmdArgs` so both CLI client and server can parse the same syntax. `CmdArgs` requires `static var parser: CmdParser<Self>` and `commonState`; `CmdParser` stores `kind`, generated help, flags, positional args, and conflict sets (`Sources/Common/cmdArgs/parseCmdArgs.swift:10-75`).
- `parseSpecificCmdArgs` is the core parser: handles `-h/--help`, unknown/duplicate flags, `--` positional-only mode, mandatory positional placeholders, and conflicts (`Sources/Common/cmdArgs/parseSpecificCmdArgs.swift:1-42`). Negative resize units are specially exempted from dash-flag handling (`lines 65-69`).
- Add/rework common flags through `SubArgParser.swift`: `windowIdSubArgParser<T>()`, `workspaceSubArgParser<T>()`, `trueBoolFlag`, `falseBoolFlag`, `boolFlag`, `singleValueSubArgParser` (`Sources/Common/cmdArgs/SubArgParser.swift:1-34`).
- Every subcommand must be present in `CmdKind` and `initSubcommands()` (`Sources/Common/cmdArgs/cmdArgsManifest.swift:1-137`), then mapped to a concrete server command in `CmdArgs.toCommand()` (`Sources/AppBundle/command/cmdManifest.swift:1-111`).
- Server command implementations conform to `Command`, carry typed `args`, implement `run(_:_:)`, and decide `shouldResetClosedWindowsCache` (`Sources/AppBundle/command/Command.swift:3-14`).
- String commands go through `parseCommand(raw, allowExecAndForget, allowEval)`: shell lex/parse first, then `parseCmdArgs(...).flatMap { $0.toCommand() }`; `exec-and-forget` is special-cased before shell parsing when allowed (`Sources/AppBundle/command/parseCommand.swift:3-26`).
- Config parser uses a top-level `configParser: [String: any ParserProtocol<Config>]` registry. Adding config fields usually means adding a property in `Config`, a parser function, and an entry in this registry (`Sources/AppBundle/config/Config.swift:25-63`, `Sources/AppBundle/config/parseConfig.swift:93-137`).
- Config callbacks/bindings parse command strings via `parseShellOfCommandsForConfig`, which accepts a string or array of strings and calls `parseCommand(... allowExecAndForget: true, allowEval: false)` (`Sources/AppBundle/config/parseConfig.swift:164-184`). Nested eval is intentionally rejected.
- Modes parse TOML tables under `mode`, then `binding`; missing `main` mode is an error (`Sources/AppBundle/config/Mode.swift:9-34`). Binding parser is in `HotkeyBinding.swift` (not deeply read here), and tests cover command strings in bindings.
- Help text is not authored in Swift. `Sources/Common/cmdHelpGenerated.swift` is generated from `docs/aerospace-*.adoc` synopsis blocks by `script/generate-cmd-help.sh`; run `./generate.sh` or `./script/generate-cmd-help.sh` after docs synopsis changes.

## Architecture

CLI/server flow from `dev-docs/architecture.md`: the `aerospace` CLI parses args, reports parse/help locally, sends args to the app server, the server parses again, runs a `Command`, then returns stdout/stderr/exit code.

Command data flow:
1. Docs `docs/aerospace-<cmd>.adoc` synopsis -> `script/generate-cmd-help.sh` -> `Sources/Common/cmdHelpGenerated.swift`.
2. Args struct in `Sources/Common/cmdArgs/impl/*CmdArgs.swift` declares `CmdParser(kind:help:flags:posArgs:conflictingOptions:)`.
3. `CmdKind` + `initSubcommands()` in `cmdArgsManifest.swift` make the subcommand parseable.
4. `parseCmdArgs`/`parseSpecificCmdArgs` produce typed `CmdArgs` or help/failure.
5. `Sources/AppBundle/command/cmdManifest.swift` casts typed args to concrete `Sources/AppBundle/command/impl/*Command.swift`.
6. `Command.run` executes against `CmdEnv`/`CmdIo`; tests typically call `parseCommand("...")` then inspect args or run `.cmdOrDie.run(...)`.

Config data flow:
1. `readConfig` finds/reads TOML and calls `parseConfig` (`parseConfig.swift:20-42`).
2. TOML is converted to `OrderedJson`; registry parsers mutate a default `Config` copy while collecting `ConfigParseDiagnostic` errors/warnings.
3. Command-valued config options and hotkey bindings reuse command parsing, so command syntax changes can break config parse tests.
4. `ConfigCommand` exposes runtime config via a built config map; its behavior is tested in `ConfigCommandTest.swift`.

Generated docs/help constraints:
- Swift help constants are derived only from `tag::synopsis` blocks, not full docs option prose.
- New/renamed commands need docs file, generated help constant name alignment (`-` -> `_`), `docs/commands.adoc`, shell completion grammar (`grammar/commands-bnf-grammar.txt` per checklist), and probably CLI subcommand descriptions from `generate.sh`.

Tests likely to touch:
- Command parser/execution tests: `Sources/AppBundleTests/command/*CommandTest.swift`.
- Config parsing: `Sources/AppBundleTests/config/ConfigTest.swift`.
- Config command introspection: `Sources/AppBundleTests/command/ConfigCommandTest.swift`.
- Test helper assertions are in `Sources/AppBundleTests/assert.swift` and setup utilities in `Sources/AppBundleTests/testUtil.swift` (located but not read).

## Modification Guidance

For a new command:
1. Add args type in `Sources/Common/cmdArgs/impl/<Name>CmdArgs.swift` with `CmdArgs`, `commonState`, `parser`, flags/pos args, and any post-parse filters.
2. Add `CmdKind` case and `initSubcommands()` branch in `Sources/Common/cmdArgs/cmdArgsManifest.swift`.
3. Add command implementation in `Sources/AppBundle/command/impl/<Name>Command.swift`.
4. Add mapping in `Sources/AppBundle/command/cmdManifest.swift`.
5. Add `docs/aerospace-<name>.adoc` synopsis/options and update docs index/grammar as needed; regenerate help with `./script/generate-cmd-help.sh` or `./generate.sh --ignore-xcodeproj` if appropriate.
6. Add parser tests and execution tests under `Sources/AppBundleTests/command/`.

For a common flag change:
- Prefer changing/adding helper in `SubArgParser.swift` if reused.
- Update each affected `CmdParser.flags` dictionary.
- Check conflict sets and post-parse `.filter` rules.
- Update docs synopsis and generated help.
- Add tests for unknown, duplicate, conflict, mandatory, `--`, and help behavior where relevant.

For a config option:
1. Add `Config` property/default in `Sources/AppBundle/config/Config.swift`.
2. Add parser function near existing specialized parsers or a new `parse*.swift` file.
3. Add top-level registry entry in `configParser` (`parseConfig.swift:93-137`) or nested table parser entry.
4. If version-gated, inspect existing tests around `persistent-workspaces` for expected diagnostics.
5. Update default/example configs and docs.
6. Add `ConfigTest` coverage for success, wrong type, unknown key interactions, warnings/errors, and default config parsing.
7. If exposed by `aerospace config`, update config map building code (search `buildConfigMap`/`ConfigMapValue`) and `ConfigCommandTest`.

## Start Here

Open `Sources/Common/cmdArgs/parseCmdArgs.swift` first. It defines the shared `CmdArgs`/`CmdParser` contract that drives docs help, parsing, server mapping, and tests. Then open the specific `Sources/Common/cmdArgs/impl/*CmdArgs.swift` and matching `Sources/AppBundle/command/impl/*Command.swift` for the command you are changing.

## Supervisor coordination

Progress update to `/Users/<username>/.pi/agent/sessions/--Users-<username>-AeroSpace--/subagent-artifacts/progress/c8d41e07/progress.md` was attempted but blocked by tool sandbox because the path is outside the working directory. No supervisor decision needed for scouting.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Completed architecture scouting only; wrote implementation-oriented notes to /Users/<username>/AeroSpace/command_config_scout.md without source-code changes."
    }
  ],
  "changedFiles": [
    "command_config_scout.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "git status --short",
      "result": "passed",
      "summary": "No tracked or staged changes reported before writing scout output."
    }
  ],
  "validationOutput": [
    "Scout output written to requested path. Progress file write was blocked outside working directory."
  ],
  "residualRisks": [
    "Did not exhaustively read every command/config parser file; focused on entry points and representative patterns."
  ],
  "noStagedFiles": true,
  "diffSummary": "Added scout notes markdown only.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "Use the listed files as starting points for actual implementation."
}
```
