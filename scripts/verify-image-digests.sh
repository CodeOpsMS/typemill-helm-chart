#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHART_DIR="${ROOT_DIR}/charts/typemill"
DOCKER_HUB_API=${DOCKER_HUB_API:-https://hub.docker.com/v2/repositories}

render_images() {
  helm template image-pin-check "$CHART_DIR" \
    --namespace typemill-image-pin-check \
    --set ai.enabled=true \
    "$@" \
    | awk '
        /^[[:space:]]*- name:/ { name=$3; gsub(/"/, "", name) }
        $1 == "image:" { gsub(/"/, "", $2); print name "|" $2 }
      ' \
    | sort -u
}

pinned_images=$(render_images)
tagged_images=$(render_images \
  --set-string image.digest= \
  --set-string securityMigrations.cyanineV226.image.digest= \
  --set-string ai.initContainer.image.digest= \
  --set-string tests.image.digest=)

if [[ $(printf '%s\n' "$pinned_images" | sed '/^$/d' | wc -l | tr -d ' ') -ne 4 ]]; then
  echo "Expected exactly four default pinned container images, rendered:" >&2
  printf '%s\n' "$pinned_images" >&2
  exit 1
fi

if [[ $(printf '%s\n' "$tagged_images" | sed '/^$/d' | wc -l | tr -d ' ') -ne 4 ]]; then
  echo "Expected exactly four default tagged container images, rendered:" >&2
  printf '%s\n' "$tagged_images" >&2
  exit 1
fi

verify_container() {
  local name=$1
  local container_name=$2
  local tagged_reference
  local pinned_reference

  tagged_reference=$(printf '%s\n' "$tagged_images" | awk -F '|' -v container="$container_name" '$1 == container { print $2 }')
  pinned_reference=$(printf '%s\n' "$pinned_images" | awk -F '|' -v container="$container_name" '$1 == container { print $2 }')

  if [[ $(printf '%s\n' "$tagged_reference" | sed '/^$/d' | wc -l | tr -d ' ') -ne 1 ]]; then
    echo "${name}: expected one rendered tag reference for container ${container_name}, got: ${tagged_reference}" >&2
    return 1
  fi
  if [[ $(printf '%s\n' "$pinned_reference" | sed '/^$/d' | wc -l | tr -d ' ') -ne 1 ]]; then
    echo "${name}: expected one rendered digest reference for container ${container_name}, got: ${pinned_reference}" >&2
    return 1
  fi

  local repository=${tagged_reference%:*}
  local tag=${tagged_reference##*:}
  local pinned_repository=${pinned_reference%@*}
  local expected=${pinned_reference#*@}

  if [[ "$repository" != "$pinned_repository" ]]; then
    echo "${name}: tagged and pinned repositories differ: ${repository} != ${pinned_repository}" >&2
    return 1
  fi

  if [[ ! "$expected" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "${name}: configured digest is missing or invalid: ${expected}" >&2
    return 1
  fi

  local api_repository=$repository
  if [[ "$api_repository" != */* ]]; then
    api_repository="library/${api_repository}"
  fi

  local metadata
  metadata=$(curl --fail --silent --show-error --location \
    --retry 3 --retry-all-errors \
    "${DOCKER_HUB_API}/${api_repository}/tags/${tag}")

  local actual
  actual=$(jq -r '.digest // empty' <<<"$metadata")
  if [[ ! "$actual" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "${name}: Docker Hub returned an invalid digest for ${repository}:${tag}: ${actual}" >&2
    return 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "${name}: digest mismatch for ${repository}:${tag}" >&2
    echo "  rendered:   ${expected}" >&2
    echo "  Docker Hub: ${actual}" >&2
    return 1
  fi

  echo "${name}: verified ${repository}:${tag}@${expected}"
}

verify_container "Typemill" "typemill"
verify_container "Cyanine v2.26 migration" "cyanine-v226-security-migration"
verify_container "AI bootstrap" "ai-config"
verify_container "Helm test" "wget"
