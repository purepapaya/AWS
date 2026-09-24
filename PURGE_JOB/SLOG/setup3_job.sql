BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'DBMAINT.PURGE_STOREDPROC_LOGS_JOB',
    job_type        => 'STORED_PROCEDURE',
    job_action      => 'DBMAINT.purge_storedproc_logs',
    number_of_arguments => 0,
    start_date      => SYSTIMESTAMP,
    -- America/Los_Angeles observes PDT/PST automatically across DST changes.
    repeat_interval => 'FREQ=WEEKLY;BYDAY=THU;BYHOUR=21;BYMINUTE=0;BYSECOND=0',
    job_class       => 'DBMAINT_JOBS_CLASS',
    enabled         => FALSE,
    comments        => 'Weekly purge of old STOREDPROC_LOGS partitions, Thu 9pm America/Los_Angeles'
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'DBMAINT.PURGE_STOREDPROC_LOGS_JOB',
    attribute => 'start_date',
    value     => TO_TIMESTAMP_TZ(TO_CHAR(SYSDATE, 'YYYY-MM-DD') || ' 21:00:00 America/Los_Angeles',
                                  'YYYY-MM-DD HH24:MI:SS TZR')
  );

  DBMS_SCHEDULER.ENABLE('DBMAINT.PURGE_STOREDPROC_LOGS_JOB');
END;
/

/*
-- one time
  BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
      job_name        => 'DBMAINT.PURGE_STOREDPROC_LOGS_ADHOC',
      job_type        => 'STORED_PROCEDURE',
      job_action      => 'DBMAINT.purge_storedproc_logs',
      number_of_arguments => 0,
      start_date      => TO_TIMESTAMP_TZ('2026-09-23 21:00:00 America/Los_Angeles', 'YYYY-MM-DD HH24:MI:SS TZR'),
      job_class       => 'DBMAINT_JOBS_CLASS',
      enabled         => TRUE,
      auto_drop       => TRUE,
      comments        => 'One-off ad-hoc run for 2026-09-23 21:00 PDT'
    );
  END;
  /
*/
