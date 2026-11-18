CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule('t1_add_operation', '5 seconds', $$CALL public.t1_add_operation()$$);

SELECT cron.schedule('t1_confirm_by_parity', '3 seconds', $$
    UPDATE public.t1
       SET state = 1
     WHERE state = 0
       AND id % 2 = floor(extract(second FROM now()))::int % 2
$$);
