# Тестове завдання PostgreSQL

Умова — [TASK.md](TASK.md).

## Запуск

Потрібен Docker з Docker Compose.

```bash
docker compose up -d --build
```

Піднімаються два інстанси PostgreSQL 17. Таблиці, дані, задачі pg_cron і реплікація створюються автоматично при першому старті.

| Інстанс | Порт | БД | Користувач / пароль |
|---|---|---|---|
| primary | 5432 | `app` | `postgres` / `postgres` |
| replica | 5433 | `app` | `postgres` / `postgres` |

Підключення:

```bash
docker exec -it t1-primary psql -U postgres -d app
```

```bash
docker exec -it t1-replica psql -U postgres -d app
```

Зупинка:

```bash
docker compose stop
```

Видалити все разом з даними, щоб наступний запуск ініціалізував базу з нуля:

```bash
docker compose down -v
```

## Реалізація

**1.** Таблиця `t1` партиціонована по даті (по місяцях), плюс default-партиція на всяк випадок. `sql/primary/01_schema.sql`.

**2.** Процедура `t1_generate_data` (`02_functions.sql`) — сама створює потрібні партиції і заливає 120к рядків приблизно за 3.5 місяці. Викликається при старті з `03_seed.sql`.

**3.** На партиціонованій таблиці не можна зробити unique тільки по `op_guid` (постгрес вимагає включати ключ партиціонування), тому guid-и пишуться в окрему таблицю `t1_op_guid` з primary key, тригером при вставці.

**4.** pg_cron, кожні 5 секунд викликає `t1_add_operation`. `06_jobs.sql`.

**5.** Теж pg_cron, кожні 3 секунди просто робить UPDATE по парності секунди. Під це є частковий індекс по `id % 2 where state = 0`.

**6.** `mv_t1_client_totals` в `04_client_totals.sql`. Оновлюється тригером, але тільки якщо в апдейті реально був перехід 0 → 1.

**7.** Логічна реплікація publication/subscription. Таблиця на репліці звичайна, без партицій — для цього в публікації `publish_via_partition_root = true`.
