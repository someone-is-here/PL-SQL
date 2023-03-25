--TODO: CLOB used wrong 

alter session set "_ORACLE_SCRIPT"=true;  

CREATE USER DEV_SCHEME IDENTIFIED BY DEV;
grant all privileges to DEV_SCHEME;

grant DEBUG CONNECT SESSION, DEBUG ANY PROCEDURE to TANUSHA;

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
   
select owner, constraint_name, constraint_type, table_name, r_owner,r_constraint_name, search_condition, status, index_name, index_owner 
From all_constraints 
WHERE owner='DEV_SCHEME' AND table_name='EMPLOYEES'; 

select owner, constraint_name, constraint_type, table_name, r_owner,r_constraint_name, search_condition, status, index_name, index_owner 
From all_constraints 
WHERE owner='PROD_SCHEME' AND table_name='EMPLOYEES'; 

describe USER_CONSTRAINTS ;
-- checks is constrains are similar
select owner, constraint_name, constraint_type, table_name, search_condition_vc, status 
From all_constraints 
WHERE owner='DEV_SCHEME' AND table_name='USERS'; 


select *
From all_constraints 
WHERE owner='DEV_SCHEME' AND table_name='DEPARTMENTS'; 


SET SERVEROUTPUT ON;

CREATE OR REPLACE FUNCTION generate_code(scheme VARCHAR2, obj_type VARCHAR2, obj_name VARCHAR2)
RETURN NCLOB
IS
proc_code NCLOB;
BEGIN
 select listagg(text, '') within group (order by line) into proc_code
    from all_source
    where owner = scheme
        and type = obj_type
        and name = obj_name
    group by obj_name;
    
    proc_code := CONCAT('CREATE OR REPLACE ', proc_code);
    
    return proc_code;
END;

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

-- all functions return wrong info
CREATE OR REPLACE FUNCTION is_diff_constraints(dev_scheme VARCHAR2, dev_table VARCHAR2,                            
                                          prod_scheme VARCHAR2, prod_table VARCHAR2)
RETURN BOOLEAN
IS

CURSOR curr_dev IS
    SELECT owner, constraint_name, constraint_type, table_name, search_condition_vc, status 
    From all_constraints 
    WHERE owner=dev_scheme AND table_name=dev_table
    ORDER BY search_condition_vc;
    
CURSOR curr_prod IS
    SELECT owner, constraint_name, constraint_type, table_name, search_condition_vc, status 
    From all_constraints 
    WHERE owner=prod_scheme AND table_name=prod_table 
    ORDER BY search_condition_vc;

dev_scheme_col curr_dev%ROWTYPE;
prod_scheme_col curr_prod%ROWTYPE;

is_different_constraint BOOLEAN;

BEGIN
    FOR  dev_scheme_col IN curr_dev
        LOOP        
         FOR prod_scheme_col IN curr_prod
            LOOP
--            DBMS_OUTPUT.PUT_LINE('-----------' || prod_table || '-----------');
--            DBMS_OUTPUT.PUT_LINE(prod_scheme_col.CONSTRAINT_TYPE || ' ' || dev_scheme_col.CONSTRAINT_TYPE);
           -- DBMS_OUTPUT.PUT_LINE(prod_scheme_col.SEARCH_CONDITION_VC || ' ' || dev_scheme_col.SEARCH_CONDITION_VC);
--            DBMS_OUTPUT.PUT_LINE(prod_scheme_col.STATUS || ' ' || dev_scheme_col.SEARCH_CONDITION_VC);
            IF prod_scheme_col.CONSTRAINT_TYPE!=dev_scheme_col.CONSTRAINT_TYPE OR
                prod_scheme_col.SEARCH_CONDITION_VC!=dev_scheme_col.SEARCH_CONDITION_VC OR
                prod_scheme_col.STATUS!=dev_scheme_col.STATUS THEN
                is_different_constraint := TRUE; 
            ELSE
                is_different_constraint := FALSE; 
            END IF;
                is_different_constraint := TRUE; 
            END LOOP;
    END LOOP;
      
      return is_different_constraint;
END;

CREATE OR REPLACE FUNCTION check_is_different_objects(dev_scheme VARCHAR2,                            
                                          prod_scheme VARCHAR2, type VARCHAR2, object_name VARCHAR2)
RETURN BOOLEAN    
IS
    obj_code_1 NCLOB;
    obj_code_2 NCLOB;
BEGIN
    obj_code_1 := generate_code(dev_scheme, type, object_name);
    obj_code_2 := generate_code(prod_scheme, type, object_name);
    
    IF obj_code_1 = obj_code_2 THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;

CREATE OR REPLACE FUNCTION create_objects_in_prod(dev_scheme VARCHAR2,                            
                                          prod_scheme VARCHAR2, type VARCHAR2)
RETURN NCLOB
IS

CURSOR curr_dev IS
    SELECT owner, object_name, object_type
    From all_procedures 
    WHERE owner=dev_scheme AND object_type=type
    ORDER BY object_name;
    
CURSOR curr_prod IS
    SELECT owner, object_name, object_type
    From all_procedures 
    WHERE owner=prod_scheme AND object_type=type
    ORDER BY object_name;

dev_scheme_col curr_dev%ROWTYPE;
prod_scheme_col curr_prod%ROWTYPE;

result NCLOB;
is_found BOOLEAN;

