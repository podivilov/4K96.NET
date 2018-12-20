# Banner
source "modules/banner.sh" "$1"

# Configuration file
source "modules/config.sh"

# Necessary variables
IS_CONNECTED="0"

#
# Main functions
#

# Menu
function menu() {
  while :
  do
    read -p "4k96> " COMMAND; COMMAND_HEAD=$(echo "$COMMAND" | cut -d " " -f1); COMMAND_BODY=$(echo "$COMMAND" | sed "s/$COMMAND_HEAD[[:space:]]//g")
    case "$COMMAND_HEAD" in
      (login   | LOGIN          ) _login "`echo $COMMAND_BODY | cut -d ' ' -f 1`" "`echo $COMMAND_BODY | cut -d ' ' -f 2`";;
      (signup  | SIGNUP         ) _signup "`echo $COMMAND_BODY | cut -d ' ' -f 1`" "`echo $COMMAND_BODY | cut -d ' ' -f 2`";;
      (list    | LIST           ) _list;;
      (send    | SEND           ) _send "`echo $COMMAND_BODY`";;
      (read    | READ           ) _read "`echo $COMMAND_BODY`";;
      (ping    | PING           ) _ping;;
      ("?"     | help    | HELP ) _help;;
      (about   | ABOUT          ) _about;;
      (version | VERSION        ) _version;;
      (logout  | LOGOUT         ) _logout;;
      (exit    | EXIT           ) _exit;;
      (*                        ) if ! [ -z "$COMMAND_HEAD" ]; then echo "Command \"$COMMAND_HEAD\" doesn't exists."; fi;;
    esac
  done
}

# Log
function log() {
  if ! grep -q "client" <<<"$0"; then
    if [[ "$DEBUG" == "1" ]] && [[ "${1^^}" == "DEBUG" ]]; then
      echo "[`date +%H:%M:%S` ${1^^}]: ${@:2}"
    elif [[ "${1^^}" == "NOTICE" ]] || [[ "${1^^}" == "INFO" ]]; then
      echo "[`date +%H:%M:%S` ${1^^}]: ${@:2}"
    fi
  fi
}

# Reset
function reset() {
  if grep -q "client" <<<"$0"; then
    tx_bytes "RESET"
    echo "Connection was reset due to an error."
    exit 299
  else
    fallback 1
  fi
}

# Flush
function flush() {
  log debug "Unset USERNAME variable..."
  unset USERNAME
  log debug "Done!"
  log debug "Unset PASSWORD variable..."
  unset PASSWORD
  log debug "Done!"
}

# Fallback
function fallback() {
  if [[ "$1" == "0" ]]; then
    log info "Falling back..."
    flush && worker
  elif [[ "$1" == "1" ]]; then
    tx_bytes "RESET"
    log info "Falling back due to an unrecoverable error..."
    flush && worker
  elif [[ "$1" == "2" ]]; then
    log info "Falling back due to an client error..."
    flush && worker
  elif [[ "$1" == "3" ]]; then
    log info "Falling back due to an server error..."
    flush && worker
  fi
}

# Transmit bytes
function tx_bytes() {
  log debug "Transmitting data: \"$1\""
  echo "$1" | minimodem -A -q -a -c "$DEFAULT_CONFIDENCE" -v "$DEFAULT_VOLUME" --startbits "$DEFAULT_STARTBITS" --stopbits "$DEFAULT_STOPBITS" --sync-byte "$DEFAULT_SYNCBYTE" -R "$DEFAULT_SAMPLERATE" --float-samples --tx "$DEFAULT_FREQUENCY"
  log debug "Transmission is over."
}

