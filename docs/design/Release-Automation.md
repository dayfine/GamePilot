# Release automation (2026-11-27)

Follow-up to `docs/design/Release-and-Onboarding.md` ([#294](https://github.com/dayfine/GamePilot/issues/294))
and PR [#310](https://github.com/dayfine/GamePilot/pull/310) (`.github/workflows/release.yml`).

PR #310 establishes the release build pipeline: on a `v*` tag (or manual dry-run dispatch), GitHub
Actions builds `gamepilot` and `gamepilot_daemon` across `macos-arm64`, `linux-x86_64`, and
`windows-x86_64`, stages each bundle with `dev/release/stage.sh`, runs `dev/release/smoke_test.sh`,
generates `SHA256SUMS.txt`, and publishes a GitHub Release with auto-generated notes.

This document defines the automation policies around that pipeline — when releases are cut, how
versions are named and embedded, how release notes are structured, what gates must pass, and how
old prereleases are cleaned up.

## 1. Cadence and triggers

| Option | How releases happen | Pros | Cons |
|---|---|---|---|
| **A. Manual stable + weekly rolling prerelease (Recommended)** | Stable `v0.x.y` cut by pushing a tag (or `workflow_dispatch`). Weekly `schedule` job updates a rolling `edge` prerelease only when `main` has new commits since the last release or `edge` build. | Stable releases stay intentional and console-verified; testers and lab machines always have a recent downloadable bundle without manual tagging. | One extra scheduled workflow run per week (skipped when `main` is quiet). |
| **B. Manual tags only** | Push `v0.x.y` or `v0.x.y-rc.N` by hand; `workflow_dispatch` remains dry-run only. | Simplest; zero scheduled CI usage. | Testers wait for manual cuts or grab expiring Actions artifacts. |
| **C. PR-driven bot (`release-please`)** | Bot maintains an open Release PR on `main` from Conventional Commits; merging it tags and releases. | Automated SemVer bumps and `CHANGELOG.md`. | Requires strict Conventional Commits across every PR and adds bot PR churn while pre-1.0. |

**Recommendation: Option A.** Skip the scheduled run when `git rev-parse HEAD` matches the commit
referenced by the latest `edge` (or latest stable) tag, so quiet weeks burn no runner minutes.
`workflow_dispatch` stays available for ad-hoc dry-run builds.

## 2. Versioning policy and propagation

### Scheme: SemVer pre-1.0 vs CalVer

- **SemVer pre-1.0 (`v0.MINOR.PATCH`, Recommended)**: already assumed by `Release-and-Onboarding.md`
  and PR #310 (`v*` tags).
  - `v0.MINOR.0` — user-visible milestones (new game/program support, Hub UI or protocol milestone,
    breaking config/CLI change).
  - `v0.MINOR.PATCH` — bug fixes, reader threshold tweaks, checkpoint plan updates.
  - `v0.MINOR.PATCH-rc.N` — release candidates for hardware soak testing before promoting to `v0.MINOR.PATCH`.
  - `edge` — rolling weekly prerelease tag (optional; alternative is dated `v0.MINOR.PATCH-dev.YYYYMMDD`).
- **CalVer (`vYYYY.MM.DD`)**: easy to pick without deciding minor vs patch, but gives users no
  signal when `consoles.json`, CLI flags, or bundle layout change during pre-1.0.

### Version propagation (zero new opam dependencies)

Today neither `gamepilot` nor `gamepilot_daemon` embeds a version string, and
`dev/lint/opam-allowlist.txt` keeps the opam dependency set minimal (no `dune-build-info`).

1. **Single source of truth**: the Git tag (`GITHUB_REF_NAME`) in CI, falling back to `dev` (or
   `dev+<short-sha>`) for local builds.
2. **OCaml (`gamepilot --version`)**: a small Dune `(rule ...)` generates a `version.ml` module
   from `GAMEPILOT_VERSION` (default `"dev"`) and `GAMEPILOT_GIT_SHA` (default `"unknown"`).
   `gamepilot --version` prints `gamepilot <version> (<sha>)`.
3. **C++ (`gamepilot_daemon --version`)**: CMake accepts `-DGAMEPILOT_VERSION=${VERSION}` (default
   `"dev"`), compiled into `gamepilot_daemon` and printed by `gamepilot_daemon --version`.
4. **Bundle & GitHub Release**:
   - Archive filename: `gamepilot-${VERSION}-${target}.{tar.gz,zip}` (already in PR #310).
   - GitHub Release prerelease flag: pass `--prerelease` automatically whenever the tag equals
     `edge` or contains `-` (e.g. `v0.1.0-rc.1`), so prereleases never hijack the `Latest` badge.

## 3. Release notes and changelog

| Approach | How it works | Trade-off |
|---|---|---|
| **`.github/release.yml` + brief manual intro on stable (Recommended)** | GitHub `--generate-notes` groups merged PRs into categories using repository labels. Stable releases are created as drafts so the maintainer can prepend 2–3 highlight bullets before publishing. | Zero merge conflicts on `main`, minimal maintenance, readable notes out of the box. |
| **Curated `CHANGELOG.md`** | Every PR updates `CHANGELOG.md` (or a bot generates it). | Frequent merge conflicts across parallel PRs; extra friction during rapid pre-1.0 iteration. |

### Proposed `.github/release.yml` categories

Aligns with existing labels (`game:frlg`, `game:bdsp`, `game:plza`, `game:sv`, `game:swsh`, `bug`,
`documentation`, `rule-audit`) plus three lightweight area labels (`area:ui`, `area:daemon`,
`area:engine`):

```yaml
changelog:
  exclude:
    labels:
      - rule-audit
  categories:
    - title: Games
      labels:
        - "game:frlg"
        - "game:bdsp"
        - "game:plza"
        - "game:sv"
        - "game:swsh"
    - title: Hub UI
      labels:
        - "area:ui"
    - title: Daemon
      labels:
        - "area:daemon"
    - title: Engine & CLI
      labels:
        - "area:engine"
    - title: Bug Fixes
      labels:
        - bug
    - title: Documentation
      labels:
        - documentation
    - title: Other Changes
      labels:
        - "*"
```

Prereleases (`edge`, `v*-rc.*`) publish immediately with auto-generated notes; stable `v0.x.y`
releases can be created with `--draft` so the maintainer can add highlights and click Publish.

## 4. Safety and verification gates

Three gates protect the `Latest` release without requiring self-hosted console runners in GitHub
Actions:

1. **CI green on the tagged commit**: a lightweight preflight job in `release.yml` queries commit
   check suites via `gh api` (or checks the required workflows `ocaml.yml`, `daemon.yml`,
   `review-tools.yml`) for `GITHUB_SHA` and fails fast if the tagged commit is not green on `main`.
2. **Cross-platform build + out-of-tree smoke test** (already in PR #310): all three matrix targets
   (`macos-arm64`, `linux-x86_64`, `windows-x86_64`) must pass `dev/release/smoke_test.sh` before
   the `publish` job runs. Extend `smoke_test.sh` to assert `gamepilot --version` and
   `gamepilot_daemon --version` match the expected version label.
3. **Prerelease -> stable hardware soak (manual)**:
   - Tag `v0.x.y-rc.1` -> publishes a GitHub Prerelease.
   - Pull the `rc` archive on a lab machine, verify `SHA256SUMS.txt`, run `./gamepilot doctor`,
     and run a representative hardware/emulator verification pass (`AGENTS.md`).
   - Once verified, tag `v0.x.y` on the same commit (or promote the verified build) to update
     `Latest`.

Least-privilege permissions from PR #310 remain unchanged: `contents: read` on `build`,
`contents: write` only on `publish`.

## 5. Retention and cleanup

- **Stable releases (`v0.x.y`)**: kept indefinitely; never auto-deleted.
- **Rolling `edge` prerelease**: updated in place (`gh release delete edge --yes` + force-update
  `edge` tag, or `gh release upload edge --clobber` + `gh release edit`), so it never accumulates
  extra entries on the Releases page.
- **Release candidates (`v0.x.y-rc.*`)**: when stable `v0.x.y` is published, automatically prune
  matching `v0.x.y-rc.*` prereleases and tags (or keep only the last 5 prereleases overall via a
  cleanup step in `publish`).
- **Actions artifacts**: set `retention-days: 7` on `actions/upload-artifact@v4` in `release.yml`
  so dry-run and intermediate build artifacts do not linger for 90 days.

## 6. Follow-up implementation order

1. **Version embedding**: add `gamepilot --version`, `gamepilot_daemon --version`, CMake/Dune
   version plumbing, and version assertions in `dev/release/smoke_test.sh`.
2. **Release hygiene in `release.yml`**: add `.github/release.yml`, automatic `--prerelease`
   detection, `--draft` for stable tags (if approved), `retention-days: 7`, and CI-green preflight
   check.
3. **Scheduled `edge` prerelease & RC cleanup**: add weekly `schedule` trigger with skip-if-unchanged
   check and automatic `v0.x.y-rc.*` cleanup on stable publish.

## 7. Open decisions

Please confirm before implementation:

1. **Scheduled prereleases**: enable a weekly rolling `edge` prerelease (skipping when `main` has
   no new commits), or keep releases manual-only (`v0.x.y` / `v0.x.y-rc.N`)? *(Recommended: weekly
   rolling `edge` + manual `v0.x.y`.)*
2. **Versioning scheme**: stay with SemVer `v0.x.y` pre-1.0, or switch to CalVer `vYYYY.MM.DD`?
   *(Recommended: SemVer `v0.x.y`.)*
3. **Stable release publishing**: create stable `v0.x.y` releases as GitHub **drafts** (to add
   brief highlights before publishing), or publish directly on tag push? *(Recommended: draft for
   stable `v0.x.y`, immediate for `edge` and `-rc`.)*
4. **Release note labels**: add `area:ui`, `area:daemon`, and `area:engine` labels for
   `.github/release.yml`, or keep notes grouped only by existing `game:*` and `bug` labels?
   *(Recommended: add the three `area:*` labels.)*
5. **RC retention**: delete `v0.x.y-rc.*` prereleases automatically when `v0.x.y` ships, or keep
   them for history? *(Recommended: auto-prune matching RCs when `v0.x.y` ships.)*
