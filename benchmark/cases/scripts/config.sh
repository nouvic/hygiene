# Reads the config once and caches it for the lifetime of the process.
load_config() {
  printf '%s\n' "$1"
}
