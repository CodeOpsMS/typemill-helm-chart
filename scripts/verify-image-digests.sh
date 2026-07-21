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
    | awk '$1 == "image:" { gsub(/"/, "", $2); print $2 }' \
    | sort -u
}

pinned_images=$(render_images)
tagged_images=$(render_images \
  --set-string image.digest= \
  --set-string ai.initContainer.image.digest= \
  --set-string tests.image.digest=)

if [[ $(printf '%s\n' "$pinned_images" | sed '/^$/d' | wc -l | tr -d ' ') -ne 3 ]]; then
  echo "Expected exactly three default pinned images, rendered:" >&2
  printf '%s\n' "$pinned_images" >&2
  exit 1
fi

if [[ $(printf '%s\n' "$tagged_images" | sed '/^$/d' | wc -l | tr -d ' ') -ne 3 ]]; then
  echo "Expected exactly three default tagged images, rendered:" >&2
  printf '%s\n' "$tagged_images" >&2
  exit 1
fi

verify_repository() {
  local name=$1
  local repository=$2
  local api_repository=$repository
  local tagged_reference
  local pinned_reference

  tagged_reference=$(printf '%s\n' "$tagged_images" | grep -F "${repository}:" || true)
  pinned_reference=$(printf '%s\n' "$pinned_images" | grep -F "${repository}@" || true)

  if [[ $(printf '%s\n' "$tagged_reference" | sed '/^$/d' | wc -l | tr -d ' ') -ne 1 ]]; then
    echo "${name}: expected one rendered tag reference for ${repository}, got: ${tagged_reference}" >&2
    return 1
  fi
  if [[ $(printf '%s\n' "$pinned_reference" | sed '/^$/d' | wc -l | tr -d ' ') -ne 1 ]]; then
    echo "${name}: expected one rendered digest reference for ${repository}, got: ${pinned_reference}" >&2
    return 1
  fi

  local tag=${tagged_reference#"${repository}:"}
  local expected=${pinned_reference#"${repository}@"}

  if [[ ! "$expected" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "${name}: configured digest is missing or invalid: ${expected}" >&2
    return 1
  fi

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

verify_repository "Typemill" "kixote/typemill"
verify_repository "AI bootstrap" "mikefarah/yq"
verify_repository "Helm test" "busybox"
