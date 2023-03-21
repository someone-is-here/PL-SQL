alter session set "_ORACLE_SCRIPT"=true;  

CREATE USER DEV_SCHEME IDENTIFIED BY DEV;
grant all privileges to DEV_SCHEME;

DROP USER PROD_USER CASCADE;
DROP USER DEV_USER CASCADE;

CREATE USER PROD_SCHEME IDENTIFIED BY PROD;
grant all privileges to PROD_SCHEME;

SELECT * FROM ALL_TABLES WHERE OWNER = 'PROD_SCHEME';
SELECT * FROM ALL_TABLES WHERE OWNER = 'DEV_SCHEME';

SELECT owner, table_name,
          column_name, data_type,
          data_length, data_precision,
          nullable, character_set_name  
   FROM all_tab_cols 
   WHERE table_name='EMPLOYEES' AND OWNER='PROD_SCHEME' ORDER BY column_name;
   
--select owner, constraint_name, constraint_type, table_name, search_condition, status, index_name, index_owner 
--From all_constraints 
--WHERE generated = 'USER NAME'
--AND owner not in ('SYS', 'SYSTEM'); 

SET SERVEROUTPUT ON;

CREATE OR REPLACE FUNCTION is_diff_tables(dev_scheme VARCHAR2, dev_table VARCHAR2,                            
                                          prod_scheme VARCHAR2, prod_table VARCHAR2)
RETURN BOOLEAN
IS

CURSOR curr_dev IS
SELECT owner, table_name,
          column_name, data_type,
          data_length, data_precision,
          nullable, character_set_name  
    FROM all_tab_cols 
    WHERE table_name=dev_table AND OWNER=dev_scheme
    ORDER BY column_name;
    
CURSOR curr_prod IS
    SELECT owner, table_name,
          column_name, data_type,
          data_length, data_precision,
          nullable, character_set_name  
    FROM all_tab_cols 
    WHERE table_name=prod_table AND OWNER=prod_scheme
    ORDER BY column_name;

dev_scheme_col curr_dev%ROWTYPE;
prod_scheme_col curr_prod%ROWTYPE;

is_different_structure BOOLEAN;

BEGIN
    OPEN curr_dev;
    OPEN curr_prod;
    
    FETCH curr_dev INTO dev_scheme_col;
    FETCH curr_prod INTO prod_scheme_col;
    
     IF prod_scheme_col.COLUMN_NAME!=dev_scheme_col.COLUMN_NAME OR
        prod_scheme_col.DATA_TYPE!=dev_scheme_col.DATA_TYPE OR
        prod_scheme_col.DATA_LENGTH!=dev_scheme_col.DATA_LENGTH OR
        prod_scheme_col.DATA_PRECISION!=dev_scheme_col.DATA_PRECISION OR
        prod_scheme_col.NULLABLE!=dev_scheme_col.NULLABLE OR
        prod_scheme_col.CHARACTER_SET_NAME!=dev_scheme_col.CHARACTER_SET_NAME THEN
        
                                   is_different_structure := TRUE; 
      ELSE
        is_different_structure := FALSE; 
      END IF;
      
      CLOSE curr_prod;
      CLOSE curr_dev;
      
      return is_different_structure;
END;


CREATE OR REPLACE FUNCTION get_diff_between_tables(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
RETURN VARCHAR2
IS
CURSOR curr_dev_scheme 
IS SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_scheme;

CURSOR curr_prod_scheme 
IS SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_scheme;

is_found BOOLEAN;

result VARCHAR2(2000);

BEGIN

 FOR dev_scheme_row IN curr_dev_scheme
   LOOP
        is_found := FALSE;
        
         FOR prod_scheme_row IN curr_prod_scheme
            LOOP
                IF prod_scheme_row.TABLE_NAME = dev_scheme_row.TABLE_NAME THEN
                    is_found := TRUE;
                    IF is_diff_tables(dev_scheme, dev_scheme_row.TABLE_NAME,
                                    prod_scheme, prod_scheme_row.TABLE_NAME) THEN
                                    
                    result := CONCAT(result, CONCAT(chr(10) || 'Different table structures of table: ', dev_scheme_row.TABLE_NAME));  
                    END IF;             
                END IF;
            END LOOP;    
            
            IF is_found = FALSE THEN
               result := CONCAT(result, CONCAT(chr(10) || 'No table: ', dev_scheme_row.TABLE_NAME));
            END IF;
   END LOOP;
   
    return result;
END;

CREATE OR REPLACE FUNCTION get_diff_between_schemes(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
RETURN VARCHAR2
IS

result VARCHAR2(2000);

BEGIN
    result := get_diff_between_tables(dev_scheme, prod_scheme);   
    return result;
END;

DECLARE
    result VARCHAR2(120);
BEGIN
    result := get_diff_between_schemes('DEV_SCHEME', 'PROD_SCHEME');
    DBMS_OUTPUT.PUT_LINE(result);
END;
