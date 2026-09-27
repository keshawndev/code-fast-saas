# Phase 2: Continuous Integration

> **Status: in progress.** The lint gate is working and the codebase is clean.
> Still to do: add a Docker build job and an image vulnerability scan, and
> require passing checks on `dev`, `staging`, and `prod`.

**Goal:** every change is checked automatically, on a clean machine, before it
can merge into an environment branch.

**Pull request:** [#6](https://github.com/keshawndev/code-fast-saas/pull/6) (draft)

## Results

_So far. Final numbers will be added when the phase is complete._

|                          | Before                                | After                                         |
| ------------------------ | ------------------------------------- | --------------------------------------------- |
| Checks on a pull request | None (I ran the build by hand)        | Lint runs automatically on every push to a PR |
| ESLint warnings          | 4, printed and ignored in every build | 0, and any new warning fails the check        |
| Lint job duration        | n/a                                   | ~21s (npm download cache restored)            |

## What I Built

| File                                                      | Purpose                                                                      |
| --------------------------------------------------------- | ---------------------------------------------------------------------------- |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | GitHub Actions workflow: lint job on PRs and pushes to environment branches |

## Design Decisions

- **Triggers match the branching model:** the workflow runs on
  `pull_request` and `push` for `dev`, `staging`, and `prod` only. Pull
  requests check a change before it merges, and pushes check the result
  after it lands. Feature branches aren't listed under `push`, because
  their PR already runs the checks, and listing them would run everything
  twice.
- **Same Node version as production:** CI uses Node 24, matching the
  `node:24-alpine` base image, so CI and the container don't disagree
  about what works.
- **`npm ci` with a cached download directory:** CI installs exactly what
  `package-lock.json` specifies, and `setup-node`'s npm cache (keyed on the
  lockfile) avoids re-downloading packages on every run.
- **Pinned action versions:** actions are pinned to a major version
  (`@v5`), so an upstream release can't silently change the pipeline.
- **Warnings are errors:** `--max-warnings=0` makes any ESLint warning fail
  the job. Warnings that don't fail anything pile up and get ignored.
- **Draft PR while building:** the PR was opened as a draft early, so CI runs
  on every push while the work is still in progress.

## Problems I Solved

### 1. The workflow never ran

- **Problem:** after pushing the workflow and opening a PR into `dev`, `gh pr checks` reported `no checks reported`.
- **Cause:** the triggers came from a starter template that targeted `main`. This project promotes through `dev` → `staging` → `prod` and PRs target `dev`, so no event matched the `on:` filter. GitHub skipped the workflow without any error.
- **Fix:** scoped `pull_request` and `push` to `dev`, `staging`, and `prod`. I chose not to trigger on every branch, because that would run CI twice (once for the push, once for the PR) on every feature-branch commit.

### 2. A deprecation warning hidden behind a green check

- **Problem:** the lint job passed, but the run log contained a `##[warning]` annotation that didn't show up in `gh pr checks`: `actions/setup-node@v4` targets Node.js 20, which GitHub runners are retiring.
- **Cause:** actions run on their own Node.js runtime, separate from the `node-version` they install for the app. v4 was built for Node 20.
- **Fix:** upgraded to `actions/setup-node@v5`. The annotation is gone from later runs.

### 3. The lint gate passed even with warnings

- **Problem:** I added `--max-warnings=0` to make warnings fail CI and expected the next run to go red, since four warnings were still in the code. It went green.
- **Cause:** the job log showed `npm warn Unknown cli config "--max-warnings"`, and the command npm ran was `> next lint`, without the flag. `npm run` reads flags after the script name as its own config options, so the flag never reached ESLint. I confirmed this by calling `npx next lint --max-warnings=0` directly, and it exited with code 1.
- **Fix:** `npm run lint -- --max-warnings=0`. The `--` tells npm to stop reading flags and pass the rest to the script. The next run showed `> next lint --max-warnings=0` and failed with exit code 1, as expected.

### 4. Clearing the warnings the gate exposed

- **Problem:** with the gate working, CI failed on four warnings that had been printed, and ignored, in every build since Phase 1.
- **Cause:** three were dead code (two unused imports and an unused `data` variable). The fourth was a real bug: `ButtonVote`'s `useEffect` reads a `localStorage` key built from `postId`, but had an empty dependency array. If React reused the component for a different post, it would keep showing the previous post's voted state.
- **Fix:** removed the dead code. For `data`, I kept the `await axios.post(...)` so the request still runs and errors still reach the `catch`. Added `localStorageKeyName` to the effect's dependencies instead of disabling the rule. It's a string, so the effect only reruns when the post actually changes. CI went green with `✔ No ESLint warnings or errors`.

## What I Learned

- CI only reads **exit codes**. Output text, warnings, and yellow
  annotations don't fail a job, so a step can print problems and still pass.
- A green check isn't the whole story. Read the run log for `##[warning]`
  annotations.
- When adding a gate, **predict that it will fail, then prove it.** A check
  that can't fail is worse than no check, because it looks like protection.
- Lint warnings aren't all cosmetic. `react-hooks/exhaustive-deps` pointed
  at real stale-state bugs, and suppressing it with a comment would have
  hidden that.
- To isolate a bug, take one layer away (here, calling the tool directly
  instead of through `npm run`) and see whether the behavior changes.
- `next lint` is deprecated and will be removed in Next.js 16. Moving to the
  ESLint CLI is a follow-up for the Next.js upgrade.
