FROM postgres:16-alpine

COPY migrations /opt/crit-db/migrations
COPY seeds /opt/crit-db/seeds
COPY tests /opt/crit-db/tests
COPY docker/postgres/init/010_initialize_database.sh /docker-entrypoint-initdb.d/010_initialize_database.sh
