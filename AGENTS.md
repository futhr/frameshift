# Frameshift agent instructions

Read `CLAUDE.md`, `README.md`, and `docs/README.md` before changing this
repository. The maintainer rules in `CLAUDE.md` apply to every AI agent.

## Git operations

- When a user has authorized commits, use Conventional Commit subjects:
  `type(scope): imperative description`. Use a narrow scope such as `host`,
  `mac`, `renderer`, `protocol`, or `docs`.
- Accepted types are `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`,
  `refactor`, `revert`, `style`, and `test`. Use `!` for a breaking change.
- Check the staged diff and subject before committing. The subject must describe
  the actual change. Do not add AI attribution or co-author trailers.
- Enable the repository's commit-message hook with
  `git config core.hooksPath .githooks` in a fresh clone.
- Never change repository visibility. Do not push or rewrite remote refs unless
  the user has expressly authorized that separate action.
