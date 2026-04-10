# AI Agent Prompt: Rules As Code GitHub Actions Update

Use this prompt with an AI coding assistant to keep the **Rules As Code** workflow (`.github/workflows/rules-as-code.yml`) on current **GitHub Action** major versions—especially to avoid hosted-runner deprecation notices (for example Node.js runtime upgrades on action bundles).

## Context

You are updating **pinned GitHub Actions** in the `salsa-images` repository. The **Rules As Code** image is built, tested, and published by this workflow.

**Key files**

| File | Role |
|------|------|
| `.github/workflows/rules-as-code.yml` | **Source of truth** for `uses: ...@vX` pins |
| `images/rules-as-code/DEVELOPER_GUIDE.md` | May reference action versions (e.g. `docker/metadata-action`) |
| `images/rules-as-code/AI_VERSION_UPDATE_PROMPT.md` | References `docker/metadata-action` in the “published image” steps |
| `images/rules-as-code/README.md` | May reference `actions/checkout` in the CI summary |

**Workflow jobs**

- **test** — checkout, `docker build`, OpenFisca tests  
- **deploy** — checkout, QEMU, Buildx, GHCR login, metadata, multi-arch build and push  

**Image registry:** `ghcr.io/salsadigitalauorg/salsa-images/rules-as-code`

## Current actions (verify in the workflow file)

Read `.github/workflows/rules-as-code.yml` and record each `uses:` line. Typical pins include:

