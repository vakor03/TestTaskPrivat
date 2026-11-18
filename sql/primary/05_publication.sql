CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD 'replicator';

GRANT SELECT ON public.t1 TO replicator;

CREATE PUBLICATION t1_pub FOR TABLE public.t1 WITH (publish_via_partition_root = true);
