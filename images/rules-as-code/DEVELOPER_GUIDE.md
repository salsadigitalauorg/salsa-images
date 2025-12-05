# Rules As Code - Developer Guide

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Design Philosophy](#design-philosophy)
- [Understanding the Build Process](#understanding-the-build-process)
- [CI/CD Pipeline](#cicd-pipeline)
- [Version Management](#version-management)
- [Development Workflow](#development-workflow)
- [Updating Dependencies](#updating-dependencies)
- [Troubleshooting](#troubleshooting)
- [Maintainability](#maintainability)

## Architecture Overview

This Docker image provides a standardised OpenFisca environment that is compatible with Lagoon hosting environments. It combines three key components:

1. **OpenFisca Core** - The rules-as-code engine with web API
2. **Country Template** - A starter template for jurisdiction-specific rules
3. **Additional OpenFisca Packages** - Data analysis libraries (pandas, matplotlib) for simulations
4. **Lagoon Configuration** - Base image and environment variables for Lagoon Dev

### Why This Design?

The image is designed to:
- **Provide a baseline**: Create a working OpenFisca instance with minimal configuration
- **Enable rapid deployment**: Pre-configure everything needed for Lagoon hosting
- **Support customisation**: Teams use [openfisca-template](https://github.com/salsadigitalauorg/openfisca-template) to replace the default rules with their jurisdiction-specific rules
- **Maintain version control**: Pin specific versions of core dependencies for reproducibility
- **Simplify onboarding**: New projects can start with tested, working rules

## Design Philosophy

### Base Image Approach

Rather than starting from scratch, we:
1. Use the official OpenFisca Country Template as a foundation
2. Automatically transform it into the `openfisca_rules` package (using `JURISDICTION_NAME=rules`)
3. Install it as an editable Python package during build time
4. Expose a web API ready for immediate use

This approach means:
- ✅ You get best-practice rule structures from OpenFisca maintainers
- ✅ Updates to the country template can be easily incorporated
- ✅ The image works out-of-the-box for testing and demonstrations
- ✅ Teams can use [openfisca-template](https://github.com/salsadigitalauorg/openfisca-template) to build real-world applications on this base

### Purpose of first-time-setup.sh

The `first-time-setup.sh` script is a **critical component** that transforms the generic Country Template into a jurisdiction-specific implementation. It:

**What it does:**
1. **Renames the package**: Converts `openfisca_country_template` → `openfisca_rules` (or your custom jurisdiction name)
2. **Updates references**: Finds and replaces all references throughout the codebase
3. **Customises metadata**: Updates pyproject.toml, README, and configuration files
4. **Installs the package**: Makes the jurisdiction package available to the Python environment

**Why it's needed:**
- OpenFisca requires a properly named package that matches the jurisdiction
- The country template is intentionally generic and must be customised
- Running this during Docker build ensures consistency across all deployments
- It automates what would otherwise be tedious manual find-and-replace work

**Key transformations:**
```bash
# Package naming (fixed in base image)
JURISDICTION_NAME="rules"  # ⚠️ Fixed - do not change
  → lowercase_jurisdiction_name="rules"
  → NO_SPACES_JURISDICTION_LABEL="rules" 
  → SNAKE_CASE_JURISDICTION="rules"
  → package_name="openfisca_rules"

# File operations
openfisca_country_template/ → openfisca_rules/
All imports updated to use openfisca_rules
All configuration updated to reference new package name

# Result: /app/openfisca-rules/openfisca_rules/
# This path is expected by openfisca-template
```

## Understanding the Build Process

### Build Stages

The Dockerfile executes these stages in order:

```dockerfile
# Stage 1: Base environment
FROM uselagoon/python-3.12:latest
ENV variables set for versions and configuration

# Stage 2: System dependencies
RUN apk add build-base linux-headers yaml-dev bash git

# Stage 3: OpenFisca Core installation
RUN pip install OpenFisca-Core[web-api]==$OPENFISCA_CORE_VERSION

# Stage 4: Additional Python packages
COPY requirements.txt + pip install

# Stage 5: Country Template download and extraction
ADD country-template from GitHub
RUN tar extract and rename to openfisca-$JURISDICTION_NAME

# Stage 6: Jurisdiction setup
COPY first-time-setup.sh
RUN execute setup script (transforms template → jurisdiction package)

# Stage 7: Service startup
CMD start OpenFisca web API server
```

### Why This Order?

1. **System deps first**: Required for compiling Python packages
2. **Core before template**: Template depends on Core being available
3. **Template before setup**: Setup script operates on the template files
4. **Setup before CMD**: Package must be installed before server can use it

### Version Pinning Strategy

**Why We Pin OpenFisca Core Instead of Relying on Country Template Dependencies**

The Dockerfile explicitly pins the OpenFisca Core version:

```dockerfile
ENV OPENFISCA_CORE_VERSION=43.4.3
RUN pip install OpenFisca-Core[web-api]==$OPENFISCA_CORE_VERSION
```

Rather than letting the Country Template's `pyproject.toml` determine the version:

```toml
# Country Template pyproject.toml
dependencies = [
    "openfisca-core[web-api]>=43",
]
```

**Reasons for explicit pinning:**

1. **Reproducibility**: 
   - Ensures every build produces identical results
   - `>=43` in template could install 43.0.0, 43.4.3, or 44.0.0 depending on when you build
   - Critical for production environments and debugging

2. **Stability**:
   - Country Template uses flexible constraints (`>=43`) for general compatibility
   - Our base image prioritises predictability over flexibility
   - Prevents unexpected behaviour from automatic updates

3. **Testing Control**:
   - We can thoroughly test a specific Core + Template combination
   - Version updates are deliberate, not automatic
   - CI/CD pipeline validates exact version combinations

4. **Compatibility Assurance**:
   - We verify that Core version works with our specific Template version
   - Country Template may support a range, but we guarantee a specific pairing
   - Example: Core 43.4.3 + Template 8.0.1 = tested and validated

5. **Deployment Consistency**:
   - All environments (dev, staging, prod) use identical versions
   - No surprises from pip installing "latest compatible version"
   - Image built in January = same as image built in December

**The Trade-off**:

| Approach | Pros | Cons |
|----------|------|------|
| **Pin in Dockerfile** (our approach) | Reproducible, predictable, tested | Must manually update versions |
| **Rely on template dependency** | Auto-updates, less maintenance | Unpredictable, may break without warning |

**When to Update**:
- Security patches in OpenFisca Core
- New features needed from Core
- Bug fixes in Core
- Regular maintenance cycle (every 3-6 months)

**How to Update Safely**:
1. Check [OpenFisca Core on PyPI](https://pypi.org/project/OpenFisca-Core/) for available versions
2. Verify compatibility with Country Template version in [pyproject.toml](https://github.com/openfisca/country-template/blob/8.0.1/pyproject.toml) (use the specific tag version)
3. Update `OPENFISCA_CORE_VERSION` in Dockerfile
4. Build and test thoroughly
5. Let CI/CD validate the new combination
6. Deploy with confidence

**Example Compatibility Check**:

```bash
# Country Template 8.0.1 requires:
openfisca-core[web-api]>=43

# We can safely use any Core version 43.x.x
# Currently pinned to: 43.4.3
# Could update to: 43.5.0 (within compatible range)
# Should test before: 44.0.0 (major version bump - may break)
```

See the [Country Template pyproject.toml](https://github.com/openfisca/country-template/blob/8.0.1/pyproject.toml) for the specific version's dependency requirements (replace `8.0.1` with your `COUNTRY_TEMPLATE_VERSION`).

## CI/CD Pipeline

### GitHub Actions Workflow

The image is automatically built, tested, and published using GitHub Actions whenever code is pushed to the repository.

**Workflow File**: `.github/workflows/rules-as-code.yml`

### Pipeline Overview

```
Push to Repository
        ↓
┌───────────────────┐
│   Test Job        │
│  (ubuntu-latest)  │
├───────────────────┤
│ 1. Checkout code  │
│ 2. Build image    │
│ 3. Run tests      │
└────────┬──────────┘
         │
    [Tests Pass?]
         │
         ↓ Yes
┌───────────────────┐
│  Deploy Job       │
│  (ubuntu-latest)  │
├───────────────────┤
│ 1. Checkout code  │
│ 2. Setup QEMU     │
│ 3. Setup Buildx   │
│ 4. Login to GHCR  │
│ 5. Extract tags   │
│ 6. Build & Push   │
│    multi-platform │
└───────────────────┘
         ↓
    Published to
    ghcr.io
```

### Test Job

**Purpose**: Validate that the image builds correctly and OpenFisca tests pass

**Steps**:
1. Checks out the repository code
2. Builds the Docker image for the host platform (linux/amd64)
3. Runs the image in a container
4. Executes OpenFisca test suite against the built-in rules
5. Stops the container

**Why it matters**: Prevents broken images from being published. If tests fail, the deploy job never runs.

### Deploy Job

**Purpose**: Build multi-platform images and publish to GitHub Container Registry

**Requirements**:
- Test job must complete successfully
- Requires `contents: read` and `packages: write` permissions

**Steps**:
1. **QEMU Setup**: Enables building for multiple CPU architectures
2. **Buildx Setup**: Configures Docker's advanced build capabilities
3. **Authentication**: Logs into GitHub Container Registry using automatic token
4. **Metadata Extraction**: Generates image tags based on Git context
5. **Multi-Platform Build**: Builds for both linux/amd64 and linux/arm64
6. **Push**: Publishes all tags to the registry

### Automatic Image Tags

The workflow automatically generates tags based on your Git context using [docker/metadata-action@v5](https://github.com/docker/metadata-action):

| Git Action | Ref | Generated Tags | Example |
|------------|-----|----------------|---------|
| Push to main | `refs/heads/main` | `main` | `rules-as-code:main` |
| Push to branch | `refs/heads/develop` | `develop` | `rules-as-code:develop` |
| Push tag | `refs/tags/2.1.1` | `2.1.1`, `latest` | `rules-as-code:2.1.1`, `rules-as-code:latest` |
| Pull request | `refs/pull/2/merge` | `pr-2` | `rules-as-code:pr-2` |

### Using the CI/CD Pipeline

#### Standard Deployment

```bash
# 1. Make your changes (e.g., update versions in Dockerfile)
vim images/rules-as-code/Dockerfile

# 2. Commit changes
git add images/rules-as-code/Dockerfile
git commit -m "Update OpenFisca Core to 43.4.3"

# 3. Push to trigger workflow
git push origin main

# 4. Monitor workflow
# Visit: https://github.com/salsadigitalauorg/salsa-images/actions

# 5. Pull updated image
docker pull ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest
```

#### Creating a Release

```bash
# 1. Ensure main branch is ready
git checkout main
git pull

# 2. Create and push a tag
git tag -a 2.1.1 -m "Release version 2.1.1 - OpenFisca Core 43.4.3"
git push origin 2.1.1

# 3. Workflow creates image tags automatically
# Available tags: 2.1.1, latest
```

#### Development Branch Testing

```bash
# 1. Create feature branch
git checkout -b feature/update-dependencies

# 2. Make changes and push
git add .
git commit -m "Test new OpenFisca version"
git push origin feature/update-dependencies

# 3. Image published with branch tag
docker pull ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:feature-update-dependencies
```

### Manual Builds (Debugging Only)

⚠️ **Only use manual builds when the GitHub Actions workflow is failing and you need to debug or push urgently.**

#### Prerequisites for Manual Push

```bash
# 1. Authenticate with GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 2. Verify Buildx is available
docker buildx version

# 3. Create builder if needed
docker buildx create --name multiplatform --use
```

#### Manual Build and Push

**Step 1: Build without pushing (verify build works)**

```bash
# Single platform build (testing on local architecture)
docker build -f images/rules-as-code/Dockerfile \
  -t ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:debug \
  images/rules-as-code

# Test the local build
docker run --rm -d --name test-debug ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:debug
docker exec test-debug sh -c 'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
docker stop test-debug

# Multi-platform build WITHOUT push (verify both platforms build)
docker buildx build --pull --rm \
  --platform linux/amd64,linux/arm64 \
  -f "images/rules-as-code/Dockerfile" \
  -t ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:debug-$(date +%Y%m%d) \
  "images/rules-as-code"

# Note: Multi-platform builds without --push don't load to local Docker
# They verify both platforms compile successfully
```

**Step 2: Push to registry (only after verification)**

⚠️ **WARNING**: This will push directly to the production registry. Ensure:
- You have verified the build works locally
- You have tested the image functionality
- You understand why the GitHub Actions workflow cannot be used
- You have appropriate permissions and are authenticated

```bash
# Push multi-platform build to registry
docker buildx build --pull --rm \
  --platform linux/amd64,linux/arm64 \
  -f "images/rules-as-code/Dockerfile" \
  -t ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:manual-$(date +%Y%m%d) \
  "images/rules-as-code" --push

# Optionally tag as latest (use with extreme caution)
# docker buildx build --pull --rm \
#   --platform linux/amd64,linux/arm64 \
#   -f "images/rules-as-code/Dockerfile" \
#   -t ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest \
#   "images/rules-as-code" --push
```

**When to use manual builds:**
- GitHub Actions is down or experiencing issues
- You need to test a specific platform locally
- Debugging build failures that don't reproduce in CI
- Emergency hotfix that can't wait for CI (rare)

**Always prefer the automated pipeline** because it:
- ✅ Runs tests automatically
- ✅ Builds both platforms consistently
- ✅ Generates proper tags
- ✅ Provides audit trail
- ✅ Requires no local setup

### Monitoring Builds

**GitHub Actions UI**:
1. Go to repository → Actions tab
2. Click on "Rules As Code build" workflow
3. View current and historical runs
4. Download logs for failed builds

**Check Published Images**:
```bash
# List all tags for the image
# Visit: https://github.com/salsadigitalauorg/salsa-images/pkgs/container/rules-as-code

# Or use Docker
docker manifest inspect ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest
```

### Troubleshooting CI/CD

#### Build Fails in Test Job

**Check**: Build logs for error messages
```bash
# Common causes:
# - Syntax error in Dockerfile
# - Package version doesn't exist
# - Network timeout downloading dependencies
```

**Solution**: Fix the issue locally first
```bash
# Test build locally
docker build -f images/rules-as-code/Dockerfile -t test images/rules-as-code

# Run tests locally
docker run --rm -d --name test-rules test
docker exec test-rules sh -c 'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
docker stop test-rules
```

#### Tests Fail But Build Succeeds

**Check**: Test output in workflow logs

**Common causes**:
- Country template updated its test structure
- OpenFisca Core version incompatible with template
- Custom modifications broke existing tests

**Solution**: Review and update tests or version compatibility

#### Deploy Job Doesn't Run

**Check**: Test job status - deploy only runs if tests pass

**Solution**: Fix failing tests first

#### Push to Registry Fails

**Check**: Permissions and authentication

**Common causes**:
- Repository permissions incorrect
- GITHUB_TOKEN expired (unlikely, auto-generated)
- Registry quota exceeded

**Solution**: Check repository settings → Actions → General → Workflow permissions

## Version Management

### Key Version Variables

The Dockerfile defines these pinned versions:

```dockerfile
ENV COUNTRY_TEMPLATE_VERSION=8.0.1      # Country template structure
ENV OPENFISCA_CORE_VERSION=43.4.3     # OpenFisca engine
ENV JURISDICTION_NAME=rules             # Fixed as "rules" (do not change)
ENV LAGOON_LOCALDEV_HTTP_PORT=8800     # Pygmy local development port indicator
```

⚠️ **Note**: `JURISDICTION_NAME=rules` is **fixed** in the base image. Do not change it, as [openfisca-template](https://github.com/salsadigitalauorg/openfisca-template) depends on this path (`/app/openfisca-rules/`). Your jurisdiction-specific customisation happens in your project (via openfisca-template), not in the base image.

### Version Dependencies

```
Python 3.12 (from base image)
    ↓
OpenFisca-Core 43.4.3
    ↓
Country Template 8.0.1
    ↓
openfisca_rules package (custom)
```

### Compatibility Matrix

| Component | Version | Notes |
|-----------|---------|-------|
| Python | 3.12 | From uselagoon base image |
| OpenFisca-Core | 43.4.3 | Includes web-api extras |
| Country Template | 8.0.1 | Must be compatible with Core version |
| pandas | >=2.3.3,<3.0.0 | For data simulations |
| matplotlib | >=3.10.7,<4.0.0 | For visualisations |

### Automated Version Updates

For automated OpenFisca Core version updates using an AI agent, see [AI_VERSION_UPDATE_PROMPT.md](./AI_VERSION_UPDATE_PROMPT.md). This prompt provides step-by-step instructions for checking for newer versions, updating the Dockerfile, testing locally, monitoring CI/CD, and creating pull requests.

## Development Workflow

### Creating a Custom OpenFisca Application

This base image is designed to be extended with your custom rules. The recommended approach is to use the **openfisca-template** project template.

#### Using the OpenFisca Template (Recommended)

The `openfisca-template` repository provides a complete project structure:

**Repository**: [openfisca-template](https://github.com/salsadigitalauorg/openfisca-template)

**What it provides**:
- Ready-to-use Dockerfile that extends this base image
- Complete development environment with Ahoy commands
- VS Code Dev Container support
- Lagoon hosting configuration
- Rule synchronisation from upstream Country Template
- Test-Driven Development workflow

**How it works**:
```dockerfile
# openfisca-template/.docker/py.dockerfile
FROM ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest

# Remove the default country template rules
RUN rm -rf /app/openfisca-rules/openfisca_rules/*

# Copy your custom rules
COPY openfisca_rules /app/openfisca-rules/openfisca_rules
```

**Quick start**:
```bash
# Clone the template
git clone https://github.com/salsadigitalauorg/openfisca-template my-project

# Initialise
cd my-project
ahoy init

# Start developing
ahoy build

# Test
ahoy test
```

**See**: [openfisca-template/DEVELOPER_GUIDE.md](https://github.com/salsadigitalauorg/openfisca-template/blob/main/DEVELOPER_GUIDE.md) for comprehensive usage guide.

#### Manual Approach (Advanced)

If you need a custom setup, create your own Dockerfile:

```dockerfile
FROM ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:${IMAGE_VERSION:-latest}

# Remove default rules
RUN rm -rf /app/openfisca-rules/openfisca_rules/*

# Copy your custom rules
COPY ./my-rules /app/openfisca-rules/openfisca_rules/

# The package is already installed in editable mode from base image
# Your rules will be loaded automatically
```

**Build and run**:
```bash
docker build -t my-openfisca-app .
docker run --rm -p 8800:8800 my-openfisca-app
```

### Testing Rule Changes

```bash
# Start container in background
docker run --rm -d --name rules-test rules-as-code

# Run OpenFisca tests
docker exec rules-test sh -c \
  'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'

# Interactive testing
docker exec -it rules-test bash
cd openfisca-rules
openfisca test --country-package openfisca_rules openfisca_rules/tests/

# Stop container
docker stop rules-test
```

### API Endpoint Testing

```bash
# Start service
docker run --rm -d --name rules-api -p 8800:8800 rules-as-code

# Check service health
curl http://localhost:8800/

# Example age calculation request
curl -X POST http://localhost:8800/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "persons": {
      "person1": {
        "birth": {"2025-01": "1970-01-01"},
        "age": {"2025-01": null}
      }
    }
  }'

# Stop service
docker stop rules-api
```

## Updating Dependencies

### Updating OpenFisca Core

1. **Check available versions** at [OpenFisca Core on PyPI](https://pypi.org/project/OpenFisca-Core/)

2. **Update Dockerfile**:
```dockerfile
ENV OPENFISCA_CORE_VERSION=43.4.3  # New version
```

3. **Test compatibility** with Country Template:
```bash
# Build test image
docker build -f images/rules-as-code/Dockerfile \
  -t rules-as-code:test images/rules-as-code

# Run tests
docker run --rm rules-as-code:test sh -c \
  'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
```

4. **Check for breaking changes** in the [changelog](https://github.com/openfisca/openfisca-core/blob/master/CHANGELOG.md)

### Updating Country Template

1. **Check available versions** at [Country Template on PyPI](https://pypi.org/project/openfisca-country-template/)

2. **Check compatibility** with your OpenFisca Core version:
   - Check the Country Template's [pyproject.toml dependencies](https://github.com/openfisca/country-template/blob/8.0.1/pyproject.toml) (use the specific tag version)
   - Look for `openfisca-core` version requirement (e.g., `openfisca-core[web-api]>=43`)

3. **Update Dockerfile**:
```dockerfile
ENV COUNTRY_TEMPLATE_VERSION=8.1.0  # New version
```

4. **Verify first-time-setup.sh compatibility**:
   - Country template updates may change file structure
   - Check if `first-time-setup.sh` script needs adjustments
   - Compare with [upstream script](https://github.com/openfisca/country-template/blob/8.0.1/first-time-setup.sh) (use the specific tag version)

5. **Test the build**:
```bash
docker build -f images/rules-as-code/Dockerfile \
  -t rules-as-code:test images/rules-as-code

# Verify package installation
docker run --rm rules-as-code:test pip list | grep openfisca

# Run tests
docker run --rm rules-as-code:test sh -c \
  'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
```

### Updating Additional Python Packages

Edit `requirements.txt`:

```txt
# Use version constraints to allow safe updates
pandas>=2.3.3,<3.0.0        # Major version pinned
matplotlib>=3.10.7,<4.0.0   # Major version pinned
```

**Version constraint strategies:**
- `==2.3.3` - Exact version (most restrictive)
- `>=2.3.3,<3.0.0` - Allow minor/patch updates (recommended)
- `>=2.3.3` - Allow all updates (risky)

### Update Checklist

When updating versions:

- [ ] Read release notes and changelogs
- [ ] Check compatibility between Core and Template versions
- [ ] Update `ENV` variables in Dockerfile
- [ ] Update `requirements.txt` if needed
- [ ] Build the image locally
- [ ] Run all tests
- [ ] Test API endpoints manually
- [ ] Document any breaking changes
- [ ] Update this document if process changes
- [ ] Test in Lagoon dev environment before production
- [ ] Tag release with version numbers in commit message

### Recommended Update Frequency

- **Security patches**: Immediately
- **OpenFisca Core**: Every 3-6 months (check for features/fixes)
- **Country Template**: As needed when beneficial features added
- **Python packages**: Every 6 months (check for security issues)

## Troubleshooting

### Build Failures

**Problem**: `pip install OpenFisca-Core` fails
```
Solution: Check if Core version exists and is compatible with Python 3.12
- Visit: https://pypi.org/project/OpenFisca-Core/ (check release history)
- Try without pinned version to test latest
```

**Problem**: Country template download fails
```
Solution: Verify template version exists
- Visit: https://pypi.org/project/openfisca-country-template/ (check version history)
- Or check GitHub tags: https://github.com/openfisca/country-template/tags
- Check tag name format (might have 'v' prefix)
```

**Problem**: first-time-setup.sh fails
```
Solution: Check if template structure has changed
- Compare with upstream script
- Check for new files/directories in template
- Verify sed commands still match file contents
```

### Runtime Issues

**Problem**: `ModuleNotFoundError: No module named 'openfisca_rules'`
```
Solution: first-time-setup.sh didn't complete successfully
- Check build logs for errors during setup stage
- Verify package was installed: pip list | grep openfisca
```

**Problem**: Port 8800 already in use
```
Solution: Change port mapping or stop conflicting service
docker run -p 8801:8800 rules-as-code  # Use different host port
```

**Problem**: API returns 500 errors
```
Solution: Check container logs and rule definitions
docker logs <container-name>
docker exec -it <container-name> bash
cd openfisca-rules
cat openfisca_rules/variables/*.py  # Check rule syntax
```

### Testing Issues

**Problem**: Tests fail after version update
```
Solution: Check for breaking changes in Core/Template
- Review changelogs
- Update test fixtures if needed
- Check if variable names or calculation methods changed
```

## Maintainability

For strategies on improving the long-term maintainability of this repository, including:

- **Automated dependency monitoring** - Using Renovate Bot or Dependabot
- **Version management improvements** - Reducing hardcoded version duplication
- **Automated testing strategies** - Matrix testing and nightly builds
- **Docker best practices** - Health checks, security scanning, and optimisation

See the **[MAINTAINABILITY.md](./MAINTAINABILITY.md)** guide.
