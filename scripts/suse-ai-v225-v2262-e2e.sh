#!/usr/bin/env bash

# Embedded PHP snippets are intentionally single-quoted so the local shell does
# not expand PHP variables before they reach the container.
# shellcheck disable=SC2016

set -Eeuo pipefail

umask 077

WORKSPACE=${WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
KUBE_CONTEXT=${KUBE_CONTEXT:-suseai}
KUBECTL_BIN=${KUBECTL_BIN:-kubectl}
HELM_BIN=${HELM_BIN:-helm}
BASELINE_REF=${BASELINE_REF:-origin/main}
STORAGE_CLASS=${STORAGE_CLASS:-longhorn}
PVC_SIZE=${PVC_SIZE:-1Gi}
OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://suse-ai-ollama.suse-private-ai.svc.cluster.local:11434/v1}
OLLAMA_MODEL=${OLLAMA_MODEL:-mistral-small3.2:latest}
SKIP_SETUP_TEST=${SKIP_SETUP_TEST:-false}

TARGET_CHART_VERSION=2.2.0
TARGET_APP_VERSION=v2.26.2
TARGET_IMAGE_DIGEST=sha256:4e9dff1795190fb3f09fc9e967643a030a0b8ee51e5e57aff086c270976ada07
TARGET_AMD64_DIGEST=sha256:88b1d058dd57a56127a3bd2a7137aad4d60706ca752925a6e8f70fd6157395f4
BASELINE_CHART_VERSION=2.1.0
BASELINE_APP_VERSION=v2.25.0
BASELINE_IMAGE_DIGEST=sha256:52e081c1149d8b4c8ae6b03b03099411d9d95f32ee7ce6b61890b391700471bd
MIGRATION_IMAGE_DIGEST=sha256:628f79a08cc75bc07777ae4b95312fb9770a531645789e698f12f96de6624156

SETUP_RELEASE=typemill-setup
UPGRADE_RELEASE=typemill-upgrade
PRODUCTION_NAMESPACES=(typemilllissa typemilllissatest typemilluhlex)

THEME_PATHS=(
  blog.twig
  home/landingpageNews.twig
  landingpage.twig
  partials/posts.twig
  cyanine.yaml
)

OLD_THEME_HASH_VALUES=(
  3328ab536a75379fecab181bb07dbc46124adf84ae54509e62e68f3bbb8f8ab4
  e5b85ecae171eba9ae600229a4cf09259aaba0ad3027bdf86999117534401e4d
  b49df2d3b6be481aa282c799b51c9a25ecb6ffd52a836fa0d091bd8113ba2bba
  2f88c75ba90abe87109495f70a1da2ff8c5eee6a9373255fc0b306c1efc5745a
  fdcf0f9e229e6f9c57d23b35a6ed664df42fdfd90a2c9eb5805a9d790ddc7752
)

NEW_THEME_HASH_VALUES=(
  71a885d3aaeb3dce70f1d5fb35510a6c3c29780e939d39daea98118dfefa26fa
  2b3a49c379bade6f367040ff6ebd270a907f5af7753d0a2a3006af46e4694c36
  6eb5fdd81f0db06aefaf07aededa3d3d9fe1666b079a123ba43529012b7e3842
  5aecdf8d3e810236cc481539fa7302fd686bad7746482cae961bcb58ee076409
)

UTC_STAMP=$(date -u +%Y%m%d%H%M%S)
RANDOM_SUFFIX=$(openssl rand -hex 3)
RUN_ID="v2262-${UTC_STAMP}-${RANDOM_SUFFIX}"
TEST_NAMESPACE="typemill-v2262-e2e-${UTC_STAMP}-${RANDOM_SUFFIX}"
TMP_ROOT=$(mktemp -d /private/tmp/typemill-v2262-e2e.XXXXXX)
BASELINE_ROOT="${TMP_ROOT}/baseline"
PROD_BEFORE="${TMP_ROOT}/production-before.jsonl"
PROD_AFTER="${TMP_ROOT}/production-after.jsonl"

NAMESPACE_UID=
NAMESPACE_CREATED=false
SETUP_PV=
UPGRADE_PV=
EXPLICIT_CLEANUP_DONE=false

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is missing: $1"
}

kube() {
  "$KUBECTL_BIN" --context "$KUBE_CONTEXT" "$@"
}

helm_cluster() {
  "$HELM_BIN" --kube-context "$KUBE_CONTEXT" "$@"
}

namespace_exists() {
  kube get namespace "$TEST_NAMESPACE" >/dev/null 2>&1
}

