FROM postgres:16

#set PostgreSQL environment variables
ENV POSTGRES_DB=mydatabase
ENV POSTGRES_USER=myuser
ENV POSTGRES_PASSWORD=mypassword

COPY task-mapping-table.sql /docker-entrypoint-initdb.d/

EXPOSE 5432