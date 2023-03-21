CREATE TABLE departments( 
  department_id number(10) NOT NULL PRIMARY KEY,
  department_name varchar2(50) NOT NULL
);

CREATE TABLE employees(
  employee_number number(10) NOT NULL PRIMARY KEY,
  employee_name varchar2(50) NOT NULL,
  department_id number(10),
  salary number(6),
  CONSTRAINT fk_departments
    FOREIGN KEY (department_id)
    REFERENCES departments(department_id)
);

ALTER TABLE departments
  ADD departemnt_mystery varchar2(45);