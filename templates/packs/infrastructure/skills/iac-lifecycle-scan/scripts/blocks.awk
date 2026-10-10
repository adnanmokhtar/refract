# blocks.awk — iac-lifecycle-scan / iac-state-scan / dr-audit: brace-aware HCL block splitter for
# ABSENCE checks. A regex negative lookahead is wrong here: a comment that names the attribute
# (`# no deletion_protection yet`) makes it match nothing (measured, research A § 4).
#
#   awk -v K='resource' -v T='aws_db_instance|aws_rds_cluster' -v NEED='deletion_protection *= *true' -f blocks.awk FILES…
#   awk -v K='variable' -v T='[^"]*(password|secret|token)[^"]*' -v NEED='sensitive *= *true' -f blocks.awk FILES…
#   awk -v K='resource' -v T='[a-z0-9_]+' -v HAVE='create_before_destroy *= *true' -v NEED='name_prefix' -f blocks.awk FILES…
#
# K     block keyword(s): resource, data, module, variable, output (default: resource)
# T     regex for the first label (the type, or the name for module/variable/output); empty for an
#       unlabelled block (K='terraform' finds root blocks lacking required_version)
# NEED  print the block when its comment-stripped body does NOT match this (empty: never)
# HAVE  … and only when the body DOES match this (default: every block). NEED and HAVE are POSIX
#       EREs: no \\b, no \\s — write ([^a-z_]|$) and [ \t]
# Prints `file:line: <header>` per block. `#` and ` //` comments are stripped before matching;
# braces inside strings count, which is safe for the attribute-level checks this is used for.
# POSIX awk (BSD awk on macOS, gawk, mawk). No output = no block of that type lacks NEED — or no
# block of that type exists: count the blocks with NEED='^$' before reading silence as a pass.
BEGIN { if (K == "") K = "resource"; if (HAVE == "") HAVE = "." }
function flush() { if (hdr != "" && body ~ HAVE && (NEED == "" ? 0 : body !~ NEED)) print hdr; hdr = ""; body = "" }
FNR == 1 { flush(); depth = 0 }
{ line = $0; sub(/#.*/, "", line); sub(/(^|[ \t])\/\/.*/, "", line) }
depth == 0 && match(line, T == "" ? "^[ \t]*(" K ")[ \t]*[{]" : "^[ \t]*(" K ")[ \t]+\"(" T ")\"") { flush(); hdr = FILENAME ":" FNR ": " substr(line, RSTART, RLENGTH) }
hdr != "" { body = body "\n" line }
{ n = gsub(/\{/, "{", line); m = gsub(/\}/, "}", line); depth += n - m; if (depth <= 0) { depth = 0; if (hdr != "" && n + m > 0) flush() } }
END { flush() }
