
/* service.name */
{{- define "service.name" -}}
{{- default .Values.service.name | trunc 63 | trimSuffix "-" }}
{{- end }}

/* service.version */
{{- define "service.version" -}}
{{- default .Values.service.image.version .Values.versionOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

/* service.labels */
{{- define "service.labels" -}}
version: {{ include "service.version" . }}
app: {{ include "service.name" . }}
{{ include "service.selectorLabels" . }}
{{- end }}

/* service.selectorLabels */
{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
{{- end }}