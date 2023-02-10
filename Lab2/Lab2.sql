DROP TABLE students;
DROP TABLE groups;

SET SERVEROUTPUT ON;

--TASK 1
CREATE TABLE students(
     id NUMBER PRIMARY KEY,
     name VARCHAR2(100) NOT NULL,
     group_id NUMBER);
     
INSERT INTO students(name, group_id) VALUES('Me', 8);
INSERT INTO students(name, group_id) VALUES('Alex', 1);
INSERT INTO students(name, group_id) VALUES('Natalia', 2);
INSERT INTO students(name, group_id) VALUES('Ash', 3);
INSERT INTO students(name, group_id) VALUES('Nile', 4);
INSERT INTO students(name, group_id) VALUES('Niall', 5);
INSERT INTO students(name, group_id) VALUES('Joy', 5);

CREATE TABLE groups(
     id NUMBER PRIMARY KEY,
     name VARCHAR2(100) NOT NULL,
     students_amount NUMBER NOT NULL);    
     
INSERT INTO groups(id, name, students_amount) VALUES(1, '053501', 0);
INSERT INTO groups(id, name, students_amount) VALUES(2, '053502', 0);
INSERT INTO groups(id, name, students_amount) VALUES(3, '053503', 0);
INSERT INTO groups(id, name, students_amount) VALUES(4, '053504', 0);
INSERT INTO groups(id, name, students_amount) VALUES(5, '053505', 0);


--TASK 2

CREATE SEQUENCE student_id_generator
  START WITH 1
  INCREMENT BY 1
  CACHE 100;

CREATE SEQUENCE group_id_generator
  START WITH 1
  INCREMENT BY 1
  CACHE 100;

CREATE OR REPLACE TRIGGER generate_student_id
  BEFORE INSERT ON students
  FOR EACH ROW
BEGIN
  :new.id := student_id_generator.nextval;
END;

CREATE OR REPLACE TRIGGER generate_group_id
  BEFORE INSERT ON groups
  FOR EACH ROW
BEGIN
  :new.id := group_id_generator.nextval;
END;

select * from groups;
select * from students;
INSERT INTO groups(name, students_amount) VALUES ('053506', 0);
delete from groups where id=4;
INSERT INTO groups VALUES (5, '053501', 0);

CREATE OR REPLACE TRIGGER check_group_name
BEFORE UPDATE OR INSERT
ON groups FOR EACH ROW
DECLARE
id_ NUMBER;
existing_name EXCEPTION;
BEGIN
        SELECT groups.id INTO id_ FROM groups WHERE groups.name=:NEW.name;
        dbms_output.put_line('This name already exists'||:NEW.name);
        raise existing_name;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('successfully inserted!');
END;

CREATE OR REPLACE TRIGGER check_group_id
BEFORE UPDATE OR INSERT
ON groups FOR EACH ROW
FOLLOWS CHECK_GROUP_NAME
DECLARE
id_ NUMBER;
existing_id EXCEPTION;
BEGIN
        SELECT groups.id INTO id_ FROM groups WHERE groups.id=:NEW.id;
               dbms_output.put_line('An id already exists'||:NEW.id);
        raise existing_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('successfully inserted!');
END;

CREATE OR REPLACE TRIGGER check_student_id
BEFORE UPDATE OR INSERT
ON students FOR EACH ROW
DECLARE
id_ NUMBER;
existing_id EXCEPTION;
BEGIN
        SELECT students.id INTO id_ FROM students WHERE students.id=:NEW.id;
        dbms_output.put_line('An id already exists'||:NEW.id);
        raise existing_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('successfully inserted!');
END;

--TASK 3
CREATE OR REPLACE TRIGGER fk_student_group
AFTER DELETE ON students FOR EACH ROW
DECLARE
   PRAGMA AUTONOMOUS_TRANSACTION;
   students_amount_in_group NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'ALTER TRIGGER fk_group_student DISABLE';
    EXECUTE IMMEDIATE 'SELECT groups.students_amount FROM groups WHERE id='||:OLD.group_id INTO students_amount_in_group;
        dbms_output.put_line(students_amount_in_group);
    IF students_amount_in_group=1 THEN
        DELETE FROM groups WHERE id=:OLD.group_id;
    END IF;
    EXECUTE IMMEDIATE 'ALTER TRIGGER fk_student_group DISABLE';
END;

CREATE OR REPLACE TRIGGER fk_group_student
AFTER DELETE ON groups FOR EACH ROW
DECLARE
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  EXECUTE IMMEDIATE 'ALTER TRIGGER fk_student_group DISABLE';
    EXECUTE IMMEDIATE 'DELETE FROM students WHERE students.group_id='||:OLD.id;
     EXECUTE IMMEDIATE 'ALTER TRIGGER fk_student_group ENABLE';
END;

select * from groups;
select * from students;
DELETE FROM groups WHERE id=7;
--TESTING
SELECT * FROM students;
SELECT * from groups;

INSERT INTO students VALUES(4, 'Roman', 2);
DELETE FROM students WHERE id=5;

    
--TASK 4
DROP TABLE journaling_students;

