CREATE SUBSCRIPTION t1_sub
    CONNECTION 'host=pg-primary port=5432 dbname=app user=replicator password=replicator'
    PUBLICATION t1_pub;
