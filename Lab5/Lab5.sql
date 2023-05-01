create table full_journal(
    id number,
    op_id number,
    op_time TIMESTAMP NOT NULL,
    table_name varchar2(100) 
);

create table country(
    id number PRIMARY KEY,
    name varchar2(56),
    abbr varchar2(2)
);

create table journal_country(
    op_id number PRIMARY KEY,
    op varchar2(1),
    op_time TIMESTAMP NOT NULL,
    id number,
    name varchar2(56),
    abbr varchar2(2)
);

create table city(
    id number PRIMARY KEY,
    name varchar2(56),
   country_id number,
   constraint fk_city_country foreign key (country_id) references country(id)
);
create table journal_city(
    op_id number PRIMARY KEY,
    op varchar2(1),
    op_time TIMESTAMP,
    id number,
    name varchar2(56),
    country_id number
);

create table department(   
  department_id        number PRIMARY KEY,   
  department_name       varchar2(50),   
  city_id           number,
  constraint fk_city_department foreign key (city_id) references city(id)
);
create table journal_department(
    op_id number PRIMARY KEY,
    op varchar2(1),
    op_time TIMESTAMP,
    department_id number,
    department_name varchar2(50),
    city_id number
);

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
    op_time TIMESTAMP,
    emp_id number,
    emp_name    varchar2(10),   
    position      varchar2(9),   
    hire_date date,   
    salary      number,   
    department_id   number    
);
CREATE OR REPLACE TRIGGER journal_country
AFTER UPDATE OR INSERT OR DELETE
ON country FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER := 0;
    amount_of_records_in_full_jornl NUMBER := 0;
    curr_time TIMESTAMP;
    table_name VARCHAR2(16) := 'journal_country';
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journal_country' INTO amount_of_records;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM full_journal' INTO amount_of_records_in_full_jornl;
    curr_time := CURRENT_TIMESTAMP;
    CASE
        WHEN inserting THEN
            INSERT INTO journal_country VALUES (amount_of_records+1,
            'I', curr_time, :NEW.id, :NEW.name, :NEW.abbr);
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl, 
            amount_of_records+1, curr_time, table_name);        
        WHEN updating THEN
             INSERT INTO journal_country VALUES (amount_of_records+1,
            'U', curr_time, :OLD.id, :OLD.name, :OLD.abbr);    
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl,
            amount_of_records+1, curr_time, table_name);
        WHEN deleting THEN
           INSERT INTO journal_country VALUES (amount_of_records+1,
            'D', curr_time, :OLD.id, :OLD.name, :OLD.abbr);
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl,
            amount_of_records+1, curr_time, table_name);
    END CASE;
    commit;
END;

CREATE OR REPLACE TRIGGER journal_city
AFTER UPDATE OR INSERT OR DELETE
ON city FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER := 0;
    amount_of_records_in_full_jornl NUMBER := 0;
    curr_time TIMESTAMP;
    table_name VARCHAR2(16) := 'journal_city';
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journal_city' INTO amount_of_records;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM full_journal' INTO amount_of_records_in_full_jornl;
    curr_time := CURRENT_TIMESTAMP;
    CASE
        WHEN inserting THEN
            INSERT INTO journal_city VALUES (amount_of_records+1,
            'I', curr_time, :NEW.id, :NEW.name, :NEW.country_id);
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl, 
            amount_of_records+1, curr_time, table_name);
        WHEN updating THEN
             INSERT INTO journal_city VALUES (amount_of_records+1,
            'U', curr_time, :OLD.id, :OLD.name, :OLD.country_id);  
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl,
            amount_of_records+1, curr_time, table_name);
        WHEN deleting THEN
           INSERT INTO journal_city VALUES (amount_of_records+1,
            'D', curr_time, :OLD.id, :OLD.name, :OLD.country_id);
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl,
            amount_of_records+1, curr_time, table_name);
    END CASE;
    commit;
