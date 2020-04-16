#!/usr/bin/env bash

# Setup variables
{{- if has .task "env" -}}
{{- range $k, $v := .task.env -}}
{{- if $v }}
export {{ $k }}=${ {{- $k }}:-{{ $v }}}
{{- end -}}
{{- end }}
export TOOLBOX_DOCKER_ENV_VARS="-e {{ $s := coll.Keys .task.env }}{{ join $s " -e " }}"
{{ end }}
export TOOLBOX_DOCKER_IMAGE=${TOOLBOX_DOCKER_IMAGE:-{{ .task.image }}}
export TOOLBOX_TOOL_NAME=$(basename "{{ (ds "task_name" ).name }}")

{{ if has .task "cmd" -}}
export TOOLBOX_TOOL={{ .task.cmd}}
{{ else }}
export TOOLBOX_TOOL="${TOOLBOX_TOOL_NAME}"
{{ end -}}

# Setup tool dirs
{{ if has .task "tool_dirs" -}}
export TOOLBOX_TOOL_DIRS="toolbox,{{ $l :=  reverse .task.tool_dirs | uniq }}{{ join $l "," }}"
{{ end -}}

{{ if has .task "working_dir" -}}
export TOOLBOX_DOCKER_WORKING_DIR={{ .task.working_dir}}
{{ end -}}

{{ if has .task "entrypoint_override" -}}
{{ if eq .task.entrypoint_override true -}}
export TOOLBOX_DOCKER_ENTRYPOINT=${TOOLBOX_DOCKER_ENTRYPOINT:-$(basename "${TOOLBOX_TOOL}")}
{{ end -}}
{{ end -}}

# Setup files
{{ if has .task "files" -}}
{{ if has .task.files "exec_contexts" -}}
{{- range $context, $files := .task.files.exec_contexts -}}
export TOOLBOX_FILES_{{ $context }}="{{ $l :=  $files | uniq }}{{ join $l "," }}"
{{ end -}}
{{ end -}}
{{ end -}}


# Includes
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-utils/includes/init.sh"
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-utils/includes/util.sh"
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-utils/includes/log.sh"
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-exec/includes/exec.sh"
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-docker/includes/docker.sh"


toolbox_exec_wrapper "toolbox_docker_exec" "$@"
