FROM pgvector/pgvector:pg16

COPY migrations /opt/crit-db/migrations
COPY seeds /opt/crit-db/seeds
COPY tests /opt/crit-db/tests
COPY scripts /opt/crit-db/scripts
COPY docker/postgres/init/010_initialize_database.sh /docker-entrypoint-initdb.d/010_initialize_database.sh

RUN sed -i 's/\r$//' /docker-entrypoint-initdb.d/010_initialize_database.sh \
    && sed -i 's/\r$//' /opt/crit-db/scripts/*.sh \
    && chmod +x /docker-entrypoint-initdb.d/010_initialize_database.sh /opt/crit-db/scripts/*.sh
