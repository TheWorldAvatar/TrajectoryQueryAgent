CREATE OR REPLACE FUNCTION get_user_id(device TEXT)
RETURNS VARCHAR AS
$$
DECLARE
    user_result VARCHAR;
BEGIN
    -- Check if the schema 'timeline' exists
    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_namespace
        WHERE nspname = 'timeline'
    ) THEN
        -- Check if the table 'smartPhone' exists in the 'timeline' schema
        IF EXISTS (
            SELECT 1
            FROM pg_catalog.pg_tables
            WHERE schemaname = 'timeline'
              AND tablename = 'smartPhone'
        ) THEN
            -- Perform the query to get the user_id
            SELECT user_id
            INTO user_result
            FROM timeline."smartPhone"
            WHERE phone_id = device;
        ELSE
            -- Return NULL if the table does not exist
            RETURN NULL;
        END IF;
    ELSE
        -- Return NULL if the schema does not exist
        RETURN NULL;
    END IF;


    RETURN user_result;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_device_ids(id VARCHAR)
RETURNS TEXT AS
$$
DECLARE
    phone_id_list TEXT[];
BEGIN
    -- Aggregate phone_id values into an array, but only if phone_id exists in the devices table
    SELECT array_agg(phone_id)
    INTO phone_id_list
    FROM timeline."smartPhone" sp
    WHERE sp.user_id = id
    AND EXISTS (
        SELECT 1
        FROM devices d
        WHERE d.device_id = sp.phone_id
    );


    RETURN phone_id_list;
END;
$$
LANGUAGE plpgsql STABLE;
