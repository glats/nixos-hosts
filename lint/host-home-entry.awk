function finish() {
  if (host != "" && !found) {
    printf "homeConfigurations.%s must load ./hosts/%s/home/default.nix through extraModules.\n", host, host
    printf "Do not import a platform module such as ./darwin/home directly; the host entry imports it (see commit 62029feb).\n"
    bad = 1
  }
}
/homeConfigurations =/ { inside = 1; next }
inside && /hostname = "/ {
  finish()
  match($0, /"[^"]+"/)
  host = substr($0, RSTART + 1, RLENGTH - 2)
  found = 0
}
inside && host != "" && index($0, "./hosts/" host "/home/default.nix") { found = 1 }
END { finish(); exit bad }
