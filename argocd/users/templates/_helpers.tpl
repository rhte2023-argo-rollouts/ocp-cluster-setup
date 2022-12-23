
/* service.name */
{{- define "service.name" -}}
{{- default .Values.service.name | trunc 63 | trimSuffix "-" }}
{{- end }}

/* service.version */
{{- define "service.version" -}}
{{- default .Values.service.image.version | quote }}
{{- end }}

/* service.labels */
{{- define "service.labels" -}}
version: {{ include "service.version" . }}
{{ include "service.selectorLabels" . }}
{{- end }}

/* service.selectorLabels */
{{- define "service.selectorLabels" -}}
app: {{ include "service.name" . }}
{{- end }}