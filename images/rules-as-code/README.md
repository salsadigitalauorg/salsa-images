# Rules As Code (Openfisca)

This provides a standardised version of [OpenFisca](https://openfisca.org/en/) which is compatible with Lagoon hosting environments.

## Attribution

- [OpenFisca template](https://github.com/openfisca/country-template)

# Local Build and Test

## Build
```bash
docker build -f images/rules-as-code/Dockerfile -t rules-as-code images/rules-as-code
```

## Test
```bash
docker run --rm -d --name rules-as-code rules-as-code
docker exec rules-as-code sh -c 'openfisca test --country-package openfisca_rules openfisca-rules/openfisca_rules/tests'
docker stop rules-as-code
```

## Build & Push for Multi Platform
```bash
docker buildx build --pull --rm --platform linux/amd64,linux/arm64 -f "images/rules-as-code/Dockerfile" -t ghcr.io/salsadigitalauorg/salsa-images/rules-as-code:latest "images/rules-as-code" --push
```