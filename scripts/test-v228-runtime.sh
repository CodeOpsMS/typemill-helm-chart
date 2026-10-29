#!/usr/bin/env bash
# Version-specific regression in an isolated kind namespace, never production.
# shellcheck disable=SC2016
set -Eeuo pipefail
umask 077

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONTEXT=$(kubectl config current-context)
[[ "$CONTEXT" == kind-* ]] || { echo "Refusing non-kind context: $CONTEXT" >&2; exit 1; }
WORK=$(mktemp -d)
NS="typemill-v228-$(openssl rand -hex 6)"
NS_UID=
RELEASE=
TARGET=sha256:dc92861ac28b6507ebc3a449430e77da1127de06371f73a15a73d7408b2ced32
CHILD=sha256:70763dd1b69326f51ca948c253beb61f47e97ed9644ac6b02f27f722d5a165ba
k() { kubectl --context "$CONTEXT" --namespace "$NS" --request-timeout=30s "$@"; }
h() { helm --kube-context "$CONTEXT" --namespace "$NS" "$@"; }
x() { k exec "deployment/$RELEASE" -c typemill -- "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

cleanup() {
  local result=$?
  trap - EXIT
  if [[ -n "$NS_UID" ]]; then
    if [[ $(k get namespace "$NS" -o jsonpath='{.metadata.uid}') != "$NS_UID" ]]; then
      echo "Refusing cleanup: namespace identity changed" >&2
      exit 1
    fi
    if [[ "$result" != 0 ]]; then
      k get pods,pvc -o wide || true
      k get events --sort-by=.lastTimestamp || true
      k logs "deployment/$RELEASE" -c cyanine-v226-security-migration --tail=50 || true
      k logs "deployment/$RELEASE" -c typemill --tail=50 || true
    fi
    k delete namespace "$NS" --wait=true --timeout=120s || result=1
  fi
  rm -rf -- "$WORK"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

theme_hashes() {
  x sh -ec 'cd /var/www/html/themes; find cyanine -type f -exec sha256sum {} \; | sort'
}
initialize_fixture() {
  # A site without settings correctly redirects every route to /tm/setup.
  # Seed only this disposable test site so HTTP checks exercise real templates,
  # not a successful setup redirect. No credentials or external services needed.
  x php -r '
    require "/var/www/html/system/vendor/autoload.php";
    $path = "/var/www/html/settings/settings.yaml";
    $settings = ["title" => "Typemill CI", "author" => "CI",
      "language" => "en", "theme" => "cyanine", "proxy" => false,
      "displayErrorDetails" => true];
    if (file_put_contents($path, Symfony\Component\Yaml\Yaml::dump($settings)) === false) { exit(1); }
    chown($path, 33);
    chgrp($path, 33);
  '
}
check_runtime() {
  x php -r '
    require "/var/www/html/system/vendor/autoload.php";
    $v = Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/system/typemill/settings/defaults.yaml")["version"];
    echo "Runtime: Typemill $v, PHP " . PHP_VERSION . "\n";
    if ($v !== "2.28.0" || PHP_VERSION !== "8.5.12") { exit(1); }
    if (hash_file("sha256", "/var/www/html/system/typemill/Models/Settings.php") !==
        "f273572502d6960d4cf45f6a123bce3585e630187918c1d69e77285eca5efe87") { exit(1); }
    if (getenv("TYPEMILL_PROXY_DETECTION") !== "false") { exit(1); }
    foreach (["/tm/login", "/"] as $path) {
      $ch = curl_init("http://127.0.0.1" . $path);
      curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 15]);
      $body = curl_exec($ch);
      $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
      echo "$path: HTTP $status\n";
      if ($body === false || $status !== 200) {
        fwrite(STDERR, substr(strip_tags((string) $body), 0, 4000) . "\n");
        exit(1);
      }
      if (preg_match("/Fatal error|Uncaught .*Exception/", $body)) { exit(1); }
    }
    echo "Typemill $v, PHP " . PHP_VERSION . ", login/homepage and proxy default verified\n";
  '
  k get pods -l "app.kubernetes.io/instance=$RELEASE" -o json |
    jq -e --arg index "$TARGET" --arg child "$CHILD" '
      [.items[] | select(.metadata.deletionTimestamp == null and
        any(.spec.containers[]; .name == "typemill"))] | length == 1 and all(.[];
        .spec.containers[0].image == ("kixote/typemill@" + $index) and
        (.status.containerStatuses[0].imageID | endswith($index) or endswith($child)) and
        ([.status.initContainerStatuses[]?.state.terminated.exitCode] | all(. == 0)))
    ' >/dev/null
}
restart() {
  k rollout restart "deployment/$RELEASE"
  k rollout status "deployment/$RELEASE" --timeout=300s
  check_runtime
}

