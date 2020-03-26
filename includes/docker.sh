#!/usr/bin/env bash

# shellcheck disable=SC2206

# Possible contexts:
# - docker
#   - dind (TOOLBOX_DOCKER_DIND == true)
# - docker_skip (TOOLBOX_DOCKER_SKIP == true )
# - shell_to_docker (TOOLBOX_DOCKER_CONTEXT == "SHELL_TO_DOCKER")

export TOOLBOX_DOCKER_CONTEXT=${TOOLBOX_DOCKER_CONTEXT:-SHELL_TO_DOCKER}
export TOOLBOX_DOCKER_MODE=${TOOLBOX_DOCKER_MODE:-}
export TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE=${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE:-}
export TOOLBOX_DOCKER_SKIP=${TOOLBOX_DOCKER_SKIP:-false}
export TOOLBOX_DOCKER_DIND=${TOOLBOX_DOCKER_DIND:-false}

# Set docker context vars
if [ -f /.dockerenv ]; then
  TOOLBOX_DOCKER_CONTEXT="DOCKER"
  TOOLBOX_DOCKER_MODE="DOCKER"
  if [ ! "${TOOLBOX_DOCKER_DIND}" == "true" ]; then
    echo "Inside docker already, setting TOOLBOX_DOCKER_SKIP to true"
    TOOLBOX_DOCKER_SKIP=true
  else
    TOOLBOX_DOCKER_MODE="DIND"
  fi
fi

