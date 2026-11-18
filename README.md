# PostgreSQL: партиціонована таблиця T1, pg_cron, materialized view, логічна реплікація

Умова — [TASK.md](TASK.md).

## Запуск

```bash
docker compose up -d --build
```

| Інстанс | Контейнер | Порт | БД / користувач / пароль |
|---|---|---|---|
| primary (PostgreSQL 17 + pg_cron) | `t1-primary` | 5432 | `app` / `postgres` / `postgres` |
| replica (PostgreSQL 17) | `t1-replica` | 5433 | `app` / `postgres` / `postgres` |

Скрипти ініціалізації виконуються автоматично при першому старті (порожній volume). Перестворити все з нуля:

```bash
docker compose down -v
```

## Відповідність пунктам завдання

| № | Реалізація | Файл |
|---|---|---|
| 1 | `t1(id, op_date, amount, state, op_guid uuid, message jsonb)`, `PARTITION BY RANGE (op_date)` з партицією `t1_default`; `message` містить `account_number`, `client_id`, `operation_type` (`online`/`offline`) | [01_schema.sql](sql/primary/01_schema.sql) |
| 2 | Процедура `t1_generate_data(p_rows, p_from, p_to, p_clients)`; перед вставкою процедура створює помісячні партиції на весь період плюс місяць уперед; за замовчуванням 120 000 рядків від початку місяця три місяці тому до `now()` | [02_functions.sql](sql/primary/02_functions.sql), [03_seed.sql](sql/primary/03_seed.sql) |
| 3 | Унікальний ключ партиціонованої таблиці мусить містити ключ партиціонування, тому глобальна унікальність `op_guid` забезпечується таблицею-реєстром `t1_op_guid(op_guid PK)` і тригерами BEFORE INSERT/DELETE; змінювати `op_guid` заборонено | [01_schema.sql](sql/primary/01_schema.sql) |
| 4 | pg_cron-задача `t1_add_operation` раз на `5 seconds` викликає процедуру `t1_add_operation()`, яка вставляє запис зі `state = 0` | [06_jobs.sql](sql/primary/06_jobs.sql) |
| 5 | pg_cron-задача `t1_confirm_by_parity` раз на `3 seconds` виконує UPDATE: якщо секунда поточного часу парна, переводить з 0 на 1 записи з парними `id`, інакше — з непарними; частковий індекс `t1_pending_parity_idx` | [06_jobs.sql](sql/primary/06_jobs.sql), [01_schema.sql](sql/primary/01_schema.sql) |
| 6 | `mv_t1_client_totals` — загальна сума по `client_id` × `operation_type` для `state = 1`. Statement-level тригер `AFTER UPDATE` з transition tables виконує `REFRESH MATERIALIZED VIEW CONCURRENTLY` лише тоді, коли в операторі є перехід `state` 0 → 1 | [04_client_totals.sql](sql/primary/04_client_totals.sql) |
| 7 | Логічна реплікація: `PUBLICATION t1_pub ... WITH (publish_via_partition_root = true)` на primary, `SUBSCRIPTION t1_sub` на replica | [05_publication.sql](sql/primary/05_publication.sql), [replica/](sql/replica) |

## Перевірка

```bash
docker exec -it t1-primary psql -U postgres -d app
```

```sql
SELECT tableoid::regclass, count(*) FROM t1 GROUP BY 1 ORDER BY 1;
SELECT state, count(*) FROM t1 GROUP BY 1;
SELECT jobname, status, count(*) FROM cron.job_run_details JOIN cron.job USING (jobid) GROUP BY 1, 2;
SELECT * FROM mv_t1_client_totals ORDER BY client_id, operation_type LIMIT 10;
SELECT (SELECT sum(total_amount) FROM mv_t1_client_totals) = (SELECT sum(amount) FROM t1 WHERE state = 1);
SELECT count(*), sum(state), sum(amount) FROM t1;
```

```bash
docker exec -it t1-replica psql -U postgres -d app -c "SELECT count(*), sum(state), sum(amount) FROM t1"
```
