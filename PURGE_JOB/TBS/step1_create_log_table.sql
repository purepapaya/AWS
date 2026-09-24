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
