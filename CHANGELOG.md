# Changelog

Format: [Keep a Changelog](https://keepachangelog.com). Versions: [SemVer](https://semver.org). Before 1.0, minor versions may change config keys and contracts.

## Unreleased

### Added
- First public version, extracted from a private workspace kit.
- Neutral core: gated scripts (`judge.sh`, `agent-merge.sh`, `agent-deploy.sh`, `uat-test.sh`, `release-decision.sh`, `session-save.sh`), guard, eight playbooks, four role briefs, templates.
- Adapters behind written contracts: host (`github`), harness (`claude-code`, `codex`, `git-hooks`), judge (`codex`, `claude`, `human`), spec (`openspec`, `plain`), identity (`own-login`, `github-app`), secrets (`env`, `command`).
- `host.sh`: one host-neutral entry point for pull requests, issues and statuses.
- `kit-info.sh`: prints how the kit is set up for a repo.
- `install-repo.sh` with harness, spec, judge and host options; an agent install guide that writes an adaptation plan first.
- Offline test suite, host conformance suite, public-content scan, CI on Linux and macOS.

### Changed from the private version
- Statuses are `adlc/*`. Repo config is `.adlc/config.env`. The pull request trailer is `adlc-change:`.
- The kit can live anywhere; enabled repos are listed in the kit's `.adlc/repos`.
- Protected branch names and the agent identity come from the machine-local `kit.env`, never from the command's environment.
- Model names became roles (planner, builder, judge, releaser).
