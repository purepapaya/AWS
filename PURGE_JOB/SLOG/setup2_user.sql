CREATE SEQUENCE DBMAINT.purge_log_run_id_seq START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE DBMAINT.PURGE_LOG (
  log_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  log_ts         TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  run_id         NUMBER NOT NULL,
  owner          VARCHAR2(128),
  table_name     VARCHAR2(128),
  partition_name VARCHAR2(128),
  action         VARCHAR2(30) NOT NULL,
  status         VARCHAR2(10) NOT NULL,
  message        VARCHAR2(4000),
  CONSTRAINT purge_log_pk PRIMARY KEY (log_id)
) pctfree 0;


CREATE OR REPLACE EDITIONABLE PROCEDURE "DBMAINT"."PURGE_STOREDPROC_LOGS" (
  p_dryrun IN NUMBER DEFAULT 0 -- 1 = print the commands only, do not execute them
)
IS
  -- Requires SELECT on DBA_TABLES/DBA_SEGMENTS/DBA_TAB_PARTITIONS and ALTER TABLE
  -- privilege on every schema's STOREDPROC_LOGS table (e.g. run as a DBA-privileged account).
  -- Assumes STOREDPROC_LOGS is range-partitioned on IN_TS (or a column that yields a
  -- comparable DATE boundary in HIGH_VALUE).
  c_threshold_bytes CONSTANT NUMBER := 53687091200; -- 50 GB

  v_sql      VARCHAR2(4000);
  v_boundary DATE;
  v_run_id   NUMBER;

  -- Autonomous so a log row survives regardless of the caller's transaction state.
  PROCEDURE log_event (
    p_owner     IN VARCHAR2 DEFAULT NULL,
    p_table     IN VARCHAR2 DEFAULT NULL,
    p_partition IN VARCHAR2 DEFAULT NULL,
    p_action    IN VARCHAR2,
    p_status    IN VARCHAR2,
    p_message   IN VARCHAR2 DEFAULT NULL
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO DBMAINT.PURGE_LOG (run_id, owner, table_name, partition_name, action, status, message)
    VALUES (v_run_id, p_owner, p_table, p_partition, p_action, p_status, p_message);
    COMMIT;
  END log_event;

BEGIN
  SELECT DBMAINT.purge_log_run_id_seq.NEXTVAL INTO v_run_id FROM dual;

  log_event(p_action => 'RUN_START', p_status => 'INFO',
    p_message => 'p_dryrun=' || NVL(p_dryrun, 0));

  FOR t IN (
    SELECT owner, table_name, SUM(bytes) AS total_bytes
    FROM (
      -- STOREDPROC_LOGS is RANGE(IN_TS)/HASH(LOG_ID) composite partitioned,
      -- so only its subpartitions carry a segment; consider TABLE SUBPARTITION only.
      SELECT tsp.table_owner AS owner, tsp.table_name, seg.bytes
      FROM   dba_tab_subpartitions tsp
      JOIN   dba_segments seg
        ON   seg.owner          = tsp.table_owner
        AND  seg.segment_name   = tsp.table_name
        AND  seg.partition_name = tsp.subpartition_name
        AND  seg.segment_type   = 'TABLE SUBPARTITION'
      WHERE  tsp.table_name = 'STOREDPROC_LOGS'
    )
    GROUP BY owner, table_name
    HAVING SUM(bytes) > c_threshold_bytes
  ) LOOP

    DBMS_OUTPUT.PUT_LINE('-- ' || t.owner || '.' || t.table_name ||
      ' size = ' || ROUND(t.total_bytes / 1024 / 1024 / 1024, 2) || ' GB, evaluating partitions older than SYSDATE-90');

    log_event(p_owner => t.owner, p_table => t.table_name, p_action => 'TABLE_OVER_THRESHOLD',
      p_status => 'INFO', p_message => 'size_gb=' || ROUND(t.total_bytes / 1024 / 1024 / 1024, 2));

    FOR p IN (
      SELECT partition_name, partition_position, high_value
      FROM   dba_tab_partitions
      WHERE  table_owner = t.owner
        AND  table_name  = t.table_name
      ORDER BY partition_position
    ) LOOP

      -- HIGH_VALUE is a partitioning-key expression (e.g. TO_DATE('...')); evaluate it.
      -- MAXVALUE or non-date boundaries raise an exception and are skipped.
      BEGIN
        EXECUTE IMMEDIATE 'SELECT ' || p.high_value || ' FROM dual' INTO v_boundary;
      EXCEPTION
        WHEN OTHERS THEN
          v_boundary := NULL;
          DBMS_OUTPUT.PUT_LINE('-- Skipping partition ' || p.partition_name ||
            ' (could not evaluate high_value): ' || SQLERRM);
          log_event(p_owner => t.owner, p_table => t.table_name, p_partition => p.partition_name,
            p_action => 'EVAL_HIGH_VALUE', p_status => 'SKIPPED', p_message => SQLERRM);
      END;

      IF v_boundary IS NOT NULL AND v_boundary <= (SYSDATE - 90) THEN

        v_sql := 'ALTER TABLE "' || t.owner || '"."' || t.table_name ||
                 '" TRUNCATE PARTITION "' || p.partition_name || '" UPDATE INDEXES';
        IF NVL(p_dryrun, 0) = 1 THEN
          DBMS_OUTPUT.PUT_LINE(v_sql || ';');
        ELSE
          BEGIN
            EXECUTE IMMEDIATE v_sql;
            log_event(p_owner => t.owner, p_table => t.table_name, p_partition => p.partition_name,
              p_action => 'TRUNCATE_PARTITION', p_status => 'SUCCESS');
          EXCEPTION
            WHEN OTHERS THEN
              DBMS_OUTPUT.PUT_LINE('-- FAILED to truncate partition ' || p.partition_name ||
                ' on ' || t.owner || '.' || t.table_name || ': ' || SQLERRM);
              log_event(p_owner => t.owner, p_table => t.table_name, p_partition => p.partition_name,
                p_action => 'TRUNCATE_PARTITION', p_status => 'FAILED', p_message => SQLERRM);
              CONTINUE;
          END;
        END IF;

        v_sql := 'ALTER TABLE "' || t.owner || '"."' || t.table_name ||
                 '" DROP PARTITION "' || p.partition_name || '" UPDATE INDEXES';
        IF NVL(p_dryrun, 0) = 1 THEN
          DBMS_OUTPUT.PUT_LINE(v_sql || ';');
        ELSE
          BEGIN
            EXECUTE IMMEDIATE v_sql;
            DBMS_SESSION.SLEEP(5);
            DBMS_OUTPUT.PUT_LINE('-- ' || t.owner || '.' || t.table_name ||
              ' truncated and dropped partition ' || p.partition_name ||
              ' (boundary ' || TO_CHAR(v_boundary, 'YYYY-MM-DD') || ')');
            log_event(p_owner => t.owner, p_table => t.table_name, p_partition => p.partition_name,
              p_action => 'DROP_PARTITION', p_status => 'SUCCESS',
              p_message => 'boundary=' || TO_CHAR(v_boundary, 'YYYY-MM-DD'));
          EXCEPTION
            WHEN OTHERS THEN
              DBMS_OUTPUT.PUT_LINE('-- FAILED to drop partition ' || p.partition_name ||
                ' on ' || t.owner || '.' || t.table_name || ': ' || SQLERRM);
              log_event(p_owner => t.owner, p_table => t.table_name, p_partition => p.partition_name,
                p_action => 'DROP_PARTITION', p_status => 'FAILED', p_message => SQLERRM);
          END;
        END IF;
      END IF;

    END LOOP;

  END LOOP;

  log_event(p_action => 'RUN_END', p_status => 'SUCCESS');
EXCEPTION
  WHEN OTHERS THEN
    log_event(p_action => 'RUN_END', p_status => 'FAILED', p_message => SQLERRM);
    RAISE;
END purge_storedproc_logs;
/
