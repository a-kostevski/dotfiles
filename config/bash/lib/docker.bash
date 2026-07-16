# Docker utility functions
# Provides helper functions for working with Docker containers
# (bash port of zsh/lib/docker.zsh)

dnames-fn() {
  local ID
  for ID in $(docker ps | awk '{print $1}' | grep -v 'CONTAINER'); do
    docker inspect "$ID" | grep Name | head -1 | awk '{print $2}' | sed 's/,//g' | sed 's%/%%g' | sed 's/"//g'
  done
}

dip-fn() {
  local DOC IP OUT=""
  echo "IP addresses of all named running containers"

  for DOC in $(dnames-fn); do
    IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$DOC")
    OUT+="$DOC\t$IP\n"
  done
  echo -e "$OUT" | column -t
}

dex-fn() {
  docker exec -it "$1" "${2:-bash}"
}

di-fn() {
  docker inspect "$1"
}

dl-fn() {
  docker logs -f "$1"
}

drun-fn() {
  docker run -it "$1" "$2"
}

dcr-fn() {
  docker compose run "$@"
}

dsr-fn() {
  docker stop "$1"
  docker rm "$1"
}

drmc-fn() {
  local ids
  ids=$(docker ps --all -q -f status=exited)
  if [[ -n "$ids" ]]; then
    echo "$ids" | xargs docker rm
  else
    echo "no exited containers."
  fi
}

drmid-fn() {
  local imgs
  imgs=$(docker images -q -f dangling=true)
  if [[ -n "$imgs" ]]; then
    echo "$imgs" | xargs docker rmi
  else
    echo "no dangling images."
  fi
}

# Filter containers by label
dlab() {
  docker ps --filter="label=$1" --format="{{.ID}}"
}

dc-fn() {
  docker compose "$@"
}

dcl-fn() {
  docker compose logs "$@"
}
