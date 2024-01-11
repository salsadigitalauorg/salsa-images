"""This file contains your openfisca package's metadata and dependencies."""

from pathlib import Path

from setuptools import find_packages, setup


this_directory = Path(__file__).parent
long_description = (this_directory / "README.md").read_text()  # pylint: disable=W1514

setup(
    name = "Openfisca-Rules",
    version = "0.0.1",
    author = "Salsa Digital",
    author_email = "info@salsa.digital",
    description = "The rules as code entrypoint.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    keywords = "",
    url = "",
    install_requires = [
        "openfisca-core[web-api] >= 41.0.0, < 42.0.0",
    ],
    extras_require = {
        "dev": [
            "autopep8 >= 2.0.2, < 3.0",
            "flake8 >= 6.0.0, < 7.0",
            "flake8-bugbear >= 23.3.23, < 24.0",
            "flake8-builtins >= 2.1.0, < 3.0",
            "flake8-coding >= 1.3.2, < 2.0",
            "flake8-commas >= 2.1.0, < 3.0",
            "flake8-comprehensions >= 3.11.1, < 4.0",
            "flake8-docstrings >= 1.7.0, < 2.0",
            "flake8-import-order >= 0.18.2, < 0.19.0",
            "flake8-print >= 5.0.0, < 6.0",
            "flake8-quotes >= 3.3.2, < 4.0",
            "flake8-simplify >= 0.19.3, < 0.20.0",
            "flake8-use-fstring >= 1.4, < 2",
            "importlib-metadata >= 6.1.0, < 7.0",
            "pycodestyle >= 2.10.0, < 3.0",
            "pylint >= 2.17.1, < 3.0",
        ],
    },
    packages = find_packages(),
)
