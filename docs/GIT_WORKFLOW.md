# Git workflow — direct writes are not required

Central repository: https://github.com/S-h-u-b-h-1/MCA. The repository is already initialized; do **not** run `git init` or create a new root commit.

## Fork-based PR process (recommended)

1. Each teammate signs in and clicks **Fork** on the central public repository.
2. Clone their fork: `git clone https://github.com/YOUR_USERNAME/MCA.git` and `cd MCA`.
3. Add upstream: `git remote add upstream https://github.com/S-h-u-b-h-1/MCA.git`.
4. Fetch current code: `git fetch upstream && git switch main && git merge --ff-only upstream/main`.
5. Create their assigned feature branch from main, implement, test, and commit as themselves.
6. Push to the personal fork and open a PR against `S-h-u-b-h-1/MCA:main`. No collaborator invitation is needed.

If a member already has a central clone, first run `git status --short`, `git switch main` and `git pull --ff-only origin main`, then configure a fork remote before pushing. Preserve unstaged work before switching.

## PR review gate

- [ ] Independently authored RTL/test/analysis and clear file ownership.
- [ ] Interface compatible with `docs/INTERFACES.md`.
- [ ] Tests rerun with real output and evidence; no unverified behavior claimed.
- [ ] Diff reviewed by another member before merging.
- [ ] Full integrated tests rerun after PRs are merged; no force push to shared main.

See `docs/TEAM_START_HERE.md` for commands and the role table.
