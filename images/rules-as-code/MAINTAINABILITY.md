# Maintainability Guide

This document outlines strategies for improving the long-term maintainability of the Rules As Code Docker image, including version management, automated monitoring, and Docker best practices.

## Table of Contents
- [Current State Analysis](#current-state-analysis)
- [Version Management Improvements](#version-management-improvements)
- [Automated Dependency Monitoring](#automated-dependency-monitoring)
- [Automated Testing Strategies](#automated-testing-strategies)
- [Docker Best Practices](#docker-best-practices)
- [Implementation Roadmap](#implementation-roadmap)

## Current State Analysis

### Hardcoded Version Locations

Currently, version numbers are maintained in multiple locations:

| Location | Versions Referenced | Update Required |
|----------|---------------------|-----------------|
| `Dockerfile` (ENV variables) | OpenFisca Core, Country Template | ✅ Primary source |
| `DEVELOPER_GUIDE.md` | All versions (multiple references) | Manual sync required |
| `README.md` | Core versions in "What's Included" | Manual sync required |
| `requirements.txt` | pandas, matplotlib | Independent |

**Pain Points:**
- Version numbers duplicated across 3+ files
- Manual updates risk inconsistency
- No automated detection of upstream updates
- No automated compatibility testing for new versions

### Upstream Dependencies

| Dependency | Repository | PyPI Package | Update Frequency |
|------------|------------|--------------|------------------|
| OpenFisca Core | [openfisca/openfisca-core](https://github.com/openfisca/openfisca-core) | [OpenFisca-Core](https://pypi.org/project/OpenFisca-Core/) | ~Monthly |
| Country Template | [openfisca/country-template](https://github.com/openfisca/country-template) | [openfisca-country-template](https://pypi.org/project/openfisca-country-template/) | ~Quarterly |
| Python Base Image | [uselagoon/python-3.12](https://github.com/uselagoon/lagoon-images) | N/A (Docker Hub) | As needed |

**Version Source Recommendation:** Both OpenFisca packages are published to **PyPI** and have **GitHub tags**. We recommend monitoring **PyPI** because:
- OpenFisca Core is installed via `pip install` - PyPI is the authoritative source
- Native Dependabot/Renovate support without custom regex
- Simpler API for version checking
- Country Template is also on PyPI even though we download the tarball from GitHub

## Version Management Improvements

### Strategy 1: Single Source of Truth with Build Args

**Current approach** - Versions defined in Dockerfile ENV:
```dockerfile
ENV COUNTRY_TEMPLATE_VERSION=8.0.1
ENV OPENFISCA_CORE_VERSION=43.4.3
```

**Improved approach** - Use ARG for build-time flexibility:
```dockerfile
# Build arguments (can be overridden at build time)
ARG OPENFISCA_CORE_VERSION=43.4.3
ARG COUNTRY_TEMPLATE_VERSION=8.0.1

# Store as ENV for runtime access
ENV OPENFISCA_CORE_VERSION=${OPENFISCA_CORE_VERSION}
ENV COUNTRY_TEMPLATE_VERSION=${COUNTRY_TEMPLATE_VERSION}
```

**Benefits:**
- CI/CD can test different versions without modifying Dockerfile
- Matrix builds can test multiple version combinations
- Default versions still work for standard builds

### Strategy 2: Centralised Version File

Create a `versions.json` file as the single source of truth:

```json
{
  "openfisca_core": "43.4.3",
  "country_template": "8.0.1",
  "python_base": "3.12",
  "pandas": ">=2.3.3,<3.0.0",
  "matplotlib": ">=3.10.7,<4.0.0"
}
```

**Implementation:**
1. Read versions in CI/CD pipeline
2. Pass as build arguments to Docker
3. Generate documentation sections automatically
4. Single file to update for version bumps

### Strategy 3: Documentation Generation

Rather than hardcoding versions in Markdown files, generate version sections:

**Option A: GitHub Actions workflow to update docs**
```yaml
- name: Extract versions from Dockerfile
  run: |
    CORE_VERSION=$(grep 'OPENFISCA_CORE_VERSION=' Dockerfile | cut -d'=' -f2)
    TEMPLATE_VERSION=$(grep 'COUNTRY_TEMPLATE_VERSION=' Dockerfile | cut -d'=' -f2)
    # Update README badges or version sections
```

**Option B: Dynamic badges in README**
```markdown
![OpenFisca Core](https://img.shields.io/badge/OpenFisca_Core-43.4.3-blue)
```

**Option C: Include file references**
- Keep version details in ONE location
- Reference that location in other docs
- Accept some duplication as documentation cost

## Automated Dependency Monitoring

### Option 1: Dependabot (Recommended for Python deps)

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  # Python dependencies in requirements.txt
  - package-ecosystem: "pip"
    directory: "/images/rules-as-code"
    schedule:
      interval: "weekly"
    reviewers:
      - "salsadigitalauorg/maintainers"
    labels:
      - "dependencies"
      - "python"
```

**Limitations:** Dependabot doesn't monitor Dockerfile ENV variables or GitHub release tags directly.

### Option 2: Renovate Bot (Recommended)

Renovate can monitor PyPI packages and Docker base images with custom version patterns.

Create `renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:base"],
  "packageRules": [
    {
      "matchPackagePatterns": ["openfisca", "OpenFisca"],
      "groupName": "OpenFisca packages"
    }
  ],
  "regexManagers": [
    {
      "fileMatch": ["^images/rules-as-code/Dockerfile$"],
      "matchStrings": [
        "ENV OPENFISCA_CORE_VERSION=(?<currentValue>.*?)\\n"
      ],
      "datasourceTemplate": "pypi",
      "depNameTemplate": "OpenFisca-Core"
    },
    {
      "fileMatch": ["^images/rules-as-code/Dockerfile$"],
      "matchStrings": [
        "ENV COUNTRY_TEMPLATE_VERSION=(?<currentValue>.*?)\\n"
      ],
      "datasourceTemplate": "pypi",
      "depNameTemplate": "openfisca-country-template"
    }
  ]
}
```

**Benefits:**
- Monitors [PyPI](https://pypi.org/) for both packages - the authoritative source for pip installations
- Native PyPI datasource support (more reliable than custom regex for GitHub)
- Creates PRs automatically when new versions are published
- Highly configurable with version filtering (e.g., ignore pre-releases)

**Alternative - GitHub Tags:**
If you prefer to monitor GitHub tags instead (e.g., to catch versions before PyPI publication), change `datasourceTemplate` to `"github-tags"` and use the repository paths:
- `"openfisca/openfisca-core"` for Core
- `"openfisca/country-template"` for Country Template

### Option 3: Custom GitHub Actions Workflow

Create `.github/workflows/check-upstream.yml`:

```yaml
name: Check Upstream Updates

on:
  schedule:
    # Run weekly on Monday at 9am UTC
    - cron: '0 9 * * 1'
  workflow_dispatch:  # Allow manual trigger

jobs:
  check-openfisca-core:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Get current version from Dockerfile
        id: current
        run: |
          CURRENT=$(grep 'OPENFISCA_CORE_VERSION=' images/rules-as-code/Dockerfile | cut -d'=' -f2)
          echo "version=$CURRENT" >> $GITHUB_OUTPUT
      
      - name: Get latest PyPI version
        id: latest
        run: |
          # Query PyPI for the latest version
          LATEST=$(curl -s https://pypi.org/pypi/OpenFisca-Core/json | jq -r '.info.version')
          echo "version=$LATEST" >> $GITHUB_OUTPUT
      
      - name: Compare versions
        run: |
          if [ "${{ steps.current.outputs.version }}" != "${{ steps.latest.outputs.version }}" ]; then
            echo "::warning::New OpenFisca Core version available: ${{ steps.latest.outputs.version }} (current: ${{ steps.current.outputs.version }})"
          fi
      
      - name: Create issue if update available
        if: steps.current.outputs.version != steps.latest.outputs.version
        uses: actions/github-script@v7
        with:
          script: |
            const title = `Update OpenFisca Core to ${{ steps.latest.outputs.version }}`;
            const body = `A new version of OpenFisca Core is available on PyPI.
            
            **Current version:** ${{ steps.current.outputs.version }}
            **Latest version:** ${{ steps.latest.outputs.version }}
            
            **PyPI:** https://pypi.org/project/OpenFisca-Core/
            **Changelog:** https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md
            
            ## Update checklist
            - [ ] Review [changelog](https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md)
            - [ ] Check compatibility with Country Template version
            - [ ] Update \`OPENFISCA_CORE_VERSION\` in Dockerfile
            - [ ] Run local build and tests
            - [ ] Update documentation if needed
            `;
            
            // Check if issue already exists
            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              labels: 'dependency-update'
            });
            
            const existingIssue = issues.data.find(i => i.title.includes('OpenFisca Core'));
            
            if (!existingIssue) {
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: title,
                body: body,
                labels: ['dependency-update', 'openfisca']
              });
            }

  check-country-template:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Get current version from Dockerfile
        id: current
        run: |
          CURRENT=$(grep 'COUNTRY_TEMPLATE_VERSION=' images/rules-as-code/Dockerfile | cut -d'=' -f2)
          echo "version=$CURRENT" >> $GITHUB_OUTPUT
      
      - name: Get latest PyPI version
        id: latest
        run: |
          # Query PyPI for the latest version
          LATEST=$(curl -s https://pypi.org/pypi/openfisca-country-template/json | jq -r '.info.version')
          echo "version=$LATEST" >> $GITHUB_OUTPUT
      
      - name: Compare and notify
        run: |
          if [ "${{ steps.current.outputs.version }}" != "${{ steps.latest.outputs.version }}" ]; then
            echo "::warning::New Country Template version available: ${{ steps.latest.outputs.version }} (current: ${{ steps.current.outputs.version }})"
          fi
```

**Why PyPI over GitHub Tags:**
- PyPI is the authoritative source for pip-installable versions
- Simpler API: single JSON endpoint returns the latest version directly
- Both packages are actively published to PyPI ([OpenFisca-Core](https://pypi.org/project/OpenFisca-Core/), [openfisca-country-template](https://pypi.org/project/openfisca-country-template/))

### Option 4: RSS/Webhook Notifications

Subscribe to package update notifications:

**PyPI RSS Feeds (Recommended):**
- **OpenFisca Core**: `https://pypi.org/rss/project/openfisca-core/releases.xml`
- **Country Template**: `https://pypi.org/rss/project/openfisca-country-template/releases.xml`

**GitHub Alternatives:**
- **GitHub Tags Atom Feed**: `https://github.com/openfisca/openfisca-core/tags.atom` (recommended - works with tags)
- **GitHub Watch**: Watch the repos for all activity (note: "Watch → Releases" won't work as OpenFisca uses tags, not formal GitHub Releases)

**Tip:** Use an RSS reader or integrate with Slack/Teams to receive notifications when new versions are published to PyPI.

## Automated Testing Strategies

### Strategy 1: Matrix Testing for Version Compatibility

Extend the CI workflow to test multiple version combinations:

```yaml
name: Compatibility Matrix

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  test-matrix:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        openfisca_core: ['43.4.3', '43.5.0', 'latest']
        country_template: ['8.0.1', '8.1.0']
        exclude:
          # Exclude known incompatible combinations
          - openfisca_core: '43.4.3'
            country_template: '8.1.0'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build with matrix versions
        run: |
          docker build \
            --build-arg OPENFISCA_CORE_VERSION=${{ matrix.openfisca_core }} \
            --build-arg COUNTRY_TEMPLATE_VERSION=${{ matrix.country_template }} \
            -f images/rules-as-code/Dockerfile \
            -t test-image \
            images/rules-as-code
      
      - name: Run tests
        run: |
          docker run --rm test-image sh -c \
            'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
      
      - name: Record compatible versions
        if: success()
        run: |
          echo "✅ Compatible: Core ${{ matrix.openfisca_core }} + Template ${{ matrix.country_template }}"
```

### Strategy 2: Nightly Builds Against Latest

```yaml
name: Nightly Latest Build

on:
  schedule:
    - cron: '0 2 * * *'  # 2am UTC daily

jobs:
  test-latest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Get latest versions from PyPI
        id: versions
        run: |
          # Query PyPI for latest versions
          CORE=$(curl -s https://pypi.org/pypi/OpenFisca-Core/json | jq -r '.info.version')
          TEMPLATE=$(curl -s https://pypi.org/pypi/openfisca-country-template/json | jq -r '.info.version')
          echo "core=$CORE" >> $GITHUB_OUTPUT
          echo "template=$TEMPLATE" >> $GITHUB_OUTPUT
      
      - name: Build with latest versions
        run: |
          docker build \
            --build-arg OPENFISCA_CORE_VERSION=${{ steps.versions.outputs.core }} \
            --build-arg COUNTRY_TEMPLATE_VERSION=${{ steps.versions.outputs.template }} \
            -f images/rules-as-code/Dockerfile \
            -t test-latest \
            images/rules-as-code
      
      - name: Run tests
        id: tests
        continue-on-error: true
        run: |
          docker run --rm test-latest sh -c \
            'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
      
      - name: Notify on failure
        if: steps.tests.outcome == 'failure'
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Nightly build failed with latest OpenFisca versions`,
              body: `The nightly build against latest upstream versions has failed.
              
              **Tested versions:**
              - OpenFisca Core: ${{ steps.versions.outputs.core }}
              - Country Template: ${{ steps.versions.outputs.template }}
              
              Please investigate compatibility issues.`,
              labels: ['nightly-failure', 'investigation-needed']
            });
```

### Strategy 3: Pre-release Testing

Test against pre-release/RC versions to catch issues early:

```yaml
- name: Test against pre-release
  run: |
    # Get all versions including pre-releases
    ALL_VERSIONS=$(curl -s https://pypi.org/pypi/OpenFisca-Core/json | jq -r '.releases | keys[]')
    # Filter for recent pre-releases (rc, beta, alpha)
    PRE_RELEASE=$(echo "$ALL_VERSIONS" | grep -E '(rc|beta|alpha)' | tail -1)
    if [ -n "$PRE_RELEASE" ]; then
      echo "Testing pre-release: $PRE_RELEASE"
      # Build and test...
    fi
```

## Docker Best Practices

### Current Implementation Review

The current Dockerfile follows many best practices but could be improved:

#### ✅ Good Practices Already Implemented
- Uses official Lagoon base image
- Pins specific versions
- Uses multi-stage concept (though single stage)
- Cleans up tar files after extraction

#### 🔧 Potential Improvements

**1. Layer Optimisation**

```dockerfile
# Current: Multiple RUN commands
RUN apk add build-base linux-headers yaml-dev bash git
RUN pip install OpenFisca-Core[web-api]==$OPENFISCA_CORE_VERSION

# Improved: Combine where logical, but keep logical separation
RUN apk add --no-cache build-base linux-headers yaml-dev bash git && \
    pip install --no-cache-dir OpenFisca-Core[web-api]==$OPENFISCA_CORE_VERSION
```

**2. Build Arguments for Flexibility**

```dockerfile
# Add at top of Dockerfile
ARG OPENFISCA_CORE_VERSION=43.4.3
ARG COUNTRY_TEMPLATE_VERSION=8.0.1

# Then use in ENV
ENV OPENFISCA_CORE_VERSION=${OPENFISCA_CORE_VERSION}
ENV COUNTRY_TEMPLATE_VERSION=${COUNTRY_TEMPLATE_VERSION}
```

**3. Health Check**

```dockerfile
# Add health check for container orchestration
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8800/ || exit 1
```

**4. Labels for Metadata**

```dockerfile
# Add OCI labels
LABEL org.opencontainers.image.source="https://github.com/salsadigitalauorg/salsa-images"
LABEL org.opencontainers.image.description="OpenFisca Rules As Code base image"
LABEL org.opencontainers.image.version="${OPENFISCA_CORE_VERSION}"
LABEL org.opencontainers.image.vendor="Salsa Digital"
```

**5. Security Scanning**

Add to CI/CD workflow:

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

**6. Non-root User (If Lagoon allows)**

```dockerfile
# Create non-root user (check Lagoon compatibility first)
RUN adduser -D -u 1000 openfisca
USER openfisca
```

### Base Image Updates

Monitor the Lagoon base image for updates:

```yaml
# In renovate.json or as a scheduled workflow
{
  "regexManagers": [
    {
      "fileMatch": ["^images/rules-as-code/Dockerfile$"],
      "matchStrings": [
        "FROM uselagoon/python-(?<currentValue>.*?):latest"
      ],
      "datasourceTemplate": "docker",
      "depNameTemplate": "uselagoon/python"
    }
  ]
}
```

## Implementation Roadmap

### Phase 1: Quick Wins (1-2 days)

- [ ] Add ARG/ENV pattern for version flexibility in Dockerfile
- [ ] Add HEALTHCHECK to Dockerfile
- [ ] Add OCI labels to Dockerfile
- [ ] Create `.github/dependabot.yml` for Python dependencies

### Phase 2: Monitoring (3-5 days)

- [ ] Create upstream version check workflow (`.github/workflows/check-upstream.yml`)
- [ ] Configure Renovate Bot for Dockerfile version monitoring
- [ ] Set up GitHub notifications for OpenFisca releases

### Phase 3: Automated Testing (1 week)

- [ ] Add matrix testing workflow for version compatibility
- [ ] Add nightly builds against latest upstream
- [ ] Add security scanning with Trivy

### Phase 4: Documentation Automation (Optional)

- [ ] Create `versions.json` as single source of truth
- [ ] Add workflow to generate version badges
- [ ] Consider automated documentation updates (with careful review)

## Recommended Approach

For this repository, we recommend:

1. **Monitor PyPI** (not GitHub tags) - Both [OpenFisca-Core](https://pypi.org/project/OpenFisca-Core/) and [openfisca-country-template](https://pypi.org/project/openfisca-country-template/) are published to PyPI, which is the authoritative source for pip installations
2. **Renovate Bot** for automated dependency monitoring - native PyPI datasource support with automatic PR creation
3. **Weekly upstream check workflow** as a backup notification system
4. **Matrix testing** to validate compatibility before updating
5. **Keep manual documentation updates** - automated doc updates can introduce errors; the current manual process with clear update checklists is acceptable

The goal is to be **notified promptly** of new versions while **maintaining control** over when updates are applied, ensuring thorough testing before deployment.

## Resources

### Tooling
- [Renovate Bot Documentation](https://docs.renovatebot.com/)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

### OpenFisca Core
- [PyPI Package](https://pypi.org/project/OpenFisca-Core/)
- [GitHub Repository](https://github.com/openfisca/openfisca-core)
- [Changelog](https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md)

### Country Template
- [PyPI Package](https://pypi.org/project/openfisca-country-template/)
- [GitHub Repository](https://github.com/openfisca/country-template)

