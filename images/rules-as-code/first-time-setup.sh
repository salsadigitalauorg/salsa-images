#!/bin/bash
# Cut down updated version of the original script https://github.com/openfisca/country-template/blob/main/first-time-setup.sh

set -e
GREEN='\033[0;32m'
PURPLE='\033[1;35m'
YELLOW='\033[0;33m'
BLUE='\033[1;34m'
JURISDICTION_NAME=${JURISDICTION_NAME:-$COUNTRY_NAME}  # backwards compatibility

lowercase_jurisdiction_name=$(echo $JURISDICTION_NAME | tr '[:upper:]' '[:lower:]' | sed 'y/āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛ/aaaaeeeeiiiioooouuuuüüüüAAAAEEEEIIIIOOOOUUUUÜÜÜÜ/')
NO_SPACES_JURISDICTION_LABEL=$(echo $lowercase_jurisdiction_name | sed -r 's/[ ]+/_/g') # allow for hyphens to be used in jurisdiction names
SNAKE_CASE_JURISDICTION=$(echo $NO_SPACES_JURISDICTION_LABEL | sed -r 's/[-]+/_/g') # remove hyphens for use in Python
package_name="openfisca_$SNAKE_CASE_JURISDICTION"

echo -e "${PURPLE}Jurisdiction title set to: \033[0m${BLUE}$JURISDICTION_NAME\033[0m"
# Removes hyphens for python environment
echo -e "${PURPLE}Jurisdiction Python label: \033[0m${BLUE}$SNAKE_CASE_JURISDICTION\033[0m"

cd openfisca-$NO_SPACES_JURISDICTION_LABEL

all_module_files=`find openfisca_country_template -type f ! -name "*.DS_Store"`
echo -e "${PURPLE}*  ${PURPLE}Replace default country_template references\033[0m"
# Use intermediate backup files (`-i`) with a weird syntax due to lack of portable 'no backup' option. See https://stackoverflow.com/q/5694228/594053.
sed -i.template "s|openfisca-country_template|openfisca-$NO_SPACES_JURISDICTION_LABEL|g" README.md Makefile pyproject.toml CONTRIBUTING.md
sed -i.template "s|country_template|$SNAKE_CASE_JURISDICTION|g" README.md pyproject.toml Makefile MANIFEST.in $all_module_files
sed -i.template "s|Country-Template|$JURISDICTION_NAME|g" README.md pyproject.toml .github/PULL_REQUEST_TEMPLATE.md CONTRIBUTING.md

echo -e "${PURPLE}*  ${PURPLE}Prepare \033[0m${BLUE}pyproject.toml\033[0m"
sed -i.template 's|:: 5 - Production/Stable|:: 1 - Planning|g' pyproject.toml
sed -i.template 's|^version = "[0-9.]*"|version = "0.0.1"|g' pyproject.toml
find . -name "*.template" -type f -delete

mv openfisca_country_template $package_name

# Install OpenFisca country template
pip install -e .

echo -e "${YELLOW}*\033[0m  Bootstrap complete for $package_name.\033[0m"