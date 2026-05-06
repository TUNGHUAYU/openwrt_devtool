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

## Action Tree Reference

The trees below show the repository and OpenWrt paths each action reads,
creates, moves, restores, or removes. Inline comments mark the affected files
and folders.

### list

`list` reads active work from the developing workspace only.

```text
workspace/
`-- developing/
    |-- FEEDS/
    |   `-- feed_devtool/<pkg>/Makefile        # read as a new package entry
    `-- PACKAGES/
        `-- <feed>/<pkg>/Makefile              # read as a modified package entry
```

### new

`new` creates a package Makefile under the devtool feed and creates the source
tree from either a local sample or a Git repository URL.

```text
.devtool/
|-- ref-Makefile/<style>/Makefile              # selected template for package Makefile
`-- ref-sources/<sample>/                      # selected sample source, without <git-url>

workspace/
`-- developing/
    |-- FEEDS/
    |   `-- feed_devtool/<pkg>/Makefile        # created package Makefile
    `-- SOURCES/
        `-- <pkg>/                             # created source git repo on dev branch

<openwrt>/
|-- feeds.conf                                 # src-link feed_devtool entry added/updated
`-- package/feeds/feed_devtool/<pkg>/          # installed by OpenWrt feeds script
```

```text
template or <git-url> -> workspace/developing/FEEDS + SOURCES -> OpenWrt feed registration
```

### modify

`modify` copies an OpenWrt package into the developing workspace, keeps a backup
of the original package, prepares source on `ref-base` and `dev`, then redirects
the OpenWrt package path to the workspace package.

```text
<openwrt>/
`-- package/<feed>/<pkg>/                      # original package selected for modify

workspace/
`-- developing/
    |-- PACKAGES/
    |   `-- <feed>/<pkg>/Makefile              # copied package; Makefile source URL redirected
    |-- PACKAGES_ORIGIN/
    |   `-- <feed>/<pkg>/                      # backup used by finish or abort
    `-- SOURCES/
        `-- <pkg>/                             # unpacked source git repo, ref-base and dev

<openwrt>/
`-- package/<feed>/<pkg> -> workspace/developing/PACKAGES/<feed>/<pkg>
                                                # symlink redirect to workspace package
```

```text
OpenWrt package -> workspace copy + origin backup -> source branch setup -> OpenWrt redirect
```

### patch

`patch` reads commits from the modified package source repository and writes
OpenWrt patch files into the modified package workspace.

```text
workspace/
`-- developing/
    |-- SOURCES/
    |   `-- <pkg>/.git                         # commits read from <base-ref>..dev
    `-- PACKAGES/
        `-- <feed>/<pkg>/
            |-- Makefile                       # base ref read from PKG_SOURCE_VERSION when omitted
            `-- patches/
                `-- 001-*.patch                # generated or replaced patch output
```

### finish

`finish` moves new packages into `workspace/finished/`. For modified packages,
it generates patches, restores the original OpenWrt package, copies patches
back into OpenWrt, removes active workspace entries, and prunes empty workspace
folders below `workspace/<phase>/<type>/`.

```text
workspace/
|-- developing/
|   |-- FEEDS/feed_devtool/<pkg>/Makefile      # moved for a new package
|   |-- SOURCES/<pkg>/                         # moved for a new package; removed for modify
|   |-- PACKAGES/<feed>/<pkg>/                 # removed after modified package finish
|   `-- PACKAGES_ORIGIN/<feed>/<pkg>/          # restored to OpenWrt, then removed
`-- finished/
    |-- FEEDS/feed_devtool/<pkg>/Makefile      # finished new package Makefile
    `-- SOURCES/<pkg>/                         # finished new package source

<openwrt>/
`-- package/<feed>/<pkg>/
    |-- Makefile                               # restored original package Makefile for modify
    `-- patches/
        `-- 001-*.patch                        # copied from workspace modified package patches
```

```text
new package: workspace/developing -> workspace/finished
modified package: workspace/developing -> restore OpenWrt package -> copy patches -> cleanup
```

### abort

`abort` removes selected generated work after confirmation. For modified
packages, it restores the original OpenWrt package from `PACKAGES_ORIGIN`.

```text
workspace/
`-- developing/
    |-- FEEDS/feed_devtool/<pkg>/              # removed for a new package
    |-- SOURCES/<pkg>/                         # removed for new or modified package work
    |-- PACKAGES/<feed>/<pkg>/                 # removed for modified package work
    `-- PACKAGES_ORIGIN/<feed>/<pkg>/          # restored to OpenWrt, then removed for modify

<openwrt>/
|-- build_dir/target-*/<pkg>*/                 # removed for a new package when present
|-- package/feeds/feed_devtool/<pkg>/          # uninstalled for a new package
|-- package/<feed>/<pkg>/                      # restored from PACKAGES_ORIGIN for modify
`-- tmp/info/.packageinfo-*<pkg>               # removed for modify when present
```

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
