# Contributing

## Commit conventions

This repository follows [Conventional Commits](https://www.conventionalcommits.org/).

Subject format: `<type>(<scope>)?!?: <subject>`. Allowed types:

```
feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
```

Examples:

```
feat: add init command
fix(check): treat empty config as a block
refactor(rewrite)!: change signature policy default
```

Enforced by git hook specified in .git/config
