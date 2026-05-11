#!/usr/bin/env bash

set -euo pipefail

OWNER="${OWNER:-A11yDevs}"
REPO="${REPO:-emacs-a11y-vm}"
ASSET_NAME="${ASSET_NAME:-debian-a11ydevs.qcow2}"
MIRROR_ROOT="${MIRROR_ROOT:-/var/www/html/a11ydevs}"
LOCK_FILE="${LOCK_FILE:-/tmp/ea11-vm-mirror.lock}"

API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
DOWNLOAD_URL="https://github.com/${OWNER}/${REPO}/releases/latest/download/${ASSET_NAME}"

mkdir -p "$MIRROR_ROOT"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "[mirror] outra execucao ja esta em andamento" >&2
    exit 0
fi

latest_json="$(curl -fsSL "$API_URL")"
latest_tag="$(printf '%s' "$latest_json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

if [[ -z "$latest_tag" ]]; then
    echo "[mirror] nao foi possivel resolver tag mais recente" >&2
    exit 1
fi

tag_dir="${MIRROR_ROOT}/${latest_tag}"
latest_dir="${MIRROR_ROOT}/latest"
asset_target="${tag_dir}/${ASSET_NAME}"
asset_latest="${latest_dir}/${ASSET_NAME}"
version_latest="${latest_dir}/VERSION"

tmp_file="$(mktemp "${MIRROR_ROOT}/.${ASSET_NAME}.XXXXXX")"
cleanup() {
    rm -f "$tmp_file"
}
trap cleanup EXIT

mkdir -p "$tag_dir" "$latest_dir"

if [[ -f "$asset_target" ]]; then
    echo "[mirror] asset ja existe para ${latest_tag}; mantendo arquivo"
else
    echo "[mirror] baixando ${ASSET_NAME} da release ${latest_tag}"
    curl -fL --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "$tmp_file"
    mv -f "$tmp_file" "$asset_target"
fi

cp -f "$asset_target" "$asset_latest"
printf '%s\n' "$latest_tag" > "$version_latest"

echo "[mirror] latest -> ${latest_tag}"

for old_dir in "${MIRROR_ROOT}"/*; do
    [[ -d "$old_dir" ]] || continue
    base_name="$(basename "$old_dir")"
    if [[ "$base_name" == "latest" || "$base_name" == "$latest_tag" ]]; then
        continue
    fi
    rm -rf "$old_dir"
    echo "[mirror] removido snapshot antigo: ${base_name}"
done

echo "[mirror] sincronizacao concluida"
