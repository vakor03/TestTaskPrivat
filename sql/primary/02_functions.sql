CREATE OR REPLACE FUNCTION public.t1_build_message(p_client_id integer, p_operation_type text)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT jsonb_build_object(
        'account_number', 'ACC' || lpad(p_client_id::text, 10, '0'),
        'client_id',      p_client_id,
        'operation_type', p_operation_type
    )
$$;

CREATE OR REPLACE PROCEDURE public.t1_generate_data(
    p_rows    integer     DEFAULT 120000,
    p_from    timestamptz DEFAULT date_trunc('month', now()) - interval '3 months',
    p_to      timestamptz DEFAULT now(),
    p_clients integer     DEFAULT 1000
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_month date;
BEGIN
    FOR v_month IN
        SELECT generate_series(
                   date_trunc('month', p_from),
                   date_trunc('month', p_to) + interval '1 month',
                   interval '1 month'
               )::date
    LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS public.%I PARTITION OF public.t1 FOR VALUES FROM (%L) TO (%L)',
            format('t1_%s', to_char(v_month, 'YYYY_MM')),
            v_month::timestamptz,
            (v_month + interval '1 month')::timestamptz
        );
    END LOOP;

    INSERT INTO public.t1 (op_date, amount, state, op_guid, message)
    SELECT p_from + random() * (p_to - p_from),
           round((1 + random() * 9999)::numeric, 2),
           (random() < 0.5)::int::smallint,
           gen_random_uuid(),
           public.t1_build_message(
               1 + floor(random() * p_clients)::int,
               CASE WHEN random() < 0.5 THEN 'online' ELSE 'offline' END
           )
    FROM generate_series(1, p_rows);
END
$$;

CREATE OR REPLACE PROCEDURE public.t1_add_operation()
LANGUAGE sql
AS $$
    INSERT INTO public.t1 (op_date, amount, state, op_guid, message)
    VALUES (
        now(),
        round((1 + random() * 9999)::numeric, 2),
        0,
        gen_random_uuid(),
        public.t1_build_message(
            1 + floor(random() * 1000)::int,
            CASE WHEN random() < 0.5 THEN 'online' ELSE 'offline' END
        )
    );
$$;
