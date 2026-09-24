BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'DBMAINT.TBS_MAINTENANCE_JOB',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'DBMAINT.tbs_manager.check_and_extend_tbs',
        number_of_arguments => 1,
        start_date      => SYSTIMESTAMP AT TIME ZONE 'America/Los_Angeles',
        repeat_interval => 'FREQ=DAILY; BYHOUR=7; BYMINUTE=0',
        job_class       => 'DBMAINT_JOBS_CLASS',
        comments        => 'Runs daily at 7 AM PST'
    );

    -- Set argument (dry run = TRUE)
    DBMS_SCHEDULER.set_job_argument_value(
        job_name => 'DBMAINT.TBS_MAINTENANCE_JOB',
        argument_position => 1,
        argument_value => '0'
    );

    DBMS_SCHEDULER.enable('DBMAINT.TBS_MAINTENANCE_JOB');
END;
/