END;

CREATE OR REPLACE TRIGGER journal_department
AFTER UPDATE OR INSERT OR DELETE
ON department FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER;
    amount_of_records_in_full_jornl NUMBER := 0;
    curr_time TIMESTAMP;
    table_name VARCHAR2(20) := 'journal_department';
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journal_department' INTO amount_of_records;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM full_journal' INTO amount_of_records_in_full_jornl;
    curr_time := CURRENT_TIMESTAMP;
    CASE
        WHEN inserting THEN
            INSERT INTO journal_department VALUES (amount_of_records+1,
            'I', curr_time, :NEW.department_id, :NEW.department_name, :NEW.city_id);
             INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl, 
            amount_of_records+1, curr_time, table_name);
        WHEN updating THEN
             INSERT INTO journal_department VALUES (amount_of_records+1,
            'U', curr_time, :OLD.department_id, :OLD.department_name, :OLD.city_id); 
             INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl, 
            amount_of_records+1, curr_time, table_name);
        WHEN deleting THEN
           INSERT INTO journal_department VALUES (amount_of_records+1,
            'D', curr_time, :OLD.department_id, :OLD.department_name, :OLD.city_id);
             INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl, 
            amount_of_records+1, curr_time, table_name);
    END CASE;
    commit;
END;

CREATE OR REPLACE TRIGGER journal_employee
AFTER UPDATE OR INSERT OR DELETE
ON employee FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER;
    amount_of_records_in_full_jornl NUMBER := 0;
    curr_time TIMESTAMP;
    table_name VARCHAR2(16) := 'journal_employee';
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journal_employee' INTO amount_of_records;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM full_journal' INTO amount_of_records_in_full_jornl;
    curr_time := CURRENT_TIMESTAMP;
    CASE
        WHEN inserting THEN
            INSERT INTO journal_employee VALUES (amount_of_records+1,
            'I', curr_time, :NEW.emp_id, :NEW.emp_name,
            :NEW.position, :NEW.hire_date, :NEW.salary, :NEW.department_id);
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl, 
            amount_of_records+1, curr_time, table_name);        
        WHEN updating THEN
             INSERT INTO journal_employee VALUES (amount_of_records+1,
            'U', curr_time, :OLD.emp_id, :OLD.emp_name,
            :OLD.position, :OLD.hire_date, :OLD.salary, :OLD.department_id);   
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl, 
            amount_of_records+1, curr_time, table_name);
        WHEN deleting THEN
           INSERT INTO journal_employee VALUES (amount_of_records+1,
            'D', curr_time, :OLD.emp_id, :OLD.emp_name,
            :OLD.position, :OLD.hire_date, :OLD.salary, :OLD.department_id);
            INSERT INTO full_journal VALUES (amount_of_records_in_full_jornl, 
            amount_of_records+1, curr_time, table_name);
    END CASE;
    commit;
END;

CREATE OR REPLACE PACKAGE data_rollback_overload IS
    PROCEDURE data_rollback(to_date TIMESTAMP);
    PROCEDURE data_rollback(msc number);
    PROCEDURE create_report(to_date TIMESTAMP);
    PROCEDURE create_report_from_old(to_date TIMESTAMP);
END data_rollback_overload;

CREATE OR REPLACE PACKAGE BODY data_rollback_overload IS
PROCEDURE data_rollback(to_date TIMESTAMP)
IS
BEGIN
    roll_back(TO_TIMESTAMP(to_date));
END data_rollback;
PROCEDURE data_rollback(msc number)
IS
BEGIN
    roll_back(TO_TIMESTAMP(CURRENT_TIMESTAMP - numToDSInterval( msc / 1000, 'second' )));
END data_rollback;
PROCEDURE create_report(to_date TIMESTAMP)
IS 
  l_clob clob;
  out_File  UTL_FILE.FILE_TYPE;
