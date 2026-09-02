# Security boundary

`DSB-start` is intentionally small. It is a public, secret-free launcher. The protected setup logic still lives behind `https://mcp.dep1c.com/connect/`.

## Что защищаем

- MCP Bearer-токен пользователя.
- Внутреннюю структуру песочницы, каталог конфигураций и install plan.
- Рабочий проект сотрудника от случайной перезаписи правил и MCP-конфигов.

## Основные решения

- Токен вводится локально через `Read-Host -AsSecureString` или читается из явно указанного файла.
- Токен передаётся protected bootstrap через временный файл с best-effort owner-only ACL.
- Токен не попадает в argv, URL, GitHub, README-примеры или completion report.
- `bootstrap.mjs` скачивается только после Bearer-аутентификации и проверяется по SHA-256 из `install-plan.json`.
- PowerShell использует `-ExecutionPolicy Bypass` только для текущего процесса.
- Скрипт не меняет `hosts`, не отключает TLS и не добавляет сертификаты.

## Остаточные риски

- Первый публичный `install.ps1` доверяется по HTTPS GitHub. Для усиления можно добавить подписанный release или корпоративный mirror.
- Cursor на текущем этапе может хранить Bearer в project-local `.cursor/mcp.json`, если сам клиент не поддерживает env-ссылку для MCP headers. Этот файл должен быть исключён из Git.
- Установка Git/Node/Python через `winget` зависит от корпоративных политик Windows и может потребовать ручного разрешения ОС.
