CREATE TABLE DBMAINT.tbs_growth_log (
    log_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    log_date          DATE DEFAULT SYSDATE,
    tablespace_name   VARCHAR2(30),
    old_pct_used      NUMBER(5,2),
    old_size_gb       NUMBER(18,2),
    action_taken      VARCHAR2(2000),
    datafile_count    NUMBER,
    status            VARCHAR2(50),
    error_msg         VARCHAR2(4000)
) pctfree 0;


select sys_context('USERENV', 'DB_NAME'), sum(datafile_count),sum(datafile_count)*32 as GB
from DBMAINT.tbs_growth_log
where status='SUCCESS' and log_date between ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1) and TRUNC(SYSDATE, 'MM') -1;


WITH last_month AS (
    SELECT * FROM DBMAINT.tbs_growth_log
    WHERE  log_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1) AND log_date <  TRUNC(SYSDATE, 'MM') and status='SUCCESS'
),
tbs_over_6 AS (
    SELECT tablespace_name, SUM(datafile_count) AS total_added
    FROM   last_month
    GROUP BY tablespace_name
    HAVING SUM(datafile_count) > 6
)
SELECT
    -- Total datafiles added across all tablespaces last month
    NVL((SELECT SUM(datafile_count) FROM last_month), 0) AS total_added_all,
    -- List of tablespaces exceeding 6 datafiles, or 'NONE'
    NVL(
        (SELECT LISTAGG(tablespace_name, ', ') WITHIN GROUP (ORDER BY tablespace_name)
         FROM tbs_over_6),
        'NONE'
    ) AS tablespaces_over_6,
    -- Total added just for those >6 tablespaces
    NVL((SELECT SUM(total_added) FROM tbs_over_6), 0) AS total_added_for_over_6
FROM dual;


WITH last_month AS (
    SELECT tablespace_name,datafile_count FROM DBMAINT.tbs_growth_log
    WHERE  log_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1) AND log_date <  TRUNC(SYSDATE, 'MM') and status='SUCCESS'
),
tbs_over_6 AS (
    SELECT tablespace_name, SUM(datafile_count) AS total_added
    FROM   last_month
    GROUP BY tablespace_name HAVING SUM(datafile_count) > 6
)
SELECT sys_context('USERENV', 'DB_NAME')||' ('||to_char(TRUNC(SYSDATE, 'MM')-1,'YYYY-MON')||') Total_Added: '||
    NVL((SELECT SUM(datafile_count)*32 FROM last_month), 0)||'GB, TBS_Grew_GT_200GB: '||
    NVL((SELECT LISTAGG(tablespace_name, ',') WITHIN GROUP (ORDER BY tablespace_name) FROM tbs_over_6), 'NONE') 
FROM dual;

desc DBMAINT.tbs_growth_log@lnk_galileo
