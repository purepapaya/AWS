-- Generates (and optionally runs) DBMS_STATS.GATHER_TABLE_STATS calls for every
-- partition of BVINE.APII_TRANS whose MAX(IN_TS) > SYSDATE-90.
--
-- Same caveat as the size-check script: this table is RANGE (APII_TRANS_ID)
-- INTERVAL partitioned / HASH (IN_TS) subpartitioned, so MAX(IN_TS) per partition
-- must be read from the data, not inferred from partition bounds.
--
-- Set c_execute below to TRUE to actually gather stats in this run;
-- leave FALSE to just print the DBMS_STATS commands for review before running them.

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  c_owner       CONSTANT VARCHAR2(30)  := '&2';
  c_table_name  CONSTANT VARCHAR2(30)  := '&1';
  c_days        CONSTANT NUMBER        := 90;
  c_execute     CONSTANT BOOLEAN       := FALSE;

  v_max_in_ts   TIMESTAMP;
  v_part_count  NUMBER := 0;
BEGIN
  FOR p IN (
    SELECT partition_name, partition_position
    FROM   all_tab_partitions
    WHERE  table_owner = c_owner
    AND    table_name   = c_table_name
    ORDER BY partition_position
  )
  LOOP
    BEGIN
      EXECUTE IMMEDIATE
        'SELECT MAX(IN_TS) FROM "' || c_owner || '"."' || c_table_name ||
        '" PARTITION ("' || p.partition_name || '")'
      INTO v_max_in_ts;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Skipping partition ' || p.partition_name || ' due to error: ' || SQLERRM);
        CONTINUE;
    END;

    IF v_max_in_ts IS NOT NULL AND v_max_in_ts > SYSDATE - c_days THEN
      v_part_count := v_part_count + 1;

      DBMS_OUTPUT.PUT_LINE(
        'exec DBMS_STATS.GATHER_TABLE_STATS(' ||
        'ownname => ''' || c_owner || ''', ' ||
        'tabname => ''' || c_table_name || ''', ' ||
        'partname => ''' || p.partition_name || ''', ' ||
        'granularity => ''ALL'', ' ||
        'estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE, ' ||
        'method_opt => ''FOR ALL COLUMNS SIZE AUTO'', ' ||
        'degree => DBMS_STATS.AUTO_DEGREE, ' ||
        'cascade => TRUE); '
      );

      IF c_execute THEN
        DBMS_STATS.GATHER_TABLE_STATS(
          ownname          => c_owner,
          tabname          => c_table_name,
          partname         => p.partition_name,
          granularity      => 'PARTITION',
          estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
          method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
          degree           => DBMS_STATS.AUTO_DEGREE,
          cascade          => TRUE
        );
      END IF;
    END IF;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
  DBMS_OUTPUT.PUT_LINE(
    'Partitions with max(in_ts) > sysdate-' || c_days || ': ' || v_part_count ||
    CASE WHEN c_execute
         THEN ' (stats gathered)'
         ELSE ' (commands printed only -- set c_execute := TRUE to run them)'
    END
  );
END;
/