# Receive bytes
function rx_bytes() {
  if [ -z "$1" ]; then
    minimodem -A -q -a -c "$DEFAULT_CONFIDENCE" -v "$DEFAULT_VOLUME" --startbits "$DEFAULT_STARTBITS" --stopbits "$DEFAULT_STOPBITS" --sync-byte "$DEFAULT_SYNCBYTE" -R "$DEFAULT_SAMPLERATE" --print-filter --rx-one "$DEFAULT_FREQUENCY" | sed -E "s/\.\.+//g"
  else
    RX=$(minimodem -A -q -a -c "$DEFAULT_CONFIDENCE" -v "$DEFAULT_VOLUME" --startbits "$DEFAULT_STARTBITS" --stopbits "$DEFAULT_STOPBITS" --sync-byte "$DEFAULT_SYNCBYTE" -R "$DEFAULT_SAMPLERATE" --print-filter --rx-one "$DEFAULT_FREQUENCY" | sed -E "s/\.\.+//g")
      if [[ "$RX" == "$1" ]]; then
        log debug "The received data are correct."
      else
        log debug "The received data \"$RX\" are not equal to \"$1\". Aborting."
        reset
      fi
  fi
}

#
# Client functions
#

# Help
function _help() {
  echo -e "Available commands:\n\nlogin	— login into the system. Usage: login [USERNAME] [PASSWORD].\nsignup	— register new username. Usage: signup [USERNAME] [PASSWORD].\nlist	— get the count of new messages.\nsend	— send a message to another user. Usage: send [USERNAME].\nread	— receive an incoming message by id. Usage: read [ID].\nping	— test the connection.\nhelp	— show this text.\nabout	— about the program.\nversion	— version of the software.\nlogout	— log out of system.\nexit	— exit without logging out."
}

# About
function _about() {
  echo "4K96.NET client/server is originally written by Mihail Podivilov <mihail@podivilov.ru>. All source code are distributed under MIT license."
}

# Version
function _version() {
  echo "4K96.NET v$PROTOCOL_VERSION (c) 2018 Mihail Podivilov <mihail@podivilov.ru>"
}

# Exit
function _exit() {
  exit 0
}

#
# Server functions
#

# Worker
function worker() {
  log info "Listening..."
  RX=$(rx_bytes); query_parse "$RX"
  if [[ "$QUERY_HEAD" == "HELLO" ]]; then
    :
  elif [[ "$QUERY_HEAD" == "PING" ]]; then
    log info "Received expected \"$QUERY_HEAD\" query."
    tx_bytes "$PROTOCOL_STUB 198 PONG"
    fallback 0
  else
    fallback 1
  fi
  log notice "Handshake sequence received!"
  log notice "Handshake in progress..."
  tx_bytes "$DEFAULT_PREFIX 100 HELLO"
  log notice "Handshake completed."
  log notice "Waiting for LOGIN or SIGNUP query..."
  log info "Listening..."
  RX=$(rx_bytes); query_parse "$RX"
  if [[ "$QUERY_HEAD" == "LOGIN" || "$QUERY_HEAD" == "SIGNUP" ]]; then
    log info "Received expected \"$QUERY_HEAD\" query."
    USERNAME=$(echo "$QUERY_BODY" | cut -d " " -f1)
    PASSWORD=$(echo "$QUERY_BODY" | cut -d " " -f2)
    if   [[ "$QUERY_HEAD" == "LOGIN" ]]; then
      if [ -d "userdata/$USERNAME" ]; then
        HASH=$(echo "$PASSWORD" | md5sum | cut -d " " -f1)
        FILE=$(cat "userdata/$USERNAME/password")
        if [[ "$HASH" == "$FILE" ]]; then
          tx_bytes "`response_form 101 AUTHORIZED`"
          ready
        else
          tx_bytes "`response_form 201 FORBIDDEN`"
          fallback 2
        fi
      else
        tx_bytes "`response_form 201 FORBIDDEN`"
        fallback 2
      fi
    elif [[ "$QUERY_HEAD" == "SIGNUP" ]]; then
      if ! [ -d "userdata/$USERNAME" ]; then
        if [[ "$USERNAME" =~ ^[[:alnum:]]*$ ]] && [[ ! "$USERNAME" =~ ^[[:digit:]]+$ ]] && [[ "$PASSWORD" =~ ^[[:alnum:]]*$ ]] && [[ ! "$PASSWORD" =~ ^[[:digit:]]+$ ]]; then
          if [[ "${#USERNAME}" -gt 4 ]] && [[ "${#USERNAME}" -lt 16 ]] && [[ "${#PASSWORD}" -gt 8 ]] && [[ "${#PASSWORD}" -lt 16 ]]; then
            mkdir -p "userdata/$USERNAME"
            touch "userdata/$USERNAME/messages"
            echo "$PASSWORD" | md5sum | cut -d " " -f1 > "userdata/$USERNAME/password"
            log notice "Successfully registered username \"$USERNAME\"."
            tx_bytes "`response_form 102 REGISTERED`"
            ready
          else
            log notice "Incorrect login or password specified."
            tx_bytes "`response_form 202 FORBIDDEN`"
            fallback 2
          fi
        else
          log notice "Incorrect login or password specified."
          tx_bytes "`response_form 202 FORBIDDEN`"
          fallback 2
        fi
      else
        log notice "Username \"$USERNAME\" is already taken."
        tx_bytes "`response_form 203 FORBIDDEN`"
        fallback 2
      fi
    fi
  else
    log info "Received unexpected \"$QUERY_HEAD\" query."
    fallback 1
  fi
}

