FROM uselagoon/python-3.12:latest

ENV COUNTRY_TEMPLATE_VERSION=8.0.1
ENV OPENFISCA_CORE_VERSION=43.3.10
ENV JURISDICTION_NAME=rules
# tells the local development environment on which port we are running
ENV LAGOON_LOCALDEV_HTTP_PORT=8800

EXPOSE 8800
WORKDIR /app

# Install OpenFisca-Core dependencies
RUN apk add build-base linux-headers yaml-dev bash git

# Install OpenFisca-Core
RUN pip install OpenFisca-Core[web-api]==$OPENFISCA_CORE_VERSION

# Install country-template
ADD https://github.com/openfisca/country-template/archive/refs/tags/$COUNTRY_TEMPLATE_VERSION.tar.gz /app
RUN tar -xzf /app/$COUNTRY_TEMPLATE_VERSION.tar.gz -C /app && \
    rm /app/$COUNTRY_TEMPLATE_VERSION.tar.gz && \
    mv /app/country-template-$COUNTRY_TEMPLATE_VERSION /app/openfisca-$JURISDICTION_NAME

# Copy first-time-setup.sh to country-template and run it
COPY first-time-setup.sh /app/
RUN . /app/first-time-setup.sh

CMD ["openfisca", "serve", "--country-package", "openfisca_rules", "--bind", "0.0.0.0:8800"]
