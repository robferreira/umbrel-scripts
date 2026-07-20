# umbrel-scripts

Scripts utilitários para **UmbrelOS** — automação de pastas compartilhadas, apps e manutenção do servidor.

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
# Copiar para o Umbrel
scp media/share-media.sh umbrel@<IP-DO-UMBREL>:/home/umbrel/scripts/

# No servidor
sudo chmod +x /home/umbrel/scripts/share-media.sh
sudo /home/umbrel/scripts/share-media.sh
```

Depois, no Jellyfin, aponte as bibliotecas para `/media/photos`, `/media/movies` e `/media/series`. No File Browser, use `/data/media/...`.

Para detalhes, flags (`--ensure`, `--check`, `--dry-run`) e cron após updates, veja [@share-media.sh](media/README.md#share-mediash).

## Requisitos gerais

- Acesso SSH ao Umbrel
- `sudo` no servidor
- Dependências específicas documentadas em cada script / seção `@`

## Contribuindo

1. Coloque o script na pasta do tema (`media/`, etc.)
2. Documente no `README.md` da pasta com uma seção `@nome-do-script`
3. Atualize a tabela de scripts neste README raiz, se fizer sentido
