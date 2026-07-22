#!/usr/bin/env bash
# =============================================================================
# share-media.sh
# Compartilha a pasta de mídia entre File Browser e Jellyfin no UmbrelOS.
#
# INSTALAÇÃO (caminho padrão: /home/umbrel/umbrel-scripts/media):
#   cd /home/umbrel
#   git clone https://github.com/robferreira/umbrel-scripts.git
#   sudo chmod +x /home/umbrel/umbrel-scripts/media/share-media.sh
#   sudo /home/umbrel/umbrel-scripts/media/share-media.sh
#   sudo /home/umbrel/umbrel-scripts/media/share-media.sh --install-service
#
# QUANDO REEXECUTAR:
#   Após atualizar o UmbrelOS, Jellyfin ou File Browser, se a mídia sumir
#   das bibliotecas ou do File Browser, rode o script novamente.
#   Use --ensure para só reaplicar se o mount tiver sumido.
#   Use --install-service para agendar --ensure no boot e semanalmente.
#
# HOST (compartilhado):
#   /home/umbrel/umbrel/data/media/{photos,movies,series}
#
# JELLYFIN (UI):
#   /media/photos  /media/movies  /media/series
#
# FILE BROWSER (UI):
#   pasta "media" na raiz → media/photos, media/movies, media/series
#   (caminho interno: /data/media/...)
#   A raiz do FB no Umbrel costuma ser umbrel/home ou data/storage em /data;
#   este script adiciona data/media montado em /data/media.
#
# VARIÁVEIS DE AMBIENTE:
#   UMBREL_ROOT   Raiz da instalação Umbrel (padrão: /home/umbrel/umbrel)
#   MEDIA_UID     UID dono das pastas (padrão: 1000)
#   MEDIA_GID     GID dono das pastas (padrão: 1000)
#
# USO:
#   sudo /home/umbrel/umbrel-scripts/media/share-media.sh
#   sudo /home/umbrel/umbrel-scripts/media/share-media.sh --dry-run
#   sudo /home/umbrel/umbrel-scripts/media/share-media.sh --ensure
#   sudo /home/umbrel/umbrel-scripts/media/share-media.sh --check
#   sudo /home/umbrel/umbrel-scripts/media/share-media.sh --install-service
# =============================================================================

set -euo pipefail

# --- Configuração ------------------------------------------------------------
UMBREL_ROOT="${UMBREL_ROOT:-/home/umbrel/umbrel}"
MEDIA_REL="data/media"
MEDIA_ROOT="${UMBREL_ROOT}/${MEDIA_REL}"
MEDIA_SUBDIRS=(photos movies series files)
APPS=(jellyfin file-browser)
MARKER="# umbrel-media-share"
MEDIA_UID="${MEDIA_UID:-1000}"
MEDIA_GID="${MEDIA_GID:-1000}"
COMPOSE_SERVICE="${COMPOSE_SERVICE:-server}"

JELLYFIN_MOUNT='${UMBREL_ROOT}/data/media:/media'
FILEBROWSER_MOUNT='${UMBREL_ROOT}/data/media:/data/media'

APP_SCRIPT="/usr/local/lib/node_modules/umbreld/source/modules/apps/legacy-compat/app-script"

SERVICE_NAME="umbrel-share-media"
SYSTEMD_SERVICE="/etc/systemd/system/${SERVICE_NAME}.service"
SYSTEMD_TIMER="/etc/systemd/system/${SERVICE_NAME}.timer"
CRON_FILE="/etc/cron.d/${SERVICE_NAME}"
LOG_FILE="${LOG_FILE:-/var/log/share-media.log}"
BOOT_DELAY_SEC="${BOOT_DELAY_SEC:-120}"

# --- Flags -------------------------------------------------------------------
DRY_RUN=false
NO_RESTART=false
RESTART_ONLY=false
ENSURE=false
CHECK_ONLY=false
INSTALL_SERVICE=false
UNINSTALL_SERVICE=false

