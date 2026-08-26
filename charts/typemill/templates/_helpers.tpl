{{/*
Expand the name of the chart.
*/}}
{{- define "typemill.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited to this.
*/}}
{{- define "typemill.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "typemill.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "typemill.labels" -}}
helm.sh/chart: {{ include "typemill.chart" . }}
{{ include "typemill.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "typemill.selectorLabels" -}}
app.kubernetes.io/name: {{ include "typemill.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "typemill.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "typemill.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Return the Typemill image reference. If image.digest is set, it takes precedence
over image.tag for immutable image pinning.
*/}}
{{- define "typemill.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end }}

{{/*
Return the immutable Typemill v2.26 image used as the Cyanine security-migration
source. Defaults are repeated here so upgrades with --reuse-values remain safe
when the previous release did not yet contain securityMigrations values.
*/}}
{{- define "typemill.cyanineV226MigrationImage" -}}
{{- $securityMigrations := .Values.securityMigrations | default dict -}}
{{- $cyanineV226 := get $securityMigrations "cyanineV226" | default dict -}}
{{- $image := get $cyanineV226 "image" | default dict -}}
{{- $repository := get $image "repository" | default "kixote/typemill" -}}
{{- $tag := get $image "tag" | default "v2.26.0" -}}
{{- $digest := "sha256:628f79a08cc75bc07777ae4b95312fb9770a531645789e698f12f96de6624156" -}}
{{- if hasKey $image "digest" -}}
{{- $digest = get $image "digest" -}}
{{- end -}}
{{- if $digest -}}
{{- printf "%s@%s" $repository $digest -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end }}

{{/*
Return the AI bootstrap init-container image reference. If digest is set, it takes
precedence over tag for immutable image pinning.
*/}}
{{- define "typemill.aiInitImage" -}}
{{- if .Values.ai.initContainer.image.digest -}}
{{- printf "%s@%s" .Values.ai.initContainer.image.repository .Values.ai.initContainer.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.ai.initContainer.image.repository .Values.ai.initContainer.image.tag -}}
{{- end -}}
{{- end }}

{{/*
Return the Helm test image reference. If tests.image.digest is set, it takes
precedence over the tag for immutable image pinning.
*/}}
{{- define "typemill.testImage" -}}
{{- $tests := .Values.tests | default dict -}}
{{- $image := $tests.image | default dict -}}
{{- $repository := $image.repository | default "busybox" -}}
{{- $digest := $image.digest | default "" -}}
{{- if $digest -}}
{{- printf "%s@%s" $repository $digest -}}
{{- else -}}
{{- printf "%s:%s" $repository ($image.tag | default "1.38.0") -}}
{{- end -}}
{{- end }}

{{/*
Typemill stores mutable state in flat files and does not support multiple pods
writing the same data. Reject configurations that could corrupt or diverge it.
*/}}
{{- define "typemill.validateScaling" -}}
{{- if ne (int .Values.replicaCount) 1 -}}
{{- fail "replicaCount must be 1 because Typemill uses mutable flat-file state and does not support multiple replicas" -}}
{{- end -}}
{{- if .Values.autoscaling.enabled -}}
{{- fail "autoscaling.enabled is unsupported because Typemill uses mutable flat-file state and must run as a single replica" -}}
{{- end -}}
{{- end }}
