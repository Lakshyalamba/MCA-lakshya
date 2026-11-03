# GitHub collaboration workflow

Leader: create empty repo `S-h-u-b-h-1/MCA` (without a GitHub-generated README) and make one real initial starter commit. The initial commit is shared scaffolding, not proof that every member contributed.

```bash
git init
git add .
git commit -m "chore: initialize MCA branch predictor"
git branch -M main
git remote add origin https://github.com/S-h-u-b-h-1/MCA.git
git push -u origin main
```

Each other member clones `main`, creates a feature branch named in their role guide, writes real work, commits logically and opens a PR. Use `git switch main && git pull --ff-only && git switch -c feature/...` to branch off the latest main. Avoid force-pushing shared branches. Do not commit just a README edit as someone's entire role.

## PR checklist

- [ ] My code is my actual work and only claims what was implemented.
- [ ] I followed `docs/INTERFACES.md` or documented a required interface change.
- [ ] Exact compile/simulation commands and output are in the PR description.
- [ ] Results include no fabricated accuracy, speedup, clock MHz or full-CPU claim.
- [ ] Another member reviewed before merge; final main tests re-run.
