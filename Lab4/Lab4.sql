SET SQLBLANKLINES ON

--write into file json object
DECLARE
  out_File  UTL_FILE.FILE_TYPE;
  lc_dir_name VARCHAR2(6) := 'RTVMS2';
  lc_file_name VARCHAR(8) := 'test.txt';
  lc_text_input NCLOB := '{
	''select'': {
		''columns'': [''id'', ''name'', ''surname'', ''group''],
		''tables'': [''students'']
	},	
	''create'': {		
		''groups'': {
			''columns'': {
				''id'': {
                    ''type'': ''number'',
                    ''allow_null'': ''NOT NULL''
                },
				''name'': {
					''type'': ''varchar2'',
					''size'': 50,
                    ''allow_null'': ''NOT NULL''
				}
			},
			''constraints'': {
				''group_pk'': {
                    ''PRIMARY KEY'': [''id'']
                }
			}	
        },
        ''students'': {
			''columns'': {
				''id'': {
                    ''type'': ''number'',
                    ''allow_null'': ''NOT NULL''
                },
				''name'': {
					''type'': ''varchar2'',
					''size'': 50,
                    ''allow_null'': ''NOT NULL''
				},
                ''surname'': {
					''type'': ''varchar2'',
					''size'': 50,
                    ''allow_null'': ''NOT NULL''
				},
                ''group_id'': {
                    ''type'': ''number'',
                    ''allow_null'': ''NOT NULL''
                }
			},
			''constraints'': {
				''students_pk'': {
                    ''PRIMARY KEY'': [''id'',''name'']
                },
                ''student_group_fk'': {
                    ''FOREIGN KEY'': {
                        ''columns'': [''group_id'', ''group_name''],
                        ''table_name'': ''groups'',
                        ''columns_from'': [''id'', ''name'']
                    }
                }
			}	
        }
	},
    ''drop'': {
        ''tables'': [''students'', ''groups'']
    }
}';
BEGIN
  out_File := UTL_FILE.FOPEN(lc_dir_name, lc_file_name , 'W');

  UTL_FILE.PUT_LINE(out_file , lc_text_input);
  UTL_FILE.FCLOSE(out_file);
END;

create or replace function parse_json_drop_object(js_obj JSON_OBJECT_T)
RETURN NCLOB
IS
lv_result_query NCLOB;

lv_ja JSON_ARRAY_T;
lv_ja_tables JSON_ARRAY_T;
lv_keys JSON_KEY_LIST;
BEGIN
    lv_ja := new JSON_ARRAY_T;
    
    lv_keys := js_obj.get_keys;
    FOR i IN 1..lv_keys.COUNT LOOP
        lv_ja_tables := js_obj.get_array(lv_keys(i));
        FOR j IN 0..lv_ja_tables.get_size - 1 LOOP
            lv_result_query := CONCAT(lv_result_query, 
             utl_lms.format_message('DROP TABLE %s;', lv_ja_tables.get(j).to_string) || chr(10));
        END LOOP;
    END LOOP;
    lv_result_query := replace(lv_result_query, '"', '');
    RETURN lv_result_query;
END;

