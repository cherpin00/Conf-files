function ip() {
  host="$1"
  host $host | awk '{print $NF}'
}
