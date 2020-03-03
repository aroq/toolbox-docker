#!/usr/bin/env bash

# Includes
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-utils/includes/init.sh"
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-utils/includes/util.sh"
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-utils/includes/log.sh"
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-utils/includes/exec.sh"
. "{{ getenv "TOOLBOX_DEPS_DIR" "toolbox/deps" }}/toolbox-docker/includes/docker.sh"

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

toolbox_docker_exec "$@"

