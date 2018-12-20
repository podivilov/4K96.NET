function _read() {
  if [[ "$IS_CONNECTED" == "0" ]]; then
    echo "Not connected."
  else
    tx_bytes "QUERY READ `echo $1` $DEFAULT_SUFFIX"
    RX=$(rx_bytes)
    if grep -q "$DEFAULT_PREFIX 103 DATA" <<<"$RX"; then
      if ! echo "$RX" | cut -d ' ' -f 4 | base64 -d &>/dev/null; then
        reset
      fi
      if echo "$RX" | cut -d ' ' -f 4 | base64 -d &>/dev/null; then
        DATA=$(echo "$RX" | cut -d ' ' -f 4 | base64 -d)
        EPOCH=$(echo "$DATA" | cut -d ' ' -f 1)
        SENDER=$(echo "$DATA" | cut -d ' ' -f 2)
        MESSAGE=$(echo "$DATA" | cut -d ' ' -f 3)
        if ! echo "$MESSAGE" | base64 -d &>/dev/null; then
          reset
        fi
        tx_bytes "QUERY RECD $DEFAULT_SUFFIX"
        RX=$(rx_bytes)
        if [[ "$RX" == "$DEFAULT_PREFIX 106 READY" ]]; then
          echo "Received message by $SENDER, which was sent `date -d @$EPOCH '+%d.%m.%y'` at `date -d @$EPOCH '+%H:%M'`."
          read -p"Press [Enter] to read the message..."
          echo "-----BEGIN PRIVATE MESSAGE-----"
          echo "$MESSAGE" | base64 -d | more
          echo "-----END PRIVATE MESSAGE-----"
        else
          reset
        fi
      else
        reset
      fi
    elif [[ "$RX" == "$DEFAULT_PREFIX 206 ABSENT" ]]; then
      echo "The message with index \"$1\" doesn't exist."
    else
      reset
    fi
  fi
}
