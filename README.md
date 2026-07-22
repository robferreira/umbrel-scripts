# umbrel-scripts

Scripts utilitários para **UmbrelOS** — automação de pastas compartilhadas, apps e manutenção do servidor.

Instalação típica no Umbrel: clonar em `/home/umbrel/umbrel-scripts` (scripts de mídia em `/home/umbrel/umbrel-scripts/media`).

## Estrutura

```
umbrel-scripts/
├── README.md          # este arquivo
└── media/             # scripts relacionados a mídia
    ├── README.md      # índice e docs de cada script (@nome)
    └── share-media.sh # compartilha mídia entre File Browser e Jellyfin
```

Novos scripts entram na pasta do tema correspondente (ex.: `media/`). Cada pasta tem um `README.md` com seções `@nome-do-script` descrevendo o que é e como usar.

## Pasta `media/`

Scripts para bibliotecas de mídia, File Browser, Jellyfin e volumes compartilhados.

Documentação detalhada: [media/README.md](media/README.md)

### Scripts disponíveis

| Script | Descrição |
|--------|-----------|
| [`share-media.sh`](media/share-media.sh) | Faz File Browser e Jellyfin usarem a mesma pasta de mídia no host |

## Uso rápido — share-media

```bash
# No Umbrel: clonar o repositório em /home/umbrel
cd /home/umbrel
git clone https://github.com/robferreira/umbrel-scripts.git

# Ou, a partir do seu PC, copiar o repositório inteiro:
# scp -r . umbrel@<IP-DO-UMBREL>:/home/umbrel/umbrel-scripts

# No servidor
sudo chmod +x /home/umbrel/umbrel-scripts/media/share-media.sh
sudo /home/umbrel/umbrel-scripts/media/share-media.sh
sudo /home/umbrel/umbrel-scripts/media/share-media.sh --install-service   # mantém após reboot/upgrade
```

Depois, no Jellyfin use `/media/photos`, `/media/movies`, `/media/series`. No File Browser, abra a pasta **`media`** na raiz (`media/photos`, etc.).

Para detalhes, flags (`--ensure`, `--install-service`, `--check`, `--dry-run`) e logs, veja [@share-media.sh](media/README.md#share-mediash).

## Requisitos gerais

- Acesso SSH ao Umbrel
- `sudo` no servidor
- Dependências específicas documentadas em cada script / seção `@`

## Contribuindo

1. Coloque o script na pasta do tema (`media/`, etc.)
2. Documente no `README.md` da pasta com uma seção `@nome-do-script`
3. Atualize a tabela de scripts neste README raiz, se fizer sentido
