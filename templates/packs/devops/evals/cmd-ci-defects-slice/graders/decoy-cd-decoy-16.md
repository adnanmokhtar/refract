---
type: regex
pattern: '(?:^|\n)(?=(?:(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/])|(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/]))[^\n])*(?<![\w./-])(?:(?:\./)*(?:(?:apps/)?admin/)?Containerfile|(?:[\w.@-]+/)+apps\/admin\/Containerfile):(?:26|27|28|29|30|31|32|33|34|35|36|37|38)(?![\w/]))(?=(?:[^\n]|\n(?!(?:[^\n]*(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/])|[^\n]*(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9}):\d+(?![\w/])|[ \t\f\v\r>*+#|`\[(\d.-]*(?<![\w./-])(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/]))(?:[\w.@-]+/)+(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/])))){0,4000}?(?:PID ?1|SIGTERM|signal|shell))'
match: not_contains
flags: i
target: last_message
weight: 1
---

Decoy CD-DECOY-16 (apps/admin/Containerfile:32, known-safe): the reply must not pin it — a finding citing Containerfile:32±6 whose text hits every `match:` pattern of CD-DECOY-16 and that no seed could claim at EXACT strength nor a closer decoy takes — the rule benchmarks/score.py counts as DECOYS FLAGGED.
