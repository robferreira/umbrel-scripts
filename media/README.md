# scripts de mídia

Scripts relacionados a mídia no **UmbrelOS** (compartilhamento de pastas, bibliotecas, File Browser, Jellyfin, etc.).

Coloque novos scripts de mídia nesta pasta e documente cada um abaixo com uma seção `@nome-do-script`.

---

## @share-media.sh

### O que é

Script Bash que faz o **File Browser** e o **Jellyfin** usarem a **mesma pasta de mídia** no host:

`/home/umbrel/umbrel/data/media`

No Umbrel, a raiz do File Browser costuma ser `umbrel/home` (ou `data/storage`) montada em `/data`. Este script **adiciona** um segundo volume: `data/media` → `/data/media`, e no Jellyfin: `data/media` → `/media`.

### O que ele faz

1. Cria `data/media/{photos,movies,series,files}`
2. Patch no `docker-compose.yml` (com backup + rollback):
   - **Jellyfin** → `…/data/media` em `/media`
   - **File Browser** → `…/data/media` em `/data/media`
3. Reinicia os dois apps
4. Verifica mounts no container **`*_server_*`** (não no `app_proxy`)

### Pré-requisitos

- UmbrelOS com **Jellyfin** e **File Browser** instalados
- `sudo`, `yq`, `docker`

### Instalação

```bash
cd /home/umbrel
git clone https://github.com/robferreira/umbrel-scripts.git

sudo chmod +x /home/umbrel/umbrel-scripts/media/share-media.sh
sudo /home/umbrel/umbrel-scripts/media/share-media.sh
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --install-service
```

### Depois de rodar — UI

| App | Caminho |
|-----|---------|
| **Jellyfin** — fotos / filmes / séries | `/media/photos`, `/media/movies`, `/media/series` |
| **File Browser** | pasta **`media`** na raiz → `media/photos`, `media/movies`, `media/series` |

Host: `/home/umbrel/umbrel/data/media/...`

### Manter após reboot / upgrade

```bash
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --install-service
```

Roda `--ensure` no boot (+120s) e todo domingo 04:00. Log: `/var/log/share-media.log`.

```bash
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --check
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --uninstall-service
```

### Uso

```bash
sudo /home/umbrel/umbrel-scripts/media/share-media.sh
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --dry-run
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --ensure
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --check
```

### Variáveis

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `UMBREL_ROOT` | `/home/umbrel/umbrel` | Raiz Umbrel |
| `MEDIA_UID` / `MEDIA_GID` | `1000` | Dono das pastas |
| `COMPOSE_SERVICE` | `server` | Serviço no compose |
| `LOG_FILE` | `/var/log/share-media.log` | Log do timer |
| `BOOT_DELAY_SEC` | `120` | Espera no boot |
