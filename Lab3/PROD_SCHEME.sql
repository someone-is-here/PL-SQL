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
CREATE TABLE a1(
    x number,
    y number
);

create index a1_index on a1(x, y);

create index a1_x_index on a1(x);

ALTER TABLE departments
  ADD departemnt_mystery varchar2(45);
  
  
CREATE TABLE test_constr(
    id number NOT NULL PRIMARY KEY
);


CREATE OR REPLACE PROCEDURE greetings 
AS 
BEGIN 

   dbms_output.put_line('Hello World!'); 
   
END; 

CREATE OR REPLACE FUNCTION find_sum_1(number_1 NUMBER) 
    RETURN NUMBER 
    IS
    sum_ NUMBER;
    BEGIN
        sum_ := number_1;
        return sum_;
    END;

CREATE OR REPLACE FUNCTION find_sum(number_1 NUMBER, number_2 NUMBER) 
    RETURN NUMBER 
    IS
    sum_ NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('result');
        sum_ := number_1 + number_2;
        return sum_;
    END;
    