[[ $(helm show chart "$ROOT/charts/typemill" | awk '$1 == "appVersion:" {gsub(/"/, "", $2); print $2}') == v2.28.0 ]] || fail "wrong target"
mkdir -p "$WORK/baseline"
git -C "$ROOT" archive typemill-2.3.1 charts/typemill | tar -x -C "$WORK/baseline"
NS_UID=$(k create namespace "$NS" -o jsonpath='{.metadata.uid}')
COMMON=(--set persistence.size=1Gi --set persistence.retain=false
  --set securityMigrations.cyanineV226.failOnModified=true
  --set 'nodeSelector.kubernetes\.io/arch=amd64' --wait --timeout=300s)

echo "Testing 2.27.1 -> 2.28.0 with persisted stock themes and strict migration"
RELEASE=upgrade
h install "$RELEASE" "$WORK/baseline/charts/typemill" --set fullnameOverride="$RELEASE" "${COMMON[@]}"
initialize_fixture
CONFIG_BEFORE=$(x sha256sum /var/www/html/settings/settings.yaml)
PVC_UID=$(k get pvc "$RELEASE" -o jsonpath='{.metadata.uid}')
BEFORE=$(theme_hashes)
x sh -ec 'for d in settings media cache plugins data content themes; do touch "/var/www/html/$d/.v228-marker"; done'
h upgrade "$RELEASE" "$ROOT/charts/typemill" --reset-then-reuse-values --wait --timeout=300s
check_runtime
restart
[[ $(k get pvc "$RELEASE" -o jsonpath='{.metadata.uid}') == "$PVC_UID" ]] || fail "PVC replaced"
[[ $(theme_hashes) == "$BEFORE" ]] || fail "persisted theme changed"
[[ $(x sha256sum /var/www/html/settings/settings.yaml) == "$CONFIG_BEFORE" ]] || fail "persisted configuration changed"
x sh -ec 'for d in settings media cache plugins data content themes; do test -f "/var/www/html/$d/.v228-marker"; done'
h test "$RELEASE" --logs --timeout=120s

echo "Testing fresh Cyanine 2.5.0 and strict-mode restart"
RELEASE=fresh
h install "$RELEASE" "$ROOT/charts/typemill" --set fullnameOverride="$RELEASE" "${COMMON[@]}"
# The workaround must not create settings.yaml and bypass the real setup wizard.
x php -r '
  if (file_exists("/var/www/html/settings/settings.yaml")) { exit(1); }
  foreach (["/tm/login" => 302, "/tm/setup" => 200] as $path => $expected) {
    $ch = curl_init("http://127.0.0.1" . $path);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 15]);
    if (curl_exec($ch) === false || curl_getinfo($ch, CURLINFO_HTTP_CODE) !== $expected) { exit(1); }
  }
  echo "Fresh setup wizard preserved; settings.yaml was not pre-created\n";