# --- Utilitários -------------------------------------------------------------
log()  { echo "[share-media] $*"; }
warn() { echo "[share-media] AVISO: $*" >&2; }
die()  { echo "[share-media] ERRO: $*" >&2; exit 1; }

script_path() {
  local src="${BASH_SOURCE[0]}"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$src"
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f "$src" 2>/dev/null || echo "$src"
  else
    echo "$src"
  fi
}

has_systemd() {
  command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]
}

usage() {
  cat <<'EOF'
share-media.sh — compartilha mídia entre File Browser e Jellyfin no UmbrelOS.

Uso:
  sudo share-media.sh [opções]

Opções:
  --dry-run             Mostra o que faria, sem alterar nada
  --no-restart          Aplica pastas e patch do compose, sem reiniciar apps
  --restart-only        Apenas reinicia jellyfin e file-browser
  --ensure              Reaplica só se pastas/mount estiverem ausentes
  --check               Só verifica o estado (exit 0 = OK, 1 = precisa ação)
  --install-service     Agenda --ensure no boot e semanalmente (systemd ou cron)
  --uninstall-service   Remove o agendamento instalado
  -h, --help            Exibe esta ajuda

Variáveis de ambiente:
  UMBREL_ROOT     Raiz do Umbrel (padrão: /home/umbrel/umbrel)
  MEDIA_UID       UID das pastas de mídia (padrão: 1000)
  MEDIA_GID       GID das pastas de mídia (padrão: 1000)
  COMPOSE_SERVICE Nome do serviço no compose (padrão: server)
  LOG_FILE        Log do agendamento (padrão: /var/log/share-media.log)
  BOOT_DELAY_SEC  Espera após o boot antes do --ensure (padrão: 120)
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)             DRY_RUN=true ;;
      --no-restart)          NO_RESTART=true ;;
      --restart-only)        RESTART_ONLY=true ;;
      --ensure)              ENSURE=true ;;
      --check)               CHECK_ONLY=true ;;
      --install-service)     INSTALL_SERVICE=true ;;
      --uninstall-service)   UNINSTALL_SERVICE=true ;;
      -h|--help)             usage; exit 0 ;;
      *) die "Opção desconhecida: $1 (use --help)" ;;
    esac
    shift
  done

  local modes=0
  [[ "$RESTART_ONLY" == true ]] && ((modes++)) || true
  [[ "$ENSURE" == true ]] && ((modes++)) || true
  [[ "$CHECK_ONLY" == true ]] && ((modes++)) || true
  [[ "$INSTALL_SERVICE" == true ]] && ((modes++)) || true
  [[ "$UNINSTALL_SERVICE" == true ]] && ((modes++)) || true
  [[ "$modes" -le 1 ]] || die \
    "Use apenas uma de: --restart-only, --ensure, --check, --install-service, --uninstall-service"
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Execute como root: sudo $0"
}

check_dependencies() {
  local missing=()
  for cmd in yq docker; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "Dependências ausentes: ${missing[*]}"
}

has_umbreld() {
  command -v umbreld >/dev/null 2>&1
}

mount_for_app() {
  case "$1" in
    jellyfin)      echo "$JELLYFIN_MOUNT" ;;
    file-browser)  echo "$FILEBROWSER_MOUNT" ;;
    *) die "App desconhecido: $1" ;;
  esac
}

mount_dest_for_app() {
  local mount_line
  mount_line="$(mount_for_app "$1")"
  echo "${mount_line#*:}"
}

compose_file_for() {
  local app="$1"
  local path="${UMBREL_ROOT}/app-data/${app}/docker-compose.yml"
  [[ -f "$path" ]] || die "Compose não encontrado: $path (app '${app}' instalado?)"
  echo "$path"
}

app_installed() {
  local app="$1"
  [[ -f "${UMBREL_ROOT}/app-data/${app}/docker-compose.yml" ]]
}