create or replace function parse_json_create_object(js_obj JSON_OBJECT_T)
RETURN NCLOB
IS
lv_result_data NCLOB;
lv_result_constr NCLOB;
lv_ja JSON_ARRAY_T;
lv_ja_tables JSON_ARRAY_T;
lv_keys_tab_names JSON_KEY_LIST;
lv_keys_tab_param JSON_KEY_LIST;
lv_keys_tab_columns JSON_KEY_LIST;
lv_keys_tab_constr JSON_KEY_LIST;
lv_keys_temp JSON_KEY_LIST;
lv_jo_table JSON_OBJECT_T;
lv_jo_param JSON_OBJECT_T;
lv_jo_temp JSON_OBJECT_T;
lv_jo_constraints JSON_OBJECT_T;
BEGIN
    lv_ja := new JSON_ARRAY_T;
    
    lv_keys_tab_names := js_obj.get_keys; 
    --table_names
    FOR i IN 1..lv_keys_tab_names.COUNT LOOP
        lv_jo_table := js_obj.get_object(lv_keys_tab_names(i));
        lv_keys_tab_param := lv_jo_table.get_keys;
        lv_result_data := CONCAT(lv_result_data, 
             utl_lms.format_message('CREATE TABLE %s (', lv_keys_tab_names(i)));
       --columns & constraints
        FOR j IN 1..lv_keys_tab_param.COUNT LOOP
            lv_jo_param := lv_jo_table.get_object(lv_keys_tab_param(j));
            lv_keys_tab_columns := lv_jo_param.get_keys;
            
            IF upper(lv_keys_tab_param(j)) = upper('columns') THEN  
                FOR k IN 1..lv_keys_tab_columns.COUNT LOOP
                    lv_result_data := CONCAT(lv_result_data, chr(10) || lv_keys_tab_columns(k));
               
                    lv_jo_temp := lv_jo_param.get_object(lv_keys_tab_columns(k)); -- jo {type, size}
                    lv_keys_temp := lv_jo_temp.get_keys;
                    FOR n in 1..lv_keys_temp.COUNT LOOP   
                        IF lv_keys_temp(n) = 'size' THEN
                            lv_result_data := CONCAT(lv_result_data,  utl_lms.format_message('(%s)',lv_jo_temp.get(lv_keys_temp(n)).to_string));
                        ELSE
                             lv_result_data := CONCAT(lv_result_data, ' ' || lv_jo_temp.get(lv_keys_temp(n)).to_string);
                        END IF;
                    END LOOP;
                    lv_result_data := CONCAT(lv_result_data, ',');   
                END LOOP;          
            ELSIF upper(lv_keys_tab_param(j)) = upper('constraints') THEN
                    lv_result_constr := '';
                    lv_keys_tab_constr := lv_jo_param.get_keys;
                    FOR n in 1..lv_keys_tab_constr.COUNT LOOP
                        lv_jo_temp := lv_jo_param.get_object(lv_keys_tab_constr(n));
                        lv_result_constr := CONCAT(lv_result_constr, 'CONSTRAINT ' || lv_keys_tab_constr(n)); --pk_id
                        lv_keys_temp := lv_jo_temp.get_keys;
                        lv_result_constr := CONCAT(lv_result_constr, utl_lms.format_message(' %s (', lv_keys_temp(1))); --PRIMARY KEY
                        IF upper(lv_keys_temp(1)) = 'PRIMARY KEY' THEN
                            lv_ja := lv_jo_temp.get_array(lv_keys_temp(1));
                            for k in 0..lv_ja.get_size - 1 LOOP
                                lv_result_constr := CONCAT(lv_result_constr, lv_ja.get(k).to_string || ', ');
                                IF k = lv_ja.get_size - 1 THEN
                                    lv_result_constr := SUBSTR(lv_result_constr, 1, length(lv_result_constr) - 2);
                                END IF;
                            END LOOP;  
                            lv_result_constr := CONCAT(lv_result_constr, '),' || chr(10));
                        ELSIF upper(lv_keys_temp(1)) = 'FOREIGN KEY' THEN
                            lv_jo_temp := lv_jo_temp.get_object(lv_keys_temp(1));
                            lv_keys_temp := lv_jo_temp.get_keys; -- col, tab_nam, col_from
                        lv_ja := lv_jo_temp.get_array(lv_keys_temp(1));
                        for k in 0..lv_ja.get_size - 1 LOOP
                            lv_result_constr := CONCAT(lv_result_constr, lv_ja.get(k).to_string || ', ');
                            IF k = lv_ja.get_size - 1 THEN
                                lv_result_constr := SUBSTR(lv_result_constr, 1, length(lv_result_constr) - 2);
                            END IF;
                        END LOOP;  
                        lv_result_constr := CONCAT(lv_result_constr, ') REFERENCES ' || lv_jo_temp.get(lv_keys_temp(2)).to_string || '( ');
                        lv_ja := lv_jo_temp.get_array(lv_keys_temp(3));
                        for k in 0..lv_ja.get_size - 1 LOOP
                            lv_result_constr := CONCAT(lv_result_constr, lv_ja.get(k).to_string || ', ');
                             IF k = lv_ja.get_size - 1 THEN
                                lv_result_constr := SUBSTR(lv_result_constr, 1, length(lv_result_constr) - 2);
                            END IF;
                        END LOOP;  
                        lv_result_constr := CONCAT(lv_result_constr, ' ) ');
                        IF lv_keys_temp.COUNT >= 4 THEN 
                            lv_result_constr := CONCAT(lv_result_constr, 'ON DELETE ' || lv_jo_temp.get(lv_keys_temp(4)).to_string || ', ');
                        ELSE 
                         lv_result_constr := CONCAT(lv_result_constr, 'ON DELETE NO ACTION, ');
                        END IF;
                    END IF;
                    END LOOP;
                    
            END IF;
        END LOOP;
        lv_result_data := CONCAT(lv_result_data, chr(10) || lv_result_constr);
        lv_result_data := SUBSTR(lv_result_data, 1, LENGTH(lv_result_data)-2);
        lv_result_data := CONCAT(lv_result_data, ');' || chr(10));
    END LOOP;
    lv_result_data := replace(lv_result_data, '"', '');
    RETURN lv_result_data;
