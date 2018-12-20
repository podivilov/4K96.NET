function _signup() {
  if [[ "$IS_CONNECTED" == "1" ]]; then
    echo "Already connected."
  else
    tx_bytes "QUERY HELLO $DEFAULT_SUFFIX"
    rx_bytes "$DEFAULT_PREFIX 100 HELLO"
    tx_bytes "QUERY SIGNUP $1 $2 $DEFAULT_SUFFIX"
    RX=$(rx_bytes)
    if [[ "$RX" == "$DEFAULT_PREFIX 102 REGISTERED" ]]; then
      USERNAME="$1"
      PASSWORD="$2"
      IS_CONNECTED="1"
      echo "Registered as $1."
    elif [[ "$RX" == "$DEFAULT_PREFIX 202 FORBIDDEN" ]]; then
      echo "Incorrect login or password specified."
    elif [[ "$RX" == "$DEFAULT_PREFIX 203 FORBIDDEN" ]]; then
      echo "Username \"$1\" is already taken."
    elif [[ "$RX" == "$DEFAULT_PREFIX 204 FORBIDDEN" ]]; then
      echo "Registration is unavailable."
    else
      reset
    fi
  fi
}
