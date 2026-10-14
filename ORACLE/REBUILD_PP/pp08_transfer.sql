alter session set global_names=false;
set timing on time on serveroutput on

BEGIN
For i in (SELECT * FROM TABLE(rdsadmin.rds_file_util.listdir('DATA_PUMP_DIR')) where filename like 'EXP%.dmp')
loop
 DBMS_FILE_TRANSFER.PUT_FILE(
    source_directory_object       => 'DATA_PUMP_DIR',
    source_file_name              => i.filename,
    destination_directory_object  => 'DATA_PUMP_DIR',
    destination_file_name         => i.filename,
    destination_database          => 'NEW_DBLINK' );
end loop;
END;
/

-- Elapsed: 00:03:29.75

