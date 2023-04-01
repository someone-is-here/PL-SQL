alter session set "_ORACLE_SCRIPT"=true;  

CREATE USER DEV_SCHEME IDENTIFIED BY DEV;
grant all privileges to DEV_SCHEME;

CREATE USER PROD_SCHEME IDENTIFIED BY PROD;
grant all privileges to PROD_SCHEME;

DROP USER PROD_USER CASCADE;
DROP USER DEV_USER CASCADE;

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

CREATE OR REPLACE FUNCTION remove_prod_indexes(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
 RETURN NCLOB
IS

CURSOR c_dev_scheme 
IS SELECT owner, index_name, table_name, uniqueness from all_indexes
    WHERE owner=dev_scheme;
    
CURSOR c_prod_scheme 
IS SELECT owner, index_name, table_name, uniqueness from all_indexes
    WHERE owner=prod_scheme;

dev_scheme_row c_dev_scheme%ROWTYPE;
prod_scheme_row c_prod_scheme%ROWTYPE;

lv_result NCLOB;
is_found BOOLEAN;

BEGIN
    FOR  prod_scheme_row IN c_prod_scheme
        LOOP        
         is_found := FALSE;
         FOR dev_scheme_row IN c_dev_scheme
            LOOP
            IF  prod_scheme_row.index_name=dev_scheme_row.index_name AND
                prod_scheme_row.table_name=dev_scheme_row.table_name  THEN
                is_found :=  TRUE;
            END IF;
            
            END LOOP;
            
            IF is_found=FALSE AND substr(prod_scheme_row.index_name,1,3) != 'SYS' THEN   
                lv_result :=  CONCAT(lv_result, chr(10) || 
                    utl_lms.format_message('DROP INDEX %s.%s;', prod_scheme, prod_scheme_row.index_name));              
                    END IF;
    END LOOP;    
      return lv_result;
END;

CREATE OR REPLACE FUNCTION create_or_update_indexes(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
RETURN NCLOB
IS 
lv_result NCLOB;
is_found BOOLEAN;

CURSOR c_dev_scheme 
IS SELECT owner, index_name, table_name, uniqueness from all_indexes
    WHERE owner=dev_scheme;

CURSOR c_prod_scheme 
IS SELECT owner, index_name, table_name, uniqueness from all_indexes
    WHERE owner=prod_scheme;
   
dev_scheme_row c_dev_scheme%ROWTYPE;
prod_scheme_row c_prod_scheme%ROWTYPE;

BEGIN
    FOR dev_scheme_row IN c_dev_scheme
   LOOP
        is_found := FALSE;
        
         FOR prod_scheme_row IN c_prod_scheme
            LOOP
            
            IF  prod_scheme_row.index_name=dev_scheme_row.index_name AND
                prod_scheme_row.table_name=dev_scheme_row.table_name THEN
                is_found := true;
                IF check_is_different_indexes(dev_scheme, dev_scheme_row.table_name, dev_scheme_row.index_name,
                                                            prod_scheme, prod_scheme_row.table_name, prod_scheme_row.index_name) THEN
                     lv_result :=  CONCAT(lv_result, chr(10) || 
                    utl_lms.format_message('DROP INDEX %s.%s;', prod_scheme, prod_scheme_row.index_name));
                    lv_result := CONCAT(lv_result, chr(10) || 
                    utl_lms.format_message('CREATE INDEX %s ON %s.%s (%s);',
                    dev_scheme_row.index_name, prod_scheme, dev_scheme_row.TABLE_NAME, TO_NCHAR(substr(get_index_columns(dev_scheme, dev_scheme_row.table_name, dev_scheme_row.index_name),1,32766))));   
                END IF;
            END IF;
                
            END LOOP;   
            IF is_found=false AND substr(dev_scheme_row.index_name,1,3) != 'SYS' THEN
                    lv_result := CONCAT(lv_result, chr(10) || utl_lms.format_message('CREATE INDEX %s ON %s.%s (%s);',
                    dev_scheme_row.index_name, prod_scheme, dev_scheme_row.TABLE_NAME, TO_NCHAR(substr(get_index_columns(dev_scheme, dev_scheme_row.table_name, dev_scheme_row.index_name),1,32766))));   
                END IF;
        END LOOP;
        
    return lv_result;
END;

CREATE OR REPLACE FUNCTION check_is_different_indexes(dev_scheme VARCHAR2, dev_table VARCHAR2, dev_index VARCHAR2,
                                                    prod_scheme VARCHAR2, prod_table VARCHAR2, prod_index VARCHAR2)
RETURN BOOLEAN
IS 

lv_col_prod_index NCLOB;
lv_col_dev_index NCLOB;

is_equal BOOLEAN := false; 

BEGIN
    lv_col_prod_index := get_index_columns(prod_scheme, prod_table, prod_index);
    lv_col_dev_index := get_index_columns(dev_scheme, dev_table, dev_index);
     
    IF lv_col_prod_index=
         lv_col_dev_index THEN
        is_equal := true;
    END IF;
    
    return is_equal;
END;

CREATE OR REPLACE FUNCTION get_index_columns(scheme VARCHAR2, table_nm VARCHAR2, index_nm VARCHAR2)
RETURN NCLOB
IS 

lv_col_index_list NCLOB;   

BEGIN

    SELECT LISTAGG(COLUMN_name, ', ') WITHIN GROUP (ORDER BY column_position) list_index into lv_col_index_list
    FROM DBA_IND_COLUMNS
    WHERE table_name=table_nm AND index_owner=scheme AND index_name=index_nm
    GROUP BY index_name
    ORDER BY list_index;
    
    return lv_col_index_list;
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
    From all_objects
    WHERE owner=dev_scheme AND object_type=type
    ORDER BY object_name;
    
CURSOR curr_prod IS
    SELECT owner, object_name, object_type
    From all_objects 
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
    From all_objects 
    WHERE owner=dev_scheme AND object_type=type
    ORDER BY object_name;
    
CURSOR curr_prod IS
    SELECT owner, object_name, object_type
    From all_objects 
    WHERE owner=prod_scheme AND object_type=type
    ORDER BY object_name;

dev_scheme_col curr_dev%ROWTYPE;
prod_scheme_col curr_prod%ROWTYPE;

lv_result NCLOB;
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
                lv_result := CONCAT(lv_result, chr(10) || 'DROP ' || type || ' ' || prod_scheme_col.OBJECT_NAME || ';');
            END IF;
    END LOOP;    
      return lv_result;
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
                     result := CONCAT(result, chr(10) || 'Different table structures of table: ' || dev_scheme_row.TABLE_NAME);                
                    END IF;   
                    
                    IF is_diff_constraints(dev_scheme, dev_scheme_row.TABLE_NAME,
                                    prod_scheme, prod_scheme_row.TABLE_NAME) THEN
                                    
                    result := CONCAT(result, chr(10) || 'Different table constraints of table: ' || dev_scheme_row.TABLE_NAME);           
                    END IF;  
                END IF;
            END LOOP;    
            
            IF is_found = FALSE THEN          
                result := CONCAT(result, chr(10) || 
               utl_lms.format_message('CREATE TABLE %s.%s AS SELECT * FROM %s.%s;',
               prod_scheme, dev_scheme_row.TABLE_NAME, dev_scheme, dev_scheme_row.TABLE_NAME));   
            END IF;
   END LOOP;
   
    return result;
END;

CREATE OR REPLACE FUNCTION get_diff_between_schemes(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
RETURN NCLOB
IS
lc_function CONSTANT VARCHAR2(9) := 'FUNCTION';  
lc_procedure CONSTANT VARCHAR2(10) := 'PROCEDURE';  
lc_package CONSTANT VARCHAR2(7) := 'PACKAGE'; 
lc_package_body CONSTANT VARCHAR2(13) := 'PACKAGE BODY';  
lv_result NCLOB;

BEGIN
--workable
    lv_result := CONCAT(lv_result,  create_objects_in_prod(dev_scheme, prod_scheme, lc_function));
    lv_result := CONCAT(lv_result,  remove_objects_in_prod(dev_scheme, prod_scheme, lc_function));
    lv_result := CONCAT(lv_result,  create_objects_in_prod(dev_scheme, prod_scheme, lc_procedure));
    lv_result := CONCAT(lv_result,  remove_objects_in_prod(dev_scheme, prod_scheme, lc_procedure));
    lv_result := CONCAT(lv_result,  create_objects_in_prod(dev_scheme, prod_scheme, lc_package));
    lv_result := CONCAT(lv_result,  remove_objects_in_prod(dev_scheme, prod_scheme, lc_package));
    lv_result := CONCAT(lv_result,  create_objects_in_prod(dev_scheme, prod_scheme, lc_package_body));
    lv_result := CONCAT(lv_result,  remove_objects_in_prod(dev_scheme, prod_scheme, lc_package_body));
    lv_result := CONCAT(lv_result, create_or_update_indexes(dev_scheme, prod_scheme));
    lv_result := CONCAT(lv_result, remove_prod_indexes(dev_scheme, prod_scheme));
--      lv_result := CONCAT(lv_result,  get_diff_between_tables(dev_scheme, prod_scheme)); 
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

SELECT owner, object_name, object_type
    From all_objects 
    WHERE owner='DEV_SCHEME'
    ORDER BY object_name;
 
SELECT owner, object_name, object_type
    From all_objects 
    WHERE owner='PROD_SCHEME'
    ORDER BY object_name;
    
--WITH FindRoot AS (
--    SELECT Id, ParentId, CAST(Id AS NCHAR(32767)), Path, 0 Distance
--    FROM dbo.MyTable
--
--    UNION ALL
--
--    SELECT C.Id, P.ParentId, C.Path + N' > ' + CAST(P.Id AS NCHAR(32767)), C.Distance + 1
--    FROM dbo.MyTable P
--    JOIN FindRoot C
--    ON C.ParentId = P.Id AND P.ParentId <> P.Id AND C.ParentId <> C.Id
-- )

--  
--    SELECT LISTAGG(COLUMN_name, '; ') WITHIN GROUP (ORDER BY column_position) into lv_dev_index_list
--    FROM DBA_IND_COLUMNS
--    WHERE table_name=dev_scheme AND index_owner=dev_scheme
--    GROUP BY index_name;
--    
--    IF lv_prod_index_list=lv_dev_index_list THEN
--        is_equal := true;
--    END IF;

SELECT owner, index_name, table_name, uniqueness from all_indexes
    WHERE owner='DEV_SCHEME';

    
SELECT LISTAGG(COLUMN_name, '') WITHIN GROUP (ORDER BY column_position) list_index
    FROM DBA_IND_COLUMNS
    WHERE table_name='A1' AND index_owner='DEV_SCHEME' AND index_name='A3_INDEX'
    GROUP BY index_name
    ORDER BY list_index;
--SELECT *
--FROM FindRoot R
--WHERE R.Id = R.ParentId 
--  AND R.ParentId <> 0
--  AND R.Distance > 0;