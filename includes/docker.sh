#!/usr/bin/env bash

# shellcheck disable=SC2206

TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE=${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE:-}

function toolbox_docker_run() {
  _log TRACE "Start 'toolbox_docker_run' function with args: $*"
  local _arguments="$*"

  local _TOOLBOX_DOCKER_EXECUTABLE=${TOOLBOX_DOCKER_EXECUTABLE:-docker}
  local _TOOLBOX_DOCKER_RUN=${TOOLBOX_DOCKER_RUN:-run}
  local _TOOLBOX_DOCKER_IMAGE=${TOOLBOX_DOCKER_IMAGE:-aroq/toolbox:latest}
  local _TOOLBOX_DOCKER_CURRENT_DIR=${TOOLBOX_DOCKER_CURRENT_DIR:-$(pwd)}
  local _TOOLBOX_DOCKER_WORKING_DIR=${TOOLBOX_DOCKER_WORKING_DIR:-}
  local _TOOLBOX_DOCKER_VOLUME_SOURCE=${TOOLBOX_VOLUME_SOURCE:-$(pwd)}
  local _TOOLBOX_DOCKER_VOLUME_TARGET=${TOOLBOX_DOCKER_VOLUME_TARGET:-${_TOOLBOX_DOCKER_VOLUME_SOURCE}}
  # local _TOOLBOX_DOCKER_SSH_FORWARD=${TOOLBOX_DOCKER_SSH_FORWARD:-false}
  local _TOOLBOX_DOCKER_ENTRYPOINT=${TOOLBOX_DOCKER_ENTRYPOINT:-}
  local _TOOLBOX_DOCKER_ENV_VARS=${TOOLBOX_DOCKER_ENV_VARS:-}

  # Only allocate tty if one is detected. See - https://stackoverflow.com/questions/911168
  local _TOOLBOX_DOCKER_RUN_FLAGS
  _TOOLBOX_DOCKER_RUN_FLAGS+=(--rm)
  if [[ -t 0 ]]; then _TOOLBOX_DOCKER_RUN_FLAGS+=(-i); fi
  if [[ -t 1 ]]; then _TOOLBOX_DOCKER_RUN_FLAGS+=(-t); fi

  local _TOOLBOX_DOCKER_RUN_ARGS=${TOOLBOX_DOCKER_RUN_ARGS:-${_arguments}}

  local _run_cmd=("${_TOOLBOX_DOCKER_RUN}" \
    $(toolbox_util_array_join "${_TOOLBOX_DOCKER_RUN_FLAGS[@]}") \
    -w ${_TOOLBOX_DOCKER_CURRENT_DIR}/${_TOOLBOX_DOCKER_WORKING_DIR} \
    -v ${_TOOLBOX_DOCKER_VOLUME_SOURCE}:${_TOOLBOX_DOCKER_VOLUME_TARGET})

  if [[ ! -z "${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE}" ]]; then
    _run_cmd+=(${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE})
  fi

  if [[ ! -z "${_TOOLBOX_DOCKER_ENV_VARS}" ]]; then
    _run_cmd+=(${_TOOLBOX_DOCKER_ENV_VARS})
  fi

  if [[ ! -z "${_TOOLBOX_DOCKER_ENTRYPOINT}" ]]; then
    _run_cmd+=(--entrypoint=${_TOOLBOX_DOCKER_ENTRYPOINT})
  fi

  _run_cmd+=(${_TOOLBOX_DOCKER_IMAGE} ${_TOOLBOX_DOCKER_RUN_ARGS})

  local _TOOLBOX_DOCKER_RUN_EXEC_METHOD=${TOOLBOX_DOCKER_RUN_EXEC_METHOD-toolbox_exec}
  "${_TOOLBOX_DOCKER_RUN_EXEC_METHOD}" "${_TOOLBOX_DOCKER_EXECUTABLE}" "${_run_cmd[@]}"
}

function toolbox_docker_exec() {
  _log TRACE "Start 'toolbox_docker_exec' function with args: $*"
  TOOLBOX_DOCKER_SKIP=${TOOLBOX_DOCKER_SKIP:-false}

  if [ "${TOOLBOX_DOCKER_SKIP}" == "true" ]; then
    toolbox_exec ${TOOLBOX_TOOL} "$@"
  else
    toolbox_docker_add_env_var_file_from_prefix "$(printf '%s\n' "$TOOLBOX_TOOL_NAME" | awk '{ print toupper($0) }')_"

    toolbox_docker_add_env_var_file "${TOOLBOX_TOOL_NAME}.env"

    toolbox_docker_run "$@"
  fi

  _log TRACE "End 'toolbox_docker_exec' function"
}

function toolbox_docker_add_env_var_file_from_prefix() {
  local _env_file
  _env_file="$(mktemp)"
  (env | grep "^${1}") >> "${_env_file}" || true
  toolbox_docker_add_env_var_file "${_env_file}" "'${1}*' prefix variable list"
}

function toolbox_docker_add_env_var_file() {
  if [[ -f "${1}" ]]; then
    local _title
    _title=${2:-"Variables from file ${1}"}
    TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE="${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE} --env-file=${1}"
    _log DEBUG "${YELLOW}${_title} - ${1}:${RESTORE}"
    _log DEBUG "${LYELLOW}$(cat "${1}")${RESTORE}"
    _log DEBUG "${YELLOW}---${RESTORE}"
  else
    _log DEBUG "File: ${1} is not found"
  fi
}