END;

create or replace function parse_json_select_object(js_obj JSON_OBJECT_T)
RETURN NCLOB
IS
lv_result_query NCLOB;
BEGIN
    RETURN 'RESULT';
END;

create or replace function parse_json(json_str NCLOB)
RETURN VARCHAR2
IS
lv_jo JSON_OBJECT_T;
lv_keys JSON_KEY_LIST;
lv_ja JSON_ARRAY_T;
lv_jo_temp JSON_OBJECT_T;
BEGIN
    lv_ja := new JSON_ARRAY_T;
    lv_jo := JSON_OBJECT_T.parse(json_str);
    lv_keys := lv_jo.get_keys;

    FOR i IN 1..lv_keys.COUNT LOOP
        DBMS_OUTPUT.put_line(lv_keys(i));
        lv_jo_temp := lv_jo.get_object(lv_keys(i));
        
        CASE lv_keys(i)
        WHEN 'select' THEN DBMS_OUTPUT.put_line(parse_json_select_object(lv_jo_temp));
        WHEN 'create' THEN DBMS_OUTPUT.put_line(parse_json_create_object(lv_jo_temp));
        WHEN 'drop' THEN DBMS_OUTPUT.put_line(parse_json_drop_object(lv_jo_temp));
        ELSE DBMS_OUTPUT.put_line('No operation availiable for ' || lv_jo_temp.to_string);
        END CASE;
        
    END LOOP;
    return 'Hi';
END;

declare
v_buff NCLOB;
lv_json_str NCLOB;
fhandle UTL_FILE.FILE_TYPE;
lc_dir_name VARCHAR2(6) := 'RTVMS2';
lc_file_name VARCHAR(8) := 'test.txt';
lv_res VARCHAR2(13);
begin
    fhandle := UTL_FILE.FOPEN(lc_dir_name, lc_file_name, 'R');
    LOOP 
          BEGIN 
             UTL_FILE.GET_LINE(fhandle, v_buff);
             lv_json_str := CONCAT(lv_json_str, chr(10) || v_buff);
          EXCEPTION 
             WHEN OTHERS THEN EXIT;
          END;
    END LOOP;
    UTL_FILE.FCLOSE(fhandle);
    lv_res := parse_json(lv_json_str);
end;