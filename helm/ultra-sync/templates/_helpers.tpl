{{/*
Expand the name of the chart.
*/}}
{{- define "ultra-sync.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "ultra-sync.fullname" -}}
{{- printf "%s-%s" (include "ultra-sync.name" .) .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "ultra-sync.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for a given component.
Usage: {{ include "ultra-sync.selectorLabels" (dict "app" "auth") }}
*/}}
{{- define "ultra-sync.selectorLabels" -}}
app: {{ .app }}
{{- end }}

{{/*
Image reference helper.
Usage: {{ include "ultra-sync.image" (dict "registry" .Values.global.imageRegistry "image" "auth" "tag" .Values.global.imageTag) }}
*/}}
{{- define "ultra-sync.image" -}}
{{ .registry }}/{{ .image }}:{{ .tag }}
{{- end }}

{{/*
OTel endpoint env var.
*/}}
{{- define "ultra-sync.otelEnv" -}}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.global.otelEndpoint | quote }}
{{- end }}
