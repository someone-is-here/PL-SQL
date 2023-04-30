create table country(
    id number PRIMARY KEY,
    name varchar2(56),
    abbr varchar2(2)
);
create table journal_country(
    op_id number PRIMARY KEY,
    op varchar2(1),
    op_time date,
    id number,
    name varchar2(56),
    abbr varchar2(2)
);
CREATE OR REPLACE TRIGGER journal_country
AFTER UPDATE OR INSERT OR DELETE
ON country FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journal_country' INTO amount_of_records;
    CASE
        WHEN inserting THEN
            INSERT INTO journal_country VALUES (amount_of_records+1,
            'I', CURRENT_TIMESTAMP, :NEW.id, :NEW.name, :NEW.abbr);
        
        WHEN updating THEN
             INSERT INTO journal_country VALUES (amount_of_records+1,
            'U', CURRENT_TIMESTAMP, :OLD.id, :OLD.name, :OLD.abbr);         
        WHEN deleting THEN
           INSERT INTO journal_country VALUES (amount_of_records+1,
            'D', CURRENT_TIMESTAMP, :OLD.id, :OLD.name, :OLD.abbr);
    END CASE;
END;

create table city(
    id number PRIMARY KEY,
    name varchar2(56),
   country_id number,
   constraint fk_city_country foreign key (country_id) references country(id)
);
create table journal_city(
    op_id number PRIMARY KEY,
    op varchar2(1),
    op_time date,
    id number,
    name varchar2(56),
    country_id number
);
CREATE OR REPLACE TRIGGER journal_city
AFTER UPDATE OR INSERT OR DELETE
ON city FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journal_city' INTO amount_of_records;
    CASE
        WHEN inserting THEN
            INSERT INTO journal_city VALUES (amount_of_records+1,
            'I', CURRENT_TIMESTAMP, :NEW.id, :NEW.name, :NEW.country_id);
        
        WHEN updating THEN
             INSERT INTO journal_city VALUES (amount_of_records+1,
            'U', CURRENT_TIMESTAMP, :OLD.id, :OLD.name, :OLD.country_id);         
        WHEN deleting THEN
           INSERT INTO journal_city VALUES (amount_of_records+1,
            'D', CURRENT_TIMESTAMP, :OLD.id, :OLD.name, :OLD.country_id);
    END CASE;
END;

create table department(   
  department_id        number PRIMARY KEY,   
  departemnt_name       varchar2(50),   
  city_id           number,
  constraint fk_city_department foreign key (city_id) references city(id)
);
create table journal_department(
    op_id number PRIMARY KEY,
    op varchar2(1),
    op_time date,
    department_id number,
    departemnt_name varchar2(56),
    city_id number
);
CREATE OR REPLACE TRIGGER journal_department
AFTER UPDATE OR INSERT OR DELETE
ON department FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journal_department' INTO amount_of_records;
    CASE
        WHEN inserting THEN
            INSERT INTO journal_department VALUES (amount_of_records+1,
            'I', CURRENT_TIMESTAMP, :NEW.department_id, :NEW.departemnt_name, :NEW.city_id);
        
        WHEN updating THEN
             INSERT INTO journal_department VALUES (amount_of_records+1,
            'U', CURRENT_TIMESTAMP, :OLD.department_id, :OLD.departemnt_name, :OLD.city_id);         
        WHEN deleting THEN
           INSERT INTO journal_department VALUES (amount_of_records+1,
            'D', CURRENT_TIMESTAMP, :OLD.department_id, :OLD.departemnt_name, :OLD.city_id);
    END CASE;
END;

create table employee(   
  emp_id    number PRIMARY KEY,   
  emp_name    varchar2(10),   
  position      varchar2(9),   
  hire_date date,   
  salary      number,   
  department_id   number,     
  constraint fk_emp_department foreign key (department_id) references department(department_id)   
);
create table journal_employee(
    op_id number PRIMARY KEY,
    op varchar2(1),
    op_time date,
    emp_id number,
    emp_name    varchar2(10),   
    position      varchar2(9),   
    hire_date date,   
    salary      number,   
    department_id   number    
);
CREATE OR REPLACE TRIGGER journal_employee
AFTER UPDATE OR INSERT OR DELETE
ON employee FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journal_employee' INTO amount_of_records;
    CASE
        WHEN inserting THEN
            INSERT INTO journal_employee VALUES (amount_of_records+1,
            'I', CURRENT_TIMESTAMP, :NEW.emp_id, :NEW.emp_name, :NEW.position, :NEW.hire_date, :NEW.salary, :NEW.department_id);
        
        WHEN updating THEN
             INSERT INTO journal_employee VALUES (amount_of_records+1,
            'U', CURRENT_TIMESTAMP, :OLD.emp_id, :OLD.emp_name, :OLD.position, :OLD.hire_date, :OLD.salary, :OLD.department_id);         
        WHEN deleting THEN
           INSERT INTO journal_employee VALUES (amount_of_records+1,
            'D', CURRENT_TIMESTAMP, :OLD.emp_id, :OLD.emp_name, :OLD.position, :OLD.hire_date, :OLD.salary, :OLD.department_id);
    END CASE;
END;

CREATE OR REPLACE PACKAGE data_rollback_overload IS
    PROCEDURE data_rollback(to_date date);
    PROCEDURE data_rollback(msc number);
END data_rollback_overload;

CREATE OR REPLACE PACKAGE BODY data_rollback_overload IS

PROCEDURE data_rollback(to_date date)
IS
BEGIN
    roll_back(TO_TIMESTAMP(to_date));
END data_rollback;

PROCEDURE data_rollback(msc number)
IS
BEGIN
    roll_back(TO_TIMESTAMP(CURRENT_TIMESTAMP - numToDSInterval( msc / 1000, 'second' )));
END data_rollback;

END data_rollback_overload;

CREATE OR REPLACE PROCEDURE roll_back(time_back TIMESTAMP)
IS
BEGIN
null;
END;

INSERT INTO country VALUES (1, 'United States', 'US');

declare
  l_clob clob;
begin
  l_clob := '<html><head>
<style>
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
}
table.center {
  margin-left: auto;
  margin-right: auto;
}
</style>
</head><body> <h1 style="text-align: center"> EMPLOYEES LIST </h1> <table style="width:100%" class="center">
  <tr align="center">
    <th align="center">EMPLOYEE</th>
    <th align="center">HIRE DATE</th>
    <th align="center">JOB</th>
  </tr>';
  for l_rec in (select * from emp) loop
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.name ||'</td> <td align="center">'
    ||l_rec.hiredate ||'</td><td align="left">'||l_rec.job ||'</td> </tr>';
  end loop;
  l_clob := l_clob || '</table></body></html>';
  OT_HTML_PKG.OT_HTML('LAB5', 'index.html', l_clob);
end;
