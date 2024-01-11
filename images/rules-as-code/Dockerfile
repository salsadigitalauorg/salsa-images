FROM uselagoon/python-3.9:latest as build

WORKDIR /app/

RUN apk add gcc libc-dev g++ linux-headers yaml-dev
RUN pip wheel --wheel-dir=/app/wheel numpy==1.20.* numexpr==2.8.* psutil PyYAML


FROM uselagoon/python-3.9:latest

EXPOSE 3000

ARG PROJECT_NAME=rule
COPY openfisca_$PROJECT_NAME /app/openfisca_$PROJECT_NAME
COPY README.md setup.cfg setup.py /app/

WORKDIR /app/

COPY --from=build /app/ /app/
COPY README.md /app/openfisca_$PROJECT_NAME
RUN apk add gcc libc-dev g++ linux-headers yaml-dev libffi-dev
RUN pip install --no-index --find-links=/app/wheel numpy numexpr psutil PyYAML
RUN pip install -e /app


ENTRYPOINT ["openfisca", "serve", "--bind", "0.0.0.0:3000"]
