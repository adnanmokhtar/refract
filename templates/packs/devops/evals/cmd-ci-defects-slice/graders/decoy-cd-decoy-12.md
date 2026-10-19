---
type: regex
pattern: '(?:^|\n)(?=(?:(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/])|(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/]))[^\n])*(?<![\w./-])(?:(?:\./)*(?:(?:apps/)?admin/)?Containerfile|(?:[\w.@-]+/)+apps\/admin\/Containerfile):(?:9|10|11|12|13|14|15|16|17|18|19|20|21)(?![\w/]))(?=(?:[^\n]|\n(?!(?:[^\n]*(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/])|[^\n]*(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9}):\d+(?![\w/])|[ \t\f\v\r>*+#|`\[(\d.-]*(?<![\w./-])(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/]))(?:[\w.@-]+/)+(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/])))){0,4000}?(?:npm ci|lockfile|frozen))'
match: not_contains
flags: i
target: last_message
weight: 1
---

Decoy CD-DECOY-12 (apps/admin/Containerfile:15, known-safe): the reply must not pin it — a finding citing Containerfile:15±6 whose text hits every `match:` pattern of CD-DECOY-12 and that no seed could claim at EXACT strength nor a closer decoy takes — the rule benchmarks/score.py counts as DECOYS FLAGGED.
