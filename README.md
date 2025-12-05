# Salsa Images

A collection of standardised Docker images for Salsa Digital projects, optimised for Lagoon hosting environments.

## Available Images

### [Rules As Code (OpenFisca)](./images/rules-as-code/)

A pre-configured OpenFisca environment for implementing rules-as-code solutions.

- **Base**: uselagoon/python-3.12
- **Purpose**: Provides OpenFisca Core with Country Template for jurisdiction-specific rule implementation
- **Use Cases**: Policy simulation, eligibility calculations, legislative rule encoding
- **Documentation**: [images/rules-as-code/README.md](./images/rules-as-code/README.md)

**Quick Start:**
```bash
docker pull ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest
docker run --rm -p 8800:8800 ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest
```

## Repository Structure

```
salsa-images/
├── images/
│   └── rules-as-code/           # OpenFisca image
│       ├── Dockerfile           # Image build configuration
│       ├── requirements.txt     # Python dependencies
│       ├── first-time-setup.sh  # Jurisdiction setup script
│       ├── README.md            # Usage documentation
│       ├── DEVELOPER_GUIDE.md   # Developer guide
│       └── MAINTAINABILITY.md   # Maintenance and automation strategies
└── README.md                    # This file
```

## Image Registry

All images are published to GitHub Container Registry:
- **Registry**: `ghcr.io/salsadigitalauorg/salsa-images`
- **Images**: `rules-as-code`
- **Platforms**: linux/amd64, linux/arm64

### Automated Builds

Images are automatically built and published via GitHub Actions:
- **Trigger**: Push to any branch or tag
- **Process**: Build → Test → Multi-platform build → Publish
- **Tags**: Automatically generated from branch names and tags
  - Push to `main` → `main` tag
  - Push to branch → `<branch-name>` tag
  - Push tag `2.1.1` → `2.1.1` and `latest` tags

View build status: [GitHub Actions](https://github.com/salsadigitalauorg/salsa-images/actions)

## Contributing

When adding new images to this repository:

1. Create a new directory under `images/`
2. Include a comprehensive README.md with:
   - Quick start guide
   - Build and test instructions
   - Configuration details
   - Usage examples
3. Add DEVELOPER_GUIDE.md for complex images (optional but recommended)
4. Use semantic versioning for image tags
5. Support multi-platform builds where possible
6. Test in Lagoon dev environment before production release

## General Build Patterns

### Automated Deployment (Recommended)

All images are automatically built and published via GitHub Actions:

```bash
# Make your changes
git add .
git commit -m "Update image configuration"
git push origin main

# Or create a release
git tag 2.1.1
git push origin 2.1.1
```

The CI/CD pipeline will:
1. Build the image
2. Run tests
3. Build for multiple platforms (amd64, arm64)
4. Push to GitHub Container Registry

### Local Build (Development/Testing)

```bash
docker build -f images/<image-name>/Dockerfile -t <image-name> images/<image-name>
```

### Manual Multi-Platform Build & Push (Debugging Only)

⚠️ **Only use when GitHub Actions is failing:**

```bash
docker buildx build --pull --rm --platform linux/amd64,linux/arm64 \
  -f "images/<image-name>/Dockerfile" \
  -t ghcr.io/salsadigitalauorg/salsa-images/<image-name>:latest \
  "images/<image-name>" --push
```

## Lagoon Compatibility

All images in this repository are designed to work with Amazee.io's Lagoon hosting platform:
- Based on or compatible with Lagoon base images
- Follow Lagoon conventions for ports and configuration
- Tested in Lagoon development and production environments
