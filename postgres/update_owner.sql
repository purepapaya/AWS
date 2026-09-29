  -- tables
  DO $$
  DECLARE r RECORD;
  BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'schemaY' LOOP
      EXECUTE format('ALTER TABLE schemaY.%I OWNER TO userX', r.tablename);                                     
    END LOOP;
  END $$;

  -- sequences
  DO $$
  DECLARE r RECORD;
  BEGIN
    FOR r IN SELECT sequencename FROM pg_sequences WHERE schemaname = 'schemaY' LOOP
      EXECUTE format('ALTER SEQUENCE schemaY.%I OWNER TO userX', r.sequencename);
    END LOOP;
  END $$;

  -- views
  DO $$
  DECLARE r RECORD;
  BEGIN
    FOR r IN SELECT viewname FROM pg_views WHERE schemaname = 'schemaY' LOOP
      EXECUTE format('ALTER VIEW schemaY.%I OWNER TO userX', r.viewname);
    END LOOP;
  END $$;

  -- the schema itself
  ALTER SCHEMA schemaY OWNER TO userX;
