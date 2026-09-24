-- Sums total bytes for all partitions of BVINE.APII_TRANS whose MAX(IN_TS) > SYSDATE-90.
--
-- Table is RANGE (APII_TRANS_ID) INTERVAL partitioned, HASH (IN_TS) subpartitioned,
-- so IN_TS ranges cannot be inferred from partition metadata (hash has no ordering) --
-- each partition's MAX(IN_TS) must be queried from the data directly.
--
-- Uses ALL_TAB_PARTITIONS / ALL_TAB_SUBPARTITIONS / ALL_SEGMENTS, which only show
-- objects visible to the connected user. If running as a DBA-privileged account
-- instead of the table owner, swap the ALL_% views below for DBA_% for full visibility.

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  c_owner       CONSTANT VARCHAR2(30) := '&2';
  c_table_name  CONSTANT VARCHAR2(30) := '&1';
  c_days        CONSTANT NUMBER       := 90;

  v_max_in_ts   TIMESTAMP;
  v_part_bytes  NUMBER;
  v_total_bytes NUMBER := 0;
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

      SELECT NVL(SUM(s.bytes), 0)
      INTO   v_part_bytes
      FROM   dba_tab_subpartitions sp
      JOIN   dba_segments s
        ON   s.owner          = sp.table_owner
        AND  s.segment_name   = sp.table_name
        AND  s.partition_name = sp.subpartition_name
        AND  s.segment_type   = 'TABLE SUBPARTITION'
      WHERE  sp.table_owner    = c_owner
      AND    sp.table_name     = c_table_name
      AND    sp.partition_name = p.partition_name;

      v_total_bytes := v_total_bytes + v_part_bytes;
      v_part_count  := v_part_count + 1;

      DBMS_OUTPUT.PUT_LINE(
        RPAD(p.partition_name, 20) ||
        ' max(in_ts)=' || TO_CHAR(v_max_in_ts, 'YYYY-MM-DD HH24:MI:SS') ||
        '  bytes=' || TO_CHAR(v_part_bytes) ||
        '  (' || TO_CHAR(ROUND(v_part_bytes / 1024 / 1024, 2)) || ' MB)'
      );
    END IF;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('Partitions with max(in_ts) > sysdate-' || c_days || ': ' || v_part_count);
  DBMS_OUTPUT.PUT_LINE('Total bytes: ' || TO_CHAR(v_total_bytes) ||
                        '  (' || TO_CHAR(ROUND(v_total_bytes / 1024 / 1024 / 1024, 3)) || ' GB)');
END;
/