function toolbox_docker_run() {
  _log TRACE "Start 'toolbox_docker_run' function with args: $*"

  TOOLBOX_DOCKER_EXECUTABLE=${TOOLBOX_DOCKER_EXECUTABLE:-docker}
  TOOLBOX_DOCKER_RUN=${TOOLBOX_DOCKER_RUN:-run}
  TOOLBOX_DOCKER_IMAGE=${TOOLBOX_DOCKER_IMAGE:-aroq/toolbox:latest}
  TOOLBOX_DOCKER_CURRENT_DIR=${TOOLBOX_DOCKER_CURRENT_DIR:-$(pwd)}
  TOOLBOX_DOCKER_WORKING_DIR=${TOOLBOX_DOCKER_WORKING_DIR:-}
  TOOLBOX_DOCKER_VOLUME_SOURCE=${TOOLBOX_VOLUME_SOURCE:-$(pwd)}
  TOOLBOX_DOCKER_VOLUME_TARGET=${TOOLBOX_DOCKER_VOLUME_TARGET:-${TOOLBOX_DOCKER_VOLUME_SOURCE}}
  TOOLBOX_DOCKER_MOUNTS=${TOOLBOX_DOCKER_MOUNTS:-}
  # local _TOOLBOX_DOCKER_SSH_FORWARD=${TOOLBOX_DOCKER_SSH_FORWARD:-false}
  TOOLBOX_DOCKER_ENTRYPOINT=${TOOLBOX_DOCKER_ENTRYPOINT:-}
  TOOLBOX_DOCKER_ENV_VARS=${TOOLBOX_DOCKER_ENV_VARS:-}
  TOOLBOX_DOCKER_EXEC_TITLE=${TOOLBOX_DOCKER_EXEC_TITLE-"Execute in docker"}

  if [[ "$OSTYPE" == "darwin"* ]]; then
    TOOLBOX_DOCKER_MOUNT_OPTIONS=":delegated"
  else
    TOOLBOX_DOCKER_MOUNT_OPTIONS=''
  fi

  TOOLBOX_DOCKER_RUN_EXEC_METHOD=${TOOLBOX_DOCKER_RUN_EXEC_METHOD-toolbox_exec}

  # Only allocate tty if one is detected. See - https://stackoverflow.com/questions/911168
  local _run_args
  _run_args+=(--rm)
  if [ "${TOOLBOX_DOCKER_RUN_EXEC_METHOD}" = "toolbox_run" ]; then
    if [[ -t 0 ]]; then _run_args+=(-i); fi
    if [[ -t 1 ]]; then _run_args+=(-t); fi
  else
    if [[ -t 0 ]]; then _run_args+=(-i); fi
    _run_args+=(-t)
  fi

  # Mounts & working dir
  local _run_cmd=("${TOOLBOX_DOCKER_RUN}" \
    $(toolbox_util_array_join "${_run_args[@]}") \
    -w ${TOOLBOX_DOCKER_CURRENT_DIR}/${TOOLBOX_DOCKER_WORKING_DIR} \
    -v ${TOOLBOX_DOCKER_VOLUME_SOURCE}:${TOOLBOX_DOCKER_VOLUME_TARGET}${TOOLBOX_DOCKER_MOUNT_OPTIONS})

  # rm -fR "${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/.tmp/mounts"
  if [[ ! -z "${TOOLBOX_DOCKER_MOUNTS}" ]]; then
    rm -fR "${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/.tmp/mounts"
    mkdir -p "${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/.tmp"
    cp -fR "${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/mounts" "${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/.tmp/"

    toolbox_exec_hook "toolbox_docker_run_mounts" "before"
    for i in ${TOOLBOX_DOCKER_MOUNTS//,/ }
    do
      # mkdir -p "${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/.tmp/mounts"
      if [ -d "${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/mounts$i" ]; then
        _run_cmd+=(-v ${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/.tmp/mounts${i}:${i}${TOOLBOX_DOCKER_MOUNT_OPTIONS})
      fi
    done
    toolbox_exec_hook "toolbox_docker_run_mounts" "after"
  fi

  if [[ ! -z "${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE}" ]]; then
    _run_cmd+=(${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE})
  fi

  if [[ ! -z "${TOOLBOX_DOCKER_ENV_VARS}" ]]; then
    _run_cmd+=(${TOOLBOX_DOCKER_ENV_VARS})
  fi

  if [[ ! -z "${TOOLBOX_DOCKER_ENTRYPOINT}" ]]; then
    _run_cmd+=(--entrypoint=${TOOLBOX_DOCKER_ENTRYPOINT})
  fi

  if [[ ! -z "${TOOLBOX_DOCKER_ENTRYPOINT}" ]]; then
    TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE=${TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE-"${YELLOW}[image: ${TOOLBOX_DOCKER_IMAGE}, entrypoint: ${TOOLBOX_DOCKER_ENTRYPOINT}]"}
  else
    TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE=${TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE-"${YELLOW}[image: ${TOOLBOX_DOCKER_IMAGE}, entrypoint: default]"}
  fi

  if [[ "${TOOLBOX_DOCKER_ENTRYPOINT}" = "sh" ]]; then
    if [ ! $# -eq 0 ]; then
      "${TOOLBOX_DOCKER_RUN_EXEC_METHOD}" "${TOOLBOX_DOCKER_EXEC_TITLE} ${TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE}${GREEN}: ${*}${RESTORE}" "${TOOLBOX_DOCKER_EXECUTABLE}" "${_run_cmd[@]}" ${TOOLBOX_DOCKER_IMAGE} -c "${*}"
    else
      "${TOOLBOX_DOCKER_RUN_EXEC_METHOD}" "${TOOLBOX_DOCKER_EXEC_TITLE}" ${TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE} "${TOOLBOX_DOCKER_EXECUTABLE}" "${_run_cmd[@]}" ${TOOLBOX_DOCKER_IMAGE}
    fi
  else
    if [ ! $# -eq 0 ]; then
      "${TOOLBOX_DOCKER_RUN_EXEC_METHOD}" "${TOOLBOX_DOCKER_EXEC_TITLE} ${TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE}${GREEN}: ${*}${RESTORE}" "${TOOLBOX_DOCKER_EXECUTABLE}" "${_run_cmd[@]}" ${TOOLBOX_DOCKER_IMAGE} "${@}"
    else
      "${TOOLBOX_DOCKER_RUN_EXEC_METHOD}" "${TOOLBOX_DOCKER_EXEC_TITLE} ${TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE}" "${TOOLBOX_DOCKER_EXECUTABLE}" "${_run_cmd[@]}" ${TOOLBOX_DOCKER_IMAGE}
    fi
  fi
}

function toolbox_docker_exec() {
  _log TRACE "Start 'toolbox_docker_exec' function with args: $*"
  TOOLBOX_DOCKER_SKIP=${TOOLBOX_DOCKER_SKIP:-false}

  if [ "${TOOLBOX_DOCKER_SKIP}" == "true" ]; then
    shift
    toolbox_exec "Execute command without docker" ${TOOLBOX_TOOL_PATH} "$@"
  else
    toolbox_docker_add_env_var_file_from_prefix "TOOLBOX_"

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