BEGIN 
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
</head><body> <h1 style="text-align: center"> EMPLOYEES LIST </h1> 
<table style="width:100%" class="center">
  <tr align="center">
    <th align="center">OPERATION</th>
     <th align="center">OPERATION_TIME</th>
    <th align="center">EMPLOYEE_ID</th>
    <th align="center">EMPLOYEE_NAME</th>
    <th align="center">POSITION</th>
    <th align="center">HIRE DATE</th>
    <th align="center">SALARY</th>
    <th align="center">DEPARTMENT_ID</th>
  </tr>';
  for l_rec in (select * from journal_employee) loop
   IF(l_rec.op_time <= to_date) THEN
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.op ||'</td> <td align="center">'
    ||l_rec.op_time ||'</td><td align="left">' || l_rec.emp_id ||'</td><td align="left">' || l_rec.emp_name 
    ||'</td><td align="left">' || l_rec.position 
    ||'</td><td align="left">' || l_rec.hire_date
    ||'</td><td align="left">' || l_rec.salary
    ||'</td><td align="left">' || l_rec.department_id ||'</td> </tr>';
    END IF;
  end loop;
  l_clob := l_clob || '</table>';
   l_clob := l_clob || '<h1 style="text-align: center"> DEPARTMENTS LIST </h1> 
<table style="width:100%" class="center">
  <tr align="center">
      <th align="center">OPERATION</th>
     <th align="center">OPERATION_TIME</th>
    <th align="center">DEPARTMENT_ID</th>
     <th align="center">DEPARTMENT_NAME</th>
    <th align="center">CITY_ID</th>
  </tr>';
  for l_rec in (select * from journal_department) loop
    IF(l_rec.op_time <= to_date) THEN
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.op ||'</td> <td align="center">'
    ||l_rec.op_time ||'</td><td align="left">' || l_rec.department_id ||'</td><td align="left">' || l_rec.department_name 
    ||'</td><td align="left">' || l_rec.city_id ||'</td> </tr>';
    END IF;
  end loop;
  l_clob := l_clob || '</table>';
     l_clob := l_clob || '<h1 style="text-align: center"> CITIES LIST </h1> 
<table style="width:100%" class="center">
  <tr align="center">
      <th align="center">OPERATION</th>
     <th align="center">OPERATION_TIME</th>
    <th align="center">ID</th>
     <th align="center">NAME</th>
    <th align="center">COUNTRY_ID</th>
  </tr>';
  for l_rec in (select * from journal_city) loop
   IF(l_rec.op_time <= to_date) THEN
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.op ||'</td> <td align="center">'
    ||l_rec.op_time ||'</td><td align="left">' || l_rec.id ||'</td><td align="left">' || l_rec.name 
    ||'</td><td align="left">' || l_rec.country_id ||'</td> </tr>';
    END IF;
  end loop;
  l_clob := l_clob || '</table>';
       l_clob := l_clob || '<h1 style="text-align: center"> COUNTRIES LIST </h1> 
<table style="width:100%" class="center">
  <tr align="center">
      <th align="center">OPERATION</th>
     <th align="center">OPERATION_TIME</th>
    <th align="center">ID</th>
     <th align="center">NAME</th>
    <th align="center">ABBR</th>
  </tr>';
  for l_rec in (select * from journal_country) loop
   IF(l_rec.op_time <= to_date) THEN
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.op ||'</td> <td align="center">'
    ||l_rec.op_time ||'</td><td align="left">' || l_rec.id ||'</td><td align="left">' || l_rec.name 
    ||'</td><td align="left">' || l_rec.abbr ||'</td> </tr>';
    END IF;
  end loop;
  l_clob := l_clob || '</table>';
  l_clob := l_clob || '</body></html>';
  out_File := UTL_FILE.FOPEN('RTVMS2', 'date.txt' , 'W');
  UTL_FILE.PUT_LINE(out_file , to_date);
  UTL_FILE.FCLOSE(out_file);
  OT_HTML_PKG.OT_HTML('LAB5', 'index.html', l_clob);
