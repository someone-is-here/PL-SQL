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
WHERE owner='DEV_SCHEME' AND table_name='DEPARTMENTS'
ORDER BY constraint_type; 

select * 
From all_constraints 
WHERE owner='DEV_SCHEME' AND table_name='EMPLOYEES'
ORDER BY constraint_type;


SELECT owner, index_name, table_name, uniqueness from all_indexes
    WHERE owner='DEV_SCHEME';
    
select owner, constraint_name, constraint_type, table_name, r_owner,r_constraint_name, search_condition, status, index_name, index_owner 
From all_constraints 
WHERE owner='PROD_SCHEME' AND table_name='TEST_CONSTR'; 


-- checks is constrains are similar
select owner, constraint_name, constraint_type, table_name, search_condition_vc, status 
From all_constraints 
WHERE owner='DEV_SCHEME' AND table_name='TEST_CONSTR'; 


select *
From all_constraints 
WHERE owner='DEV_SCHEME' AND table_name='DEPARTMENTS'; 

select *
    from all_constraints
    where r_owner = 'DEV_SCHEME'
    and constraint_type = 'R'   
    and table_name = 'USERS'
    and r_constraint_name in (
        select constraint_name from all_constraints
        where constraint_type in ('P', 'U')
        and owner = 'DEV_SCHEME')
    order by table_name, constraint_name;
    
 select * from all_constraints
        where constraint_type in ('P', 'U')
        and owner = 'DEV_SCHEME';
        
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

grant SELECT_CATALOG_ROLE to function create_table;
CREATE OR REPLACE FUNCTION create_table(dev_scheme VARCHAR2, prod_scheme VARCHAR2, table_name VARCHAR2)
RETURN NCLOB
AS 
lv_result NCLOB;
BEGIN
    select dbms_metadata.get_ddl('TABLE', table_name, dev_scheme) INTO lv_result from dual;
    lv_result := CONCAT(REGEXP_REPLACE(lv_result, upper(dev_scheme),upper(prod_scheme)), ';');
    
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

CREATE OR REPLACE FUNCTION is_diff_reference_key(scheme_name VARCHAR2, table_nm VARCHAR2, constr_nm VARCHAR2)
RETURN VARCHAR2
IS
lv_constr_nm VARCHAR2(30);    
lv_table_nm VARCHAR2(30);

BEGIN
    select r_constraint_name into lv_constr_nm
    from all_constraints
    where r_owner = scheme_name
    and constraint_type = 'R'   
    and table_name = table_nm
    and constraint_name=constr_nm;
    
    select table_name into lv_table_nm from all_constraints
        where constraint_type in ('P', 'U')
        and owner = scheme_name and constraint_name=lv_constr_nm;
        
   return lv_table_nm;
   
   EXCEPTION
        WHEN no_data_found
    THEN
        lv_table_nm := 'null';
        return lv_table_nm;

END;

CREATE OR REPLACE FUNCTION is_diff_constraints(dev_scheme VARCHAR2, dev_table VARCHAR2,                            
                                          prod_scheme VARCHAR2, prod_table VARCHAR2)
RETURN BOOLEAN
IS

CURSOR curr_dev IS
    SELECT owner, constraint_name, constraint_type, table_name, search_condition_vc, status, index_name 
    From all_constraints 
    WHERE owner=dev_scheme AND table_name=dev_table
    ORDER BY constraint_type;
    
CURSOR curr_prod IS
    SELECT owner, constraint_name, constraint_type, table_name, search_condition_vc, status, index_name 
    From all_constraints 
    WHERE owner=prod_scheme AND table_name=prod_table 
    ORDER BY constraint_type;

dev_scheme_col curr_dev%ROWTYPE;
prod_scheme_col curr_prod%ROWTYPE;
is_different_constraint BOOLEAN := FALSE;

BEGIN
    FOR  dev_scheme_col IN curr_dev
        LOOP        
         FOR prod_scheme_col IN curr_prod
            LOOP
            IF  (prod_scheme_col.constraint_type='C' AND dev_scheme_col.constraint_type='C')
            AND (prod_scheme_col.CONSTRAINT_TYPE!=dev_scheme_col.CONSTRAINT_TYPE OR
                prod_scheme_col.SEARCH_CONDITION_VC!=dev_scheme_col.SEARCH_CONDITION_VC OR
                prod_scheme_col.STATUS!=dev_scheme_col.STATUS) THEN
                is_different_constraint := TRUE; 
            ELSIF (prod_scheme_col.constraint_type='R' AND dev_scheme_col.constraint_type='R') AND
              (prod_scheme_col.constraint_name != dev_scheme_col.constraint_name
            OR is_diff_reference_key(dev_scheme, dev_scheme_col.table_name, dev_scheme_col.constraint_name)
            !=is_diff_reference_key(prod_scheme, prod_scheme_col.table_name, prod_scheme_col.constraint_name)) THEN
                is_different_constraint := TRUE; 

            ELSIF (prod_scheme_col.constraint_type='P' AND dev_scheme_col.constraint_type='P') AND
            not check_is_different_indexes(dev_scheme, dev_scheme_col.table_name, dev_scheme_col.index_name,
                                                    prod_scheme, prod_scheme_col.table_name, prod_scheme_col.index_name)THEN
                is_different_constraint := TRUE; 
            END IF;

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

