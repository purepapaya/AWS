-- monthly_tbs_report.sql
set pagesize 0 linesize 500 trimspool on
WITH last_month AS (
    SELECT tablespace_name,datafile_count FROM DBMAINT.tbs_growth_log
    WHERE  log_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1) AND log_date <  TRUNC(SYSDATE, 'MM') and statu
s='SUCCESS'
),
tbs_over_6 AS (
    SELECT tablespace_name, SUM(datafile_count) AS total_added
    FROM   last_month
    GROUP BY tablespace_name HAVING SUM(datafile_count) > 6
)
SELECT sys_context('USERENV', 'DB_NAME')||' ('||to_char(TRUNC(SYSDATE, 'MM')-1,'YYYY-MON')||') Total_Added
: '||
    NVL((SELECT SUM(datafile_count)*32 FROM last_month), 0)||'GB, TBS_Grew_GT_200GB: '||
    NVL((SELECT LISTAGG(tablespace_name, ',') WITHIN GROUP (ORDER BY tablespace_name) FROM tbs_over_6), 'N
ONE')
FROM dual;


-- monthly_tbs_report.sh
#!/bin/bash -
#author         : yuliu
#date           : 2025.12.2
#version        : 1
#usage          : monthly_tbs_report.sh
#============================================================================
. /home/dba/setoraenv
TOOLING_DIR=/u03/dbanfs/database-tooling/current
$TOOLING_DIR/common/visitsql -g awscv $TOOLING_DIR/cron/admin/monthly_tbs_report.sql | grep Total > /tmp/monthly_tbs_report.txt
$TOOLING_DIR/common/visitsql -g awsprds $TOOLING_DIR/cron/admin/monthly_tbs_report.sql | grep Total >> /tmp/monthly_tbs_report.txt
cat /tmp/monthly_tbs_report.txt |mailx -s "Monthly TBS Report" yuliu@sofi.org,ubasterretxea@sofi.org,kpalit@sofi.org,rdasaiah@sofi.org,mignatoski@sofi.org,yliang@sofi.org,sunalcalargun@sofi.org,ptormey@sofi.org