| Action repository | Purpose |
|-------------------|---------|
| [actions/checkout](https://github.com/actions/checkout) | Clone repository |
| [docker/setup-qemu-action](https://github.com/docker/setup-qemu-action) | QEMU for multi-arch |
| [docker/setup-buildx-action](https://github.com/docker/setup-buildx-action) | Docker Buildx |
| [docker/login-action](https://github.com/docker/login-action) | Registry login |
| [docker/metadata-action](https://github.com/docker/metadata-action) | Image tags and labels |
| [docker/build-push-action](https://github.com/docker/build-push-action) | Build and push image |

**Important:** Exact major versions change over time—always read the workflow file first, then compare with the latest releases below.

## Task: Update GitHub Actions

Follow these steps in order.

### Step 1: Check for newer major versions

1. For each `owner/repo` in the workflow’s `uses:` lines, query the **latest** GitHub release tag (or the highest stable major tag the project documents):

   ```bash
   gh api "repos/actions/checkout/releases/latest" --jq '.tag_name'
   gh api "repos/docker/setup-qemu-action/releases/latest" --jq '.tag_name'
   gh api "repos/docker/setup-buildx-action/releases/latest" --jq '.tag_name'
   gh api "repos/docker/login-action/releases/latest" --jq '.tag_name'
   gh api "repos/docker/metadata-action/releases/latest" --jq '.tag_name'
   gh api "repos/docker/build-push-action/releases/latest" --jq '.tag_name'
   ```

   Alternatively, open each repository’s **Releases** page on GitHub.

2. Compare with the versions pinned in `.github/workflows/rules-as-code.yml` (e.g. `@v6`, `@v4`).

3. **If everything is already at the latest majors you intend to support**, stop and report that no update is needed.

4. **If updates are needed**, read each action’s release notes for **breaking changes** (inputs renamed, Node runner requirements, removed environment variables). The Docker actions often note Node runtime and `@actions/core` bumps in major releases.

### Step 2: Create a feature branch

1. Use an up-to-date `main`:

   ```bash
   git checkout main
   git pull origin main
   ```

2. Create a branch, for example:

   ```bash
   git checkout -b chore/upgrade-rules-as-code-gha-actions
   ```

### Step 3: Update the workflow

1. Edit **only** `.github/workflows/rules-as-code.yml` (unless release notes require workflow logic changes).

2. Bump each `uses: owner/repo@vN` to the target major (and minor if your policy pins full semver—this repo typically pins **major** tags such as `@v6`).

3. **Do not** change job semantics, `env:`, image names, or permissions unless a release requires it.

### Step 4: Sync documentation

Search for stale version strings so docs match the workflow:

```bash
rg 'actions/checkout@v|docker/(setup-qemu|setup-buildx|login|metadata|build-push)-action@v' images/rules-as-code/ .github/workflows/
```

Update any of:

- `images/rules-as-code/DEVELOPER_GUIDE.md` (metadata-action link text)
- `images/rules-as-code/AI_VERSION_UPDATE_PROMPT.md` (metadata-action in “published image” / tag steps)
- `images/rules-as-code/README.md` (if it names `actions/checkout` or other pins)

### Step 5: Validate the workflow file

Ensure the YAML is valid, for example:

```bash
ruby -ryaml -e "YAML.load_file('.github/workflows/rules-as-code.yml'); puts 'YAML OK'"
```

### Step 6: Build and test locally (same as CI test job)

1. Build the image:

   ```bash
   docker build -f images/rules-as-code/Dockerfile -t rules-as-code:test images/rules-as-code
   ```

2. Run OpenFisca tests:

   ```bash
   docker run --rm -d --name rules-as-code-test rules-as-code:test
   docker exec rules-as-code-test sh -c 'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
   docker stop rules-as-code-test
   ```

3. If tests fail, fix the cause or stop and report (failures here are usually unrelated to Action pins—investigate Dockerfile and rules).

### Step 7: Optional — run `act` for the test job

If [nektos/act](https://github.com/nektos/act) is installed, simulate the **test** job:

```bash
act push -j test -W .github/workflows/rules-as-code.yml --container-architecture linux/amd64
```

The **deploy** job (GHCR push, multi-arch) is usually **not** run locally without registry credentials; rely on GitHub Actions for that after merge.

### Step 8: Commit and push

```bash
git add .github/workflows/rules-as-code.yml images/rules-as-code/
git commit -m "chore(ci): upgrade Rules As Code GitHub Actions"
git push -u origin chore/upgrade-rules-as-code-gha-actions
```

### Step 9: Monitor CI

After push, the **Rules As Code build** workflow runs. Confirm both **test** and **deploy** succeed, for example:

```bash
gh run list --workflow=rules-as-code.yml --branch=chore/upgrade-rules-as-code-gha-actions --limit=1
gh run watch --workflow=rules-as-code.yml --branch=chore/upgrade-rules-as-code-gha-actions
```

### Step 10: Open a pull request

Create a PR to `main` summarising:

- Which actions moved from which version to which  
- That YAML was validated, Docker build and OpenFisca tests passed, and (if used) `act` test job passed  
- Link to relevant upstream release notes  

## Important notes

- **Hosted runner deprecations** (for example Node 20) often disappear after upgrading to actions that bundle **Node 24**—check each action’s release notes.  
- **Dependabot** can open PRs for GitHub Actions; still review release notes before merging.  
- Keep **OpenFisca** version updates separate from **Action** updates when possible (clearer history and simpler rollback). Use [AI_VERSION_UPDATE_PROMPT.md](./AI_VERSION_UPDATE_PROMPT.md) for Core/Country Template bumps.

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| Workflow fails on `docker/build-push-action` | Release notes for removed inputs or env vars; `context` / `tags` still valid |
| Metadata tags look wrong | `docker/metadata-action` breaking changes; `images:` input |
| Annotation about deprecated Node on an action | Upgrade that action to a release that supports the current runner policy |
| `act` differs from GitHub | Local Docker socket, architecture flags, and `act` image versions |

## Related

- [AI_VERSION_UPDATE_PROMPT.md](./AI_VERSION_UPDATE_PROMPT.md) — OpenFisca Core and Country Template version updates  
- [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md) — CI/CD overview and compatibility matrix  
- [MAINTAINABILITY.md](./MAINTAINABILITY.md) — Broader dependency and monitoring strategy  