lv_result NCLOB;

BEGIN

 FOR dev_scheme_row IN curr_dev_scheme
   LOOP
        is_found := FALSE;
        
         FOR prod_scheme_row IN curr_prod_scheme
            LOOP
                IF prod_scheme_row.TABLE_NAME = dev_scheme_row.TABLE_NAME THEN
                    is_found := TRUE;
                    IF check_table_on_circular_references(dev_scheme,  dev_scheme_row.TABLE_NAME) THEN
                            DBMS_OUTPUT.PUT_LINE('------CIRCULAR REFERENCE FOUND ON TABLE ' || dev_scheme ||'.'|| dev_scheme_row.table_name);
                    END IF;
                    IF check_table_on_circular_references(prod_scheme,  prod_scheme_row.TABLE_NAME) THEN
                            DBMS_OUTPUT.PUT_LINE('------CIRCULAR REFERENCE FOUND ON TABLE ' || prod_scheme ||'.'|| prod_scheme_row.table_name);
                    END IF;
                    IF is_diff_tables(dev_scheme, dev_scheme_row.TABLE_NAME,
                                    prod_scheme, prod_scheme_row.TABLE_NAME) THEN
                                    
                        lv_result := CONCAT(lv_result, chr(10) || '--DROP AND RECREATE BECAUSE OF DIFFERENT TABLES STRUCTURE');    
                        lv_result := CONCAT(lv_result, chr(10) || 
                                   utl_lms.format_message('DROP TABLE %s.%s;',
                                    prod_scheme, prod_scheme_row.TABLE_NAME)); 
                        lv_result := CONCAT(lv_result, chr(10) || 
                                   create_table(dev_scheme, prod_scheme, dev_scheme_row.TABLE_NAME));              
                    ELSIF is_diff_constraints(dev_scheme, dev_scheme_row.TABLE_NAME,
                                    prod_scheme, prod_scheme_row.TABLE_NAME) THEN
                                    
                    lv_result := CONCAT(lv_result, chr(10) || '--DROP AND RECREATE BECAUSE OF DIFFERENT TABLES CONSTRAINTS');    
                        lv_result := CONCAT(lv_result, chr(10) || 
                                   utl_lms.format_message('DROP TABLE %s.%s;',
                                    prod_scheme, prod_scheme_row.TABLE_NAME)); 
                        lv_result := CONCAT(lv_result, chr(10) || 
                                   create_table(dev_scheme, prod_scheme, dev_scheme_row.TABLE_NAME));              
                    END IF;   
                    
                     
                END IF;
            END LOOP;    
            
            IF is_found = FALSE THEN          
               lv_result := CONCAT(lv_result, chr(10) || 
                                   create_table(dev_scheme, prod_scheme, dev_scheme_row.TABLE_NAME));   
            END IF;
   END LOOP;
   
    return lv_result;
END;

CREATE OR REPLACE FUNCTION remove_prod_tables(dev_scheme VARCHAR2,
                                                    prod_scheme VARCHAR2)
RETURN NCLOB
IS
CURSOR curr_dev_scheme 
IS SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_scheme;

CURSOR curr_prod_scheme 
IS SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_scheme;

is_found BOOLEAN;
lv_result NCLOB;

BEGIN

 FOR prod_scheme_row IN curr_prod_scheme
   LOOP
        is_found := FALSE;
        
         FOR dev_scheme_row IN curr_dev_scheme
            LOOP
                IF prod_scheme_row.TABLE_NAME = dev_scheme_row.TABLE_NAME THEN
                    is_found := TRUE;        
                    END IF;   
            END LOOP;    
            
            IF is_found = FALSE THEN          
               lv_result := CONCAT(lv_result, chr(10) || 
                                   utl_lms.format_message('DROP TABLE %s.%s;',
                                    prod_scheme, prod_scheme_row.TABLE_NAME)); 
            END IF;
   END LOOP;
   
    return lv_result;
END;

CREATE OR REPLACE FUNCTION find_circular_references(scheme_name VARCHAR2, table_nm VARCHAR2, constr_nm VARCHAR2,
                                                        old_name VARCHAR2, table_temp_name VARCHAR2)
