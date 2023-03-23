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

CREATE OR REPLACE FUNCTION generate_code(scheme VARCHAR2, type VARCHAR2, name VARCHAR2)
RETURN VARCHAR2
IS
proc_code CLOB;
BEGIN
 select listagg(text, '') within group (order by line) into proc_code
    from all_source
    where owner = scheme
        and type = type
        and name = name
    group by name;
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

CREATE OR REPLACE FUNCTION get_diff_between_objects(dev_scheme VARCHAR2,                            
                                          prod_scheme VARCHAR2, type VARCHAR2)
RETURN VARCHAR2
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

result VARCHAR2(30000);
is_found BOOLEAN;

BEGIN
    result := '';
    FOR  dev_scheme_col IN curr_dev
        LOOP        
         is_found := FALSE;
         FOR prod_scheme_col IN curr_prod
            LOOP
            
            IF prod_scheme_col.OBJECT_NAME=dev_scheme_col.OBJECT_NAME THEN
                is_found :=  TRUE;
            END IF;
            
            END LOOP;
            
            IF is_found=FALSE THEN            
                result := CONCAT(result, chr(10) || generate_code(dev_scheme, type, dev_scheme_col.OBJECT_NAME));
            END IF;
    END LOOP;    
      return result;
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
ddl_script VARCHAR2(2000);

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
                    
                    IF is_diff_constraints(dev_scheme, dev_scheme_row.TABLE_NAME,
                                    prod_scheme, prod_scheme_row.TABLE_NAME) THEN
                                    
                    result := CONCAT(result, CONCAT(chr(10) || 'Different table constraints of table: ', dev_scheme_row.TABLE_NAME));  
                    END IF;  
                END IF;
            END LOOP;    
            
            IF is_found = FALSE THEN
               result := CONCAT(result, CONCAT(chr(10) || 'No table: ', dev_scheme_row.TABLE_NAME));
               ddl_script := CONCAT(ddl_script, chr(10) || 
               utl_lms.format_message('CREATE TABLE %s.%s AS SELECT * FROM %s.%s;',
               prod_scheme, dev_scheme_row.TABLE_NAME, dev_scheme, dev_scheme_row.TABLE_NAME));
            END IF;
   END LOOP;
   
    return ddl_script;
END;

CREATE OR REPLACE FUNCTION get_diff_between_schemes(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
RETURN CLOB
IS

result CLOB;

BEGIN
    result := get_diff_between_tables(dev_scheme, prod_scheme); 
    result := CONCAT(result, CONCAT(chr(10), get_diff_between_objects(dev_scheme, prod_scheme, 'FUNCTION')));
    result := CONCAT(result, CONCAT(chr(10), get_diff_between_objects(dev_scheme, prod_scheme, 'PROCEDURE')));
    result := CONCAT(result, CONCAT(chr(10), get_diff_between_objects(dev_scheme, prod_scheme, 'PACKAGE')));

    return result;
END;

DECLARE
    result CLOB;
BEGIN
    result := get_diff_between_schemes('DEV_SCHEME', 'PROD_SCHEME');
    DBMS_OUTPUT.PUT_LINE(result);
END;


select * from dba_objects 
   where owner='DEV_SCHEME' AND object_type in ( 'PROCEDURE', 'PACKAGE', 'FUNCTION', 'PACKAGE BODY' );
   
SELECT authid from all_procedures WHERE owner='DEV_SCHEME';

select * from dba_source where owner='DEV_SCHEME' and name='GREETINGS' order by line;
select * from dba_source where name='GREETINGS' order by line;