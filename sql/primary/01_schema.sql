CREATE TABLE public.t1 (
    id       bigint GENERATED ALWAYS AS IDENTITY,
    op_date  timestamptz   NOT NULL,
    amount   numeric(14,2) NOT NULL,
    state    smallint      NOT NULL,
    op_guid  uuid          NOT NULL,
    message  jsonb         NOT NULL,
    CONSTRAINT t1_pk PRIMARY KEY (id, op_date),
    CONSTRAINT t1_amount_chk CHECK (amount > 0),
    CONSTRAINT t1_state_chk CHECK (state IN (0, 1)),
    CONSTRAINT t1_message_chk CHECK (
        jsonb_typeof(message) = 'object'
        AND message ? 'account_number'
        AND message ? 'client_id'
        AND message ->> 'operation_type' IN ('online', 'offline')
    )
) PARTITION BY RANGE (op_date);

CREATE TABLE public.t1_default PARTITION OF public.t1 DEFAULT;

CREATE INDEX t1_pending_parity_idx ON public.t1 ((id % 2)) WHERE state = 0;

CREATE TABLE public.t1_op_guid (
    op_guid uuid PRIMARY KEY
);

CREATE OR REPLACE FUNCTION public.t1_op_guid_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.op_guid IS DISTINCT FROM OLD.op_guid THEN
            RAISE EXCEPTION 'op_guid is immutable (id=%)', OLD.id
                USING ERRCODE = 'integrity_constraint_violation';
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        DELETE FROM public.t1_op_guid WHERE op_guid = OLD.op_guid;
        RETURN OLD;
    END IF;
    INSERT INTO public.t1_op_guid (op_guid) VALUES (NEW.op_guid);
    RETURN NEW;
END
$$;

CREATE TRIGGER t1_op_guid_guard_bi
    BEFORE INSERT ON public.t1
    FOR EACH ROW EXECUTE FUNCTION public.t1_op_guid_guard();

CREATE TRIGGER t1_op_guid_guard_bu
    BEFORE UPDATE OF op_guid ON public.t1
    FOR EACH ROW EXECUTE FUNCTION public.t1_op_guid_guard();

CREATE TRIGGER t1_op_guid_guard_bd
    BEFORE DELETE ON public.t1
    FOR EACH ROW EXECUTE FUNCTION public.t1_op_guid_guard();