'
initialize_fixture
CONFIG_BEFORE=$(x sha256sum /var/www/html/settings/settings.yaml)
check_runtime
BEFORE=$(theme_hashes)
restart
[[ $(theme_hashes) == "$BEFORE" ]] || fail "new stock theme changed"
[[ $(x sha256sum /var/www/html/settings/settings.yaml) == "$CONFIG_BEFORE" ]] || fail "fresh configuration changed"
LOGS=$(k logs "deployment/$RELEASE" -c cyanine-v226-security-migration)
[[ $(printf '%s\n' "$LOGS" | grep -c 'matches reviewed v2.27.1 stock') == 3 ]] || fail "new hashes not recognized"
[[ "$LOGS" != *WARNING* ]] || fail "unexpected stock warning"
h test "$RELEASE" --logs --timeout=120s

echo "Testing saved theme settings, workaround idempotence and unknown-code rejection"
x php -r '
  require "/var/www/html/system/vendor/autoload.php";
  $path = "/var/www/html/settings/settings.yaml";
  $settings = Symfony\Component\Yaml\Yaml::parseFile($path);
  $settings["themes"]["cyanine"] = ["landingpage" => true, "introPosition" => "1",
    "introTitle" => "Retained CI theme title"];
  file_put_contents($path, Symfony\Component\Yaml\Yaml::dump($settings, 5));
'
CONFIG_BEFORE=$(x sha256sum /var/www/html/settings/settings.yaml)
restart
[[ $(x sha256sum /var/www/html/settings/settings.yaml) == "$CONFIG_BEFORE" ]] || fail "custom theme configuration changed"
x php -r '
  $body = file_get_contents("http://127.0.0.1/");
  if (!str_contains($body, "Retained CI theme title")) { exit(1); }
'
PATCH_SCRIPT="$ROOT/charts/typemill/files/cyanine-v2271-fallback.php"
k exec -i "deployment/$RELEASE" -c typemill -- php <"$PATCH_SCRIPT"
check_runtime
x sh -ec 'cp /var/www/html/system/typemill/Models/Settings.php /tmp/v2271-settings-original; printf "\n// custom\n" >> /var/www/html/system/typemill/Models/Settings.php'
CUSTOM_CODE=$(x sha256sum /var/www/html/system/typemill/Models/Settings.php)
if k exec -i "deployment/$RELEASE" -c typemill -- php <"$PATCH_SCRIPT" >"$WORK/unknown-code.log" 2>&1; then
  fail "workaround accepted unknown application code"
fi
grep -q 'unrecognized Settings.php; refusing to modify custom code' "$WORK/unknown-code.log" || fail "wrong code rejection reason"
[[ $(x sha256sum /var/www/html/system/typemill/Models/Settings.php) == "$CUSTOM_CODE" ]] || fail "custom application code overwritten"
x php -r '
  $path = "/var/www/html/system/typemill/settings/defaults.yaml";
  copy($path, "/tmp/v228-defaults-original");
  $source = file_get_contents($path);
  $updated = str_replace("2.28.0", "2.29.0", $source, $count);
  if ($count !== 1 || file_put_contents($path, $updated) === false) { exit(1); }
'
k exec -i "deployment/$RELEASE" -c typemill -- php <"$PATCH_SCRIPT" >"$WORK/future-version.log" 2>&1
grep -q 'leaving application code unchanged' "$WORK/future-version.log" || fail "runtime version guard missing"
[[ $(x sha256sum /var/www/html/system/typemill/Models/Settings.php) == "$CUSTOM_CODE" ]] || fail "unsupported application code overwritten"
x sh -ec 'cp /tmp/v228-defaults-original /var/www/html/system/typemill/settings/defaults.yaml'
x sh -ec 'cp /tmp/v2271-settings-original /var/www/html/system/typemill/Models/Settings.php'

# Execute the rendered migration against a modified test theme. All mutation is
# confined to this disposable namespace; the migration itself must not change it.
MIGRATION=$(k get deployment "$RELEASE" -o json | jq -r '.spec.template.spec.initContainers[0].command[2]' |
  sed 's|/work/themes|/var/www/html/themes|g')
