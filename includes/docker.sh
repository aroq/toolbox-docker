#!/usr/bin/env bash

# shellcheck disable=SC2206

# Default varable values

function toolbox_docker_run {
  _log TRACE "Start 'toolbox_docker_run' function"
  local _arguments="$*"

  TOOLBOX_DOCKER_EXECUTABLE=${TOOLBOX_DOCKER_EXECUTABLE:-docker}
  TOOLBOX_DOCKER_RUN=${TOOLBOX_DOCKER_RUN:-run}
  TOOLBOX_DOCKER_IMAGE=${TOOLBOX_DOCKER_IMAGE:-aroq/toolbox:latest}
  TOOLBOX_DOCKER_CURRENT_DIR=${TOOLBOX_DOCKER_CURRENT_DIR:-$(pwd)}
  TOOLBOX_DOCKER_WORKING_DIR=${TOOLBOX_DOCKER_WORKING_DIR:-}
  TOOLBOX_DOCKER_VOLUME_SOURCE=${TOOLBOX_VOLUME_SOURCE:-$(pwd)}
  TOOLBOX_DOCKER_VOLUME_TARGET=${TOOLBOX_DOCKER_VOLUME_TARGET:-${TOOLBOX_DOCKER_VOLUME_SOURCE}}
  TOOLBOX_DOCKER_SSH_FORWARD=${TOOLBOX_DOCKER_SSH_FORWARD:-false}
  TOOLBOX_DOCKER_ENTRYPOINT=${TOOLBOX_DOCKER_ENTRYPOINT:-}
  TOOLBOX_DOCKER_ENV_VARS=${TOOLBOX_DOCKER_ENV_VARS:-}
  TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE=${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE:-}

  # Only allocate tty if one is detected. See - https://stackoverflow.com/questions/911168
  TOOLBOX_DOCKER_RUN_FLAGS+=(--rm)
  if [[ -t 0 ]]; then TOOLBOX_DOCKER_RUN_FLAGS+=(-i); fi
  if [[ -t 1 ]]; then TOOLBOX_DOCKER_RUN_FLAGS+=(-t); fi

  TOOLBOX_DOCKER_RUN_ARGS=${TOOLBOX_DOCKER_RUN_ARGS:-${_arguments}}

  local run_cmd=("${TOOLBOX_DOCKER_RUN}" \
    $(toolbox_util_array_join "${TOOLBOX_DOCKER_RUN_FLAGS[@]}") \
    -w ${TOOLBOX_DOCKER_CURRENT_DIR}/${TOOLBOX_DOCKER_WORKING_DIR} \
    -v ${TOOLBOX_DOCKER_VOLUME_SOURCE}:${TOOLBOX_DOCKER_VOLUME_TARGET})

  if [[ ! -z "${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE}" ]]; then
    run_cmd+=(${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE})
  fi

  if [[ ! -z "${TOOLBOX_DOCKER_ENV_VARS}" ]]; then
    run_cmd+=(${TOOLBOX_DOCKER_ENV_VARS})
  fi

  if [[ ! -z "${TOOLBOX_DOCKER_ENTRYPOINT}" ]]; then
    run_cmd+=(--entrypoint=${TOOLBOX_DOCKER_ENTRYPOINT})
  fi

  run_cmd+=(${TOOLBOX_DOCKER_IMAGE} ${TOOLBOX_DOCKER_RUN_ARGS})

  toolbox_exec "${TOOLBOX_DOCKER_EXECUTABLE}" "${run_cmd[@]}"
}

function toolbox_docker_exec() {
  _log TRACE "Start 'toolbox_docker_exec' function"
  TOOLBOX_DOCKER_SKIP=${TOOLBOX_DOCKER_SKIP:-false}

  if [ "${TOOLBOX_DOCKER_SKIP}" == "true" ]; then
    toolbox_exec "$@"
  else
    # Provide TOOLBOX_* environment variables file
    local toolbox_env_file
    toolbox_env_file="$(mktemp)"

    local _prefix=$(printf '%s\n' "$TOOLBOX_TOOL_NAME" | awk '{ print toupper($0) }')

    (env | grep "^${_prefix}_") >> "${toolbox_env_file}" || true
    _log DEBUG "${YELLOW}'${_prefix}_*' variable list - ${toolbox_env_file}:${RESTORE}"
    _log DEBUG "${LYELLOW}$(cat "${toolbox_env_file}")${RESTORE}"
    _log DEBUG "${YELLOW}---${RESTORE}"
    TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE=${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE:-}
    TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE="${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE} --env-file=${toolbox_env_file}"

    if [[ -f "${TOOLBOX_TOOL_NAME}.env" ]]; then
      TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE="${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE} --env-file=${TOOLBOX_TOOL_NAME}.env"
      _log DEBUG "${YELLOW}Variable list from tool - ${TOOLBOX_TOOL_NAME}.env:${RESTORE}"
      _log DEBUG "$(cat "${TOOLBOX_TOOL_NAME}".env)"
    fi

    toolbox_docker_run "$@"
  fi

  _log TRACE "End 'toolbox_docker_exec' function"
}

