DROP TABLE MyTable;
CREATE TABLE MyTable(
    id NUMBER PRIMARY KEY,
    val NUMBER NOT NULL
);

BEGIN
FOR i IN 1 .. 10 LOOP
	INSERT INTO MyTable values (i, ROUND(dbms_random.value(1,1000)));
END LOOP;
END;

SELECT * from MyTable;

CREATE OR REPLACE FUNCTION get_even_odd_equality(table_name VARCHAR2) 
RETURN VARCHAR2
IS
    even_counter NUMBER := 0;
    odd_counter NUMBER := 0;
    result_value VARCHAR2(10); 
    num_ NUMBER := 1;
    cnt NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE(table_name);
    EXECUTE IMMEDIATE utl_lms.format_message('SELECT COUNT(id) FROM %s', table_name) 
    INTO cnt;
    FOR i IN 1 ..cnt  LOOP
		EXECUTE IMMEDIATE utl_lms.format_message('SELECT %s.val from %s
                                                            WHERE %s.id=%d',table_name,table_name, table_name, i)
		INTO num_;
		IF MOD (num_, 2) = 0  THEN
            even_counter := even_counter + 1;
		ELSE
            odd_counter := odd_counter + 1;
		END IF;
   END LOOP;
    IF even_counter > odd_counter THEN
		result_value := 'TRUE';
    ELSIF even_counter < odd_counter THEN
		result_value := 'FALSE';
	ELSIF even_counter = odd_counter THEN
		result_value := 'EQUAL';
    ELSE
        result_value := 'NULL';
	END IF;
        
    DBMS_OUTPUT.PUT_LINE(cnt);
    DBMS_OUTPUT.PUT_LINE(even_counter);
    DBMS_OUTPUT.PUT_LINE(odd_counter);
    
    RETURN result_value;
END;

CREATE OR REPLACE FUNCTION get_insert_query(table_name VARCHAR2, id IN NUMBER, val IN NUMBER) 
RETURN VARCHAR2
IS
BEGIN
    RETURN utl_lms.format_message('INSERT INTO %s VALUES (%d, %d)', table_name, TO_CHAR(id), TO_CHAR(val));
    
END;

SELECT get_even_odd_equality('MyTable') from DUAL;
SELECT get_insert_query('MyTable', 18, 13) from DUAL;

CREATE OR REPLACE FUNCTION get_insert_val(table_name IN VARCHAR2, id IN NUMBER) 
RETURN VARCHAR2
IS
get_val NUMBER;
BEGIN
    EXECUTE IMMEDIATE utl_lms.format_message('SELECT %s.val from %s
                                                            WHERE %s.id=%d',table_name, table_name, table_name, TO_CHAR(id))
                                                            INTO get_val;
    
   RETURN utl_lms.format_message('INSERT INTO %s VALUES (%d, %d)', table_name, TO_CHAR(id), TO_CHAR(get_val));
END;

SELECT get_insert_val('MyTable', 3) from DUAL;


CREATE OR REPLACE PROCEDURE insert_operation(table_name VARCHAR2, id NUMBER, val NUMBER) 
IS
BEGIN
	EXECUTE IMMEDIATE utl_lms.format_message('INSERT INTO %s(id,val) VALUES (%d, %d)', table_name, TO_CHAR(id), TO_CHAR(val));
END;

EXEC insert_operation('MyTable', 10001, 13);

select * from MyTable WHERE id=10001;
 
CREATE OR REPLACE PROCEDURE delete_operation(table_name VARCHAR2, id NUMBER) 
IS
BEGIN
	EXECUTE IMMEDIATE utl_lms.format_message('DELETE FROM %s WHERE id=%d', table_name, TO_CHAR(id));
END;

EXEC delete_operation('MyTable', 10001);

select * from MyTable WHERE id=10001;

CREATE OR REPLACE PROCEDURE update_operation(table_name VARCHAR2, id NUMBER, val NUMBER) 
IS
BEGIN
	EXECUTE IMMEDIATE utl_lms.format_message('UPDATE %s SET val=%d WHERE id=%d', table_name, TO_CHAR(val), TO_CHAR(id));
END;	

EXEC update_operation('MyTable', 10001, 201);

CREATE OR REPLACE FUNCTION get_year_income(monthly_income NUMBER, adding_percent NUMBER) 
RETURN VARCHAR2
IS
    result_value REAL;
    wrong_percent EXCEPTION;
BEGIN   
    IF adding_percent < 0 THEN
        RAISE wrong_percent;        
    END IF;        
    result_value := (1 + (1/100)*adding_percent)*12*monthly_income;
    RETURN  utl_lms.format_message('%d', TO_CHAR(result_value));

    EXCEPTION
        WHEN INVALID_NUMBER THEN
            RETURN utl_lms.format_message('Wrong input type');
        WHEN wrong_percent THEN
            RETURN utl_lms.format_message('Wrong percent');
        WHEN ZERO_DIVIDE THEN 
            RETURN utl_lms.format_message('%d', TO_CHAR(monthly_income * 12));
END;

SET SERVEROUTPUT ON;

DECLARE
    res VARCHAR2(100);
BEGIN
    SELECT get_year_income(12, 13) INTO res from DUAL;
    dbms_output.put_line(res);
    
    EXCEPTION
        WHEN INVALID_NUMBER THEN
             dbms_output.put_line('Wrong input type');
END;


