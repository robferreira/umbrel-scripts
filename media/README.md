# scripts de mídia

Scripts relacionados a mídia no **UmbrelOS** (compartilhamento de pastas, bibliotecas, File Browser, Jellyfin, etc.).

Coloque novos scripts de mídia nesta pasta e documente cada um abaixo com uma seção `@nome-do-script`.

---

## @share-media.sh

### O que é

Script Bash que faz o **File Browser** e o **Jellyfin** usarem a **mesma pasta de mídia** no host Umbrel.

Sem isso, cada app vê só o próprio volume Docker: o que você envia no File Browser não aparece no Jellyfin (e o contrário também).

### O que ele faz

1. Cria `/home/umbrel/umbrel/data/media` com subpastas `photos`, `movies` e `series`
2. Ajusta dono (`1000:1000` por padrão) e `chmod 755` **apenas em diretórios** (não altera permissões de arquivos)
3. Adiciona volume no `docker-compose.yml` de cada app (com backup + rollback se o patch falhar):
   - Jellyfin → `…/data/media` montado em `/media`
   - File Browser → `…/data/media` montado em `/data/media`
4. Reinicia os dois apps
5. Verifica se o mount está no compose e (quando aplicável) no container em execução

### Pré-requisitos

- UmbrelOS com **Jellyfin** e **File Browser** instalados
- Executar como **root** (`sudo`)
- Dependências no servidor: `yq` e `docker`

### Instalação no Umbrel

No seu PC (a partir da raiz deste repositório):

```bash
scp media/share-media.sh umbrel@<IP-DO-UMBREL>:/home/umbrel/scripts/
```

No servidor (SSH ou terminal web):

```bash
sudo mkdir -p /home/umbrel/scripts
sudo chmod +x /home/umbrel/scripts/share-media.sh

# 1) Aplica o share agora
sudo /home/umbrel/scripts/share-media.sh

# 2) Agenda para manter após reboot / upgrade
sudo /home/umbrel/scripts/share-media.sh --install-service
```

### Manter após reboot ou upgrade

O Umbrel pode **reescrever** o `docker-compose.yml` depois de atualizar o SO ou os apps — e o mount de mídia some. Para isso existir o modo `--ensure` e o agendamento automático.

#### Instalar o agendamento (recomendado)

```bash
sudo /home/umbrel/scripts/share-media.sh --install-service
```

Isso configura:

| Quando | O que acontece |
|--------|----------------|
| **No boot** | Espera **120s** (Docker/apps subirem) e roda `--ensure` |
| **Toda domingo 04:00** | Roda `--ensure` de novo (pega upgrades sem reboot) |

Preferência de backend:

1. **systemd** (timer `umbrel-share-media.timer`) — se disponível
2. **cron** (`/etc/cron.d/umbrel-share-media`) — fallback

Logs em `/var/log/share-media.log`.

#### Verificar se está agendado

```bash
# Se usou systemd:
systemctl status umbrel-share-media.timer
systemctl list-timers | grep share-media

# Se usou cron:
cat /etc/cron.d/umbrel-share-media

# Ver log
tail -f /var/log/share-media.log
```

#### Remover o agendamento

```bash
sudo /home/umbrel/scripts/share-media.sh --uninstall-service
```

Isso **não** desfaz o share nos composes — só para de rodar sozinho.

#### Ajuste fino (opcional)

```bash
# Espera maior no boot (ex.: 3 minutos) e outro arquivo de log
sudo BOOT_DELAY_SEC=180 LOG_FILE=/var/log/share-media.log \
  /home/umbrel/scripts/share-media.sh --install-service
```

### Uso

```bash
# Execução completa (pastas + patch + reinício + verificação)
sudo /home/umbrel/scripts/share-media.sh

# Só simula (não altera nada)
sudo /home/umbrel/scripts/share-media.sh --dry-run

# Aplica pastas/patch sem reiniciar
sudo /home/umbrel/scripts/share-media.sh --no-restart

# Só reinicia jellyfin e file-browser
sudo /home/umbrel/scripts/share-media.sh --restart-only

# Reaplica somente se pastas/mount estiverem ausentes
sudo /home/umbrel/scripts/share-media.sh --ensure

# Só verifica o estado (exit 0 = OK, exit 1 = precisa ação)
sudo /home/umbrel/scripts/share-media.sh --check

# Agenda no boot + semanalmente
sudo /home/umbrel/scripts/share-media.sh --install-service

# Remove o agendamento
sudo /home/umbrel/scripts/share-media.sh --uninstall-service
```

### Depois de rodar — configuração na UI

| App | Caminho |
|-----|---------|
| **Jellyfin** — biblioteca de fotos | `/media/photos` |
| **Jellyfin** — filmes | `/media/movies` |
| **Jellyfin** — séries | `/media/series` |
| **File Browser** — upload | `/data/media/photos`, `/data/media/movies`, `/data/media/series` |

É a mesma pasta física no host; só muda o caminho dentro de cada container.

### Quando reexecutar manualmente

Se a mídia sumir e o agendamento não estiver instalado (ou ainda não rodou):

```bash
sudo /home/umbrel/scripts/share-media.sh --ensure
```

### Variáveis de ambiente

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `UMBREL_ROOT` | `/home/umbrel/umbrel` | Raiz da instalação Umbrel |
| `MEDIA_UID` | `1000` | UID dono das pastas de mídia |
| `MEDIA_GID` | `1000` | GID dono das pastas de mídia |
| `COMPOSE_SERVICE` | `server` | Nome do serviço no `docker-compose.yml` |
| `LOG_FILE` | `/var/log/share-media.log` | Log do agendamento |
| `BOOT_DELAY_SEC` | `120` | Segundos de espera após o boot |

Exemplo:

```bash
sudo UMBREL_ROOT=/home/umbrel/umbrel COMPOSE_SERVICE=server \
  /home/umbrel/scripts/share-media.sh --ensure
```

### Ajuda

```bash
sudo /home/umbrel/scripts/share-media.sh --help
```