require_apps_installed() {
  local missing=()
  local app
  for app in "${APPS[@]}"; do
    app_installed "$app" || missing+=("$app")
  done
  [[ ${#missing[@]} -eq 0 ]] || die \
    "Apps não instalados (pasta app-data ausente): ${missing[*]}. Instale-os no Umbrel e rode novamente."
}

compose_service_exists() {
  local compose_file="$1"
  yq -e ".services.${COMPOSE_SERVICE}" "$compose_file" >/dev/null 2>&1
}

compose_has_media_mount() {
  local compose_file="$1"
  local mount_dest="$2"
  grep -qF "\${UMBREL_ROOT}/${MEDIA_REL}:${mount_dest}" "$compose_file" 2>/dev/null
}

# Remove mounts gerenciados por este script (data/media no destino) e legado data/storage:/media
remove_old_media_entries() {
  local compose_file="$1"
  local mount_dest="$2"

  if ! grep -qE 'UMBREL_ROOT.*/data/(media|storage)' "$compose_file" 2>/dev/null \
     && ! grep -qF "$MARKER" "$compose_file" 2>/dev/null; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v marker="$MARKER" -v dest=":${mount_dest}" '
    index($0, marker) { next }
    /\$\{UMBREL_ROOT\}\/data\/media/ && index($0, dest) { next }
    /\$\{UMBREL_ROOT\}\/data\/storage:\/media/ { next }
    { print }
  ' "$compose_file" > "$tmp"
  mv "$tmp" "$compose_file"
}

restore_backup() {
  local compose_file="$1"
  local backup="$2"
  if [[ -f "$backup" ]]; then
    cp -a "$backup" "$compose_file"
    warn "Compose restaurado a partir de: $backup"
  fi
}

patch_compose() {
  local app="$1"
  local compose_file
  compose_file="$(compose_file_for "$app")"
  local mount_line
  mount_line="$(mount_for_app "$app")"
  local mount_dest="${mount_line#*:}"

  if ! compose_service_exists "$compose_file"; then
    die "[$app] Serviço '.services.${COMPOSE_SERVICE}' não encontrado em $compose_file. Defina COMPOSE_SERVICE se o nome for outro."
  fi

  if compose_has_media_mount "$compose_file" "$mount_dest"; then
    log "[$app] Volume de mídia já configurado em $(basename "$compose_file")"
    return 0
  fi

  log "[$app] Aplicando patch em $compose_file"

  if [[ "$DRY_RUN" == true ]]; then
    log "[$app] (dry-run) Adicionaria: - ${mount_line}"
    return 0
  fi

  local backup="${compose_file}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$compose_file" "$backup"
  log "[$app] Backup: $backup"

  remove_old_media_entries "$compose_file" "$mount_dest"

  if ! yq -i ".services.${COMPOSE_SERVICE}.volumes += [\"\${UMBREL_ROOT}/${MEDIA_REL}:${mount_dest}\"]" \
      "$compose_file"; then
    restore_backup "$compose_file" "$backup"
    die "[$app] Falha ao aplicar yq; compose restaurado do backup"
  fi

  if ! compose_has_media_mount "$compose_file" "$mount_dest"; then
    restore_backup "$compose_file" "$backup"
    die "[$app] Mount não apareceu após o patch; compose restaurado do backup"
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v dest=":${mount_dest}" -v marker="$MARKER" '
    /\$\{UMBREL_ROOT\}\/data\/media/ && index($0, dest) && !seen {
      match($0, /^[[:space:]]*/)
      indent = substr($0, RSTART, RLENGTH)
      print indent marker
      seen = 1
    }
    { print }
  ' "$compose_file" > "$tmp"
  mv "$tmp" "$compose_file"

  log "[$app] Volume adicionado: ${mount_line}"
}

setup_media_dirs() {
  log "Criando estrutura em ${MEDIA_ROOT} ..."
  if [[ "$DRY_RUN" == true ]]; then
    log "(dry-run) mkdir -p ${MEDIA_ROOT}/{${MEDIA_SUBDIRS[*]}}"
    log "(dry-run) chown ${MEDIA_UID}:${MEDIA_GID}; chmod 755 nas pastas"
    return 0
  fi

  mkdir -p "${MEDIA_ROOT}"
  local sub
  for sub in "${MEDIA_SUBDIRS[@]}"; do
    mkdir -p "${MEDIA_ROOT}/${sub}"
    chown "${MEDIA_UID}:${MEDIA_GID}" "${MEDIA_ROOT}/${sub}"
    chmod 755 "${MEDIA_ROOT}/${sub}"
  done
  chown "${MEDIA_UID}:${MEDIA_GID}" "${MEDIA_ROOT}"
  chmod 755 "${MEDIA_ROOT}"
  log "Pastas prontas: ${MEDIA_ROOT}/{${MEDIA_SUBDIRS[*]}}"
}

media_dirs_ok() {
  local sub
  [[ -d "$MEDIA_ROOT" ]] || return 1
  for sub in photos movies series; do
    [[ -d "${MEDIA_ROOT}/${sub}" ]] || return 1
  done
  return 0
}

compose_mounts_ok() {
  local app compose_file mount_dest
  for app in "${APPS[@]}"; do
    app_installed "$app" || return 1
    compose_file="$(compose_file_for "$app")"
    mount_dest="$(mount_dest_for_app "$app")"
    compose_has_media_mount "$compose_file" "$mount_dest" || return 1
  done
  return 0
}

restart_app() {
  local app="$1"
  log "[$app] Reiniciando ..."

  if [[ "$DRY_RUN" == true ]]; then
    log "[$app] (dry-run) Reiniciaria o app"
    return 0
  fi

  if has_umbreld; then
    umbreld client apps.restart.mutate --appId "$app" \
      && { log "[$app] Reiniciado via umbreld"; return 0; } \
      || warn "[$app] umbreld falhou, tentando app-script ..."
  fi

  if [[ -x "$APP_SCRIPT" ]]; then
    UMBREL_ROOT="$UMBREL_ROOT" "$APP_SCRIPT" restart "$app" \
      && { log "[$app] Reiniciado via app-script"; return 0; }
  fi

  warn "[$app] Reinício automático falhou. Reinicie manualmente pela UI do Umbrel."
}

# Prefere o container *_server_* (evita app_proxy)
find_container() {
  local app="$1"
  local names name
  names="$(docker ps --format '{{.Names}}' | grep -E "${app}" || true)"
  [[ -n "$names" ]] || return 0

  while IFS= read -r name; do
    [[ "$name" == *"_server_"* || "$name" == *"_server" ]] && { echo "$name"; return 0; }
  done <<< "$names"

  echo "$names" | head -n1
}

container_has_dest_mount() {
  local container="$1"
  local dest="$2"
  docker inspect "$container" \
    --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' \
    2>/dev/null | grep -qF " -> ${dest}"
}

container_media_mount_line() {
  local container="$1"
  docker inspect "$container" \
    --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' \
    2>/dev/null | grep -F "data/media" || true
}

verify_setup() {
  local expect_live="${1:-true}"
  local status=0

  log "========== Verificação =========="

  if [[ -d "$MEDIA_ROOT" ]]; then
    log "Pastas no host (${MEDIA_ROOT}):"
    ls -la "$MEDIA_ROOT" 2>/dev/null || warn "Não foi possível listar ${MEDIA_ROOT}"
  else
    warn "Pasta ${MEDIA_ROOT} não existe"
    status=1
  fi

  local app container compose_file mount_dest mounts
  for app in "${APPS[@]}"; do
    mount_dest="$(mount_dest_for_app "$app")"

    if ! app_installed "$app"; then
      warn "[$app] App não instalado (compose ausente)"
      status=1
      continue
    fi

    compose_file="$(compose_file_for "$app")"
    if compose_has_media_mount "$compose_file" "$mount_dest"; then
      log "[$app] Compose OK: ${MEDIA_REL} -> ${mount_dest}"
    else
      warn "[$app] Compose SEM mount (esperado: ${MEDIA_REL}:${mount_dest})"
      status=1
    fi

    if [[ "$expect_live" != true ]]; then
      log "[$app] (pulando inspeção do container — dry-run / ainda não reiniciado)"
      continue
    fi

    container="$(find_container "$app")"
    if [[ -z "$container" ]]; then
      warn "[$app] Container não encontrado em docker ps"
      status=1
      continue
    fi

    log "[$app] Container: ${container}"
    mounts="$(container_media_mount_line "$container")"

    if [[ -n "$mounts" ]] && echo "$mounts" | grep -qF " -> ${mount_dest}"; then
      log "[$app] Mount OK:"
      echo "$mounts" | while read -r line; do [[ -n "$line" ]] && log "  $line"; done
    else
      warn "[$app] Mount data/media -> ${mount_dest} não encontrado no container"
      log "[$app] Todos os mounts:"
      docker inspect "$container" \
        --format '{{range .Mounts}}  {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' \
        2>/dev/null || true
      status=1
    fi
  done

  log "================================="
  log "Jellyfin: bibliotecas em /media/photos, /media/movies, /media/series"
  log "File Browser: pasta media/ na raiz (media/photos, media/movies, media/series)"
  return "$status"
}

needs_action() {
  media_dirs_ok || return 0
  compose_mounts_ok || return 0
  return 1
}

apply_compose_patches() {
  local app
  for app in "${APPS[@]}"; do
    patch_compose "$app"
  done
}

restart_apps() {
  local app
  for app in "${APPS[@]}"; do
    restart_app "$app"
  done
}

run_check() {
  log "Modo --check (somente leitura)"
  local status=0
  if ! media_dirs_ok; then
    warn "Pastas de mídia incompletas em ${MEDIA_ROOT}"
    status=1
  else
    log "Pastas de mídia OK"
  fi

  if ! compose_mounts_ok; then
    warn "Um ou mais composes sem mount de mídia"
    status=1
  else
    log "Composes OK"
  fi

  if ! verify_setup true; then
    status=1
  fi

  if [[ "$status" -eq 0 ]]; then
    log "Estado OK — nada a fazer."
  else
    log "Ação necessária — rode sem --check (ou com --ensure)."
  fi
  return "$status"
}

run_ensure() {
  log "Modo --ensure (reaplica só se necessário)"

  if ! needs_action; then
    log "Pastas e composes já estão corretos."
    if [[ "$DRY_RUN" == true ]]; then
      verify_setup false || true
      return 0
    fi
    local app container needs_restart=false mount_dest
    for app in "${APPS[@]}"; do
      mount_dest="$(mount_dest_for_app "$app")"
      container="$(find_container "$app")"
      if [[ -z "$container" ]] || ! container_has_dest_mount "$container" "$mount_dest"; then
        warn "[$app] Container sem mount ao vivo (${mount_dest}) — será reiniciado"
        needs_restart=true
      fi
    done
    if [[ "$needs_restart" == true && "$NO_RESTART" != true ]]; then
      restart_apps
    fi
    verify_setup true || true
    return 0
  fi

  log "Detectada configuração incompleta — aplicando correções ..."
  setup_media_dirs
  apply_compose_patches

  if [[ "$NO_RESTART" == true ]]; then
    log "Pulando reinício (--no-restart)."
    verify_setup false || true
  else
    restart_apps
    verify_setup true || true
  fi
}

install_systemd_units() {
  local script="$1"

  if [[ "$DRY_RUN" == true ]]; then
    log "(dry-run) Criaria ${SYSTEMD_SERVICE} e ${SYSTEMD_TIMER}"
    return 0
  fi

  cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Umbrel share-media ensure (File Browser + Jellyfin)
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
Environment=UMBREL_ROOT=${UMBREL_ROOT}
Environment=MEDIA_UID=${MEDIA_UID}
Environment=MEDIA_GID=${MEDIA_GID}
Environment=COMPOSE_SERVICE=${COMPOSE_SERVICE}
ExecStart=${script} --ensure
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

[Install]
WantedBy=multi-user.target
EOF

  cat > "$SYSTEMD_TIMER" <<EOF
[Unit]
Description=Timer for Umbrel share-media ensure (boot + weekly)

[Timer]
OnBootSec=${BOOT_DELAY_SEC}
OnCalendar=Sun *-*-* 04:00:00
Persistent=true
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}.timer"
  log "systemd instalado: ${SYSTEMD_TIMER}"
  log "  - boot: +${BOOT_DELAY_SEC}s --ensure | semanal: domingo 04:00 | log: ${LOG_FILE}"
}

install_cron() {
  local script="$1"

  if [[ "$DRY_RUN" == true ]]; then
    log "(dry-run) Criaria ${CRON_FILE}"
    return 0
  fi

  cat > "$CRON_FILE" <<EOF
# Gerenciado por share-media.sh — use --uninstall-service para remover
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
UMBREL_ROOT=${UMBREL_ROOT}

@reboot root sleep ${BOOT_DELAY_SEC} && ${script} --ensure >> ${LOG_FILE} 2>&1
0 4 * * 0 root ${script} --ensure >> ${LOG_FILE} 2>&1
EOF
  chmod 644 "$CRON_FILE"
  log "cron instalado: ${CRON_FILE}"
}

remove_cron_if_present() {
  if [[ -f "$CRON_FILE" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log "(dry-run) Removeria ${CRON_FILE}"
    else
      rm -f "$CRON_FILE"
      log "Removido: ${CRON_FILE}"
    fi
  fi
}

remove_systemd_if_present() {
  if [[ -f "$SYSTEMD_TIMER" ]] || [[ -f "$SYSTEMD_SERVICE" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log "(dry-run) Removeria unidades systemd ${SERVICE_NAME}"
      return 0
    fi
    if has_systemd; then
      systemctl disable --now "${SERVICE_NAME}.timer" 2>/dev/null || true
      systemctl disable --now "${SERVICE_NAME}.service" 2>/dev/null || true
    fi
    rm -f "$SYSTEMD_TIMER" "$SYSTEMD_SERVICE"
    if has_systemd; then
      systemctl daemon-reload 2>/dev/null || true
    fi
    log "Unidades systemd removidas: ${SERVICE_NAME}"
  fi
}

install_service() {
  local script
  script="$(script_path)"
  [[ -f "$script" ]] || die "Script não encontrado: $script"
  [[ -x "$script" ]] || chmod +x "$script"

  log "Instalando agendamento automático ..."
  log "Script: ${script}"

  if has_systemd; then
    remove_cron_if_present
    install_systemd_units "$script"
  else
    warn "systemd não disponível — usando cron"
    remove_systemd_if_present
    install_cron "$script"
  fi
  log "Pronto. Após reboot/upgrade, o mount será reaplicado se sumir."
}

uninstall_service() {
  log "Removendo agendamento automático ..."
  remove_systemd_if_present
  remove_cron_if_present
  log "Agendamento removido. O share nos composes não foi alterado."
}

main() {
  parse_args "$@"
  require_root

  if [[ "$INSTALL_SERVICE" == true ]]; then
    install_service
    exit 0
  fi

  if [[ "$UNINSTALL_SERVICE" == true ]]; then
    uninstall_service
    exit 0
  fi

  check_dependencies

  log "Umbrel root: ${UMBREL_ROOT}"
  log "Mídia:       ${MEDIA_ROOT}"

  if [[ "$CHECK_ONLY" == true ]]; then
    run_check
    exit $?
  fi

  if [[ "$RESTART_ONLY" == true ]]; then
    require_apps_installed
    restart_apps
    verify_setup true || true
    exit 0
  fi

  require_apps_installed

  if [[ "$ENSURE" == true ]]; then
    run_ensure
    log "Concluído."
    exit 0
  fi

  setup_media_dirs
  apply_compose_patches

  if [[ "$NO_RESTART" == true ]]; then
    log "Pulando reinício (--no-restart)."
    verify_setup false || true
  else
    if [[ "$DRY_RUN" == true ]]; then
      log "(dry-run) Verificação abaixo reflete o estado ATUAL."
      restart_apps
      verify_setup false || true
    else
      restart_apps
      verify_setup true || true
    fi
  fi

  log "Concluído."
}

main "$@"
