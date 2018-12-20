function _logout() {
  if [[ "$IS_CONNECTED" == "0" ]]; then
    echo "Not connected."
  else
    tx_bytes "QUERY LOGOUT $DEFAULT_SUFFIX"
    rx_bytes "$DEFAULT_PREFIX 199 LOGOUT"
    IS_CONNECTED="0"
    echo "Logged out."
  fi
}
