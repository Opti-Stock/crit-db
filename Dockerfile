FROM postgres:16-alpine

COPY docker/postgres/init /docker-entrypoint-initdb.d
