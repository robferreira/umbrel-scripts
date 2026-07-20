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

No servidor (SSH):

```bash
sudo mkdir -p /home/umbrel/scripts
sudo chmod +x /home/umbrel/scripts/share-media.sh
sudo /home/umbrel/scripts/share-media.sh
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

# Reaplica somente se pastas/mount estiverem ausentes (ideal após update / cron)
sudo /home/umbrel/scripts/share-media.sh --ensure

# Só verifica o estado (exit 0 = OK, exit 1 = precisa ação)
sudo /home/umbrel/scripts/share-media.sh --check
```

### Depois de rodar — configuração na UI

| App | Caminho |
|-----|---------|
| **Jellyfin** — biblioteca de fotos | `/media/photos` |
| **Jellyfin** — filmes | `/media/movies` |
| **Jellyfin** — séries | `/media/series` |
| **File Browser** — upload | `/data/media/photos`, `/data/media/movies`, `/data/media/series` |

É a mesma pasta física no host; só muda o caminho dentro de cada container.

### Quando reexecutar

Após atualizar **UmbrelOS**, **Jellyfin** ou **File Browser**, o Umbrel pode reescrever o `docker-compose.yml` e o mount sumir. Nesse caso:

```bash
sudo /home/umbrel/scripts/share-media.sh --ensure
```

Opcional (cron semanal, por exemplo):

```cron
0 4 * * 0 root /home/umbrel/scripts/share-media.sh --ensure >> /var/log/share-media.log 2>&1
```

### Variáveis de ambiente

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `UMBREL_ROOT` | `/home/umbrel/umbrel` | Raiz da instalação Umbrel |
| `MEDIA_UID` | `1000` | UID dono das pastas de mídia |
| `MEDIA_GID` | `1000` | GID dono das pastas de mídia |
| `COMPOSE_SERVICE` | `server` | Nome do serviço no `docker-compose.yml` |

Exemplo:

```bash
sudo UMBREL_ROOT=/home/umbrel/umbrel COMPOSE_SERVICE=server /home/umbrel/scripts/share-media.sh --ensure
```

### Ajuda

```bash
sudo /home/umbrel/scripts/share-media.sh --help
```