BEGIN
    FOR  dev_scheme_col IN curr_dev
        LOOP        
         is_found := FALSE;
         FOR prod_scheme_col IN curr_prod
            LOOP
            IF prod_scheme_col.OBJECT_NAME=dev_scheme_col.OBJECT_NAME  
                AND not check_is_different_objects(dev_scheme, prod_scheme, type, dev_scheme_col.OBJECT_NAME) THEN
                is_found :=  TRUE;
            END IF;
            
            END LOOP;
            
            IF is_found=FALSE THEN   
                result := CONCAT(result, chr(10) || generate_code(dev_scheme, type, dev_scheme_col.OBJECT_NAME));
            END IF;
    END LOOP;    
      return result;
END;

CREATE OR REPLACE FUNCTION remove_objects_in_prod(dev_scheme VARCHAR2,                            
                                          prod_scheme VARCHAR2, type VARCHAR2)
RETURN NCLOB
IS

CURSOR curr_dev IS
    SELECT owner, object_name, object_type
    From all_procedures 
    WHERE owner=dev_scheme AND object_type=type
    ORDER BY object_name;
    
CURSOR curr_prod IS
    SELECT owner, object_name, object_type
    From all_procedures 
    WHERE owner=prod_scheme AND object_type=type
    ORDER BY object_name;

dev_scheme_col curr_dev%ROWTYPE;
prod_scheme_col curr_prod%ROWTYPE;

result NCLOB;
is_found BOOLEAN;

BEGIN
    FOR  prod_scheme_col IN curr_prod
        LOOP        
         is_found := FALSE;
         FOR dev_scheme_col IN curr_dev
            LOOP
            IF prod_scheme_col.OBJECT_NAME=dev_scheme_col.OBJECT_NAME THEN
                is_found :=  TRUE;
            END IF;
            
            END LOOP;
            
            IF is_found=FALSE THEN   
                result := CONCAT(result, chr(10) || 'DROP ' || type || ' ' || prod_scheme_col.OBJECT_NAME || ';');
            END IF;
    END LOOP;    
      return result;
END;

CREATE OR REPLACE FUNCTION get_diff_between_tables(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
RETURN NCLOB
IS
CURSOR curr_dev_scheme 
IS SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_scheme;

CURSOR curr_prod_scheme 
IS SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_scheme;

is_found BOOLEAN;

result NCLOB;
ddl_script NCLOB;

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
                     dbms_lob.append(result, CONCAT(result, CONCAT(chr(10) || 'Different table structures of table: ', dev_scheme_row.TABLE_NAME)));                
                    END IF;   
                    
                    IF is_diff_constraints(dev_scheme, dev_scheme_row.TABLE_NAME,
                                    prod_scheme, prod_scheme_row.TABLE_NAME) THEN
                                    
                    dbms_lob.append(result, CONCAT(result, CONCAT(result, CONCAT(chr(10) || 'Different table constraints of table: ', dev_scheme_row.TABLE_NAME))));           
                    END IF;  
                END IF;
            END LOOP;    
            
            IF is_found = FALSE THEN
                dbms_lob.append(result, CONCAT(chr(10) || 'No table: ', dev_scheme_row.TABLE_NAME));           
                dbms_lob.append(result, CONCAT(ddl_script, chr(10) || 
               utl_lms.format_message('CREATE TABLE %s.%s AS SELECT * FROM %s.%s;',
               prod_scheme, dev_scheme_row.TABLE_NAME, dev_scheme, dev_scheme_row.TABLE_NAME)));   
            END IF;
   END LOOP;
   
    return ddl_script;
END;

CREATE OR REPLACE FUNCTION get_diff_between_schemes(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
RETURN NCLOB
IS
lc_function CONSTANT VARCHAR2(9) := 'FUNCTION';  
lc_procedure CONSTANT VARCHAR2(10) := 'PROCEDURE';  
lv_result NCLOB;

BEGIN
    lv_result := CONCAT(lv_result,  create_objects_in_prod(dev_scheme, prod_scheme, lc_function));
    lv_result := CONCAT(lv_result,  remove_objects_in_prod(dev_scheme, prod_scheme, lc_function));
    lv_result := CONCAT(lv_result,  create_objects_in_prod(dev_scheme, prod_scheme, lc_procedure));
    lv_result := CONCAT(lv_result,  remove_objects_in_prod(dev_scheme, prod_scheme, lc_procedure));
    
    return lv_result;
END;


DECLARE
 -- l_file    UTL_FILE.FILE_TYPE;
  result    CLOB;
  lv_buffer  VARCHAR2(32766);
  lv_amount  BINARY_INTEGER := 32766;
  lv_offset     INTEGER := 1;
BEGIN
    
--  l_file := UTL_FILE.fopen('DOCUMENTS', 'prod.txt', 'w', 32766);
--    
  result := get_diff_between_schemes('DEV_SCHEME', 'PROD_SCHEME');
  LOOP
    DBMS_LOB.READ(result, lv_amount, lv_offset, lv_buffer);
    DBMS_OUTPUT.PUT_LINE(lv_buffer);
    --UTL_FILE.put(l_file, lv_buffer);
    lv_offset := lv_offset + lv_amount;
    EXIT WHEN lv_amount > DBMS_LOB.GETLENGTH(result) - lv_offset + 1;
  END LOOP;

--  EXCEPTION
--  WHEN OTHERS THEN
--    DBMS_OUTPUT.put_line(SQLERRM);
--    UTL_FILE.fclose(l_file);
--    
--UTL_FILE.fclose(l_file);
END;

    
select * from dba_objects 
   where owner='DEV_SCHEME' AND object_type in ( 'PROCEDURE', 'PACKAGE', 'FUNCTION', 'PACKAGE BODY' );
   
SELECT authid from all_procedures WHERE owner='DEV_SCHEME';

select * from dba_source where owner='DEV_SCHEME' and name='GREETINGS' order by line;
select * from dba_source where name='GREETINGS' order by line;