END;
PROCEDURE create_report_from_old(to_date TIMESTAMP)
IS 
  out_File UTL_FILE.FILE_TYPE;
  from_date_str clob;
  from_date TIMESTAMP;
  l_clob clob;
BEGIN 
  out_File := UTL_FILE.FOPEN('RTVMS2', 'date.txt' , 'R');
  UTL_FILE.GET_LINE(out_file , from_date_str);
  UTL_FILE.FCLOSE(out_file);
  from_date := TO_TIMESTAMP(from_date_str);
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
</head><body> <h1 style="text-align: center"> EMPLOYEES LIST </h1> 
<table style="width:100%" class="center">
  <tr align="center">
    <th align="center">OPERATION</th>
     <th align="center">OPERATION_TIME</th>
    <th align="center">EMPLOYEE_ID</th>
    <th align="center">EMPLOYEE_NAME</th>
    <th align="center">POSITION</th>
    <th align="center">HIRE DATE</th>
    <th align="center">SALARY</th>
    <th align="center">DEPARTMENT_ID</th>
  </tr>';
  for l_rec in (select * from journal_employee) loop
   IF(l_rec.op_time <= to_date and l_rec.op_time >= from_date) THEN
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.op ||'</td> <td align="center">'
    ||l_rec.op_time ||'</td><td align="left">' || l_rec.emp_id ||'</td><td align="left">' || l_rec.emp_name 
    ||'</td><td align="left">' || l_rec.position 
    ||'</td><td align="left">' || l_rec.hire_date
    ||'</td><td align="left">' || l_rec.salary
    ||'</td><td align="left">' || l_rec.department_id ||'</td> </tr>';
    END IF;
  end loop;
  l_clob := l_clob || '</table>';
   l_clob := l_clob || '<h1 style="text-align: center"> DEPARTMENTS LIST </h1> 
<table style="width:100%" class="center">
  <tr align="center">
      <th align="center">OPERATION</th>
     <th align="center">OPERATION_TIME</th>
    <th align="center">DEPARTMENT_ID</th>
     <th align="center">DEPARTMENT_NAME</th>
    <th align="center">CITY_ID</th>
  </tr>';
  for l_rec in (select * from journal_department) loop
   IF(l_rec.op_time <= to_date and l_rec.op_time >= from_date) THEN
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.op ||'</td> <td align="center">'
    ||l_rec.op_time ||'</td><td align="left">' || l_rec.department_id ||'</td><td align="left">' || l_rec.department_name 
    ||'</td><td align="left">' || l_rec.city_id ||'</td> </tr>';
    END IF;
  end loop;
  l_clob := l_clob || '</table>';
     l_clob := l_clob || '<h1 style="text-align: center"> CITIES LIST </h1> 
<table style="width:100%" class="center">
  <tr align="center">
      <th align="center">OPERATION</th>
     <th align="center">OPERATION_TIME</th>
    <th align="center">ID</th>
     <th align="center">NAME</th>
    <th align="center">COUNTRY_ID</th>
  </tr>';
  for l_rec in (select * from journal_city) loop
   IF(l_rec.op_time <= to_date and l_rec.op_time >= from_date) THEN
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.op ||'</td> <td align="center">'
    ||l_rec.op_time ||'</td><td align="left">' || l_rec.id ||'</td><td align="left">' || l_rec.name 
    ||'</td><td align="left">' || l_rec.country_id ||'</td> </tr>';
    END IF;
  end loop;
  l_clob := l_clob || '</table>';
       l_clob := l_clob || '<h1 style="text-align: center"> COUNTRIES LIST </h1> 
