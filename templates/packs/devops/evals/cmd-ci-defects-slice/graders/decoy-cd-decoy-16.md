---
type: regex
pattern: '(?:^|\n)(?=[ \t\f\v\r>*+#|`\[(\d.-]*(?:(?:critical|high|medium|low|info|blocker|major|minor|nit|p[0-4]|site|sites|location|file|where|\[[^\]\n]{1,40}\])[ \t\f\v\r>*_|`:.,()\[\]\u2014\u2013\u00b7-]*)?(?<![\w./-])(?:(?:\./)*(?:(?:apps/)?admin/)?Containerfile|(?:[\w.@-]+/)+apps\/admin\/Containerfile):(?:26|27|28|29|30|31|32|33|34|35|36|37|38)(?![\w/]))(?=(?:[^\n]|\n(?!(?:[ \t\f\v\r>*+#|`\[(\d.-]*(?:(?:critical|high|medium|low|info|blocker|major|minor|nit|p[0-4]|site|sites|location|file|where|\[[^\]\n]{1,40}\])[ \t\f\v\r>*_|`:.,()\[\]\u2014\u2013\u00b7-]*)?(?:(?<![\w./-])(?:(?:[\w.@-]+/)+[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?|[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}:\d+)(?![\w/])|(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9}):\d+(?![\w/]))|[ \t\f\v\r>*+#|`\[(\d.-]*(?:(?:critical|high|medium|low|info|blocker|major|minor|nit|p[0-4]|site|sites|location|file|where|\[[^\]\n]{1,40}\])[ \t\f\v\r>*_|`:.,()\[\]\u2014\u2013\u00b7-]*)?(?<![\w./-])(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/]))(?:[\w.@-]+/)+(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/])))){0,4000}?(?:PID ?1|SIGTERM|signal|shell))'
match: not_contains
flags: i
target: last_message
weight: 1
---

Decoy CD-DECOY-16 (apps/admin/Containerfile:32, known-safe): the reply must not pin it — a finding citing Containerfile:32±6 whose text hits every `match:` pattern of CD-DECOY-16 and that no seed could claim at EXACT strength nor a closer decoy takes — the rule benchmarks/score.py counts as DECOYS FLAGGED.