# Ready
function ready() {
  while :; do
    log info "Listening..."
    RX=$(rx_bytes); query_parse "$RX"
    case "$QUERY_HEAD" in
      "LIST")
        log debug "QUERY_HEAD variable is set to \"$QUERY_HEAD\"."
        log info "Received expected \"$QUERY_HEAD\" query."
        COUNT=$(grep -c $ "userdata/$USERNAME/messages")
        if [[ "$COUNT" =~ ^[0-9]+$ ]]; then
          tx_bytes "$DEFAULT_PREFIX 103 DATA `echo $COUNT | base64`"
        else
          tx_bytes "$DEFAULT_PREFIX 205 STUCK"
          fallback 3
        fi
      ;;
      "SEND")
        log debug "QUERY_HEAD variable is set to \"$QUERY_HEAD\"."
        log info "Received expected \"$QUERY_HEAD\" query."
        SENDER="$USERNAME"
        RECIPIENT=$(echo "$QUERY_BODY" | cut -d ' ' -f 1)
        MESSAGE=$(echo "$QUERY_BODY" | cut -d ' ' -f 2)
        if [ -d "userdata/$RECIPIENT" ]; then
          if echo "$MESSAGE" | base64 -d &>/dev/null; then
            echo "`date +%s` $RECIPIENT $MESSAGE" >> "userdata/$RECIPIENT/messages"
            tx_bytes "$DEFAULT_PREFIX 104 SENT"
          else
            tx_bytes "$DEFAULT_PREFIX 205 STUCK"
            fallback 3
          fi
        else
          tx_bytes "$DEFAULT_PREFIX 206 ABSENT"
        fi
      ;;
      "READ")
        log debug "QUERY_HEAD variable is set to \"$QUERY_HEAD\"."
        log info "Received expected \"$QUERY_HEAD\" query."
        LINE_NUMBER=$(echo "$QUERY_BODY" | cut -d ' ' -f 1)
        LINE_CONTENTS=$(sed "$LINE_NUMBER""q;d" "userdata/$USERNAME/messages")
        if ! [[ -z "$LINE_CONTENTS" ]]; then
          tx_bytes "$DEFAULT_PREFIX 103 DATA `echo $LINE_CONTENTS | base64`"
          log info "Listening..."
          RX=$(rx_bytes); query_parse "$RX"
          if [[ "$QUERY_HEAD" == "RECD" ]]; then
            sed -e "$LINE_NUMBER""d" "userdata/$USERNAME/messages" > "userdata/$USERNAME/messages"
            tx_bytes "$DEFAULT_PREFIX 106 READY"
          else
            fallback 1
          fi
        else
          tx_bytes "$DEFAULT_PREFIX 206 ABSENT"
        fi
      ;;
      "PING")
        log debug "QUERY_HEAD variable is set to \"$QUERY_HEAD\"."
        log info "Received expected \"$QUERY_HEAD\" query."
        tx_bytes "$PROTOCOL_STUB 198 PONG"
      ;;
      "LOGOUT")
        log debug "QUERY_HEAD variable is set to \"$QUERY_HEAD\"."
        log info "Received expected \"$QUERY_HEAD\" query."
        tx_bytes "$PROTOCOL_STUB 199 LOGOUT"
        fallback 0
      ;;
      *)
        log debug "QUERY_HEAD variable is set to \"$QUERY_HEAD\"."
        log info "Received unexpected \"$QUERY_HEAD\" query."
        fallback 1
      ;;
    esac
  done
}