CREATE TABLE journaling_students (
    id NUMBER PRIMARY KEY,
    operation VARCHAR2(2) NOT NULL,
    date_of_writting TIMESTAMP NOT NULL,
    student_id NUMBER,
    student_name VARCHAR2(100) NOT NULL,
    student_group_id NUMBER
);

CREATE OR REPLACE TRIGGER journal_students
AFTER UPDATE OR INSERT OR DELETE
ON students FOR EACH ROW
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
    amount_of_records NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM journaling_students' INTO amount_of_records;
    CASE
        WHEN inserting THEN
            INSERT INTO journaling_students VALUES (amount_of_records+1,
            'I', CURRENT_TIMESTAMP, :NEW.id, :NEW.name, :NEW.group_id);
        
        WHEN updating THEN
             INSERT INTO journaling_students VALUES (amount_of_records+1,
            'BU', CURRENT_TIMESTAMP, :OLD.id, :OLD.name, :OLD.group_id);
             INSERT INTO journaling_students VALUES (amount_of_records+2,
            'AU', CURRENT_TIMESTAMP, :NEW.id, :NEW.name, :NEW.group_id);           
        WHEN deleting THEN
           INSERT INTO journaling_students VALUES (amount_of_records+1,
            'D', CURRENT_TIMESTAMP, :OLD.id, :OLD.name, :OLD.group_id);
    END CASE;
END;

INSERT INTO students(id, name, group_id) VALUES(6, 'Dima', 1);
INSERT INTO students(id, name, group_id) VALUES(7, 'Roman', 1);
UPDATE students SET students.group_id=2 WHERE students.id=7;
DELETE FROM students WHERE students.id=7;

select * from journaling_students;
   
--TASK 5
CREATE OR REPLACE PROCEDURE roll_back(time_back TIMESTAMP) 
IS
CURSOR c_journal IS SELECT * FROM journaling_students;
wrong_operation EXCEPTION;
BEGIN  
    FOR r_journal IN c_journal LOOP
        IF r_journal.date_of_writting > time_back THEN 
            IF r_journal.operation = 'I' THEN
                        dbms_output.put_line(r_journal.operation);
                DELETE FROM students WHERE id=r_journal.student_id;
            ELSIF r_journal.operation = 'D' THEN
                        dbms_output.put_line(r_journal.operation);
                INSERT INTO students VALUES(r_journal.student_id, r_journal.student_name, r_journal.student_group_id);
            ELSIF r_journal.operation = 'BU' THEN
                        dbms_output.put_line(r_journal.operation);
                UPDATE students SET 
                students.name=r_journal.student_name,
                students.group_id=r_journal.student_group_id 
                WHERE students.id=r_journal.student_id;
            ELSIF r_journal.operation = 'AU' THEN
                null;
            ELSE 
                RAISE wrong_operation;
            END IF;
        END IF;
    END LOOP;
END;

EXEC roll_back(TO_TIMESTAMP('10.02.23 20:59:20'));
EXEC roll_back(TO_TIMESTAMP(CURRENT_TIMESTAMP - 45));
EXEC roll_back(TO_TIMESTAMP(CURRENT_TIMESTAMP + numToDSInterval( 10000, 'second' )));

--TASK 6
CREATE OR REPLACE TRIGGER update_group
AFTER UPDATE OR INSERT OR DELETE
ON students FOR EACH ROW
DECLARE
    students_in_group NUMBER;
BEGIN
    CASE
        WHEN inserting THEN
            EXECUTE IMMEDIATE 'SELECT groups.students_amount FROM groups WHERE id='||:NEW.group_id INTO students_in_group;
            EXECUTE IMMEDIATE 'UPDATE groups SET groups.students_amount=:students WHERE id='||:NEW.group_id USING (students_in_group+1);
        
        WHEN updating THEN
            EXECUTE IMMEDIATE 'SELECT groups.students_amount FROM groups WHERE groups.id='||:OLD.group_id INTO students_in_group;
            EXECUTE IMMEDIATE 'UPDATE groups SET groups.students_amount=:students WHERE groups.id='||:OLD.group_id USING (students_in_group-1);
            EXECUTE IMMEDIATE 'SELECT groups.students_amount FROM groups WHERE id='||:NEW.group_id INTO students_in_group;
            EXECUTE IMMEDIATE 'UPDATE groups SET groups.students_amount=:students WHERE id='||:NEW.group_id USING (students_in_group+1);
            
        WHEN deleting THEN
            EXECUTE IMMEDIATE 'SELECT groups.students_amount FROM groups WHERE groups.id='||:OLD.group_id INTO students_in_group;
            EXECUTE IMMEDIATE 'UPDATE groups SET groups.students_amount=:students WHERE groups.id='||:OLD.group_id USING (students_in_group-1);
    END CASE;
EXCEPTION 
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('the group has been deleted');
END;

--TESTING
select * from students;
select * from groups;

INSERT INTO students(id, name, group_id) VALUES(1, 'Na', 7);
UPDATE students SET students.group_id=4 WHERE students.id=10;
DELETE FROM groups WHERE id=7;    