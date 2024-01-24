FROM uselagoon/python-3.11:latest

ENV COUNTRY_TEMPLATE_VERSION=6.0.1
ENV OPENFISCA_CORE_VERSION=41.4.1
ENV COUNTRY_NAME=rules

EXPOSE 3000
WORKDIR /app

# Install OpenFisca-Core dependencies
RUN apk add build-base linux-headers yaml-dev

# Install OpenFisca-Core
RUN pip install OpenFisca-Core[web-api]==$OPENFISCA_CORE_VERSION

# Install country-template
ADD https://github.com/openfisca/country-template/archive/refs/tags/$COUNTRY_TEMPLATE_VERSION.tar.gz /app
RUN tar -xzf /app/$COUNTRY_TEMPLATE_VERSION.tar.gz -C /app && \
    rm /app/$COUNTRY_TEMPLATE_VERSION.tar.gz && \
    mv /app/country-template-$COUNTRY_TEMPLATE_VERSION /app/country-template

# Copy bootstrap.sh to country-template and run it
COPY bootstrap.sh /app
RUN . /app/bootstrap.sh

ENTRYPOINT ["openfisca", "serve", "--bind", "0.0.0.0:3000"]
