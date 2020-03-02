#!/usr/bin/env bash

# Set strict bash mode
set -euo pipefail

#  Set bash options
TOOLBOX_BASH_SET_OPTIONS=${TOOLBOX_BASH_SET_OPTIONS:-}
if [ ! -z "${TOOLBOX_BASH_SET_OPTIONS}" ]; then
  set "${TOOLBOX_BASH_SET_OPTIONS}"
fi

{{ if has .task "env" -}}
{{- range $k, $v := .task.env -}}
{{- if $v }}
export {{ $k }}=${ {{- $k }}:-{{ $v }}}
{{ end -}}
{{ end -}}
export TOOLBOX_DOCKER_ENV_VARS="-e {{ $s := coll.Keys .task.env }}{{ join $s " -e " }}"
{{ end -}}

export TOOLBOX_TOOL_NAME="{{ (ds "task_name" ).name }}"

export TOOLBOX_DOCKER_IMAGE=${TOOLBOX_DOCKER_IMAGE:-{{ .task.image }}}

{{ if has .task "run_wrapper_path" -}}
{{ if has .task "cmd" -}}
exec {{ .task.run_wrapper_path }} {{ .task.cmd }} "$@"
{{ else }}
exec {{ .task.run_wrapper_path }} "$@"
{{ end -}}
{{ else }}
{{ if has .task "cmd" -}}
exec toolbox/.toolbox/deps/toolbox-variant/run {{ .task.cmd }} "$@"
{{ else }}
exec toolbox/.toolbox/deps/toolbox-variant/run "$@"
{{ end -}}
{{ end -}}
