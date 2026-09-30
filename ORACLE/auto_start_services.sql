CREATE OR REPLACE EDITIONABLE PROCEDURE "MASTER"."START_EL_SERVICES"
IS
cursor tempvar is select name from sys.service$ where network_name is not null and name not in (select value from v$parameter where name='service_names');
loopvar tempvar%ROWTYPE;
begin
OPEN tempvar;
loop
fetch tempvar into loopvar;
EXIT WHEN tempvar%NOTFOUND;
begin
  sys.DBMS_SERVICE.start_service(loopvar.name);
end;
end loop;
close tempvar;
end;
/

CREATE OR REPLACE EDITIONABLE TRIGGER "MASTER"."TR_START_EL_SERVICES"
after startup on database
begin
start_el_services;
end;
/
