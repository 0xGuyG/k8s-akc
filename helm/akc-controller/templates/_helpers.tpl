{{/*
Expand the name of the chart.
*/}}
{{- define "akc-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "akc-controller.fullname" -}}
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
{{- define "akc-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "akc-controller.labels" -}}
helm.sh/chart: {{ include "akc-controller.chart" . }}
{{ include "akc-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "akc-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "akc-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "akc-controller.serviceAccountName" -}}
{{- if .Values.rbac.create }}
{{- default (include "akc-controller.fullname" .) .Values.rbac.serviceAccountName }}
{{- else }}
{{- default "default" .Values.rbac.serviceAccountName }}
{{- end }}
{{- end }}

{{/*
Create the name of the config map to use
*/}}
{{- define "akc-controller.configMapName" -}}
{{- if .Values.configMap.create }}
{{- printf "%s-config" (include "akc-controller.fullname" .) }}
{{- else }}
{{- .Values.controller.config.akc.configMapName }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "akc-controller.secretName" -}}
{{- if .Values.secret.create }}
{{- printf "%s-secret" (include "akc-controller.fullname" .) }}
{{- else }}
{{- printf "%s-secret" (include "akc-controller.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the image path
*/}}
{{- define "akc-controller.image" -}}
{{- $registry := .Values.controller.image.registry -}}
{{- if .Values.global.imageRegistry -}}
{{- $registry = .Values.global.imageRegistry -}}
{{- end -}}
{{- printf "%s/%s:%s" $registry .Values.controller.image.repository .Values.controller.image.tag -}}
{{- end }}

{{/*
Create namespace
*/}}
{{- define "akc-controller.namespace" -}}
{{- .Values.controller.config.akc.namespace | default "akc-system" }}
{{- end }}