RETURN VARCHAR2
IS
lv_curr_table_name VARCHAR2(100);
CURSOR curr_names_fk(tab_name VARCHAR2) IS 
select *
    from all_constraints
    where r_owner = scheme_name
    and constraint_type = 'R'   
    and table_name = tab_name
    and r_constraint_name in (
        select constraint_name from all_constraints
        where constraint_type in ('P', 'U')
        and owner = scheme_name)
    order by table_name, constraint_name;
    
lv_row curr_names_fk%ROWTYPE;
lv_row_count number := 0;
sql_stmt VARCHAR2(50);

BEGIN
    lv_curr_table_name := is_diff_reference_key(scheme_name , table_nm, constr_nm);
    EXECUTE IMMEDIATE  utl_lms.format_message('INSERT INTO %s(name) VALUES (%s)', table_temp_name, CONCAT('''', table_nm||''''));
    IF table_nm != 'null' THEN
        EXECUTE IMMEDIATE  utl_lms.format_message('select COUNT(name) from %s WHERE name=%s', table_temp_name, CONCAT('''', table_nm || '''')) INTO lv_row_count;
    END IF;                         
 WHILE lv_curr_table_name != 'null' AND lv_curr_table_name != old_name AND lv_row_count <= 1
  LOOP
  OPEN curr_names_fk(lv_curr_table_name);
    LOOP
        FETCH curr_names_fk INTO lv_row;
        lv_curr_table_name := find_circular_references(scheme_name , lv_curr_table_name, lv_row.constraint_name, old_name, table_temp_name);
  
         EXECUTE IMMEDIATE  utl_lms.format_message('INSERT INTO %s(name) VALUES (%s)', table_temp_name, CONCAT('''', lv_curr_table_name||''''));
         IF table_nm != 'null' THEN
            EXECUTE IMMEDIATE  utl_lms.format_message('select COUNT(name) from %s WHERE name=%s', table_temp_name, CONCAT('''', lv_curr_table_name || '''')) INTO lv_row_count;
        END IF; 
    
        EXIT WHEN curr_names_fk%notfound OR 
        lv_curr_table_name = old_name OR
        lv_curr_table_name='null' OR
        lv_row_count > 1;
        
    END LOOP;
    CLOSE curr_names_fk;
    END LOOP;
    
    IF lv_curr_table_name = old_name THEN
        return lv_curr_table_name;
    END IF;
    IF lv_row_count > 1 THEN
        return old_name;
    END IF;
    
    return 'null';
END;

CREATE OR REPLACE FUNCTION check_table_on_circular_references(scheme_name VARCHAR2, table_nm VARCHAR2)
RETURN BOOLEAN
IS
CURSOR curr_constr IS
select *
    from all_constraints
    where r_owner = scheme_name
    and constraint_type = 'R'   
    and table_name = table_nm
    and r_constraint_name in (
        select constraint_name from all_constraints
        where constraint_type in ('P', 'U')
        and owner = scheme_name)
    order by table_name, constraint_name;

lv_constr_row curr_constr%ROWTYPE;
lv_table_name VARCHAR(30) := 'temp12345678';
BEGIN
    FOR lv_constr_row IN curr_constr
    LOOP
     EXECUTE IMMEDIATE  utl_lms.format_message('CREATE TABLE %s (name VARCHAR2(100))', lv_table_name);
        IF find_circular_references(scheme_name, table_nm, lv_constr_row.constraint_name, table_nm, lv_table_name) = table_nm THEN
            EXECUTE IMMEDIATE utl_lms.format_message('DROP TABLE %s', lv_table_name);
            return true;
        ELSE
            EXECUTE IMMEDIATE utl_lms.format_message('DROP TABLE %s', lv_table_name);
        END IF;
    END LOOP;
    return false;
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
    
    lv_result := CONCAT(lv_result,  get_diff_between_tables(dev_scheme, prod_scheme)); 
    lv_result := CONCAT(lv_result,  remove_prod_tables(dev_scheme, prod_scheme));    
    return lv_result;
END;


DECLARE
  lv_result    CLOB;
  lv_buffer  VARCHAR2(32766);
  lv_amount  BINARY_INTEGER := 32766;
  lv_offset     INTEGER := 1;
  res BOOLEAN;
BEGIN
    lv_result := get_diff_between_schemes('DEV_SCHEME', 'PROD_SCHEME');

  LOOP
    DBMS_LOB.READ(lv_result, lv_amount, lv_offset, lv_buffer);
    DBMS_OUTPUT.PUT_LINE(lv_buffer);
    lv_offset := lv_offset + lv_amount;
    EXIT WHEN lv_amount > DBMS_LOB.GETLENGTH(lv_result) - lv_offset + 1;
  END LOOP;
END;
