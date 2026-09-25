#!/usr/bin/env bash
# Isolated upgrade regression; creates and removes only a unique test namespace.
# Embedded PHP variables must not be expanded by the local shell.
# shellcheck disable=SC2016
set -Eeuo pipefail
umask 077

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KUBE_CONFIG=${KUBE_CONFIG:-$HOME/.kube/configs/suseai.yaml}
HELM_BIN=${HELM_BIN:-helm}
STORAGE_CLASS=${STORAGE_CLASS:-longhorn}
RUN_ID="$(date -u +%Y%m%d%H%M%S)-$(openssl rand -hex 3)"
TEST_NS="typemill-v227-e2e-$RUN_ID"
RELEASE=typemill-upgrade
WORK=$(mktemp -d /tmp/typemill-v227-e2e.XXXXXX)
NS_UID=
PVC_UID=
PVC_NAME=
PV_NAME=
TARGET_INDEX=sha256:7dfb517d24f0c3b430f6f1bdf4b62e585aebd695dc6d18febc23e18674e945c4
TARGET_AMD64=sha256:5cdd75c655447c0e7c3676e7999c0e7643d01a720a356d79748466a12ead586b

k() { kubectl --kubeconfig "$KUBE_CONFIG" --request-timeout=30s "$@"; }
h() { "$HELM_BIN" --kubeconfig "$KUBE_CONFIG" "$@"; }
log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
fail() { log "FAIL: $*"; exit 1; }

guard_namespace() {
  local current
  [[ "$TEST_NS" =~ ^typemill-v227-e2e-[0-9]{14}-[a-f0-9]{6}$ && -n "$NS_UID" ]] || return 1
  current=$(k get namespace "$TEST_NS" -o json) || return 1
  jq -e --arg uid "$NS_UID" --arg run "$RUN_ID" \
    '.metadata.uid == $uid and .metadata.labels["typemill-e2e/run-id"] == $run' \
    <<<"$current" >/dev/null
}

cleanup() {
  local result=$? current_pvc remaining
  trap - EXIT HUP INT TERM
  set +e
  if [[ -n "$NS_UID" ]]; then
    if ! guard_namespace; then
      log "Cleanup refused: namespace identity changed or could not be verified ($TEST_NS)"
      exit 1
    fi
    if [[ "$result" -ne 0 ]]; then
      k get pods,pvc --namespace "$TEST_NS" -o wide
      k get events --namespace "$TEST_NS" --sort-by=.lastTimestamp
      k logs --namespace "$TEST_NS" -l "app.kubernetes.io/instance=$RELEASE" -c typemill --tail=50
    fi
    if [[ -n "$PVC_UID" ]]; then
      current_pvc=$(k get pvc "$PVC_NAME" --namespace "$TEST_NS" --ignore-not-found -o json) || {
        log "Cleanup refused: could not verify the test PVC"
        exit 1
      }
      if [[ -n "$current_pvc" ]] && [[ $(jq -r '.metadata.uid' <<<"$current_pvc") != "$PVC_UID" ]]; then
        log "Cleanup refused: test PVC identity changed ($TEST_NS/$PVC_NAME)"
        exit 1
      fi
    fi
    log "Removing UID-verified namespace $TEST_NS (including its test PVC)"
    k delete namespace "$TEST_NS" --wait=true --timeout=180s || result=1
    if [[ -n "$PV_NAME" ]]; then
      k wait --for=delete "pv/$PV_NAME" --timeout=180s || result=1
      remaining=$(k get pv "$PV_NAME" --ignore-not-found -o name) || result=1
      [[ -z "$remaining" ]] || result=1
    fi
  fi
  log "Result=$result; local evidence: $WORK"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

pod_name() {
  k get pods --namespace "$TEST_NS" -l "app.kubernetes.io/instance=$RELEASE" -o json |
    jq -er '[.items[] | select(.metadata.deletionTimestamp == null and .status.phase == "Running")][0].metadata.name'
}
x() { k exec --namespace "$TEST_NS" "$POD" -c typemill -- "$@"; }
http_code() {
  x php -r '
    $ch = curl_init("http://127.0.0.1" . $argv[1]);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_FOLLOWLOCATION => false,
      CURLOPT_PATH_AS_IS => true, CURLOPT_TIMEOUT => 10]);
    if (curl_exec($ch) === false) { fwrite(STDERR, curl_error($ch)); exit(1); }
    echo curl_getinfo($ch, CURLINFO_HTTP_CODE);
  ' "$1"
}
theme_hashes() {
  x sh -ec 'cd /var/www/html/themes/cyanine; sha256sum blog.twig home/landingpageNews.twig landingpage.twig partials/posts.twig cyanine.yaml'
}
check_state() {
  [[ $(x php -r 'echo getenv("TYPEMILL_PROXY_DETECTION");') == false ]] || fail "proxy default changed"
  [[ $(http_code /tm/login) == 200 ]] || fail "login unhealthy"
  x env E2E_RUN_ID="$RUN_ID" sh -ec '
    for directory in settings media cache plugins data content themes; do
      test "$(cat "/var/www/html/$directory/.v227-marker")" = "$E2E_RUN_ID:$directory"
    done
  '
  x php -r '
    require "/var/www/html/system/vendor/autoload.php";
    $s = Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/settings/settings.yaml");
    foreach (["ai_adapter" => "openai-responses", "ai_base_url" => "http://127.0.0.1:9/v1",
      "ai_model" => "e2e-no-provider-call", "aitemperature" => "", "aioutputtoken" => "128000"] as $k => $v) {
      if (!array_key_exists($k, $s) || $s[$k] !== $v) { fwrite(STDERR, "Unexpected setting: $k\n"); exit(1); }
    }
    $secret = Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/settings/secrets.yaml") ?? [];
    foreach (["ai_api_key", "chatgptKey", "claudeKey"] as $key) {
      if (array_key_exists($key, $secret)) { exit(1); }
    }
    echo "AI settings and secret-free bootstrap verified\n";
  '
}

