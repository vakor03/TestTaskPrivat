CREATE TABLE public.t1 (
    id       bigint        NOT NULL,
    op_date  timestamptz   NOT NULL,
    amount   numeric(14,2) NOT NULL,
    state    smallint      NOT NULL,
    op_guid  uuid          NOT NULL,
    message  jsonb         NOT NULL,
    CONSTRAINT t1_pk PRIMARY KEY (id, op_date)
);
