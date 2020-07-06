#!/usr/bin/env bash

# shellcheck disable=SC2206

# Possible contexts:
# - Executed inside HOST without Docker (TOOLBOX_EXEC_CONTEXT == "HOST" )
# - Docker executed inside toolbox (TOOLBOX_EXEC_CONTEXT == "DOCKER_INSIDE")
# - Docker executed outide toolbox (TOOLBOX_EXEC_CONTEXT == "DOCKER_OUTSIDE")
# - Docker executed inside Docker (TOOLBOX_EXEC_CONTEXT == "DOCKER_DIND")

export TOOLBOX_EXEC_CONTEXT=${TOOLBOX_EXEC_CONTEXT:-DOCKER_INSIDE}
export TOOLBOX_DOCKER_MODE=${TOOLBOX_DOCKER_MODE:-}
export TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE=${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE:-}
# export TOOLBOX_DOCKER_DIND=${TOOLBOX_DOCKER_DIND:-false}
export TOOLBOX_DOCKER_MOUNTS_DIR=${TOOLBOX_DOCKER_MOUNTS_DIR-toolbox/mounts}
export TOOLBOX_SUDO_PREFIX=${TOOLBOX_SUDO_PREFIX-""}

GITHUB_ACTIONS=${GITHUB_ACTIONS-}

# Set docker context vars
if [ -f /.dockerenv ]; then
  if [ ! "${TOOLBOX_EXEC_CONTEXT}" = "DOCKER_DIND" ]; then
    TOOLBOX_EXEC_CONTEXT="DOCKER_OUTSIDE"
  fi
else
  if [ ! -z ${GITHUB_ACTIONS} ]; then
    TOOLBOX_EXEC_CONTEXT="GITHUB_ACTIONS"
    TOOLBOX_SUDO_PREFIX="sudo"
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
  TOOLBOX_DOCKER_EXEC_TITLE=${TOOLBOX_DOCKER_EXEC_TITLE:-"Execute in docker"}

  TOOLBOX_DOCKER_RUN_EXEC_METHOD=${TOOLBOX_DOCKER_RUN_EXEC_METHOD:-toolbox_run}

  TOOLBOX_DOCKER_RUN_ARG_CLEANUP=${TOOLBOX_DOCKER_RUN_ARG_CLEANUP:-true}
  TOOLBOX_DOCKER_RUN_ARG_ALLOCATE_PSEUDO_TTY=${TOOLBOX_DOCKER_RUN_ARG_ALLOCATE_PSEUDO_TTY:-true}
  TOOLBOX_DOCKER_RUN_ARG_KEEP_STDIN_OPEN=${TOOLBOX_DOCKER_RUN_ARG_KEEP_STDIN_OPEN:-true}
  TOOLBOX_DOCKER_RUN_ARGS=${TOOLBOX_DOCKER_RUN_ARGS:-}

  local _run_args

  if [ "${TOOLBOX_DOCKER_RUN_ARG_CLEANUP}" = true ]; then
    _run_args+=(--rm)
  fi

  # Only allocate tty if one is detected. See - https://stackoverflow.com/questions/911168
  if [ "${TOOLBOX_DOCKER_RUN_ARG_KEEP_STDIN_OPEN}" = true ]; then
    if [[ -t 0 ]]; then _run_args+=(-i); fi
  fi

  if [ "${TOOLBOX_DOCKER_RUN_ARG_ALLOCATE_PSEUDO_TTY}" = true ]; then
    _run_args+=(-t)
  fi

  _run_args+=(${TOOLBOX_DOCKER_RUN_ARGS})

  # Mounts & working dir
  if [[ "$OSTYPE" == "darwin"* ]]; then
    TOOLBOX_DOCKER_MOUNT_OPTIONS=":delegated"
  else
    TOOLBOX_DOCKER_MOUNT_OPTIONS=''
  fi
  local _run_cmd=("${TOOLBOX_DOCKER_RUN}" \
    $(toolbox_util_array_join "${_run_args[@]}") \
    -w ${TOOLBOX_DOCKER_CURRENT_DIR}/${TOOLBOX_DOCKER_WORKING_DIR} \
    -v ${TOOLBOX_DOCKER_VOLUME_SOURCE}:${TOOLBOX_DOCKER_VOLUME_TARGET}${TOOLBOX_DOCKER_MOUNT_OPTIONS})

  if [[ ! -z "${TOOLBOX_DOCKER_MOUNTS}" ]]; then
    for i in ${TOOLBOX_DOCKER_MOUNTS//,/ }
    do
      if [ -e "${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/.tmp/mounts${i}" ]; then
        _run_cmd+=(-v ${TOOLBOX_DOCKER_CURRENT_DIR}/toolbox/.tmp/mounts${i}:${i}${TOOLBOX_DOCKER_MOUNT_OPTIONS})
      fi
    done
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

  if [ ! $# -eq 0 ]; then
    "${TOOLBOX_DOCKER_RUN_EXEC_METHOD}" "${TOOLBOX_DOCKER_EXEC_TITLE} ${TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE}${GREEN}: ${*}${RESTORE}" "${TOOLBOX_DOCKER_EXECUTABLE}" "${_run_cmd[@]}" ${TOOLBOX_DOCKER_IMAGE} "${@}"
  else
    "${TOOLBOX_DOCKER_RUN_EXEC_METHOD}" "${TOOLBOX_DOCKER_EXEC_TITLE} ${TOOLBOX_DOCKER_EXEC_ENTRYPOINT_TITLE}" "${TOOLBOX_DOCKER_EXECUTABLE}" "${_run_cmd[@]}" ${TOOLBOX_DOCKER_IMAGE}
  fi
}

function toolbox_docker_exec() {
  _log TRACE "Start 'toolbox_docker_exec' function with args: $*"

  if [ "${TOOLBOX_EXEC_CONTEXT}" = "HOST" ] || [ "${TOOLBOX_EXEC_CONTEXT}" = "DOCKER_OUTSIDE" ]; then
    "${TOOLBOX_EXEC_METHOD}" "Execute without docker" "${TOOLBOX_TOOL}" "$@"
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
