SET SERVEROUTPUT ON SIZE UNLIMITED
set linesize 500 trimspool on feedback off term off verify off
spool purge_&1..&2..sql
prompt set timing on time on echo on set pagesize 0
DECLARE
  v_max_in_ts  TIMESTAMP;
  v_check_sql  VARCHAR2(500);
BEGIN
  FOR p IN (
    SELECT partition_name, partition_position
    FROM   all_tab_partitions
    WHERE  table_owner = '&2'
    AND    table_name  = '&1'
    ORDER BY partition_position
  ) LOOP

    v_check_sql := 'SELECT MAX(in_ts) FROM "&2"."&1" PARTITION ("' || p.partition_name || '")';

    EXECUTE IMMEDIATE v_check_sql INTO v_max_in_ts;

    IF v_max_in_ts IS NOT NULL AND v_max_in_ts < SYSDATE - 90 THEN
      DBMS_OUTPUT.PUT_LINE('-- Partition ' || p.partition_name ||
        ' MAX(IN_TS) = ' || TO_CHAR(v_max_in_ts, 'YYYY-MM-DD HH24:MI:SS'));
      DBMS_OUTPUT.PUT_LINE(v_check_sql || ';');
      DBMS_OUTPUT.PUT_LINE('ALTER TABLE "&2"."&1" TRUNCATE PARTITION "' || p.partition_name || '" UPDATE INDEXES;');
      DBMS_OUTPUT.PUT_LINE('ALTER TABLE "&2"."&1" DROP PARTITION "' || p.partition_name || '" UPDATE INDEXES;');
      DBMS_OUTPUT.PUT_LINE('host sleep 10');
      DBMS_OUTPUT.PUT_LINE(' ');
    END IF;

  END LOOP;
END;
/
spool off
set feedback on term on verify on

