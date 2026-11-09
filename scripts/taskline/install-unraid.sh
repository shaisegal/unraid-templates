#!/bin/sh
# Run on the Unraid host. Creates only the Taskline container, appdata and template.
set -eu
image=${TASKLINE_IMAGE:-ghcr.io/shaisegal/unraid-taskline:latest}
port=${TASKLINE_PORT:-18082}
config=/mnt/user/appdata/taskline
name=unraid-taskline
template=/boot/config/plugins/dockerMan/templates-user/my-taskline.xml
base=https://raw.githubusercontent.com/shaisegal/unraid-templates/main
[ "$(id -u)" = 0 ] || { echo 'Run in the Unraid root terminal.' >&2; exit 1; }
[ -f /etc/unraid-version ] || { echo 'This installer is for Unraid only.' >&2; exit 1; }
case "$port" in *[!0-9]*|'') echo 'Invalid port' >&2; exit 1;; esac
[ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || exit 1
if docker container inspect "$name" >/dev/null 2>&1; then
    echo 'Taskline already exists. Update through Unraid Docker; this installer does not replace containers.' >&2
    exit 1
fi
[ ! -e "$template" ] || { echo 'Taskline user template already exists; refusing to overwrite it.' >&2; exit 1; }
[ -d /etc/cron.d ] && [ -S /var/run/docker.sock ] || { echo 'Host cron or Docker socket missing.' >&2; exit 1; }
# Fetch and pull before creating host configuration.
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT HUP INT TERM
curl -fsSL "$base/taskline.xml" -o "$staging/taskline.xml"
grep -q '<Name>unraid-taskline</Name>' "$staging/taskline.xml" || { echo 'Unexpected template' >&2; exit 1; }
docker pull "$image"
mkdir -p "$config" "$(dirname "$template")"
set -- --mount "type=bind,src=$config,dst=/config" \
    --mount 'type=bind,src=/etc/cron.d,dst=/host/etc/cron.d,readonly' \
    --mount 'type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly'
if [ -d /boot/config/plugins/user.scripts ]; then
    set -- "$@" --mount 'type=bind,src=/boot/config/plugins/user.scripts,dst=/host/boot/config/plugins/user.scripts,readonly'
fi
if [ -d /var/spool/cron/crontabs ]; then
    set -- "$@" --mount 'type=bind,src=/var/spool/cron/crontabs,dst=/host/var/spool/cron/crontabs,readonly'
fi
docker run -d --name "$name" --restart unless-stopped --read-only --cap-drop ALL \
    --security-opt no-new-privileges:true --publish "$port:8080" \
    --env TZ=Europe/Berlin --label net.unraid.docker.managed=dockerman \
    --label "net.unraid.docker.webui=http://[IP]:[PORT:8080]" \
    "$@" "$image"
# Save the template with the actual installation port and image.
sed -e "s#<Repository>[^<]*</Repository>#<Repository>$image</Repository>#" \
    -e "s#>18082</Config>#>$port</Config>#" "$staging/taskline.xml" > "$template"
i=0
until curl -fsS "http://127.0.0.1:$port/api/health"; do
    i=$((i + 1))
    [ "$i" -lt 15 ] || { echo 'Container started but health endpoint did not become ready. Inspect docker logs unraid-taskline.' >&2; exit 1; }
    sleep 2
done
printf '\nTaskline is ready on host port %s. Open Container & Scans to connect Radarr.\n' "$port"
