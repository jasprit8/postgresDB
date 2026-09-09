FROM postgres:16

COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
COPY task-mapping-table.sql /docker-entrypoint-initdb.d/

EXPOSE 5432