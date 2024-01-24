#!/bin/bash

set -e

lowercase_country_name=$(echo $COUNTRY_NAME | tr '[:upper:]' '[:lower:]')

mv country-template openfisca-$lowercase_country_name
cd openfisca-$lowercase_country_name
all_module_files=`find openfisca_country_template -type f ! -name "*.DS_Store"`

set -x

# Use intermediate backup files (`-i`) with a weird syntax due to lack of portable 'no backup' option. See https://stackoverflow.com/q/5694228/594053.
sed -i.template "s|country_template|$lowercase_country_name|g" setup.py setup.cfg Makefile MANIFEST.in $all_module_files
sed -i.template "s|Country-Template|$COUNTRY_NAME|g" setup.py $all_module_files
find . -name "*.template" -type f -delete

set +x

mv openfisca_country_template openfisca_$lowercase_country_name

# Install OpenFisca country template
pip install -e .