# Phase 2: Continuous Integration

> **Status: in progress.** Lint, Docker build, smoke test, and vulnerability
> scan are working. Still to do: require passing checks on `dev`, `staging`,
> and `prod`, and keep dependencies and actions updated automatically.

**Goal:** every change is checked automatically, on a clean machine, before it
can merge into an environment branch.

**Pull request:** [#6](https://github.com/keshawndev/code-fast-saas/pull/6) (draft)

## Results

_So far. Final numbers will be added when the phase is complete._

|                               | Before                                | After                                                          |
| ----------------------------- | ------------------------------------- | -------------------------------------------------------------- |
| Checks on a pull request      | None (I ran the build by hand)        | Lint, Docker build, smoke test, and image scan on every push   |
| ESLint warnings               | 4, printed and ignored in every build | 0, and any new warning fails the check                         |
| HIGH/CRITICAL CVEs in image   | 6 (unknown until the first scan)      | 0, and any new fixable one fails the check                     |
| Package managers in runtime   | npm, npx, corepack, yarn              | None (only `node`)                                             |
| Lint job duration             | n/a                                   | ~20s (npm download cache restored)                             |
| Docker build job duration     | n/a                                   | 2m19s with no cache → 1m20s with GitHub Actions layer cache    |
| Image size                    | 336 MB                                | 336 MB (removing npm hides it but doesn't shrink base layers)  |

## What I Built

| File                                                      | Purpose                                                                                     |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | GitHub Actions workflow: lint job, then build → smoke test → Trivy scan in one job          |
| [`Dockerfile`](../Dockerfile)                             | Runtime stage now removes npm, npx, corepack, and yarn, which the running app doesn't need  |
| [`package.json`](../package.json)                         | `overrides` forces Next.js's bundled postcss to a patched 8.5.x                             |

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
- **Fast checks first:** the Docker build job has `needs: lint`, so a
  ~20s lint failure stops the pipeline before it spends over a minute
  building an image.
- **Build the image in CI, then run it:** lint checks the code, but the
  image is what gets deployed. The smoke test starts the container with
  **no** environment variables, database, or secrets, and requests
  `/api/health`. This proves the image starts on its own, and that nothing
  needs a secret at build time.
- **Buildx with the GitHub Actions cache:** `docker/build-push-action` with
  `cache-to: type=gha,mode=max` caches every build stage, including the
  slow `npm ci` layer, between runs on fresh VMs. `push: false` for now;
  pushing to a registry comes in Phase 4.
- **Build, test, and scan in one job:** the smoke test and the Trivy scan
  run on the same machine as the build, so they check the exact image that
  was built. (Jobs run on separate VMs and don't share Docker images; see
  Problem 7.) Later, when the pipeline pushes to a registry, the pushed
  image will be the one that was scanned.
- **Scan policy:** fail on `HIGH` and `CRITICAL`, with `ignore-unfixed:
  true`, and `exit-code: 1` set explicitly (the action's default exits 0
  even when it finds vulnerabilities). Failing on every severity would
  keep the pipeline permanently red, and a permanently red check gets
  ignored. When a finding has no fix, the plan is to accept the risk in a
  `.trivyignore` with a reason and a review date, not to loosen the gate.
- **Third-party action pinned to a commit SHA:** `aquasecurity/trivy-action`
  is pinned to a full SHA with a `# v0.36.0` comment. Tags can be moved to
  point at different code, and SHAs can't. That action had its own
  published security advisory in February 2026.
- **Ship only what runs:** the runtime image runs `node server.js`, so npm,
  npx, corepack, and yarn are removed from the runner stage. That cleared
  four CVEs and removes tools an attacker could use from a shell in the
  container. The build stages keep npm.
- **Patch transitive dependencies with `overrides`:** Next.js 15 pins its
  own postcss 8.4.31, even in its latest 15.x release. Next 16 fixes it,
  but that's a major upgrade outside this PR's scope. An npm override
  forces the patched 8.5.x line, which is API-compatible (Next 16 uses it),
  and CI's build and smoke test confirm it works.
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

### 5. The smoke test couldn't find an image that had just been built

- **Problem:** the Build image step succeeded, then `docker run` in the next step failed with `Unable to find image 'code-fast-saas:ci' locally` and `pull access denied ... may require 'docker login'`.
- **Cause:** the `docker login` hint was a red herring, since there's no registry repository to log in to. Docker only tried a pull because the image wasn't in its local store. The run log showed `driver: docker-container` and `load: false`: `setup-buildx-action` runs BuildKit in its own container, and without `load` or `push`, the finished image stays in that builder's cache, where the Docker Engine can't see it. The same image had worked on my laptop because plain `docker build` puts the image straight into the engine.
- **Fix:** added `load: true`, which exports the image into the runner's Docker Engine. No credentials needed.

### 6. The smoke test failed with "connection reset," but worked by hand

- **Problem:** with the image loaded, the container started, but `curl` failed on its first attempt with `(56) Recv failure: Connection reset by peer`, even though it had `--retry 10`. The same commands had worked when I ran them one at a time.
- **Cause:** `docker run -d` returns when the container starts, not when the app inside is listening. Docker's port proxy accepts connections on the host right away, and resets them while nothing is listening in the container yet. The curl command used `--retry-connrefused`, which only retries a *refused* connection (exit 7), not a *reset* (exit 56), so curl gave up after one try. I reproduced it locally by running `docker run` and `curl` together, with no gap between them.
- **Fix:** switched to `--retry-all-errors`. With `--fail`, a real HTTP error still fails the check after 10 retries (~20s), so the check can still fail, just not on a startup race. Confirmed locally (a reset on attempt 1, `{"status":"ok"}` on attempt 2) and in CI.

### 7. The scan job couldn't find the image the build job had just built

- **Problem:** I first put the Trivy scan in its own `scan` job with `needs: build`. It failed with `unable to find the specified image "code-fast-saas:ci"`, followed by four sub-errors, including `permission denied` for containerd and `UNAUTHORIZED` from Docker Hub.
- **Cause:** Trivy tries several image sources in turn, so only the first sub-error mattered: Docker said `No such image`. The permission and auth errors were fallbacks failing afterward. I added a temporary `docker images` step to both jobs: the image was listed in the build job and missing in the scan job. Every job runs on a fresh VM, and `needs:` only controls order, not sharing.
- **Fix:** moved the scan into the build job, after the smoke test, and removed the debug steps. Passing the image between jobs as an artifact (`docker save` + upload/download) would also work, but it adds ~237 MB of transfer to every run.

### 8. The scanner found six HIGH CVEs, and the obvious fix didn't take

- **Problem:** the first working scan failed on six HIGH vulnerabilities, all with fixed versions available.
- **Cause:** I located each package inside the image with `docker run --entrypoint sh ... find`. Four (in `brace-expansion`, `ip-address`, and `tar`) were inside **npm**, which comes with the `node:24-alpine` base image, but the running app never uses npm. Two were in **postcss 8.4.31**, which Next.js pins for itself. After I added an `overrides` rule for postcss, the scan still showed 8.4.31. I had only changed `package.json`, and `npm ci` installs exactly what `package-lock.json` says. It didn't warn that the two files disagreed. Running `npm install` still didn't update it: npm kept the version that was already locked. `npm ls postcss` showed the mismatch: `postcss@8.4.31 invalid: "^8.5.18"`.
- **Fix:** removed npm, npx, corepack, and yarn in the runtime stage (6 → 2 findings). For postcss, I got stuck and had my AI mentor walk me through the fix: remove the stale `next/node_modules/postcss` entry from the lockfile, then regenerate it so npm resolved it again under the override (2 → 0). Next.js now shares the top-level `postcss@8.5.28`.

### 9. My local npm rewrote parts of the lockfile it shouldn't have

- **Problem:** my first lockfile commit for the postcss fix also contained 90 unrelated deleted lines, all `"libc": ["glibc"]` or `["musl"]` entries.
- **Cause:** toolchain drift. My WSL environment had Node 22 / npm 10, while the Dockerfile and CI use Node 24 / npm 11. npm 11 records which C library each native binary needs, and npm 10 dropped that metadata when it rewrote the file. That matters because the Alpine image uses musl.
- **Fix:** restored the lockfile and regenerated it inside the same image CI uses (`docker run -v "$PWD":/w -w /w node:24-alpine npm install --package-lock-only --ignore-scripts`). The final diff was only the 29 lines of the stale postcss entry. Follow-up: run Node 24 locally and add an `.nvmrc`, so local tools match CI.

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
- Error messages can point in the wrong direction. "May require `docker
  login`" was Docker's generic fallback. Checking which step failed, and
  what the log said the step before, showed that credentials weren't the
  problem. Adding a secret wouldn't have fixed it.
- Keep a known-good baseline. Running the smoke test by hand first proved
  the image was fine, so when CI failed, the difference had to be in how
  CI built or ran it.
- A container being "up" doesn't mean the app is ready. Scripts run the
  next command within milliseconds, so a startup race that never happens
  when typing commands by hand shows up in CI.
- Actions (`uses:`) are someone else's code running in my pipeline with my
  repo's permissions. I use official GitHub and Docker actions pinned to
  a version. For third-party actions, pinning to a commit SHA is safer,
  because tags can be moved.
- When a tool tries several fallbacks, the first error is usually the real
  one. Later "permission denied" and "unauthorized" messages were just
  fallbacks failing.
- Jobs don't share machines. `needs:` sets order, not state. Anything a
  later job needs has to be passed explicitly.
- When you can't see a CI machine's state, add a temporary step that prints
  it (`docker images`), then remove it.
- Triage a CVE before fixing it: where is it, does the running app use it,
  and is there a fix? Two different answers led to two different fixes.
- Deleting files in a later Docker layer hides them but doesn't shrink the
  image, because the bytes stay in the base layers.
- `package.json` holds rules and `package-lock.json` holds exact versions.
  `npm ci` only reads the lockfile, so a dependency change isn't real until
  the lockfile changes, and the scan is what proved it hadn't.
- The same command can give different results on different tool versions.
  Run tools that write shared files (like lockfiles) with the same version
  CI uses.
- `next lint` is deprecated and will be removed in Next.js 16. Moving to the
  ESLint CLI is a follow-up for the Next.js upgrade.
