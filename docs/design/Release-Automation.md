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

| Trigger | What it produces | Behavior |
|---|---|---|
| **Daily `schedule` on `main`** | Dated nightly prerelease (`nightly-YYYY-MM-DD`) | Skipped when `main` (`git rev-parse HEAD`) has no new commits since the last `nightly-*` tag, so quiet days burn no runner minutes. Published immediately as a prerelease. |
| **Manual tag push (`v0.x.y`, `v0.x.y-rc.N`)** | Stable release or release candidate | Stable releases stay intentional and console-verified. `v0.x.y-rc.N` publishes immediately as a prerelease; `v0.x.y` is created as a GitHub draft. |
| **`workflow_dispatch`** | Dry-run build | Builds and smoke-tests all three platforms without publishing a GitHub Release. |

Alternatives considered and rejected:
- **Manual tags only**: forces testers to wait for manual cuts or download expiring Actions artifacts.
- **Weekly rolling `edge` tag**: rewriting a single tag in place loses short-term rollback history when a regression lands.
- **PR-driven bot (`release-please`)**: requires strict Conventional Commits across every PR and adds bot PR churn while pre-1.0.

## 2. Versioning policy and propagation

### Scheme: SemVer pre-1.0 + dated nightlies

We stay with **SemVer pre-1.0 (`v0.MINOR.PATCH`)** for stable releases (already assumed by
`Release-and-Onboarding.md` and PR #310's `v*` tags) rather than CalVer, so users get a clear
signal when `consoles.json`, CLI flags, or bundle layout change during pre-1.0:

- `v0.MINOR.0` — user-visible milestones (new game/program support, Hub UI or protocol milestone,
  breaking config/CLI change).
- `v0.MINOR.PATCH` — bug fixes, reader threshold tweaks, checkpoint plan updates.
- `v0.MINOR.PATCH-rc.N` — release candidates for hardware soak testing before promoting to `v0.MINOR.PATCH`.
- `nightly-YYYY-MM-DD` — daily scheduled prerelease tag cut from `main` when new commits have landed.

### Version propagation (zero new opam dependencies)

Today neither `gamepilot` nor `gamepilot_daemon` embeds a version string, and
`dev/lint/opam-allowlist.txt` keeps the opam dependency set minimal (no `dune-build-info`).

1. **Single source of truth**: the Git tag (`GITHUB_REF_NAME`, or the generated `nightly-YYYY-MM-DD`
   tag on scheduled runs) in CI, falling back to `dev` (or `dev+<short-sha>`) for local builds.
2. **OCaml (`gamepilot --version`)**: a small Dune `(rule ...)` generates a `version.ml` module
   from `GAMEPILOT_VERSION` (default `"dev"`) and `GAMEPILOT_GIT_SHA` (default `"unknown"`).
   `gamepilot --version` prints `gamepilot <version> (<sha>)`.
3. **C++ (`gamepilot_daemon --version`)**: CMake accepts `-DGAMEPILOT_VERSION=${VERSION}` (default
   `"dev"`), compiled into `gamepilot_daemon` and printed by `gamepilot_daemon --version`.
4. **Bundle & GitHub Release**:
   - Archive filename: `gamepilot-${VERSION}-${target}.{tar.gz,zip}` (already in PR #310).
   - GitHub Release publishing mode:
     - `nightly-*` and `v0.x.y-rc.N` (any tag starting with `nightly-` or containing `-`): pass
       `--prerelease` and publish immediately, so prereleases never hijack the `Latest` badge.
     - Stable `v0.x.y`: create with `--draft` so the maintainer can prepend brief highlights before
       clicking Publish.

## 3. Release notes and changelog

GitHub's `--generate-notes` backed by `.github/release.yml` groups merged PRs into categories using
repository labels, avoiding the merge-conflict churn of a hand-maintained `CHANGELOG.md` during
pre-1.0 iteration.

### `.github/release.yml` categories

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

Prereleases (`nightly-*`, `v*-rc.*`) publish immediately with auto-generated notes; stable `v0.x.y`
releases are created with `--draft` so the maintainer can prepend 2–3 highlight bullets before
publishing.

## 4. Safety and verification gates

Three gates protect the `Latest` release without requiring self-hosted console runners in GitHub
Actions:

1. **CI green on the tagged commit**: a lightweight preflight job in `release.yml` queries commit
   check suites via `gh api` (or checks the required workflows `ocaml.yml`, `daemon.yml`,
   `review-tools.yml`) for `GITHUB_SHA` and fails fast if the tagged commit is not green on `main`.
2. **All-or-nothing cross-platform build + out-of-tree smoke test** (already in PR #310): all three
   matrix targets (`macos-arm64`, `linux-x86_64`, `windows-x86_64`) must build cleanly and pass
   out-of-tree `dev/release/smoke_test.sh` before the `publish` job runs — no partial-platform
   releases. Extend `smoke_test.sh` to assert `gamepilot --version` and `gamepilot_daemon --version`
   match the expected version label.
3. **Prerelease -> stable hardware soak (manual)**:
   - Tag `v0.x.y-rc.1` -> publishes a GitHub Prerelease.
   - Pull the `rc` archive on a lab machine, verify `SHA256SUMS.txt`, run `./gamepilot doctor`,
     and run a representative hardware/emulator verification pass (`AGENTS.md`).
   - Once verified, tag `v0.x.y` on the same commit (or promote the verified build) to create the
     stable draft release and update `Latest` on publish.

Least-privilege permissions from PR #310 remain unchanged: `contents: read` on `build`,
`contents: write` only on `publish`.

## 5. Retention and cleanup

- **Stable releases (`v0.x.y`)**: kept indefinitely; never auto-deleted.
- **Daily nightlies (`nightly-YYYY-MM-DD`)**: auto-prune older `nightly-*` prereleases and their
  tags in the `publish` job so only the last 7 nightlies are kept.
- **Release candidates (`v0.x.y-rc.*`)**: when stable `v0.x.y` ships, automatically prune all
  matching `v0.x.y-rc.*` prereleases and tags.
- **Actions artifacts**: set `retention-days: 7` on `actions/upload-artifact@v4` in `release.yml`
  so dry-run and intermediate build artifacts do not linger for 90 days.

## 6. Follow-up implementation order

1. **Version embedding**: add `gamepilot --version`, `gamepilot_daemon --version`, CMake/Dune
   version plumbing, and version assertions in `dev/release/smoke_test.sh`.
2. **Release hygiene in `release.yml`**: add `.github/release.yml`, automatic `--prerelease`
   detection (`nightly-*` and `-rc.*`), `--draft` for stable `v0.x.y` tags, `retention-days: 7`,
   and CI-green preflight check.
3. **Daily nightlies & prerelease cleanup**: add the daily `schedule` trigger creating
   `nightly-YYYY-MM-DD` (skipped when `main` has no new commits since the last nightly), auto-prune
   older nightlies beyond the last 7, and auto-prune `v0.x.y-rc.*` when `v0.x.y` ships.

## 7. Decisions (agreed 2026-11-26)

1. **Cadence & triggers**: daily scheduled nightly prereleases (skipped when `main` has no new
   commits since the last nightly) + manual stable tags (`v0.x.y`, `v0.x.y-rc.N`) +
   `workflow_dispatch` dry-runs.
2. **Nightly tags & retention**: dated tags (`nightly-YYYY-MM-DD`), auto-pruning older nightlies to
   keep the last 7.
3. **Stable versioning**: SemVer pre-1.0 (`v0.MINOR.PATCH` and `v0.MINOR.PATCH-rc.N`), propagated
   into `gamepilot --version` and `gamepilot_daemon --version`.
4. **Publishing flow**: stable `v0.x.y` created as a GitHub draft; `nightly-*` and `-rc.N`
   published immediately as prereleases.
5. **Platform gate**: all-or-nothing across macOS, Linux, and Windows (all 3 builds + out-of-tree
   `smoke_test.sh` must pass before publishing).
6. **Release notes & RC cleanup**: `.github/release.yml` grouping by `game:*` + `area:ui`,
   `area:daemon`, `area:engine` + `bug` + `documentation` (excluding `rule-audit`), and
   auto-pruning `v0.x.y-rc.*` when `v0.x.y` ships.
