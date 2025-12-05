# Rules As Code (OpenFisca)

This provides a standardised version of [OpenFisca](https://openfisca.org/en/) which is compatible with Lagoon hosting environments. It creates a ready-to-use OpenFisca instance pre-configured with the Country Template, transformed into a jurisdiction-specific rules package.

## Quick Start

### Prerequisites

- Docker installed and running
- Docker Buildx for multi-platform builds (optional)
- Basic understanding of OpenFisca concepts (optional but helpful)

### Run Pre-built Image

```bash
docker pull ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest
docker run --rm -p 8800:8800 ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest
```

Access the API at: http://localhost:8800

## Local Build and Test

### Build

```bash
docker build -f images/rules-as-code/Dockerfile -t rules-as-code images/rules-as-code
```

### Test

```bash
docker run --rm -d --name rules-as-code rules-as-code
docker exec rules-as-code sh -c 'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
docker stop rules-as-code
```

### Verify Service

```bash
# Start service
docker run --rm -d --name rules-as-code -p 8800:8800 rules-as-code

# Check endpoint
curl http://localhost:8800/

# Check installed packages
docker exec rules-as-code pip list | grep openfisca

# Stop service
docker stop rules-as-code
```

## Production Deployment

### Automated Build & Deploy (Recommended)

The image is automatically built and published via GitHub Actions on every push to the repository.

**Workflow**: `.github/workflows/rules-as-code.yml`

The CI/CD pipeline:
1. **Test Job**: Builds the image and runs OpenFisca tests
2. **Deploy Job**: If tests pass, builds multi-platform images and pushes to GitHub Container Registry

**Triggered by**: Any push to any branch

**Image Tags**: Automatically generated based on:
- Branch name (e.g., `main`, `develop`)
- Git tags (e.g., `2.1.1` creates tags `2.1.1` and `latest`)
- Pull requests (e.g., `pr-2`)

To deploy:
```bash
# Simply push your changes
git add .
git commit -m "Update OpenFisca version"
git push

# Or create a release tag
git tag 2.1.1
git push origin 2.1.1
```

### Manual Build & Push (Debugging Only)

⚠️ **Use manual builds only when debugging issues with the GitHub Actions workflow.**

```bash
docker buildx build --pull --rm --platform linux/amd64,linux/arm64 \
  -f "images/rules-as-code/Dockerfile" \
  -t ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest \
  "images/rules-as-code" --push
```

**Requirements for manual push:**
- Docker Buildx installed
- Authenticated with GitHub Container Registry: `docker login ghcr.io`
- Write permissions to the repository

### Lagoon Configuration

The image is pre-configured for Lagoon environments:
- **Port**: 8800 (hardcoded in Dockerfile)
- **Base Image**: uselagoon/python-3.12
- **Health Check**: API responds at root endpoint (`/`)

## What's Included

### Core Components

- **OpenFisca Core 43.4.3**: The rules-as-code engine with web API
- **Country Template 8.0.1**: Starter template transformed into `openfisca_rules` package
- **Additional Libraries**:
  - pandas >=2.3.3,<3.0.0 - For data manipulation and simulations
  - matplotlib >=3.10.7,<4.0.0 - For data visualisation

### Configuration

The image uses these environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `COUNTRY_TEMPLATE_VERSION` | 8.0.1 | Country template release to use |
| `OPENFISCA_CORE_VERSION` | 43.4.3 | OpenFisca Core engine version |
| `JURISDICTION_NAME` | rules | Jurisdiction identifier for package naming |
| `LAGOON_LOCALDEV_HTTP_PORT` | 8800 | Pygmy local development port indicator |

## Documentation

- **[DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md)** - Comprehensive developer guide with architecture explanation, development workflow, and version management
- **[MAINTAINABILITY.md](./MAINTAINABILITY.md)** - Strategies for automated dependency monitoring, version management, and Docker best practices
- **[OpenFisca Documentation](https://openfisca.org/doc/)** - Official OpenFisca documentation
- **[Country Template](https://github.com/openfisca/country-template)** - Upstream template repository

## Common Use Cases

### 1. Creating a Custom OpenFisca Application (Recommended)

Use the **openfisca-template** for a complete project setup:

```bash
# Clone the template
git clone https://github.com/salsadigitalauorg/openfisca-template my-project
cd my-project

# Initialise with your project name
ahoy init

# Start development
ahoy build
```

**See**: [openfisca-template documentation](https://github.com/salsadigitalauorg/openfisca-template/blob/main/DEVELOPER_GUIDE.md) for full guide.

### 2. Quick Testing with Default Rules

```bash
# Start API server with default country template rules
docker run --rm -d --name rules-api -p 8800:8800 rules-as-code

# Access the API
curl http://localhost:8800/

# Run built-in tests
docker exec rules-api openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests

# Stop when done
docker stop rules-api
```

### 3. Custom Dockerfile (Advanced)

For custom setups, extend the base image:

```dockerfile
FROM ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest

# Remove default rules
RUN rm -rf /app/openfisca-rules/openfisca_rules/*

# Copy your custom rules
COPY ./my-rules /app/openfisca-rules/openfisca_rules/
```

Build and run:
```bash
docker build -t my-openfisca-app .
docker run --rm -p 8800:8800 my-openfisca-app
```

## Troubleshooting

### Port Already in Use

```bash
# Use a different host port
docker run --rm -p 8801:8800 rules-as-code
```

### Check Container Logs

```bash
docker logs <container-name>
```

### Interactive Debugging

```bash
docker run --rm -it rules-as-code bash
# Inside container:
cd openfisca-rules
openfisca test --country-package openfisca_rules openfisca_rules/tests/
```

## Updating Versions

See [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md) for detailed instructions on:
- Updating OpenFisca Core version
- Updating Country Template version
- Understanding the build process and architecture
- Development workflow and best practices
