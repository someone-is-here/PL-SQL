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
     
INSERT INTO groups(id, name, students_amount) VALUES(1, '053501', 1);
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
   
END;

--TESTING
select * from students;
select * from groups;

INSERT INTO students(id, name, group_id) VALUES(1, 'Natali', 1);
UPDATE students SET students.group_id=5 WHERE students.id=1;
DELETE FROM students WHERE id=1;