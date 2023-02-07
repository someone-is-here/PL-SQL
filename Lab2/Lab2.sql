DROP TABLE students;
DROP TABLE groups;

--TASK 1
CREATE TABLE students(
     id NUMBER PRIMARY KEY,
     name VARCHAR2(100) NOT NULL,
     group_id NUMBER);
     
INSERT INTO students(id, name, group_id) VALUES(2, 'Alina', 1);

CREATE TABLE groups(
     id NUMBER PRIMARY KEY,
     name VARCHAR2(100) NOT NULL,
     students_amount NUMBER NOT NULL);    
     
INSERT INTO groups(id, name, students_amount) VALUES(1, '053501', 0);
INSERT INTO groups(id, name, students_amount) VALUES(2, '053502', 0);
INSERT INTO groups(id, name, students_amount) VALUES(3, '053503', 0);
INSERT INTO groups(id, name, students_amount) VALUES(4, '053504', 0);
INSERT INTO groups(id, name, students_amount) VALUES(5, '053505', 0);

CREATE TABLE students_journaling
SET SERVEROUTPUT ON;

--CURSOR c_groups IS SELECT * FROM groups;
--FOR r_group IN c_groups LOOP
--        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM students WHERE group_id='||r_group.id INTO students_in_group;
--        IF students_in_group != r_group.students_amount
--        dbms_output.put_line( r_group.id || ': ' ||  r_group.name || ' students: ' || r_group.students_amount);
--    END LOOP;   

CREATE OR REPLACE TRIGGER insert_or_update_student
BEFORE UPDATE OR INSERT
ON students FOR EACH ROW
DECLARE
students_amount NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM students' INTO students_amount;
    FOR i IN 1 .. students_amount LOOP
        i
    END LOOP;
    dbms_output.put_line(students_amount);
--    EXECUTE IMMEDIATE utl_lms.format_message('INSERT INTO students VALUES(%d, %d, %d)', students_amount+1,NEW.name, NEW.group);
    dbms_output.put_line( utl_lms.format_message('INSERT INTO students VALUES(%d, %s, %d)', TO_CHAR(students_amount+1), :NEW.name, TO_CHAR(:NEW.group_id)));
END;

--TASK 3
CREATE OR REPLACE TRIGGER fk_student_group
AFTER DELETE ON students FOR EACH ROW
DECLARE
   students_amount_in_group NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT groups.students_amount FROM groups WHERE id='||:OLD.group_id INTO students_amount_in_group;
        dbms_output.put_line(students_amount_in_group);
    IF students_amount_in_group=1 THEN
        DELETE FROM groups WHERE id=:OLD.group_id;
    END IF;
END;

--TESTING
SELECT * FROM students;
SELECT * from groups;

INSERT INTO students VALUES(4, 'Roman', 2);
DELETE FROM students WHERE id=3;
    
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

EXEC roll_back(TO_TIMESTAMP('05.02.23 22:11:17'));

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

INSERT INTO students(id, name, group_id) VALUES(1, 'Natali', 1);
UPDATE students SET students.group_id=2 WHERE students.id=7;
DELETE FROM students WHERE id=1;    