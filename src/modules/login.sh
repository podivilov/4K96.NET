function _login() {
  if [[ "$IS_CONNECTED" == "1" ]]; then
    echo "Already connected."
  else
    tx_bytes "QUERY HELLO $DEFAULT_SUFFIX"
    rx_bytes "$DEFAULT_PREFIX 100 HELLO"
    tx_bytes "QUERY LOGIN $1 $2 $DEFAULT_SUFFIX"
    RX=$(rx_bytes)
    if [[ "$RX" == "$DEFAULT_PREFIX 101 AUTHORIZED" ]]; then
      USERNAME="$1"
      PASSWORD="$2"
      IS_CONNECTED="1"
      echo "Logged in as $1."
    elif [[ "$RX" == "$DEFAULT_PREFIX 201 FORBIDDEN" ]]; then
      echo "Incorrect login or password specified."
    else
      reset
    fi
  fi
}
