function _send() {
  if [[ "$IS_CONNECTED" == "0" ]]; then
    echo "Not connected."
  else
    if [[ -z "$1" ]]; then
      echo "Specify the name of the recipient."
      read -p "... " USERNAME
    else
      USERNAME="$1"
    fi
    echo "Type your message above. Use the \".\" symbol when done."
    read -p "... " -d "." MESSAGE
    echo -e "\\nSending message..."
    tx_bytes "QUERY SEND $USERNAME `echo \"$MESSAGE\" | base64 | tr -d '\040\011\012\015'` $DEFAULT_SUFFIX"
    RX=$(rx_bytes)
    if [[ "$RX" == "$DEFAULT_PREFIX 104 SENT" ]];  then
      echo "Message sent."
    elif [[ "$RX" == "$DEFAULT_PREFIX 205 STUCK" ]]; then
      echo "Something went wrong while data processing."
    elif [[ "$RX" == "$DEFAULT_PREFIX 206 ABSENT" ]]; then
      echo "The recipient does not exist."
    else
      reset
    fi
  fi
}
