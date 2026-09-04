# Security boundary

`DSB-start` is intentionally small. It is a public, secret-free launcher. The protected setup logic still lives behind `https://mcp.dep1c.com/connect/`.

## Что защищаем

- MCP Bearer-токен пользователя.
- Внутреннюю структуру песочницы, каталог конфигураций и install plan.
- Рабочий проект сотрудника от случайной перезаписи правил и MCP-конфигов.

## Основные решения

- Токен читается из локального файла в корне проекта, переданного launcher-у через `-TokenFile`.
- При `-TokenFile` protected bootstrap получает путь к исходному token-файлу; второй временный файл с токеном не создаётся.
- Токен не попадает в argv, URL, GitHub, README-примеры или completion report.
- `bootstrap.mjs` скачивается только после Bearer-аутентификации и проверяется по SHA-256 из `install-plan.json`.
- PowerShell использует `-ExecutionPolicy Bypass` только для текущего процесса.
- Первичное скачивание launcher-а не требует Git: оно выполняется через HTTPS/PowerShell, а Git проверяется и устанавливается уже внутри `install.ps1`.
- Скрипт не меняет `hosts`, не отключает TLS и не добавляет сертификаты.
- Агент не должен создавать дополнительный wrapper `.ps1`, включать `Start-Transcript` или копировать token-файл в `%TEMP%`; это лишние поверхности риска и частый источник срабатываний поведенческих антивирусов.

## Остаточные риски

- Первый публичный `install.ps1` доверяется по HTTPS GitHub. Для усиления можно добавить подписанный release или корпоративный mirror.
- Cursor на текущем этапе может хранить Bearer в project-local `.cursor/mcp.json`, если сам клиент не поддерживает env-ссылку для MCP headers. Этот файл должен быть исключён из Git.
- Установка Git/Node/Python через `winget` зависит от корпоративных политик Windows и может потребовать ручного разрешения ОС.
