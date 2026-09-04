# DSB-start

Минимальный стартовый установщик DepSandbox для рабочих проектов.

Цель: сотрудник открывает проект в Codex или Cursor, кладёт выданный MCP-токен в локальный файл в корне проекта и пишет агенту одну человеческую фразу. Агент сам находит token-файл, запускает официальный launcher с `-TokenFile`, а дальше установка идёт по актуальной защищённой инструкции с `https://mcp.dep1c.com/connect/`.

## Быстрый запуск

Напишите агенту в проекте:

```text
Подключи песочницу DepSandbox (https://github.com/KORUS-Consulting-GK-LLC/DSB-start) к текущему проекту. Токен лежит в файле в корне проекта.
```

Агент должен открыть этот репозиторий, прочитать `AGENT-INSTALL.md`, найти token-файл в корне проекта, сам запустить официальный `DSB-start` из GitHub и выполнить настройку. Если в корне проекта несколько похожих файлов, агент должен спросить имя файла.

Если token-файла нет, пользователь должен создать его в корне проекта и повторить поручение агенту. Вставлять токен в чат, команду, URL или Git нельзя.

Если установщик сообщает `DEPSANDBOX_DOMAIN_UNAVAILABLE`, токен ещё не прочитан и не отправлен. Агент должен остановиться и сказать пользователю: `обратитесь к администратору, песочница недоступна по доменному имени`.

## Команда для агента

Эта команда нужна агенту или администратору как технический fallback. Обычному пользователю достаточно фразы из раздела «Быстрый запуск». Агент должен заменить `.depsandbox-token.txt` на фактическое имя token-файла, если пользователь положил файл под другим именем.

```powershell
$tokenFile = Resolve-Path -LiteralPath '.depsandbox-token.txt'
$u = 'https://raw.githubusercontent.com/KORUS-Consulting-GK-LLC/DSB-start/main/install.ps1'
$p = Join-Path $env:TEMP ('dsb-start-' + [guid]::NewGuid() + '.ps1')
Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p
Unblock-File -LiteralPath $p -ErrorAction SilentlyContinue
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p -TokenFile $tokenFile -RemoveTokenFileAfterRead
```

## Что делает установщик

1. Проверяет Git, Node.js 18+ и Python 3; если их нет, ищет встроенные runtime-инструменты Codex и пытается поставить недостающее через `winget`.
2. Проверяет DNS, TCP и стандартный HTTPS/TLS доступ к `mcp.dep1c.com:443` до чтения токена.
3. Берёт MCP-токен из локального файла в корне проекта.
4. С этим токеном получает `install-plan.json` с `mcp.dep1c.com`.
5. Скачивает защищённый `bootstrap.mjs`, сверяет SHA-256 из install plan.
6. Передаёт токен bootstrap-скрипту через временный файл, а не через аргументы командной строки.
7. Удаляет временный файл с токеном после запуска, а при `-RemoveTokenFileAfterRead` удаляет и одноразовый source-файл внутри проекта.
8. Если конфигурация не выбрана автоматически, показывает список и просит выбрать одну, несколько, все или только базовые MCP.

## Параметры

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 [-ProjectRoot C:\path\project] [-Client auto|codex|cursor] [-TokenFile .\.depsandbox-token.txt] [-RemoveTokenFileAfterRead] [-Configuration UT1152781,ERP_2_5_26_118] [-BaseOnly] [-AllConfigurations] [-DryRun] [-KeepRunArtifacts]
```

Полезные варианты:

- `-Client codex` или `-Client cursor` — зафиксировать IDE, если автоопределение не подходит.
- `-TokenFile .\.depsandbox-token.txt` — взять токен из локального файла, не открывая интерактивный ввод.
- `-RemoveTokenFileAfterRead` — удалить одноразовый token-файл после чтения, только если он внутри проекта.
- `-Configuration UT1152781` — сразу выбрать пару, без интерактивного списка.
- `-BaseOnly` — подключить только базовые MCP без пары конфигурации.
- `-AllConfigurations` — подключить все активные пары из каталога.
- `-DryRun` — проверить маршрут без записи проектных файлов.
- `-KeepRunArtifacts` — оставить staging/source-копии в `.depsandbox/runs` для диагностики упавшей установки.

## Безопасность

- В этом репозитории нет токенов, внутренних портов, credentials и пользовательских конфигов.
- Токен не передаётся в URL, argv, Git или чат.
- При недоступности `mcp.dep1c.com:443` или ошибке стандартного HTTPS/TLS установщик останавливается до чтения токена и просит обратиться к администратору.
- Скрипт не отключает TLS-проверку и не правит `hosts`.
- Для PowerShell используется process-local `-ExecutionPolicy Bypass`, системная политика Windows не меняется.
- Настоящая инструкция, каталог конфигураций и bootstrap отдаются только после Bearer-аутентификации на `mcp.dep1c.com`.

## Для агента

Ожидаемая пользовательская фраза:

```text
Подключи песочницу DepSandbox (https://github.com/KORUS-Consulting-GK-LLC/DSB-start) к текущему проекту. Токен лежит в файле в корне проекта.
```

Агент должен прочитать `AGENT-INSTALL.md`, найти token-файл в корне проекта, открыть терминал в корне проекта и выполнить команду из раздела «Команда для агента» с `-TokenFile`.

Если Git не установлен на машине пользователя, это тоже штатный сценарий. Первая команда скачивает launcher без Git, а `install.ps1` дальше найдёт доступный Git или установит его сам.

## Проверка репозитория

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```