<table style="width:100%" class="center">
  <tr align="center">
      <th align="center">OPERATION</th>
     <th align="center">OPERATION_TIME</th>
    <th align="center">ID</th>
     <th align="center">NAME</th>
    <th align="center">ABBR</th>
  </tr>';
  for l_rec in (select * from journal_country) loop
   IF(l_rec.op_time <= to_date and l_rec.op_time >= from_date) THEN
    l_clob := l_clob || '<tr align="center"> <td align="left">'|| l_rec.op ||'</td> <td align="center">'
    ||l_rec.op_time ||'</td><td align="left">' || l_rec.id ||'</td><td align="left">' || l_rec.name 
    ||'</td><td align="left">' || l_rec.abbr ||'</td> </tr>';
    END IF;
  end loop;
  l_clob := l_clob || '</table>';
  l_clob := l_clob || '</body></html>';
  OT_HTML_PKG.OT_HTML('LAB5', 'index.html', l_clob);
  EXCEPTION 
    WHEN OTHERS 
    THEN dbms_output.put_line(SQLCODE);
END;
END data_rollback_overload;

CREATE OR REPLACE PROCEDURE roll_back(time_back TIMESTAMP)
IS
PRAGMA AUTONOMOUS_TRANSACTION;
CURSOR c_journal_country(id NUMBER) IS SELECT * FROM journal_country WHERE op_id=id;
r_country journal_country%rowtype;
CURSOR c_journal_city(id NUMBER) IS SELECT * FROM journal_city WHERE op_id=id;
r_city journal_city%rowtype;
CURSOR c_journal_department(id NUMBER) IS SELECT * FROM journal_department WHERE op_id=id;
r_department journal_department%rowtype;
CURSOR c_journal_employee(id NUMBER) IS SELECT * FROM journal_employee WHERE op_id=id;
r_employee journal_employee%rowtype;
CURSOR c_get_full_journal IS SELECT * FROM full_journal WHERE op_time > time_back order by op_time DESC;
wrong_operation EXCEPTION;
BEGIN
    FOR r_item IN c_get_full_journal LOOP
     IF r_item.op_time > time_back THEN 
        CASE r_item.table_name
            WHEN 'journal_country' THEN 
              OPEN c_journal_country(r_item.op_id);
               FETCH c_journal_country INTO r_country;
               dbms_output.put_line('journal_country'|| ' ' ||r_country.op ||r_country.op_id);
                CASE r_country.op
                WHEN 'I' THEN
                  DELETE FROM country WHERE id=r_country.id;
                WHEN 'U' THEN
                    UPDATE country SET 
                        country.name=r_country.name,
                        country.abbr=r_country.abbr 
                        WHERE country.id=r_country.id;
                WHEN 'D' THEN
                 INSERT INTO country VALUES(r_country.id, r_country.name, r_country.abbr);
                ELSE raise wrong_operation;
                END CASE;
              CLOSE c_journal_country;
            WHEN 'journal_city' THEN
             OPEN c_journal_city(r_item.op_id);
             FETCH c_journal_city INTO r_city;
             dbms_output.put_line('journal_city'|| ' ' || r_city.op || r_city.op_id);
                CASE r_city.op
                WHEN 'I' THEN
                  DELETE FROM city WHERE id=r_city.id;
                WHEN 'U' THEN
                    UPDATE city SET 
                        city.name=r_city.name,
                        city.country_id=r_city.country_id 
                        WHERE city.id=r_city.id;
                WHEN 'D' THEN
                 INSERT INTO city VALUES(r_city.id, r_city.name, r_city.country_id);
                ELSE raise wrong_operation;
                END CASE;
              CLOSE c_journal_city;
            WHEN 'journal_department' THEN
             OPEN c_journal_department(r_item.op_id);
              FETCH c_journal_department INTO r_department;
                dbms_output.put_line('journal_department'|| ' ' ||r_department.op||r_department.op_id);
                CASE r_department.op
                WHEN 'I' THEN
                  DELETE FROM department WHERE department_id=r_department.department_id;
                WHEN 'U' THEN
                    UPDATE department SET 
                        department.department_name=r_department.department_name,
                        department.city_id=r_department.city_id 
                        WHERE department.department_id=r_department.department_id;
                WHEN 'D' THEN
                 INSERT INTO department VALUES(r_department.department_id, r_department.department_name, r_department.city_id);
                ELSE raise wrong_operation;
                END CASE;
              CLOSE c_journal_department;
            WHEN 'journal_employee' THEN
             OPEN c_journal_employee(r_item.op_id);
                FETCH c_journal_employee INTO r_employee;
                dbms_output.put_line('journal_employee' || ' ' || r_employee.op || r_employee.op_id);
                CASE r_employee.op
                WHEN 'I' THEN
                  DELETE FROM employee WHERE emp_id=r_employee.emp_id;
                WHEN 'U' THEN
                    UPDATE employee SET 
                        employee.emp_name=r_employee.emp_name,
                        employee.position=r_employee.position,
                        employee.hire_date=r_employee.hire_date,
                        employee.salary=r_employee.salary,
                         employee.department_id=r_employee.department_id
                        WHERE employee.emp_id=r_employee.emp_id;
                WHEN 'D' THEN
                 INSERT INTO employee VALUES(r_employee.emp_id, r_employee.emp_name, r_employee.position,
                 r_employee.hire_date, r_employee.salary, r_employee.department_id);
                ELSE raise wrong_operation;
                END CASE;
              CLOSE c_journal_employee;
            ELSE raise wrong_operation;
        END CASE;
      commit;
     END IF;      
    END LOOP;
