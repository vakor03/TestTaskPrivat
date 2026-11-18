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