guard_namespace() {
  [[ "$TEST_NAMESPACE" =~ ^typemill-v2262-e2e-[0-9]{14}-[a-f0-9]{6}$ ]] || {
    printf 'Cleanup guard rejected namespace format: %s\n' "$TEST_NAMESPACE" >&2
    return 1
  }

  local forbidden
  for forbidden in "${PRODUCTION_NAMESPACES[@]}"; do
    [[ "$TEST_NAMESPACE" != "$forbidden" ]] || {
      printf 'Cleanup guard rejected production namespace: %s\n' "$TEST_NAMESPACE" >&2
      return 1
    }
  done

  local current_uid current_run current_part current_purpose
  current_uid=$(kube get namespace "$TEST_NAMESPACE" -o jsonpath='{.metadata.uid}') || return 1
  current_run=$(kube get namespace "$TEST_NAMESPACE" -o jsonpath='{.metadata.labels.codex\.openai\.com/run-id}') || return 1
  current_part=$(kube get namespace "$TEST_NAMESPACE" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}') || return 1
  current_purpose=$(kube get namespace "$TEST_NAMESPACE" -o jsonpath='{.metadata.labels.codex\.openai\.com/purpose}') || return 1

  [[ -n "$NAMESPACE_UID" && "$current_uid" == "$NAMESPACE_UID" ]] || {
    printf 'Cleanup guard rejected namespace UID: expected=%s actual=%s\n' "$NAMESPACE_UID" "$current_uid" >&2
    return 1
  }
  [[ "$current_run" == "$RUN_ID" ]] || return 1
  [[ "$current_part" == typemill-e2e ]] || return 1
  [[ "$current_purpose" == v225-v2262 ]] || return 1
}

release_exists() {
  helm_cluster status "$1" --namespace "$TEST_NAMESPACE" >/dev/null 2>&1
}

diagnose_namespace() {
  namespace_exists || return 0
  log "Diagnostic snapshot for ${TEST_NAMESPACE}"
  kube get deployment,pod,service,pvc --namespace "$TEST_NAMESPACE" -o wide || true
  kube get events --namespace "$TEST_NAMESPACE" --sort-by=.lastTimestamp || true

  local pod init_container
  while IFS= read -r pod; do
    [[ -n "$pod" ]] || continue
    kube describe pod --namespace "$TEST_NAMESPACE" "$pod" || true
    kube logs --namespace "$TEST_NAMESPACE" "$pod" --container typemill --tail=200 || true
    while IFS= read -r init_container; do
      [[ -n "$init_container" ]] || continue
      kube logs --namespace "$TEST_NAMESPACE" "$pod" --container "$init_container" --tail=200 || true
    done < <(kube get pod --namespace "$TEST_NAMESPACE" "$pod" -o json | jq -r '.spec.initContainers[]?.name')
  done < <(kube get pods --namespace "$TEST_NAMESPACE" -o json | jq -r '.items[].metadata.name')
}

wait_for_absence() {
  local kind=$1
  local name=$2
  local scope=${3:-namespaced}
  local attempts=${4:-120}
  local count

  for ((count = 1; count <= attempts; count++)); do
    if [[ "$scope" == cluster ]]; then
      if ! kube get "$kind" "$name" >/dev/null 2>&1; then
        return 0
      fi
    elif ! kube get "$kind" "$name" --namespace "$TEST_NAMESPACE" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  return 1
}

cleanup_on_exit() {
  local status=$?
  trap - EXIT HUP INT TERM

  if [[ "$EXPLICIT_CLEANUP_DONE" != true && "$NAMESPACE_CREATED" == true ]] && namespace_exists; then
    diagnose_namespace
    if guard_namespace; then
      if release_exists "$SETUP_RELEASE"; then
        helm_cluster uninstall "$SETUP_RELEASE" --namespace "$TEST_NAMESPACE" --wait --timeout 5m || true
      fi
      if release_exists "$UPGRADE_RELEASE"; then
        helm_cluster uninstall "$UPGRADE_RELEASE" --namespace "$TEST_NAMESPACE" --wait --timeout 5m || true
      fi
      kube delete namespace "$TEST_NAMESPACE" --wait=false || true
      wait_for_absence namespace "$TEST_NAMESPACE" cluster 300 || true
    else
      printf 'ERROR: cleanup guard failed; test namespace was not deleted: %s\n' "$TEST_NAMESPACE" >&2
    fi
  fi

  exit "$status"
}

trap cleanup_on_exit EXIT HUP INT TERM

production_snapshot() {
  local output=$1
  local namespace

  {
    for namespace in "${PRODUCTION_NAMESPACES[@]}"; do
      kube get namespace "$namespace" -o json | jq -cS '{kind:"Namespace",name:.metadata.name,uid:.metadata.uid}'
      kube get deployments --namespace "$namespace" -o json | jq -cS \
        '.items[] | {kind:"Deployment",namespace:.metadata.namespace,name:.metadata.name,uid:.metadata.uid,generation:.metadata.generation,images:[.spec.template.spec.containers[].image],ready:.status.readyReplicas,available:.status.availableReplicas}'
      kube get pvc --namespace "$namespace" -o json | jq -cS \
        '.items[] | {kind:"PVC",namespace:.metadata.namespace,name:.metadata.name,uid:.metadata.uid,volume:.spec.volumeName,phase:.status.phase}'
    done
  } >"$output"
}