END;

INSERT INTO country VALUES (1, 'United States', 'US');
INSERT INTO country VALUES (2, 'Republic of Belarus', 'BL');
UPDATE country SET name = 'Belarus', abbr = 'BY' WHERE id=2;
DELETE FROM country where id=2;
select * from journal_country;

INSERT INTO city VALUES (1, 'New York', 1);
INSERT INTO city VALUES (2, 'Dallas', 1);
INSERT INTO city VALUES (3, 'Chicag', 1);
INSERT INTO city VALUES (4, 'Boston', 1);
UPDATE city SET name = 'Chicago' WHERE id=3;
DELETE FROM city where id=2;
select * from journal_city;

INSERT INTO department VALUES (1, 'ACCOUNTING', 1);
INSERT INTO department VALUES (2, 'RESEARCH', 2);
INSERT INTO department VALUES (3, 'SALES', 3);
INSERT INTO department VALUES (4, 'OP', 4);
UPDATE department SET department_name = 'OPERATIONS' WHERE department_id=4;
DELETE FROM department where department_id=2;
select * from journal_department;

INSERT INTO employee VALUES ( 1, 'Alexsandr', 'PRESIDENT', to_date('17-11-2012','dd-mm-yyyy'), 5000, 1);
INSERT INTO employee VALUES ( 2, 'Alex', 'PRESIDENT', to_date('17-12-2012','dd-mm-yyyy'), 5000, 3);
INSERT INTO employee VALUES ( 3, 'Mike', 'PRESIDENT', to_date('17-12-2012','dd-mm-yyyy'), 5000, 4);
UPDATE employee SET position = 'MANAGER', salary = 4500 WHERE emp_id=3;
select * from journal_employee;



BEGIN
    data_rollback_overload.data_rollback(TO_TIMESTAMP('01.05.23 23:09:23,674000000'));
    data_rollback_overload.create_report_from_old(TO_TIMESTAMP('01.05.23 23:09:23,674000000'));
END;


SELECT * FROM full_journal WHERE op_time > TO_TIMESTAMP('01.05.23 22:18:40') order by op_time DESC;
select * from department;
select * from employee;
select * from city;
select * from country;
drop table employee;
drop table journal_employee;
drop table department;
drop table journal_department;
drop table city;
drop table journal_city;
drop table country;
drop table journal_country;
drop table full_journal;