log "Evidence directory: $WORK"
mkdir -p "$WORK/baseline"
git -C "$REPO" archive typemill-2.2.0 charts/typemill | tar -x -C "$WORK/baseline"
[[ $("$HELM_BIN" show chart "$WORK/baseline/charts/typemill" | awk '$1 == "appVersion:" {gsub(/"/, "", $2); print $2}') == v2.26.2 ]] || fail "incorrect baseline"
[[ $("$HELM_BIN" show chart "$REPO/charts/typemill" | awk '$1 == "appVersion:" {gsub(/"/, "", $2); print $2}') == v2.27.0 ]] || fail "incorrect target"
[[ -z $(k get namespace "$TEST_NS" --ignore-not-found -o name) ]] || fail "test namespace already exists"
NS_UID=$(jq -n --arg ns "$TEST_NS" --arg run "$RUN_ID" \
  '{apiVersion:"v1",kind:"Namespace",metadata:{name:$ns,labels:{"typemill-e2e/run-id":$run}}}' |
  k create -f - -o jsonpath='{.metadata.uid}')
guard_namespace || fail "namespace identity not recorded"

log "Installing baseline Chart 2.2.0 / Typemill v2.26.2"
h install "$RELEASE" "$WORK/baseline/charts/typemill" --namespace "$TEST_NS" \
  --set persistence.storageClass="$STORAGE_CLASS" --set persistence.size=1Gi \
  --set 'nodeSelector.kubernetes\.io/arch=amd64' \
  --set ai.enabled=true --set ai.baseUrl=http://127.0.0.1:9/v1 \
  --set ai.model=e2e-no-provider-call --wait --timeout=8m
POD=$(pod_name)
PVC_NAME=$(k get pvc --namespace "$TEST_NS" -o json | jq -er '.items[0].metadata.name')
PVC_UID=$(k get pvc "$PVC_NAME" --namespace "$TEST_NS" -o jsonpath='{.metadata.uid}')
PV_NAME=$(k get pvc "$PVC_NAME" --namespace "$TEST_NS" -o jsonpath='{.spec.volumeName}')
DEPLOYMENT=$(k get deployment --namespace "$TEST_NS" -o jsonpath='{.items[0].metadata.name}')
[[ $(x php -r 'require "/var/www/html/system/vendor/autoload.php"; echo Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/system/typemill/settings/defaults.yaml")["version"];') == 2.26.2 ]] || fail "baseline version mismatch"
log "Baseline runtime: $(x php -r 'echo PHP_VERSION;')"
# As in the previous media regression, enable frontend sessions for the flash
# message/login redirect used by protected downloads; preserve AI bootstrap values.
x php -r '
  require "/var/www/html/system/vendor/autoload.php";
  $path = "/var/www/html/settings/settings.yaml";
  $settings = Symfony\Component\Yaml\Yaml::parseFile($path);
  $settings = array_merge($settings, ["title" => "Typemill E2E", "author" => "E2E",
    "language" => "en", "access" => true, "proxy" => false]);
  file_put_contents($path, Symfony\Component\Yaml\Yaml::dump($settings, 5, 2));
