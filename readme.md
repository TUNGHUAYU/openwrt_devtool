# openwrt-devtool

> author: Terry Yu
>
> version: v3.1.x

## Usage

Run commands from this repository after configuring the target OpenWrt tree.

```bash
bash devtool.sh help
```

Use command-specific help for arguments and examples.

```bash
bash devtool.sh <command> help
```

## Workspace Layout

Active development work is stored under `workspace/developing/`.

- `FEEDS/`: new package Makefiles in the local devtool feed.
- `SOURCES/`: source repositories or generated sample source trees.
- `PACKAGES/`: copied OpenWrt package directories for `modify`.
- `PACKAGES_ORIGIN/`: original OpenWrt package backups for `modify`.

Completed new package work is moved under `workspace/finished/`.

- `FEEDS/`: finished package Makefiles.
- `SOURCES/`: finished source trees.

When the configured OpenWrt tree is available, devtool also maintains a local
`codebase` symlink that points to that tree. This makes the current OpenWrt
checkout easy to inspect without committing machine-local paths.

## List Active Work

List new and modified packages currently tracked by devtool.

```bash
bash devtool.sh list
```

This reads active packages from `workspace/developing/FEEDS` and `workspace/developing/PACKAGES`.

## New Package

Create a package from the local sample Makefile and sample source templates.

```bash
bash devtool.sh new <pkg-name>
```

Devtool prompts for a Makefile style and sample source, then creates:

```text
workspace/developing/FEEDS/feed_devtool/<pkg-name>/Makefile
workspace/developing/SOURCES/<pkg-name>/
```

Reference templates include common OpenWrt package styles such as CMake,
autotools, Meson, plain Make, Python 3 modules, files-only packages, and
prebuilt-artifact installers. Matching hello-world source trees live under
`.devtool/ref-sources/`.

Create a package from a Git repository URL.

```bash
bash devtool.sh new <pkg-name> <git-url>
```

The package Makefile is created in the devtool feed and the Git source is cloned into `workspace/developing/SOURCES/<pkg-name>/` on the `dev` branch.

## Modify Existing Package

Modify an existing package from the configured OpenWrt workspace.

```bash
bash devtool.sh modify [<pkg-pattern>]
```

Devtool shows a package menu, copies the selected package into `workspace/developing/PACKAGES/`, backs up the original into `workspace/developing/PACKAGES_ORIGIN/`, prepares source under `workspace/developing/SOURCES/`, and redirects the OpenWrt package to the devtool workspace.

Preview the planned steps without changing package state.

```bash
bash devtool.sh modify [<pkg-pattern>] --dry-run
```

## Patch Modified Package

Generate OpenWrt patches from source commits for a modified package.

```bash
bash devtool.sh patch [<pkg-pattern>] [<base-ref>]
```

Without `<pkg-pattern>`, devtool lists modified packages for selection. Without `<base-ref>`, devtool uses the package `PKG_SOURCE_VERSION`, then falls back to `ref-base`.

Example:

```bash
bash devtool.sh patch libcap-ng ref-base
```

Patches are written to the selected package `patches/` directory in `workspace/developing/PACKAGES/`.

## Finish Work

Finish a new package.

```bash
bash devtool.sh finish <pkg-name>
```

For new packages, devtool moves:

```text
workspace/developing/FEEDS/feed_devtool/<pkg-name>/Makefile
workspace/developing/SOURCES/<pkg-name>/
```

to:

```text
workspace/finished/FEEDS/feed_devtool/<pkg-name>/Makefile
workspace/finished/SOURCES/<pkg-name>/
```

Finish a modified package.

```bash
bash devtool.sh finish <pkg-pattern>
```

For modified packages, devtool generates patches, restores the original OpenWrt package directory, moves generated patches into the OpenWrt package `patches/` directory, and removes the active devtool workspace entries.

After a successful non-dry-run finish, devtool prunes empty workspace folders
below the protected `workspace/<phase>/<type>/` layout.

Preview finish steps without changing state.

```bash
bash devtool.sh finish [<pkg-pattern>] --dry-run
```

## Abort Work

Abort selected active work after confirmation.

```bash
bash devtool.sh abort
```

For new packages, devtool removes generated feed and source workspace entries. For modified packages, it restores the original OpenWrt package and removes active package, source, and backup workspace entries.
