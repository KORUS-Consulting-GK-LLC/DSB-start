# DSB-start

Минимальный стартовый установщик DepSandbox для рабочих проектов.

Цель: сотрудник открывает проект в своём агентском клиенте, кладёт выданный MCP-токен в локальный файл в корне проекта и пишет агенту одну человеческую фразу. Агент сам находит token-файл, запускает официальный launcher с `-TokenFile`, а дальше установка идёт по актуальной защищённой инструкции с `https://mcp.dep1c.com/connect/`.

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
$clientId = 'zcode' # агент заменяет на фактический id своей среды
$u = 'https://raw.githubusercontent.com/KORUS-Consulting-GK-LLC/DSB-start/b1e2c8ca3aaf080c5bd0b8284f189e3dd769f873/install.ps1'
$expected = '6afcefe6049bb34f45398bea042b05c7c514a7f42ef7aa6596e8b3f1c7f8584d'
$launcherDir = Join-Path (Get-Location) '.depsandbox\launcher'
New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
$p = Join-Path $launcherDir 'install.ps1'
Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p -TimeoutSec 20
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant() -ne $expected) {
  Remove-Item -LiteralPath $p -Force
  throw 'DSB-start launcher integrity check failed.'
}
Unblock-File -LiteralPath $p -ErrorAction SilentlyContinue
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p -Client $clientId -TokenFile $tokenFile -RemoveTokenFileAfterRead
```

## Что делает установщик

1. Скачивается по адресу конкретного Git commit и до запуска проверяется по SHA-256.
2. Проверяет Git, Node.js 18+ и Python 3; если их нет, ищет доступные runtime-инструменты и пытается поставить недостающее через `winget`.
3. Проверяет DNS, TCP и стандартный HTTPS/TLS доступ к `mcp.dep1c.com:443` до чтения токена.
4. Берёт MCP-токен из локального файла в корне проекта.
5. С этим токеном получает версионированный `install-plan.json` с `mcp.dep1c.com`.
6. Скачивает защищённый `bootstrap.mjs`, сверяет SHA-256, версии и pinned upstreams.
7. Передаёт bootstrap-скрипту путь к исходному token-файлу, а не сам токен в аргументах командной строки.
8. При `-RemoveTokenFileAfterRead` удаляет одноразовый source-файл внутри проекта, если нативная MCP-настройка уже выполнена.
9. Если конфигурация не выбрана автоматически, возвращает выбор текущему агенту, а не открывает отдельный диалог в терминале.

## Параметры

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 [-ProjectRoot C:\path\project] [-Client auto|codex|cursor|zcode|other] [-TokenFile .\.depsandbox-token.txt] [-RemoveTokenFileAfterRead] [-Configuration UT1152781,ERP_2_5_26_118] [-BaseOnly] [-AllConfigurations] [-DryRun] [-KeepRunArtifacts]
```

Полезные варианты:

- `-Client codex`, `-Client cursor` или фактическое имя текущей среды, например `zcode` — текущий агент определяет его сам и не предлагает пользователю чужие IDE.
- `-TokenFile .\.depsandbox-token.txt` — взять токен из локального файла, не открывая интерактивный ввод.
- `-RemoveTokenFileAfterRead` — удалить одноразовый token-файл внутри проекта после успешной нативной MCP-настройки; для generic/ZCode файл сохраняется до ручного переноса в штатное хранилище клиента.
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
- Публичный launcher запускается только с URL конкретного Git commit после проверки SHA-256; mutable `main/install.ps1` не используется как release-вход.
- При `-TokenFile` launcher передаёт bootstrap исходный token-файл; второй временный файл с токеном не создаётся. Временный token-файл нужен только для старого скрытого prompt fallback.
- Для PowerShell используется process-local `-ExecutionPolicy Bypass`, системная политика Windows не меняется.
- Настоящая инструкция, каталог конфигураций и bootstrap отдаются только после Bearer-аутентификации на `mcp.dep1c.com`.

## Для агента

Ожидаемая пользовательская фраза:

```text
Подключи песочницу DepSandbox (https://github.com/KORUS-Consulting-GK-LLC/DSB-start) к текущему проекту. Токен лежит в файле в корне проекта.
```

Агент должен прочитать `AGENT-INSTALL.md`, найти token-файл в корне проекта,
определить фактическое имя текущего клиента, открыть терминал в корне проекта и
выполнить команду из раздела «Команда для агента» с `-Client` и `-TokenFile`.
Для неизвестного bootstrap-у клиента агент продолжает настройку штатным способом
именно своей среды по `.depsandbox/mcp-servers.json`, проверяет tools и только
после этого удаляет одноразовый token-файл.

Если Git не установлен на машине пользователя, это тоже штатный сценарий. Первая команда скачивает launcher без Git, а `install.ps1` дальше найдёт доступный Git или установит его сам.

## Проверка репозитория

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```
