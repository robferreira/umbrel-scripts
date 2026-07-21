# scripts de mídia

Scripts relacionados a mídia no **UmbrelOS** (compartilhamento de pastas, bibliotecas, File Browser, Jellyfin, etc.).

Coloque novos scripts de mídia nesta pasta e documente cada um abaixo com uma seção `@nome-do-script`.

---

## @share-media.sh

### O que é

Script Bash que faz o **File Browser** e o **Jellyfin** enxergarem a **mesma mídia** no Umbrel, usando o storage nativo do sistema:

`/home/umbrel/umbrel/data/storage`

O File Browser **já** monta esse storage em `/data`. O script só precisa montar o mesmo caminho no Jellyfin em `/media` e criar as pastas `photos`, `movies` e `series`.

### O que ele faz

1. Cria em `data/storage` as pastas `photos`, `movies` e `series` (sem alterar dono de todo o storage)
2. Remove mounts legados de versões antigas (`data/media`) nos composes
3. Adiciona no Jellyfin: `${UMBREL_ROOT}/data/storage` → `/media` (com backup + rollback)
4. **Não** altera o File Browser (já tem `data/storage` → `/data`)
5. Reinicia Jellyfin (e File Browser) e verifica os mounts

### Pré-requisitos

- UmbrelOS com **Jellyfin** e **File Browser** instalados
- Executar como **root** (`sudo`)
- Dependências no servidor: `yq` e `docker`

### Instalação no Umbrel

Caminho padrão dos scripts: `/home/umbrel/umbrel-scripts/media`.

No Umbrel (SSH ou terminal web):

```bash
cd /home/umbrel
git clone https://github.com/robferreira/umbrel-scripts.git

sudo chmod +x /home/umbrel/umbrel-scripts/media/share-media.sh

# 1) Aplica o share agora
sudo /home/umbrel/umbrel-scripts/media/share-media.sh

# 2) Agenda para manter após reboot / upgrade
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --install-service
```

Alternativa a partir do seu PC (copia o repositório inteiro):

```bash
scp -r . umbrel@<IP-DO-UMBREL>:/home/umbrel/umbrel-scripts
```

### Manter após reboot ou upgrade

O Umbrel pode **reescrever** o `docker-compose.yml` do Jellyfin depois de atualizar — e o mount de `/media` some. Use `--ensure` ou o agendamento automático.

#### Instalar o agendamento (recomendado)

```bash
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --install-service
```

| Quando | O que acontece |
|--------|----------------|
| **No boot** | Espera **120s** e roda `--ensure` |
| **Toda domingo 04:00** | Roda `--ensure` de novo |

Preferência: **systemd** (`umbrel-share-media.timer`); fallback **cron**. Log: `/var/log/share-media.log`.

#### Verificar / remover

```bash
systemctl status umbrel-share-media.timer
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --uninstall-service
```

### Uso

```bash
sudo /home/umbrel/umbrel-scripts/media/share-media.sh
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --dry-run
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --ensure
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --check
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --install-service
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --uninstall-service
```

### Depois de rodar — configuração na UI

| App | Caminho |
|-----|---------|
| **Jellyfin** — fotos | `/media/photos` |
| **Jellyfin** — filmes | `/media/movies` |
| **Jellyfin** — séries | `/media/series` |
| **File Browser** — upload | `/photos`, `/movies`, `/series` (raiz do app) |

No host é a mesma pasta: `/home/umbrel/umbrel/data/storage/{photos,movies,series}`.

> **Nota:** o path nativo `/downloads` do Jellyfin continua existindo (só `data/storage/downloads`). Use `/media/...` para as bibliotecas compartilhadas com o File Browser.

### Migração (se rodou a versão antiga com `data/media`)

1. Rode o script de novo — ele remove mounts `data/media` e aplica `data/storage` → `/media` no Jellyfin
2. No File Browser, use `/photos`, `/movies`, `/series` (não mais `/data/media/...`)
3. No Jellyfin, atualize as bibliotecas para `/media/photos`, `/media/movies`, `/media/series`
4. Se houver arquivos em `data/media`, copie para `data/storage`:

```bash
sudo cp -a /home/umbrel/umbrel/data/media/photos /home/umbrel/umbrel/data/storage/ 2>/dev/null || true
sudo cp -a /home/umbrel/umbrel/data/media/movies /home/umbrel/umbrel/data/storage/ 2>/dev/null || true
sudo cp -a /home/umbrel/umbrel/data/media/series /home/umbrel/umbrel/data/storage/ 2>/dev/null || true
```

### Variáveis de ambiente

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `UMBREL_ROOT` | `/home/umbrel/umbrel` | Raiz da instalação Umbrel |
| `MEDIA_UID` | `1000` | UID das pastas `photos`/`movies`/`series` |
| `MEDIA_GID` | `1000` | GID das pastas |
| `COMPOSE_SERVICE` | `server` | Nome do serviço no compose |
| `LOG_FILE` | `/var/log/share-media.log` | Log do agendamento |
| `BOOT_DELAY_SEC` | `120` | Espera após o boot |

### Ajuda

```bash
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --help
```
