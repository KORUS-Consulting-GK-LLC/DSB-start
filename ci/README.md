# GitHub Actions activation

`github-actions.yml` is the reviewed workflow candidate. Copy it to
`.github/workflows/ci.yml` using a GitHub credential with `workflow` scope.

The current OAuth credential can push source code but GitHub rejects workflow
changes. Keep this file versioned until an owner activates it; do not weaken the
workflow or embed another token to bypass that restriction.
