# MCA team start guide — no collaborator setup needed

Main repository: https://github.com/S-h-u-b-h-1/MCA. Read `docs/INTERFACES.md` and your individual `docs/team_roles/` guide first.

## Everyone works from the central main, via a personal fork

1. On GitHub, open the central repo and click **Fork** into your own account.
2. Substitute your real username for `YOUR_USERNAME`:

```bash
git clone https://github.com/YOUR_USERNAME/MCA.git
cd MCA
git remote add upstream https://github.com/S-h-u-b-h-1/MCA.git
git fetch upstream
git switch main
git merge --ff-only upstream/main
make verify-p1
```

3. Create one feature branch, implement your own module, and write self-checking tests:

| Person | Branch | Main work |
| --- | --- | --- |
| Tanish | `feature/tanish-btb` | 16-entry tagged BTB + hit/miss/collision testbench |
| Tanmay | `feature/tanmay-control` | Next PC, branch resolution, flush/redirect, integration |
| Vansh | `feature/vansh-baselines-verification` | 1-bit/static comparison, BEQ/BNE traces |
| Lakshya | `feature/lakshya-evaluation` | Accuracy/CPI plots, resource/timing analysis and report/video |

```bash
git switch -c YOUR_FEATURE_BRANCH
# Edit and verify your assigned files.
git add PATHS_YOU_CHANGED
git diff --cached --check
git commit -m "feat: implement assigned MCA module"
git push -u origin YOUR_FEATURE_BRANCH
```

4. On GitHub, open a PR from your fork's feature branch **into** `S-h-u-b-h-1/MCA:main`. No collaborator invitation or push permission on the central repository is required.

If you **already cloned** the central repository, run `git status --short`, `git switch main`, `git pull --ff-only origin main`. Before pushing, add your own fork as a remote because central push access is not automatic. Preserve uncommitted work by committing or stashing it first.

The leader reviews real code/tests and merges passing PRs. Do not use `git init` in an existing repo, fake another contributor's commits, force-push central main, or describe unfinished modules as working.

**Phase I deadline:** 16 November 2026, 11:59 PM IST. See `docs/FACULTY_REQUIREMENTS.md` for the IEEE report, video and project-evaluation gates.
