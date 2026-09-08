CREATE SCHEMA my_schema;

CREATE TABLE my_schema.employee(
    id SERIAL_PRIMARY_KEY,
    name VARCHAR(100) NOT NULL,
    department VARCHAR(100),
);
