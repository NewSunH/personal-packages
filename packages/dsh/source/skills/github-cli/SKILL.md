---
name: github-cli
description: Conservative GitHub work through gh with explicit checks before remote mutations.
whenToUse: Use for GitHub repositories, issues, pull requests, releases, checks, and Actions work performed through the GitHub CLI.
---

# GitHub CLI workflow

Use `gh` for GitHub operations and `git` for local repository state.

Before acting, confirm the repository, branch, authentication status, and requested scope. Read-only inspection is safe to perform directly. Before a remote mutation such as creating or editing an issue, pushing, merging, closing, publishing a release, or changing repository settings, show the exact target and obtain user confirmation unless that mutation was already explicit in the current request.

Never print tokens or credentials. Prefer structured output (`--json` plus `--jq`) when available. For CI failures, inspect the failing check and relevant log segment before changing code. Do not merge or force-push merely because checks pass.
