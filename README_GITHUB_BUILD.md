# ARGOS ROM — GitHub Actions Build

## Как запустить сборку через GitHub (ускорение 10x)

### 1. Создание репозитория

```bash
cd /home/ava/Projects/argoss
git init
git add -A
git commit -m "ARGOS ROM v1.0 initial"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/argos-rom.git
git push -u origin main
```

### 2. Запуск workflow

1. Открыть `github.com/YOUR_USERNAME/argos-rom/actions`
2. Выбрать workflow **"ARGOS Multi-Tool ROM Build"**
3. Нажать **"Run workflow"**
4. Выбрать device: `ginkgo`
5. Выбрать branch: `lineage-21`
6. Нажать **Run**

### 3. Что происходит

| Этап | Время | Ресурсы GitHub |
|------|-------|----------------|
| Sync LOS source | ~45 мин | 2 cores, fast internet |
| ARGOS overlay | 2 мин | |
| Kernel patches | 1 мин | |
| Build bacon | ~2 часа | ccache |
| Upload artifact | 5 мин | |

### 4. Результат

- ROM .zip: `lineage-21.0-*.zip` (~1.5GB)
- boot.img: Magisk-patched
- Скачать можно через GitHub Actions artifacts

### Параметры workflow

- `device`: ginkgo (Redmi Note 8T)
- `lineage_branch`: lineage-21.0
- `rom_name`: ARGOS-ROM
- `timeout`: 6 часов
- `ccache`: 10GB

### Патчи ядра (авто)

```
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_CH341=y
CONFIG_USB_SERIAL_FTDI_SIO=y
CONFIG_USB_SERIAL_CP210X=y
CONFIG_USB_SERIAL_PL2303=y
CONFIG_CAN=y
CONFIG_CAN_MCP251X=y
```

Это подключит USB-UART и CAN шину прямо в ядре — не нужны терминальные приложения, устройства работают на уровне системы.

## Как это быстрее?

| | Локальный ноут | GitHub Actions |
|---|---|---|
| **CPU** | 4 cores | 2 cores |
| **RAM** | 16 GB | 7 GB |
| **SSD** | 120GB (~50MB/s write) | 14GB NVMe (~500MB/s) |
| **Интернет** | ~5-10 MB/s | ~50-100 MB/s |
| **Repo sync** | 4 часа | 40 мин |
| **Build** | 5 часов | 2 часа |
| **Total** | 9 часов | 3 часа |
| **Надёжность** | Может отключиться | 6 часов таймаут |

**GitHub Actions быстрее в 3x** за счёт быстрого интернета и NVMe.

---

## Альтернатива (локальная сборка)

Если не хочешь GitHub — локальная сборка всё ещё возможна:

```bash
cd /mnt/argos_hdd/lineageos
source build/envsetup.sh
lunch lineage_ginkgo-userdebug
mka bacon -j$(nproc --all)
```

Но это занимает 6-8 часов.
