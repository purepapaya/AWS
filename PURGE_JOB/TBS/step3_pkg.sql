CREATE OR REPLACE PACKAGE DBMAINT.tbs_manager AS
    PROCEDURE check_and_extend_tbs(p_dry_run IN NUMBER DEFAULT 0);
END tbs_manager;
/

CREATE OR REPLACE PACKAGE BODY DBMAINT.tbs_manager AS
    PROCEDURE check_and_extend_tbs(p_dry_run IN NUMBER DEFAULT 0) IS
        -- Cursor to get smallfile tablespaces with current size, max size, and percent used
        CURSOR c_tbs IS
            WITH df AS ( SELECT tablespace_name, SUM(bytes) AS cur_bytes,
                       SUM(CASE WHEN maxbytes > 0 THEN maxbytes ELSE bytes END) AS max_bytes
                FROM dba_data_files GROUP BY tablespace_name),
            fs AS ( SELECT tablespace_name, SUM(bytes) AS free_bytes FROM dba_free_space GROUP BY tablespace_name)
            SELECT ts.tablespace_name, df.cur_bytes, df.max_bytes, NVL(fs.free_bytes,0) AS free_bytes,
                   ROUND(((df.cur_bytes - NVL(fs.free_bytes,0)) / df.max_bytes) * 100, 2) AS pct_used,
                   ROUND(df.cur_bytes/POWER(1024,3),2) AS allocated_gb,
                   ROUND(df.max_bytes/POWER(1024,3),2) AS max_gb
              FROM dba_tablespaces ts
              JOIN df ON ts.tablespace_name = df.tablespace_name
              LEFT JOIN fs ON ts.tablespace_name = fs.tablespace_name
             WHERE ts.bigfile = 'NO' and ROUND(((df.cur_bytes - NVL(fs.free_bytes,0)) / df.max_bytes) * 100, 2)>=80;

        v_datafile_count INTEGER := 0;
        v_total_count    INTEGER := 0;
        v_action         VARCHAR2(4000);
        v_sql            VARCHAR2(4000);
        v_err            VARCHAR2(4000);
        v_status         VARCHAR2(20);
    BEGIN
        FOR r IN c_tbs LOOP
            v_action := NULL;
            BEGIN
                -- Decide how many datafiles to add based on thresholds
                IF r.max_gb < 800 AND r.pct_used >= 80 THEN
                    v_datafile_count := ROUND(ceil(0.1*r.max_gb/32),0);
                ELSIF r.max_gb between 800 and 5120 AND r.pct_used >= 85 THEN
                    v_datafile_count := ROUND(ceil(0.05*r.max_gb/32),0);
                ELSIF r.max_gb >= 5120 AND r.pct_used >= 90 THEN
                    v_datafile_count := ROUND(ceil(0.05*r.max_gb/32),0);
                ELSE
                    v_datafile_count := 0;
                END IF;
                -- do not exceed max datafiles to add per day per tablespace:
                IF v_datafile_count > 6 THEN
                    DBMS_OUTPUT.PUT_LINE('WARNING: max reached for '||r.tablespace_name||' '||v_datafile_count);
                    v_datafile_count :=  6;
                END IF;
                -- do not exceed max storage to add per day
                IF v_total_count > 30 THEN
                    DBMS_OUTPUT.PUT_LINE('WARNING: max total reached: '||v_total_count);
                    v_datafile_count := 0;
                ELSE
                   v_total_count := v_total_count + v_datafile_count;
                END IF;
                IF v_datafile_count > 0 THEN
                    IF p_dry_run = 1 THEN
                       v_action := '[DRY RUN] Would add ' || v_datafile_count || ' datafile(s) in ' || r.tablespace_name;
                       DBMS_OUTPUT.PUT_LINE(v_action);
                       v_status := 'DRYRUN';
                    ELSE
                       -- Add the required number of datafiles
                       FOR i IN 1 .. v_datafile_count LOOP
                          v_sql := 'ALTER TABLESPACE '||r.tablespace_name||' ADD DATAFILE SIZE 32767M';
                          EXECUTE IMMEDIATE v_sql;
                       END LOOP;
                       v_action := 'Added ' || v_datafile_count || ' datafile(s)';
                       v_status := 'SUCCESS';
                    END IF;
                ELSE
                    v_action := 'No action required.';
                    v_status := 'NOACTION';
                END IF;

                -- Log success
                IF v_datafile_count > 0 THEN
                   INSERT INTO DBMAINT.tbs_growth_log(tablespace_name, old_pct_used, old_size_gb, action_taken, datafile_count, status)
                   VALUES (r.tablespace_name, r.pct_used, r.max_gb, v_action, v_datafile_count, v_status);
                   COMMIT;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_err := SQLERRM;
                    -- Log failure
                    INSERT INTO DBMAINT.tbs_growth_log ( tablespace_name, old_pct_used, old_size_gb, action_taken, datafile_count, status, error_msg)
                    VALUES ( r.tablespace_name, r.pct_used, r.max_gb, v_action, v_datafile_count, 'FAILED', v_err);
                    COMMIT;
            END;
        END LOOP;
        IF v_total_count > 30 THEN
            INSERT INTO DBMAINT.tbs_growth_log(tablespace_name, old_pct_used, old_size_gb, action_taken, datafile_count, status)
            VALUES ('TOTAL', 0, 0, '[WARNING] 1TB quota exceeded!', v_total_count, 'WARNING');
            COMMIT;
        END IF;

    END check_and_extend_tbs;

END tbs_manager;
/
