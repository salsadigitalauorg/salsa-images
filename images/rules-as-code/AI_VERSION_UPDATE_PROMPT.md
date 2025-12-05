# AI Agent Prompt: OpenFisca Core Version Update

Use this prompt with an AI coding assistant to automate OpenFisca Core version updates for the rules-as-code Docker image.

## Context

You are updating the OpenFisca Core version in the `salsa-images` repository. This repository contains Docker images for Salsa Digital projects, specifically the `rules-as-code` image which provides a pre-configured OpenFisca environment.

**Key Files:**
- `images/rules-as-code/Dockerfile` - Contains `ENV OPENFISCA_CORE_VERSION=X.X.X` on line 4
- `.github/workflows/rules-as-code.yml` - CI/CD workflow that builds, tests, and publishes the image
- `images/rules-as-code/DEVELOPER_GUIDE.md` - Contains version management documentation and compatibility matrix

**Current Version:** Check `images/rules-as-code/Dockerfile` line 4 for the current `OPENFISCA_CORE_VERSION` value.

**Image Registry:** `ghcr.io/salsadigitalauorg/salsa-images/rules-as-code`

## Task: Update OpenFisca Core Version

Follow these steps in order:

### Step 1: Check for Latest Version

1. Query PyPI for the latest OpenFisca-Core version:
   ```bash
   pip index versions OpenFisca-Core
   ```
   Or use the PyPI API:
   ```bash
   curl -s https://pypi.org/pypi/OpenFisca-Core/json | jq -r '.info.version'
   ```
   Or check the [PyPI project page](https://pypi.org/project/OpenFisca-Core/) directly.

2. Compare the latest version with the current version in `images/rules-as-code/Dockerfile` (line 4).

3. **If no newer version exists**, stop here and report that the image is already up to date.

4. **If a newer version exists**, verify compatibility:
   - Check the current `COUNTRY_TEMPLATE_VERSION` in `images/rules-as-code/Dockerfile` (line 3)
   - Verify the new OpenFisca Core version is compatible with the Country Template version by checking the [Country Template's pyproject.toml](https://github.com/openfisca/country-template/blob/8.0.1/pyproject.toml) (replace `8.0.1` with the current `COUNTRY_TEMPLATE_VERSION`)
   - Look for `openfisca-core[web-api]>=X` requirement to ensure compatibility
   - Review the [OpenFisca Core changelog](https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md) for breaking changes

5. **If compatible**, proceed to Step 2. **If incompatible**, report the issue and consider if `COUNTRY_TEMPLATE_VERSION` also needs updating.

### Step 2: Create Feature Branch

1. Ensure you're on the `main` branch and it's up to date:
   ```bash
   git checkout main
   git pull origin main
   ```

2. Create a new feature branch with the format `update/openfisca-core-X.X.X` (replace X.X.X with the new version):
   ```bash
   git checkout -b update/openfisca-core-X.X.X
   ```

### Step 3: Update Dockerfile

1. Read `images/rules-as-code/Dockerfile`.

2. Update line 4 to change `ENV OPENFISCA_CORE_VERSION=X.X.X` to the new version number.

3. **Important:** Only update the `OPENFISCA_CORE_VERSION` variable. Do NOT change:
   - `COUNTRY_TEMPLATE_VERSION` (line 3)
   - `JURISDICTION_NAME` (line 5) - This is fixed as "rules"
   - `LAGOON_LOCALDEV_HTTP_PORT` (line 7)

### Step 4: Build and Test Locally

1. Build the Docker image:
   ```bash
   docker build -f images/rules-as-code/Dockerfile -t rules-as-code:test images/rules-as-code
   ```

2. Run the OpenFisca tests to verify compatibility:
   ```bash
   docker run --rm -d --name rules-as-code-test rules-as-code:test
   docker exec rules-as-code-test sh -c 'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
   docker stop rules-as-code-test
   ```

3. **If tests fail:**
   - Investigate the failure by reviewing the test output
   - Check if the new OpenFisca Core version has breaking changes in the [changelog](https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md)
   - Verify Country Template compatibility (check compatibility matrix in DEVELOPER_GUIDE.md)
   - Review test output for specific error messages
   - If the version is incompatible, stop here and report the issue
   - Consider if `COUNTRY_TEMPLATE_VERSION` also needs updating

4. **If tests pass**, proceed to Step 5.

### Step 5: Commit and Push

1. Stage the changed file:
   ```bash
   git add images/rules-as-code/Dockerfile
   ```

2. Create a commit with a descriptive message:
   ```bash
   git commit -m "chore: update OpenFisca Core to X.X.X"
   ```
   (Replace X.X.X with the actual new version)

3. Push the branch to the remote repository:
   ```bash
   git push origin update/openfisca-core-X.X.X
   ```

### Step 6: Monitor CI/CD Workflow

1. Wait for the GitHub Actions workflow to trigger (it runs on push).

2. Check the workflow file `.github/workflows/rules-as-code.yml` to understand the process:
   - **test job**: Builds the image and runs OpenFisca tests
   - **deploy job**: Builds multi-platform image and pushes to GHCR

3. **Monitor using GitHub CLI (recommended):**

   First, check if GitHub CLI is installed:
   ```bash
   gh --version
   ```

   If installed, authenticate if needed:
   ```bash
   gh auth status
   # If not authenticated, run: gh auth login
   ```

   Get the latest workflow run for your branch:
   ```bash
   gh run list --workflow=rules-as-code.yml --branch=update/openfisca-core-X.X.X --limit=1
   ```

   Watch the workflow run in real-time:
   ```bash
   gh run watch --workflow=rules-as-code.yml --branch=update/openfisca-core-X.X.X
   ```

   Or check the status of a specific run:
   ```bash
   # Get the run ID from the list command above, then:
   gh run view <RUN_ID> --workflow=rules-as-code.yml
   ```

   View logs for a specific job:
   ```bash
   gh run view <RUN_ID> --log --job=<JOB_ID>
   # Or view all jobs:
   gh run view <RUN_ID> --log
   ```

   Check if the workflow completed successfully:
   ```bash
   gh run list --workflow=rules-as-code.yml --branch=update/openfisca-core-X.X.X --limit=1 --json conclusion,status
   ```

4. **Alternative: Monitor using GitHub API (if gh CLI not available):**

   Get the latest workflow run:
   ```bash
   curl -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/salsadigitalauorg/salsa-images/actions/workflows/rules-as-code.yml/runs?branch=update/openfisca-core-X.X.X\&per_page=1
   ```

   Extract the run ID from the response, then check status:
   ```bash
   curl -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/salsadigitalauorg/salsa-images/actions/runs/<RUN_ID>
   ```

   Poll for completion (check every 30 seconds):
   ```bash
   while true; do
     STATUS=$(curl -s -H "Accept: application/vnd.github+json" \
                   -H "X-GitHub-Api-Version: 2022-11-28" \
                   https://api.github.com/repos/salsadigitalauorg/salsa-images/actions/runs/<RUN_ID> | \
                   jq -r '.status')
     echo "Workflow status: $STATUS"
     if [ "$STATUS" = "completed" ]; then
       CONCLUSION=$(curl -s -H "Accept: application/vnd.github+json" \
                         -H "X-GitHub-Api-Version: 2022-11-28" \
                         https://api.github.com/repos/salsadigitalauorg/salsa-images/actions/runs/<RUN_ID> | \
                         jq -r '.conclusion')
       echo "Workflow conclusion: $CONCLUSION"
       break
     fi
     sleep 30
   done
   ```

   View logs (requires authentication token):
   ```bash
   # Set GITHUB_TOKEN if available
   curl -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/salsadigitalauorg/salsa-images/actions/runs/<RUN_ID>/logs
   ```

5. **Manual monitoring (fallback):**
   - Open: `https://github.com/salsadigitalauorg/salsa-images/actions`
   - Filter by your branch: `update/openfisca-core-X.X.X`
   - Click on the latest workflow run to view details

6. Wait for both jobs (`test` and `deploy`) to complete successfully.

7. **If the workflow fails:**
   - Review the error logs using the methods above
   - Identify which job failed (test or deploy)
   - Fix any issues and push additional commits
   - Re-monitor the workflow

8. **If the workflow succeeds**, proceed to Step 7.

### Step 7: Verify Published Image

1. Identify the image tag that was created. The workflow uses `docker/metadata-action@v5` which creates tags based on:
   - Branch name: The branch name may be sanitised (slashes converted to hyphens)
   - SHA: Short commit SHA
   - For branch `update/openfisca-core-X.X.X`, the tag might be `update-openfisca-core-X.X.X` or similar

2. Check the workflow logs or use GitHub CLI to see the exact tag:
   ```bash
   # View the deploy job logs to see the tags that were pushed
   gh run view <RUN_ID> --log --job=deploy
   ```

3. Pull the new image from GHCR (adjust tag name based on actual output):
   ```bash
   docker pull ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:update-openfisca-core-X.X.X
   ```
   Or check available tags at: `https://github.com/salsadigitalauorg/salsa-images/pkgs/container/rules-as-code`

4. Test the pulled image:
   ```bash
   docker run --rm -d --name rules-as-code-verify ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:update-openfisca-core-X.X.X
   docker exec rules-as-code-verify sh -c 'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
   docker stop rules-as-code-verify
   ```
   (Replace the tag with the actual tag from step 2)

5. **If verification fails**, investigate and report the issue.

6. **If verification succeeds**, proceed to Step 8.

### Step 8: Create Pull Request

1. Create a pull request from your feature branch to `main`.

   **Using GitHub CLI (if available):**
   ```bash
   gh pr create --base main --head update/openfisca-core-X.X.X \
     --title "chore: update OpenFisca Core to X.X.X" \
     --body "## Summary
   Updates OpenFisca Core from [OLD_VERSION] to X.X.X

   ## Changes
   - Updated \`ENV OPENFISCA_CORE_VERSION\` in \`images/rules-as-code/Dockerfile\`

   ## Testing
   - ✅ Local Docker build successful
   - ✅ OpenFisca tests passed locally
   - ✅ CI/CD workflow completed successfully
   - ✅ Published image verified and tested

   ## References
   - OpenFisca Core changelog: https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md"
   ```

   **Or create manually via GitHub web interface:**
   - Go to: `https://github.com/salsadigitalauorg/salsa-images/compare/main...update/openfisca-core-X.X.X`
   - Title: `chore: update OpenFisca Core to X.X.X`
   - Description should include:
     - Previous version → New version
     - Link to OpenFisca Core [changelog](https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md)
     - Confirmation that local tests passed
     - Confirmation that CI/CD workflow completed successfully
     - Confirmation that published image was verified

2. Example PR description:
   ```markdown
   ## Summary
   Updates OpenFisca Core from 43.4.3 to X.X.X

   ## Changes
   - Updated `ENV OPENFISCA_CORE_VERSION` in `images/rules-as-code/Dockerfile`

   ## Testing
   - ✅ Local Docker build successful
   - ✅ OpenFisca tests passed locally
   - ✅ CI/CD workflow completed successfully
   - ✅ Published image verified and tested

   ## References
   - OpenFisca Core changelog: https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md
   ```

3. Submit the pull request and wait for review/merge.

## Important Notes

- **Do NOT update `COUNTRY_TEMPLATE_VERSION`** unless you've verified compatibility with the new OpenFisca Core version. Check the compatibility matrix in `DEVELOPER_GUIDE.md`.
- **Do NOT change `JURISDICTION_NAME`** - it's fixed as "rules" and required by dependent projects.
- Always test locally before pushing to ensure the update doesn't break functionality.
- If tests fail, investigate thoroughly before proceeding. Breaking changes may require additional updates.
- The CI/CD workflow automatically creates image tags based on branch names and commits.
- See the [Update Checklist](DEVELOPER_GUIDE.md#update-checklist) in DEVELOPER_GUIDE.md for a comprehensive checklist of items to verify during updates.

## Troubleshooting

**Tests fail after version update:**
- Check [OpenFisca Core changelog](https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md) for breaking changes
- Verify Country Template compatibility by checking the [Country Template's pyproject.toml](https://github.com/openfisca/country-template/blob/8.0.1/pyproject.toml) (replace version with current `COUNTRY_TEMPLATE_VERSION`)
- Review test output for specific error messages
- Consider if dependencies in `requirements.txt` need updating
- Check if `COUNTRY_TEMPLATE_VERSION` needs updating for compatibility

**CI/CD workflow fails:**
- Check GitHub Actions logs for specific errors
- Verify Docker build context is correct
- Ensure all required files are present
- Check registry permissions

**Image tag not found:**
- Wait a few minutes for the image to propagate in GHCR
- Verify the workflow completed successfully
- Check the workflow logs for the exact tag name created
- Use `docker/metadata-action` output to determine the tag