# Parsing
function query_parse() {
  log debug "Received data: $1"
  log debug "Parsing query..."
  if grep -q "$PROTOCOL_STUB" <<<"$1"; then
    HEAD=$(echo "$1" | cut -d " " -f1)
    log debug "HEAD variable is set to \"$HEAD\""
    if [[ "$HEAD" == "QUERY" ]]; then
      QUERY=$(echo "$1" | sed "s/[[:space:]]$PROTOCOL_NAME\/$PROTOCOL_VERSION//g")
      QUERY_HEAD=$(echo "$1" | cut -d " " -f2)
      QUERY_BODY=$(echo "$QUERY" | sed "s/QUERY[[:space:]]//g" | sed "s/$QUERY_HEAD[[:space:]]//g")
      log debug "QUERY variable is set to \"$QUERY\""
      log debug "QUERY_HEAD variable is set to \"$QUERY_HEAD\""
      log debug "QUERY_BODY variable is set to \"$QUERY_BODY\""
    else
      log debug "Looks like this is not a query. Aborting."
      reset
    fi
  else
    log debug "Protocol stub is not found in the query. Aborting."
    reset
  fi
}

# Query forming
function query_form() {
  echo "QUERY $@ $PROTOCOL_STUB"
}

# Response forming
function response_form() {
  echo "$PROTOCOL_STUB $1 ${@:2}"
}

# Login
log debug "Loading \"LOGIN\" module..."
source "modules/login.sh"
log debug "Module \"LOGIN\" has been loaded."

# Signup
log debug "Loading \"SIGNUP\" module..."
source "modules/signup.sh"
log debug "Module \"SIGNUP\" has been loaded."

# List
log debug "Loading \"LIST\" module..."
source "modules/list.sh"
log debug "Module \"LIST\" has been loaded."

# Send
log debug "Loading \"SEND\" module..."
source "modules/send.sh"
log debug "Module \"SEND\" has been loaded."

# Read
log debug "Loading \"READ\" module..."
source "modules/read.sh"
log debug "Module \"READ\" has been loaded."

# Ping
log debug "Loading \"PING\" module..."
source "modules/ping.sh"
log debug "Module \"PING\" has been loaded."

# Logout
log debug "Loading \"LOGOUT\" module..."
source "modules/logout.sh"
log debug "Module \"LOGOUT\" has been loaded."

# Notify when all modules have loaded
log debug "Loading of modules is over."

# Values of variables from the configuration file
log debug "PROTOCOL_NAME variable is set to \"$PROTOCOL_NAME\""
log debug "PROTOCOL_VERSION variable is set to \"$PROTOCOL_VERSION\""
log debug "PROTOCOL_STUB variable is set to \"$PROTOCOL_NAME/$PROTOCOL_VERSION\""
log debug "DEFAULT_PREFIX variable is set to \"$PROTOCOL_STUB\""
log debug "DEFAULT_SUFFIX variable is set to \"$PROTOCOL_STUB\""
log debug "DEFAULT_CONFIDENCE variable is set to \"$DEFAULT_CONFIDENCE\""
log debug "DEFAULT_VOLUME variable is set to \"$DEFAULT_VOLUME\""
log debug "DEFAULT_STARTBITS variable is set to \"$DEFAULT_STARTBITS\""
log debug "DEFAULT_STOPBITS variable is set to \"$DEFAULT_STOPBITS\""
log debug "DEFAULT_SYNCBYTE variable is set to \"$DEFAULT_SYNCBYTE\""
log debug "DEFAULT_SAMPLERATE variable is set to \"$DEFAULT_SAMPLERATE\""
log debug "DEFAULT_FREQUENCY variable is set to \"$DEFAULT_FREQUENCY\""

# Warning that debug mode is in use
log debug "Running in the debug mode."