'
x env E2E_RUN_ID="$RUN_ID" sh -ec '
  for directory in settings media cache plugins data content themes; do
    printf "%s:%s\n" "$E2E_RUN_ID" "$directory" > "/var/www/html/$directory/.v227-marker"
  done
  printf "%s\n" "$E2E_RUN_ID" > /var/www/html/media/files/v227-protected.pdf
  printf "\nmedia/files/v227-protected.pdf: member\n" >> /var/www/html/media/files/filerestrictions.yaml
  ln -s v227-protected.pdf /var/www/html/media/files/v227-alias.pdf
'
BASELINE_THEMES=$(theme_hashes)
BASELINE_NORMAL=$(http_code /media/files/v227-protected.pdf)
BASELINE_ALIAS=$(http_code /media/files/v227-alias.pdf)
log "Baseline media: protected=$BASELINE_NORMAL, symlink=$BASELINE_ALIAS"
[[ "$BASELINE_NORMAL" == 302 ]] || fail "baseline restriction missing"
[[ "$BASELINE_ALIAS" == 200 ]] || fail "baseline symlink regression fixture not effective"

log "Upgrading to Chart 2.3.0 / v2.27.0 with Responses adapter, empty temperature and 128000 tokens"
h upgrade "$RELEASE" "$REPO/charts/typemill" --namespace "$TEST_NS" \
  --reset-then-reuse-values --set ai.adapter=openai-responses \
  --set-string ai.temperature= --set ai.outputTokens=128000 --wait --timeout=8m
POD=$(pod_name)
[[ $(k get pvc "$PVC_NAME" --namespace "$TEST_NS" -o jsonpath='{.metadata.uid}') == "$PVC_UID" ]] || fail "PVC replaced"
[[ $(k get pvc "$PVC_NAME" --namespace "$TEST_NS" -o jsonpath='{.spec.volumeName}') == "$PV_NAME" ]] || fail "PV replaced"
[[ $(x php -r 'require "/var/www/html/system/vendor/autoload.php"; echo Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/system/typemill/settings/defaults.yaml")["version"];') == 2.27.0 ]] || fail "target version mismatch"
RUNTIME=$(x php -r 'echo PHP_VERSION;')
[[ "$RUNTIME" == 8.5.* ]] || fail "unexpected PHP runtime $RUNTIME"
log "Target runtime: PHP $RUNTIME"
POD_JSON=$(k get pod "$POD" --namespace "$TEST_NS" -o json)
log "Runtime imageID: $(jq -r '.status.containerStatuses[0].imageID' <<<"$POD_JSON")"
# containerd can report either the pinned OCI index or its amd64 manifest.
jq -e --arg index "$TARGET_INDEX" --arg child "$TARGET_AMD64" '
  .spec.containers[0].image == ("kixote/typemill@" + $index) and
  (.status.containerStatuses[0].imageID | (endswith($child) or endswith($index))) and
  ([.status.initContainerStatuses[].state.terminated.exitCode] | length == 2 and all(. == 0))
' <<<"$POD_JSON" >/dev/null || fail "unexpected image digest or init-container status"
[[ $(theme_hashes) == "$BASELINE_THEMES" ]] || fail "current Cyanine files changed"
check_state
[[ $(http_code /media/files/v227-protected.pdf) == 302 ]] || fail "normal media restriction missing"
[[ $(http_code /media/files/%76%32%32%37-protected.pdf) == 302 ]] || fail "encoded media restriction missing"
[[ $(http_code /media/files/v227-alias.pdf) == 404 ]] || fail "symlink bypass not blocked"
log "Media checks passed: protected=302, encoded=302, symlink=404 (baseline symlink=200)"
k logs "$POD" --namespace "$TEST_NS" -c cyanine-v226-security-migration

log "Restarting and verifying retained state"
k rollout restart "deployment/$DEPLOYMENT" --namespace "$TEST_NS"
k rollout status "deployment/$DEPLOYMENT" --namespace "$TEST_NS" --timeout=8m
POD=$(pod_name)
check_state
[[ $(theme_hashes) == "$BASELINE_THEMES" ]] || fail "theme changed after restart"
h test "$RELEASE" --namespace "$TEST_NS" --logs --timeout=3m
h list --namespace "$TEST_NS" -o json |
  jq -e '.[0].chart == "typemill-2.3.0" and .[0].app_version == "v2.27.0" and .[0].status == "deployed"' >/dev/null
log "PASS: upgrade, runtime, image, PVC/PV, seven paths, AI settings, media authorization, migration idempotence and Helm test"