pod_for_release() {
  local release=$1
  kube get pods --namespace "$TEST_NAMESPACE" -l "app.kubernetes.io/instance=${release}" -o json | jq -er '
    [.items[]
      | select(.metadata.deletionTimestamp == null)
      | select(.status.phase == "Running")
      | select(any(.spec.containers[]?; .name == "typemill"))
    ] as $pods
    | if ($pods | length) == 1 then $pods[0].metadata.name
      else error("expected exactly one active application pod") end'
}

guard_pod() {
  local pod=$1
  local release=$2
  guard_namespace || return 1
  [[ $(kube get pod --namespace "$TEST_NAMESPACE" "$pod" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}') == "$release" ]]
  [[ $(kube get pod --namespace "$TEST_NAMESPACE" "$pod" -o jsonpath='{.spec.containers[0].name}') == typemill ]]
}

app_exec() {
  local pod=$1
  shift
  kube exec --namespace "$TEST_NAMESPACE" "$pod" --container typemill -- "$@"
}

raw_http_code() {
  local pod=$1
  local path=$2
  app_exec "$pod" env TYPEMILL_E2E_PATH="$path" php -r '
    $path = getenv("TYPEMILL_E2E_PATH");
    $socket = fsockopen("127.0.0.1", 80, $errno, $error, 5);
    if (!$socket) { fwrite(STDERR, "$errno:$error\n"); exit(2); }
    fwrite($socket, "GET {$path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    $line = trim((string) fgets($socket));
    fclose($socket);
    if (!preg_match("~^HTTP/[0-9.]+ ([0-9]{3})~", $line, $match)) { fwrite(STDERR, "$line\n"); exit(3); }
    echo $match[1];
  '
}

theme_hash() {
  local pod=$1
  local relative_path=$2
  app_exec "$pod" sha256sum "/var/www/html/themes/cyanine/${relative_path}" | awk '{print $1}'
}

marker_hashes() {
  local pod=$1
  app_exec "$pod" sha256sum \
    /var/www/html/settings/.typemill-e2e-marker \
    /var/www/html/content/.typemill-e2e-marker \
    /var/www/html/media/.typemill-e2e-marker \
    /var/www/html/plugins/.typemill-e2e-marker \
    /var/www/html/themes/.typemill-e2e-marker \
    /var/www/html/data/.typemill-e2e-marker \
    /var/www/html/cache/.typemill-e2e-marker
}

assert_theme_hash() {
  local pod=$1
  local relative_path=$2
  local expected=$3
  local actual
  actual=$(theme_hash "$pod" "$relative_path")
  [[ "$actual" == "$expected" ]] || fail "unexpected Cyanine hash for ${relative_path}: ${actual}"
}

pvc_identity() {
  local pvc=$1
  kube get pvc --namespace "$TEST_NAMESPACE" "$pvc" -o json | jq -r '[.metadata.uid,.spec.volumeName] | @tsv'
}

verify_runtime_image() {
  local pod=$1
  local expected_index=$2
  local expected_child=$3
  local image_id
  image_id=$(kube get pod --namespace "$TEST_NAMESPACE" "$pod" -o jsonpath='{.status.containerStatuses[?(@.name=="typemill")].imageID}')
  if [[ "$image_id" != *"${expected_index}"* && "$image_id" != *"${expected_child}"* ]]; then
    fail "unexpected runtime imageID: ${image_id}"
  fi
  log "Runtime imageID: ${image_id}"
}

verify_ai_settings() {
  local pod=$1
  local ai_json
  ai_json=$(app_exec "$pod" env \
    EXPECTED_AI_URL="$OLLAMA_BASE_URL" \
    EXPECTED_AI_MODEL="$OLLAMA_MODEL" \
    php -r '
      require "/var/www/html/system/vendor/autoload.php";
      $settings = Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/settings/settings.yaml");
      $selected = [
        "adapter" => $settings["ai_adapter"] ?? null,
        "baseUrl" => $settings["ai_base_url"] ?? null,
        "model" => $settings["ai_model"] ?? null,
        "provider" => $settings["ai_provider_name"] ?? null,
        "timeout" => (string) ($settings["aitimeout"] ?? ""),
        "reasoning" => (string) ($settings["ai_reasoning_effort"] ?? "")
      ];
      echo json_encode($selected, JSON_UNESCAPED_SLASHES);
    ')

  jq -e \
    --arg url "$OLLAMA_BASE_URL" \
    --arg model "$OLLAMA_MODEL" \
    '.adapter == "openai" and .baseUrl == $url and .model == $model and .provider == "Ollama" and .timeout == "180" and .reasoning == ""' \
    <<<"$ai_json" >/dev/null || fail "unexpected persisted AI settings: ${ai_json}"

  local secret_keys
  secret_keys=$(app_exec "$pod" php -r '
    require "/var/www/html/system/vendor/autoload.php";
    $file = "/var/www/html/settings/secrets.yaml";
    $secrets = is_file($file) ? Symfony\Component\Yaml\Yaml::parseFile($file) : [];
    $present = array_values(array_intersect(["ai_api_key", "chatgptKey", "claudeKey"], array_keys((array) $secrets)));
    echo json_encode($present);
  ')
  [[ "$secret_keys" == '[]' ]] || fail "unexpected AI secret keys on the PVC: ${secret_keys}"
}

verify_ollama() {
  local pod=$1
  app_exec "$pod" env OLLAMA_MODELS_URL="${OLLAMA_BASE_URL}/models" OLLAMA_EXPECTED_MODEL="$OLLAMA_MODEL" php -r '
    $context = stream_context_create(["http" => ["timeout" => 10, "ignore_errors" => true]]);
    $body = @file_get_contents(getenv("OLLAMA_MODELS_URL"), false, $context);
    if ($body === false) { fwrite(STDERR, "Ollama /v1/models is unreachable\n"); exit(2); }
    $payload = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
    $ids = array_values(array_filter(array_map(static fn($item) => $item["id"] ?? null, $payload["data"] ?? [])));
    if (!in_array(getenv("OLLAMA_EXPECTED_MODEL"), $ids, true)) {
      fwrite(STDERR, "Expected model is missing. Available: " . implode(",", $ids) . "\n");
      exit(3);
    }
    echo "models=" . count($ids) . " expected=present\n";
  '
}

for command in "$KUBECTL_BIN" "$HELM_BIN" git jq awk openssl tar rg; do
  require_command "$command"
done

[[ -d "$WORKSPACE/charts/typemill" ]] || fail "chart directory not found: ${WORKSPACE}"
[[ $(awk '$1 == "version:" {print $2; exit}' "$WORKSPACE/charts/typemill/Chart.yaml") == "$TARGET_CHART_VERSION" ]] || fail "unexpected target chart version"
[[ $(awk '$1 == "appVersion:" {gsub(/\"/, "", $2); print $2; exit}' "$WORKSPACE/charts/typemill/Chart.yaml") == "$TARGET_APP_VERSION" ]] || fail "unexpected target app version"
rg -q "$TARGET_IMAGE_DIGEST" "$WORKSPACE/charts/typemill/values.yaml" || fail "target image digest is not configured"
rg -q "$MIGRATION_IMAGE_DIGEST" "$WORKSPACE/charts/typemill/values.yaml" || fail "migration image digest changed unexpectedly"

log "Run ID: ${RUN_ID}"
log "Temporary evidence: ${TMP_ROOT}"
log "Checking cluster and internal Ollama endpoint"
kube get --raw=/readyz | grep -qx ok || fail "Kubernetes API is not ready"
kube get endpointslice --namespace suse-private-ai -l kubernetes.io/service-name=suse-ai-ollama -o json | jq -e \
  '[.items[].endpoints[] | select(.conditions.ready == true)] | length > 0' >/dev/null || fail "Ollama has no ready endpoint"

log "Capturing production invariants (read-only)"
production_snapshot "$PROD_BEFORE"

mkdir -p "$BASELINE_ROOT"
git -C "$WORKSPACE" archive --format=tar "$BASELINE_REF" charts/typemill | tar -xf - -C "$BASELINE_ROOT"
[[ $(awk '$1 == "version:" {print $2; exit}' "$BASELINE_ROOT/charts/typemill/Chart.yaml") == "$BASELINE_CHART_VERSION" ]] || fail "unexpected baseline chart version"
[[ $(awk '$1 == "appVersion:" {gsub(/\"/, "", $2); print $2; exit}' "$BASELINE_ROOT/charts/typemill/Chart.yaml") == "$BASELINE_APP_VERSION" ]] || fail "unexpected baseline app version"

log "Creating guarded test namespace ${TEST_NAMESPACE}"
if namespace_exists; then
  fail "refusing to adopt an existing test namespace: ${TEST_NAMESPACE}"
fi
kube create namespace "$TEST_NAMESPACE" --dry-run=client -o json \
  | jq --arg run "$RUN_ID" '.metadata.labels += {
      "app.kubernetes.io/part-of":"typemill-e2e",
      "codex.openai.com/run-id":$run,
      "codex.openai.com/purpose":"v225-v2262"
    }' \
  | kube create -f - >/dev/null
NAMESPACE_UID=$(kube get namespace "$TEST_NAMESPACE" -o jsonpath='{.metadata.uid}')
NAMESPACE_CREATED=true
guard_namespace || fail "new namespace did not pass its guard"

if [[ "$SKIP_SETUP_TEST" != true ]]; then
  log "Fresh v2.26.2 setup probe"
  helm_cluster upgrade --install "$SETUP_RELEASE" "$WORKSPACE/charts/typemill" \
  --namespace "$TEST_NAMESPACE" \
  --wait \
  --timeout 15m \
  --set persistence.storageClass="$STORAGE_CLASS" \
  --set persistence.size="$PVC_SIZE" \
  --set persistence.retain=false \
  --set securityMigrations.cyanineV226.enabled=false \
  --set ai.enabled=false \
  --set tests.enabled=false \
  --set ingress.enabled=false \
  --set-string resources.requests.cpu=50m \
  --set-string resources.requests.memory=128Mi \
  --set-string resources.limits.memory=512Mi

SETUP_PVC=$SETUP_RELEASE
read -r SETUP_PVC_UID SETUP_PV < <(pvc_identity "$SETUP_PVC")
SETUP_PV_UID=$(kube get pv "$SETUP_PV" -o jsonpath='{.metadata.uid}')
SETUP_POD=$(pod_for_release "$SETUP_RELEASE")
guard_pod "$SETUP_POD" "$SETUP_RELEASE" || fail "setup pod guard failed"
[[ $(kube get deployment --namespace "$TEST_NAMESPACE" "$SETUP_RELEASE" -o jsonpath='{.spec.template.spec.containers[0].image}') == "kixote/typemill@${TARGET_IMAGE_DIGEST}" ]] || fail "setup deployment uses an unexpected image"
verify_runtime_image "$SETUP_POD" "$TARGET_IMAGE_DIGEST" "$TARGET_AMD64_DIGEST"

if app_exec "$SETUP_POD" test -e /var/www/html/settings/settings.yaml; then
  fail "fresh setup unexpectedly has settings/settings.yaml"
fi

guard_pod "$SETUP_POD" "$SETUP_RELEASE" || fail "setup pod guard failed before disposable directory removal"
app_exec "$SETUP_POD" rm -rf -- \
  /var/www/html/settings/users \
  /var/www/html/media/tmp \
  /var/www/html/media/original \
  /var/www/html/media/live \
  /var/www/html/media/thumbs \
  /var/www/html/media/custom \
  /var/www/html/media/files

for missing_path in \
  /var/www/html/settings/users \
  /var/www/html/media/tmp \
  /var/www/html/media/original \
  /var/www/html/media/live \
  /var/www/html/media/thumbs \
  /var/www/html/media/custom \
  /var/www/html/media/files; do
  if app_exec "$SETUP_POD" test -e "$missing_path"; then
    fail "disposable setup path was not removed: ${missing_path}"
  fi
done

[[ $(raw_http_code "$SETUP_POD" /tm/setup) == 200 ]] || fail "fresh /tm/setup did not return HTTP 200"

SETUP_PATHS=(
  /var/www/html/settings/users
  /var/www/html/media/tmp
  /var/www/html/media/original
  /var/www/html/media/live
  /var/www/html/media/thumbs
  /var/www/html/media/custom
  /var/www/html/media/files
)
for setup_path in "${SETUP_PATHS[@]}"; do
  metadata=$(app_exec "$SETUP_POD" stat -c '%u:%g|%a' "$setup_path")
  [[ "$metadata" == '33:33|755' ]] || fail "unexpected setup path metadata for ${setup_path}: ${metadata}"
done
app_exec "$SETUP_POD" setpriv --reuid=33 --regid=33 --clear-groups test -w /var/www/html/settings/users

log "Confirming the documented v2.26.2 existing-read-only-directory setup regression"
app_exec "$SETUP_POD" chmod 0555 /var/www/html/settings/users
if app_exec "$SETUP_POD" setpriv --reuid=33 --regid=33 --clear-groups test -w /var/www/html/settings/users; then
  fail "read-only setup directory is unexpectedly writable as UID/GID 33"
fi
REGRESSION_RESULT=$(app_exec "$SETUP_POD" setpriv --reuid=33 --regid=33 --clear-groups php -r '
  require "/var/www/html/system/vendor/autoload.php";
  $storage = new Typemill\Models\StorageWrapper("\\Typemill\\Models\\Storage");
  echo ($storage->checkFolder("settingsFolder", "users") ? "true" : "false") . "|";
  echo ($storage->createFolder("settingsFolder", "users") ? "true" : "false");
')
[[ "$REGRESSION_RESULT" == 'false|true' ]] || fail "setup permission regression changed unexpectedly: ${REGRESSION_RESULT}"
app_exec "$SETUP_POD" chmod 0755 /var/www/html/settings/users

log "Removing the disposable setup release and verifying PVC/PV cleanup"
guard_namespace || fail "namespace guard failed before setup release cleanup"
helm_cluster uninstall "$SETUP_RELEASE" --namespace "$TEST_NAMESPACE" --wait --timeout 5m
wait_for_absence pvc "$SETUP_PVC" namespaced 150 || fail "setup PVC was not deleted"
wait_for_absence pv "$SETUP_PV" cluster 150 || fail "setup PV was not reclaimed"
  log "Setup storage removed: pvc=${SETUP_PVC_UID} pv=${SETUP_PV_UID}"
else
  log "SKIPPED by request: fresh v2.26.2 setup and existing-read-only-directory regression probe"
fi

log "Installing baseline chart ${BASELINE_CHART_VERSION}/${BASELINE_APP_VERSION}"
helm_cluster upgrade --install "$UPGRADE_RELEASE" "$BASELINE_ROOT/charts/typemill" \
  --namespace "$TEST_NAMESPACE" \
  --wait \
  --timeout 15m \
  --set persistence.storageClass="$STORAGE_CLASS" \
  --set persistence.size="$PVC_SIZE" \
  --set persistence.retain=true \
  --set ingress.enabled=false \
  --set-string resources.requests.cpu=50m \
  --set-string resources.requests.memory=128Mi \
  --set-string resources.limits.memory=512Mi

UPGRADE_PVC=$UPGRADE_RELEASE
UPGRADE_IDENTITY_BEFORE=$(pvc_identity "$UPGRADE_PVC")
read -r UPGRADE_PVC_UID UPGRADE_PV <<<"$UPGRADE_IDENTITY_BEFORE"
UPGRADE_PV_UID=$(kube get pv "$UPGRADE_PV" -o jsonpath='{.metadata.uid}')
log "Upgrade storage identity: pvc=${UPGRADE_PVC_UID} pv=${UPGRADE_PV_UID}"
BASELINE_POD=$(pod_for_release "$UPGRADE_RELEASE")
guard_pod "$BASELINE_POD" "$UPGRADE_RELEASE" || fail "baseline pod guard failed"
[[ $(kube get deployment --namespace "$TEST_NAMESPACE" "$UPGRADE_RELEASE" -o jsonpath='{.spec.template.spec.containers[0].image}') == "kixote/typemill@${BASELINE_IMAGE_DIGEST}" ]] || fail "baseline deployment uses an unexpected image"
verify_runtime_image "$BASELINE_POD" "$BASELINE_IMAGE_DIGEST" "$BASELINE_IMAGE_DIGEST"
[[ $(app_exec "$BASELINE_POD" php -r 'echo PHP_VERSION;') == 8.3.* ]] || fail "baseline does not use PHP 8.3"
[[ $(app_exec "$BASELINE_POD" php -r 'require "/var/www/html/system/vendor/autoload.php"; $d=Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/system/typemill/settings/defaults.yaml"); echo $d["version"];') == 2.25.0 ]] || fail "baseline defaults version mismatch"

for index in "${!THEME_PATHS[@]}"; do
  assert_theme_hash "$BASELINE_POD" "${THEME_PATHS[$index]}" "${OLD_THEME_HASH_VALUES[$index]}"
done

log "Writing non-sensitive persistence, security, and custom-theme fixtures to the isolated PVC"
guard_pod "$BASELINE_POD" "$UPGRADE_RELEASE" || fail "baseline pod guard failed before fixture write"
app_exec "$BASELINE_POD" env TYPEMILL_E2E_RUN_ID="$RUN_ID" php -r '
  require "/var/www/html/system/vendor/autoload.php";
  $run = getenv("TYPEMILL_E2E_RUN_ID");
  $yaml = Symfony\Component\Yaml\Yaml::dump([
    "title" => "Typemill E2E",
    "author" => "E2E",
    "language" => "en",
    "access" => true,
    "proxy" => false
  ], 5, 2);
  file_put_contents("/var/www/html/settings/settings.yaml", $yaml);
  foreach (["settings", "content", "media", "plugins", "themes", "data", "cache"] as $root) {
    $path = "/var/www/html/{$root}/.typemill-e2e-marker";
    file_put_contents($path, "{$root}|{$run}\n");
  }
  if (!is_dir("/var/www/html/media/files")) { mkdir("/var/www/html/media/files", 0755, true); }
  file_put_contents("/var/www/html/media/files/e2e-protected.pdf", "protected|{$run}\n");
  file_put_contents(
    "/var/www/html/media/files/filerestrictions.yaml",
    Symfony\Component\Yaml\Yaml::dump(["media/files/e2e-protected.pdf" => "member"], 3, 2)
  );
  file_put_contents("/var/www/html/themes/cyanine/cyanine.yaml", "\n# typemill-e2e-custom {$run}\n", FILE_APPEND);
'

MARKERS_BEFORE=$(marker_hashes "$BASELINE_POD")
CUSTOM_CYANINE_HASH=$(theme_hash "$BASELINE_POD" cyanine.yaml)
[[ "$CUSTOM_CYANINE_HASH" != "${OLD_THEME_HASH_VALUES[4]}" ]] || fail "Cyanine customization fixture did not change the hash"

BASELINE_NORMAL_CODE=$(raw_http_code "$BASELINE_POD" /media/files/e2e-protected.pdf)
BASELINE_BYPASS_CODE=$(raw_http_code "$BASELINE_POD" /media/files//e2e-protected.pdf)
log "Baseline media responses: normal=${BASELINE_NORMAL_CODE} path-equivalent=${BASELINE_BYPASS_CODE}"
[[ "$BASELINE_NORMAL_CODE" == 302 ]] || fail "baseline protected media path should redirect anonymous users"
[[ "$BASELINE_BYPASS_CODE" == 200 ]] || fail "baseline path-equivalence bypass was not reproduced"

log "Upgrading the same PVC to ${TARGET_CHART_VERSION}/${TARGET_APP_VERSION}"
helm_cluster upgrade "$UPGRADE_RELEASE" "$WORKSPACE/charts/typemill" \
  --namespace "$TEST_NAMESPACE" \
  --reset-values \
  --wait \
  --timeout 15m \
  --set persistence.storageClass="$STORAGE_CLASS" \
  --set persistence.size="$PVC_SIZE" \
  --set persistence.retain=true \
  --set securityMigrations.cyanineV226.enabled=true \
  --set securityMigrations.cyanineV226.failOnModified=false \
  --set ai.enabled=true \
  --set ai.adapter=openai \
  --set-string ai.baseUrl="$OLLAMA_BASE_URL" \
  --set-string ai.model="$OLLAMA_MODEL" \
  --set-string ai.providerName=Ollama \
  --set-string ai.providerTerms= \
  --set ai.timeoutSeconds=180 \
  --set-string ai.reasoningEffort= \
  --set typemill.proxyDetection=false \
  --set tests.enabled=true \
  --set ingress.enabled=false \
  --set-string resources.requests.cpu=50m \
  --set-string resources.requests.memory=128Mi \
  --set-string resources.limits.memory=512Mi

TARGET_POD=$(pod_for_release "$UPGRADE_RELEASE")
guard_pod "$TARGET_POD" "$UPGRADE_RELEASE" || fail "target pod guard failed"
[[ $(kube get deployment --namespace "$TEST_NAMESPACE" "$UPGRADE_RELEASE" -o jsonpath='{.spec.template.spec.containers[0].image}') == "kixote/typemill@${TARGET_IMAGE_DIGEST}" ]] || fail "target deployment uses an unexpected image"
[[ $(kube get deployment --namespace "$TEST_NAMESPACE" "$UPGRADE_RELEASE" -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="cyanine-v226-security-migration")].image}') == "kixote/typemill@${MIGRATION_IMAGE_DIGEST}" ]] || fail "migration source image changed unexpectedly"
verify_runtime_image "$TARGET_POD" "$TARGET_IMAGE_DIGEST" "$TARGET_AMD64_DIGEST"
[[ $(app_exec "$TARGET_POD" php -r 'echo PHP_VERSION;') == 8.5.* ]] || fail "target does not use PHP 8.5"
[[ $(app_exec "$TARGET_POD" php -r 'require "/var/www/html/system/vendor/autoload.php"; $d=Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/system/typemill/settings/defaults.yaml"); echo $d["version"];') == 2.26.2 ]] || fail "target defaults version mismatch"
[[ $(kube get deployment --namespace "$TEST_NAMESPACE" "$UPGRADE_RELEASE" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="TYPEMILL_PROXY_DETECTION")].value}') == false ]] || fail "proxy detection is not fail-closed"
[[ -z $(kube get ingress --namespace "$TEST_NAMESPACE" -o name) ]] || fail "isolated test unexpectedly created an Ingress"

MIGRATION_LOG=$(kube logs --namespace "$TEST_NAMESPACE" "$TARGET_POD" --container cyanine-v226-security-migration)
printf '%s\n' "$MIGRATION_LOG"
[[ $(grep -c 'Cyanine v2.26 migration: updated ' <<<"$MIGRATION_LOG") -eq 4 ]] || fail "expected four stock Cyanine files to be updated"
[[ $(grep -c 'preserving customized cyanine.yaml' <<<"$MIGRATION_LOG") -eq 1 ]] || fail "expected exactly one custom Cyanine warning"

for index in "${!NEW_THEME_HASH_VALUES[@]}"; do
  assert_theme_hash "$TARGET_POD" "${THEME_PATHS[$index]}" "${NEW_THEME_HASH_VALUES[$index]}"
done
assert_theme_hash "$TARGET_POD" cyanine.yaml "$CUSTOM_CYANINE_HASH"

UPGRADE_IDENTITY_AFTER=$(pvc_identity "$UPGRADE_PVC")
[[ "$UPGRADE_IDENTITY_AFTER" == "$UPGRADE_IDENTITY_BEFORE" ]] || fail "PVC/PV identity changed during upgrade"
[[ $(marker_hashes "$TARGET_POD") == "$MARKERS_BEFORE" ]] || fail "one or more persistence markers changed during upgrade"

TARGET_NORMAL_CODE=$(raw_http_code "$TARGET_POD" /media/files/e2e-protected.pdf)
TARGET_BYPASS_CODE=$(raw_http_code "$TARGET_POD" /media/files//e2e-protected.pdf)
log "Target media responses: normal=${TARGET_NORMAL_CODE} path-equivalent=${TARGET_BYPASS_CODE}"
[[ "$TARGET_NORMAL_CODE" == 302 ]] || fail "target protected media path should redirect anonymous users"
[[ "$TARGET_BYPASS_CODE" == 302 ]] || fail "target did not close the path-equivalence media bypass"
TRAVERSAL_CODE=$(raw_http_code "$TARGET_POD" '/media/files/%2e%2e/e2e-protected.pdf')
[[ "$TRAVERSAL_CODE" == 400 || "$TRAVERSAL_CODE" == 404 ]] || fail "unexpected traversal response: ${TRAVERSAL_CODE}"

verify_ai_settings "$TARGET_POD"
verify_ollama "$TARGET_POD"

log "Running the packaged Helm connectivity test"
helm_cluster test "$UPGRADE_RELEASE" --namespace "$TEST_NAMESPACE" --logs --timeout 10m

log "Restarting the isolated deployment to verify migration idempotence and PVC stability"
kube rollout restart deployment "$UPGRADE_RELEASE" --namespace "$TEST_NAMESPACE"
kube rollout status deployment "$UPGRADE_RELEASE" --namespace "$TEST_NAMESPACE" --timeout 15m
RESTARTED_POD=$(pod_for_release "$UPGRADE_RELEASE")
guard_pod "$RESTARTED_POD" "$UPGRADE_RELEASE" || fail "restarted pod guard failed"

RESTART_LOG=$(kube logs --namespace "$TEST_NAMESPACE" "$RESTARTED_POD" --container cyanine-v226-security-migration)
printf '%s\n' "$RESTART_LOG"
[[ $(grep -c 'Cyanine v2.26 migration: updated ' <<<"$RESTART_LOG" || true) -eq 0 ]] || fail "idempotent restart replaced files again"
[[ $(grep -c 'is already current' <<<"$RESTART_LOG") -eq 4 ]] || fail "expected four already-current Cyanine files after restart"
[[ $(grep -c 'preserving customized cyanine.yaml' <<<"$RESTART_LOG") -eq 1 ]] || fail "custom Cyanine warning changed after restart"

[[ $(pvc_identity "$UPGRADE_PVC") == "$UPGRADE_IDENTITY_BEFORE" ]] || fail "PVC/PV identity changed after restart"
[[ $(marker_hashes "$RESTARTED_POD") == "$MARKERS_BEFORE" ]] || fail "persistence markers changed after restart"
for index in "${!NEW_THEME_HASH_VALUES[@]}"; do
  assert_theme_hash "$RESTARTED_POD" "${THEME_PATHS[$index]}" "${NEW_THEME_HASH_VALUES[$index]}"
done
assert_theme_hash "$RESTARTED_POD" cyanine.yaml "$CUSTOM_CYANINE_HASH"
verify_ai_settings "$RESTARTED_POD"
verify_ollama "$RESTARTED_POD"
[[ $(raw_http_code "$RESTARTED_POD" /media/files//e2e-protected.pdf) == 302 ]] || fail "media protection changed after restart"

log "Uninstalling target release; retained PVC must remain until namespace cleanup"
guard_namespace || fail "namespace guard failed before final uninstall"
helm_cluster uninstall "$UPGRADE_RELEASE" --namespace "$TEST_NAMESPACE" --wait --timeout 5m
kube get pvc --namespace "$TEST_NAMESPACE" "$UPGRADE_PVC" >/dev/null || fail "retained PVC disappeared during Helm uninstall"
[[ $(pvc_identity "$UPGRADE_PVC") == "$UPGRADE_IDENTITY_BEFORE" ]] || fail "retained PVC identity changed after Helm uninstall"

log "Deleting the exact guarded namespace and waiting for Longhorn PV reclamation"
guard_namespace || fail "namespace guard failed before final namespace cleanup"
kube delete namespace "$TEST_NAMESPACE" --wait=false
wait_for_absence namespace "$TEST_NAMESPACE" cluster 300 || fail "test namespace was not deleted"
wait_for_absence pv "$UPGRADE_PV" cluster 300 || fail "upgrade PV was not reclaimed"
NAMESPACE_CREATED=false
EXPLICIT_CLEANUP_DONE=true

log "Capturing production invariants after isolated cleanup"
production_snapshot "$PROD_AFTER"
if ! diff -u "$PROD_BEFORE" "$PROD_AFTER"; then
  fail "production deployment/PVC invariants changed during the isolated test"
fi

if [[ "$SKIP_SETUP_TEST" == true ]]; then
  log "PASS: v2.25→v2.26.2 upgrade, PVC, media security, Cyanine, AI/Ollama, restart, Helm test, production invariants, and cleanup (fresh setup/read-only regression skipped by request)"
else
  log "PASS: fresh setup, v2.25→v2.26.2 upgrade, PVC, media security, Cyanine, AI/Ollama, restart, Helm test, production invariants, and cleanup"
fi
log "Evidence directory: ${TMP_ROOT}"
