CREATE MATERIALIZED VIEW public.mv_t1_client_totals AS
SELECT (message ->> 'client_id')::int AS client_id,
       message ->> 'operation_type'    AS operation_type,
       sum(amount)                     AS total_amount
  FROM public.t1
 WHERE state = 1
 GROUP BY 1, 2;

CREATE UNIQUE INDEX mv_t1_client_totals_uk ON public.mv_t1_client_totals (client_id, operation_type);

CREATE OR REPLACE FUNCTION public.t1_refresh_client_totals()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM old_rows o
          JOIN new_rows n USING (id)
         WHERE o.state = 0
           AND n.state = 1
    ) THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_t1_client_totals;
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER t1_refresh_client_totals_au
    AFTER UPDATE ON public.t1
    REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION public.t1_refresh_client_totals();
