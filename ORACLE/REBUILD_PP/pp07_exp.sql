set scan off
set serveroutput on
set escape off
whenever sqlerror exit 

DECLARE
    h1 number;
    s varchar2(1000):=NULL;
    v_jobname   VARCHAR2(30) := 'EXP_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24');
    errorvarchar varchar2(100):= 'ERROR';
    tryGetStatus number := 0;
    success_with_info EXCEPTION;
    PRAGMA EXCEPTION_INIT(success_with_info, -31627);
begin
    h1 := dbms_datapump.open (operation => 'EXPORT', job_mode => 'SCHEMA', job_name => v_jobname, version => 'COMPATIBLE'); 
    tryGetStatus := 1;
    dbms_datapump.set_parallel(handle => h1, degree => 1); 
    dbms_datapump.add_file(handle => h1, filename => v_jobname || '_%U.dmp', directory => 'DATA_PUMP_DIR', filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE); 
    dbms_datapump.metadata_filter(handle => h1, name => 'SCHEMA_EXPR', value => 'IN(''ELIS_MS_WORK_MGMT'',''ELIS_MS_LB'',''NTVAN'',''ELIS_MS_JRS'',''PC_ELIS2'',''ELIS_MS_ELIS_QUERY'',''ELIS_MS_ETS'',''ELIS_MS_DMS_EXPLORER'',''ACTIVITIUSERDEVELOP'',''ELIS2USERDEVELOP'',''ELIS_MS_OFF_REC_DOC_GEN'',''SAHOSSEI'',''ELIS_MS_IDRES'',''ELIS_MS_DVS'',''ORAMON'',''ELIS_MS_DIG_EVD_VIEWER'',''ELIS_MS_CRU'',''ELIS2_LB_ADMIN'',''ELIS2DATADEVELOP'',''ELIS_MS_ERDS'',''ELIS_MS_CDDS'',''ACTIVITIDATADEVELOP'',''ELIS2CODEDEVELOP'',''ACTIVITICODEDEVELOP'',''JRWINSTE'',''ACALCAMO'',''ECHAN1'',''PJGIFFIN'',''MJBUCHMA'',''CSJACOBS'',''TSGANDHO'',''JDAYRES'',''SAHMED1'',''MRANJBAR'',''RPARAMAS'',''JCHEUNG1'',''TGROBERS'',''DMBELYEA'',''GABOGNAR'',''BSAXENA'',''DDKIM'',''JGARCIAR'',''KVCHAGAN'',''DJKRAMER'',''BADAVIS'',''MAWILLIA'',''RLBILYEU'',''MABROMAV'',''YYOON'',''TQIU'',''CKGARCIA'',''SNKRANKI'',''WCHEN1'',''DRSCHUMA'',''SPMCCALL'',''KRNEELEY'',''RCREDDY'',''JMKHANAN'',''JRLO'',''MKLEIN'',''CYGAW'',''BMBISSET'',''MSBAUER'',''LPSCHARE'',''GKBRYANT'',''BDRICKS'',''MAPALITT'',''JRGILL'',''DMGOLLHA'',''JARUSSEL'',''EDFRANKL'',''NRJACKSO'',''HRSHAH1'',''HVARDHA'',''KWGYOVAI'',''LRNATHAN'',''CPGOETTE'',''JPEDDY'',''JKKALYAN'',''MAHMED'',''YYLUK'',''TABROADN'',''RTMCNISH'',''CCGRAVES'',''MEFUENTE'',''WSHI'',''EAZHU'',''JWLUO'',''MLKUNIAN'',''GDELIYA'',''JMGIONFR'',''SAHMED3'',''EYALVIAL'',''GGMCDONN'',''NBSHREST'',''JBHAMRIC'',''RATURKMA'',''ADBERTEL'',''WHBERHE'',''DQTEAGUE'',''CSANUNKO'',''LCHELLER'',''NABRADY'',''CJWILSON'',''OCTIEDEM'',''AMPATRIC'',''CWFISCHE'',''SKWOK'',''TMNGUYE1'',''JATHOMAS'',''JDBOGGS'',''ALULCIUC'',''YLIU'',''TNKOONTZ'',''CRHUMPHR'',''CJSULLI1'',''KIMALIK'',''EDNAVAR'',''ELIS_MS_ELP'',''AKFRYER'',''RDHANDA'',''ALNGUYEN'',''MTARAQ'',''JMLEAHY'',''VAULTADMIN'',''KVENUGOP'',''BHUANG'',''SCSIM'',''EBWAKTOL'',''SSKWON'',''TJRANDOL'',''CENEWSOM'',''ELIS_MS_EICP'',''PCHAU'',''HTTRANG'',''JDHUBBAR'',''HZHOU1'',''JEBILBRO'',''SPLUNKAUD'',''SSHARMA4'',''MYTARK'',''BCMADSEN'',''AGGEBREL'',''ALMONGER'',''EAHYNDMA'',''MDLAPUZ'',''JSCORY'',''BNGUYEN'',''ARAHMAN'',''JFWANG'',''CMOMEILI'',''BCLEMON'',''ELIS_MS_PFVS'',''WHKUEH'',''FJGLAESE'',''CISSCAN'',''CNTANG'',''SIBRAHI1'',''CAMANIBU'',''JAYAMADA'',''MAKWIATK'',''PRHARDIN'',''EJONES'',''NJWARZIN'',''CAJUDD'',''RVRAMIRE'',''TBFIKADU'',''MROZENTS'',''SMAO'',''RTNGO'',''MHTEKLEZ'',''AISLAM'',''GHEISBRU'',''AJKAMIEN'')');

    dbms_datapump.add_file(handle => h1, filename => v_jobname || '.log', directory => 'DATA_PUMP_DIR',  filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE); 
    dbms_datapump.data_filter(handle => h1, name => 'INCLUDE_ROWS', value => 1);
    dbms_datapump.set_parameter(handle => h1, name => 'DATA_ACCESS_METHOD', value => 'AUTOMATIC'); 
    dbms_datapump.metadata_filter(h1, 'EXCLUDE_PATH_EXPR', 'IN (''STATISTICS'')');
    -- Optional: compress everything (data + metadata) to shrink the dump file
    DBMS_DATAPUMP.SET_PARAMETER(handle => h1, name => 'COMPRESSION', value => 'ALL');
    dbms_datapump.start_job(handle => h1, skip_current => 0, abort_step => 0); 
    dbms_datapump.detach(handle => h1); 
    errorvarchar := 'NO_ERROR'; 
EXCEPTION
    WHEN OTHERS THEN
    BEGIN 
        IF ((errorvarchar = 'ERROR')AND(tryGetStatus=1)) THEN 
            DBMS_DATAPUMP.DETACH(h1);
        END IF;
    EXCEPTION 
    WHEN OTHERS THEN 
        NULL;
    END;
    RAISE;
END;
/

