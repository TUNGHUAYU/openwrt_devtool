# Repository Guidelines

## Project Structure & Module Organization

`devtool.sh` is the main Bash entrypoint for the OpenWrt devtool workflow. Configuration lives in `.devtool/configs/`, shared helpers in `.devtool/scripts/_*.sh`, and command implementations in `.devtool/scripts/action_*.sh`. OpenWrt package templates are stored in `.devtool/ref-Makefile/`; starter source trees are stored in `.devtool/ref-sources/`. `workspace/` contains generated package/feed/source work and is ignored by Git.

## Build, Test, and Development Commands

- `bash devtool.sh help` shows available commands after repository/OpenWrt checks pass.
- `bash devtool.sh list` lists packages currently tracked in the devtool workspace.
- `bash devtool.sh new <pkg-name> [<http-url>]` creates a package from local templates or an HTTP git repository.
- `bash devtool.sh modify [<pkg-pattern>] [--dry-run]` copies an existing package, creates `ref-base` and `dev`, and leaves `HEAD` on `dev`.
- `bash devtool.sh patch [<pkg-pattern>] [<base-ref>]` appends source patches from modified package commits to `patches/`; without a pattern, select from modified packages. Omitted base defaults to `ref-base`.
- `bash devtool.sh abort` removes selected generated work after confirmation.
- `bash tests/run_tests.sh` runs the Bash test suite.
- `bash -n devtool.sh .devtool/scripts/*.sh` performs a Bash syntax check.

There is no standalone repo build; package builds run through the configured OpenWrt tree.

## Coding Style & Naming Conventions

Use Bash syntax consistent with existing files. Keep public helper functions in the `FUNC_*` style and global variables uppercase, such as `DEVTOOL_DIR`, `OPENWRT_DIR`, and `PKG_NAME`. Prefer existing helpers from `.devtool/scripts/_core.sh`, `_init.sh`, and `_utils.sh` before adding new workflow code. Quote paths where practical and keep generated workspace paths out of source changes.

## Testing Guidelines

For script changes, run `bash tests/run_tests.sh` and the Bash syntax check. For workflow changes, test against a disposable OpenWrt checkout and temporary package workspace. Exercise both `new` and `modify` paths when changing shared helpers or workspace logic.

## Commit & Pull Request Guidelines

Recent commits use bracketed prefixes such as `[FIX][system]`, `[ENH][system]`, `[FEAT][new]`, and `[DOC]`. Keep commits focused on one behavior change. Pull requests should describe the affected command path, manual commands run, OpenWrt workspace impact, and any template changes.

## Security & Configuration Tips

Do not commit `.openwrt_dir`, private repository URLs, credentials, or generated build output. Treat `workspace/` as disposable local state unless intentionally updating a sample. Remote package creation currently expects HTTP-compatible git URLs.
