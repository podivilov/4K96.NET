function _ping() {
  tx_bytes "QUERY PING $DEFAULT_SUFFIX"
  rx_bytes "$PROTOCOL_STUB 198 PONG"
  echo "Pong."
}
