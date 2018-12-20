function _list() {
  if [[ "$IS_CONNECTED" == "0" ]]; then
    echo "Not connected."
  else
    tx_bytes "QUERY LIST $DEFAULT_SUFFIX"
    RX=$(rx_bytes)
    if grep -q "$DEFAULT_PREFIX 103 DATA" <<<"$RX"; then
      if ! echo "$RX" | cut -d " " -f4 | base64 -d &>/dev/null; then
        reset
      else
        RX=$(echo "$RX" | cut -d " " -f4 | base64 -d)
      fi
      if [[ "$RX" -gt 0 ]]; then
        if [[ "$RX" == "1" ]]; then
          echo "You have $RX new message."
        else
          echo "You have $RX new messages."
        fi
      else
        echo "You have no new messages."
      fi
    elif [[ "$RX" == "$DEFAULT_PREFIX 205 STUCK" ]]; then
      echo "Something went wrong while data processing."
    else
      reset
    fi
  fi
}
