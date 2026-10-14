set timing on time on
SET SERVEROUTPUT ON

DECLARE
    h1          NUMBER;
    v_job_state VARCHAR2(30);
    v_jobname   VARCHAR2(30) := 'IMP_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISS');
    errorvarchar VARCHAR2(30);
    tryGetStatus number := 0;
    v_job_status KU$_STATUS;
BEGIN
    h1 := DBMS_DATAPUMP.OPEN( operation => 'IMPORT', job_mode  => 'SCHEMA', job_name  => v_jobname);
  
    -- Point at the dump file(s) produced by the export job
    DBMS_DATAPUMP.ADD_FILE( handle    => h1, filename  => 'EXP_2026081321_%U.dmp', directory => 'DATA_PUMP_DIR', filetype  => DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
    DBMS_DATAPUMP.ADD_FILE( handle    => h1, filename  => v_jobname || '.log', directory => 'DATA_PUMP_DIR', filetype  => DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);

    -- What to do if objects already exist: SKIP | APPEND | TRUNCATE | REPLACE
    DBMS_DATAPUMP.SET_PARAMETER(handle => h1, name => 'TABLE_EXISTS_ACTION', value => 'SKIP');
    DBMS_DATAPUMP.SET_PARALLEL(handle => h1, degree => 2);

    DBMS_DATAPUMP.START_JOB(h1);
    DBMS_OUTPUT.PUT_LINE('Started job: ' || v_jobname);

    --v_job_state := 'UNDEFINED';
    --WHILE v_job_state NOT IN ('COMPLETED', 'STOPPED') LOOP
    --  DBMS_DATAPUMP.GET_STATUS( handle=> h1, mask => DBMS_DATAPUMP.KU$_STATUS_JOB_STATUS, timeout   => 60, job_state => v_job_state, status=>v_job_status);
      --DBMS_OUTPUT.PUT_LINE('Job state: ' || v_job_state);
    --END LOOP;

    DBMS_DATAPUMP.DETACH(handle => h1);
    DBMS_OUTPUT.PUT_LINE('Job ' || v_jobname || ' finished with state ' || v_job_state);
EXCEPTION
    WHEN OTHERS THEN
    BEGIN 
        IF ((errorvarchar = 'ERROR')AND(tryGetStatus=1)) THEN 
            DBMS_DATAPUMP.DETACH(h1);
        END IF;
    EXCEPTION 
    WHEN OTHERS THEN 
        NULL;
    END;
    RAISE;
END;
/

-- Job "MASTER"."IMP_20260722190550" completed with 8911 error(s) at Thu Jul 23 17:21:08 2026 elapsed 0 22:15:15

