grant select on dba_data_files to DBMAINT;
grant select on dba_free_space to DBMAINT;
grant select on dba_tablespaces to DBMAINT;
grant alter tablespace to DBMAINT;

GRANT CREATE JOB TO DBMAINT;
GRANT EXECUTE ON DBMS_SCHEDULER TO DBMAINT;