for relative in home/landingpageNews.twig partials/posts.twig cyanine.yaml; do
  x sh -ec 'cp "/var/www/html/themes/cyanine/$1" /tmp/v2271-original; printf "\n# custom\n" >> "/var/www/html/themes/cyanine/$1"' sh "$relative"
  CUSTOM=$(theme_hashes)
  if x env TYPEMILL_FAIL_ON_MODIFIED=true sh -ec "$MIGRATION" >"$WORK/custom.log" 2>&1; then
    fail "strict migration accepted customized $relative"
  fi
  grep -q "preserving customized $relative" "$WORK/custom.log" || fail "wrong rejection reason"
  [[ $(theme_hashes) == "$CUSTOM" ]] || fail "custom file overwritten"
  x sh -ec 'cp /tmp/v2271-original "/var/www/html/themes/cyanine/$1"; chown 33:33 "/var/www/html/themes/cyanine/$1"' sh "$relative"
done
[[ $(theme_hashes) == "$BEFORE" ]] || fail "fixture restoration failed"
echo "Testing a fresh installation without persistence"
RELEASE=ephemeral
h install "$RELEASE" "$ROOT/charts/typemill" --set fullnameOverride="$RELEASE" \
  --set persistence.enabled=false "${COMMON[@]}"
x test ! -e /var/www/html/settings/settings.yaml
initialize_fixture
check_runtime
h test "$RELEASE" --logs --timeout=120s

echo "Testing the yq AI bootstrap and repeated startup"
RELEASE=ai-bootstrap
h install "$RELEASE" "$ROOT/charts/typemill" --set fullnameOverride="$RELEASE" \
  --set ai.enabled=true --set ai.adapter=openai-responses \
  --set ai.baseUrl=http://127.0.0.1:9/v1 --set ai.model=ci-no-provider-call \
  --set-string ai.temperature= --set ai.outputTokens=128000 \
  --set ai.timeoutSeconds=180 --set ai.reasoningEffort=low "${COMMON[@]}"
x php -r '
  require "/var/www/html/system/vendor/autoload.php";
  $path = "/var/www/html/settings/settings.yaml";
  $settings = Symfony\Component\Yaml\Yaml::parseFile($path);
  foreach (["ai_adapter" => "openai-responses", "ai_base_url" => "http://127.0.0.1:9/v1",
    "ai_model" => "ci-no-provider-call", "aitemperature" => "", "aioutputtoken" => "128000",
    "aitimeout" => "180", "ai_reasoning_effort" => "low"] as $key => $value) {
    if (!array_key_exists($key, $settings) || $settings[$key] !== $value) {
      fwrite(STDERR, "Unexpected AI bootstrap value: $key\n"); exit(1);
    }
  }
  $secrets = Symfony\Component\Yaml\Yaml::parseFile("/var/www/html/settings/secrets.yaml") ?? [];
  foreach (["ai_api_key", "chatgptKey", "claudeKey"] as $key) {
    if (array_key_exists($key, $secrets)) { exit(1); }
  }
  $settings = array_merge($settings, ["title" => "Typemill AI CI", "author" => "CI",
    "language" => "en", "theme" => "cyanine", "proxy" => false,
    "custom_bootstrap_marker" => "preserve"]);
  if (file_put_contents($path, Symfony\Component\Yaml\Yaml::dump($settings)) === false) { exit(1); }
  chown($path, 33); chgrp($path, 33);
  echo "AI bootstrap settings and empty secrets verified\n";
'
check_runtime
CONFIG_BEFORE=$(x sha256sum /var/www/html/settings/settings.yaml)
restart
[[ $(x sha256sum /var/www/html/settings/settings.yaml) == "$CONFIG_BEFORE" ]] || fail "repeated AI bootstrap changed stored settings"
h test "$RELEASE" --logs --timeout=120s

echo "PASS: v2.28.0 runtime, image, upgrade, PVC, seven paths, old/new themes, setup wizard, unchanged settings, workaround guards, restart, strict custom-file rejection, ephemeral installation, AI bootstrap and Helm tests"
