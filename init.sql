CREATE SCHEMA my_schema;

CREATE TABLE my_schema.employee (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department VARCHAR(100)
);
