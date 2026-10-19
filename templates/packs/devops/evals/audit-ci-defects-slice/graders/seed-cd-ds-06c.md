---
type: regex
pattern: '(?:^|\n)(?=(?:(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/])|(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/]))[^\n])*(?<![\w./-])(?:(?:\./)*(?:(?:apps/)?worker/)?Dockerfile|(?:[\w.@-]+/)+apps\/worker\/Dockerfile):(?:1|2|3|4|5|6|7|8)(?![\w/]))(?=(?:[^\n]|\n(?!(?:[^\n]*(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/])|[^\n]*(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9}):\d+(?![\w/])|[ \t\f\v\r>*+#|`\[(\d.-]*(?<![\w./-])(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/]))(?:[\w.@-]+/)+(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/])))){0,4000}?(?:node.?20|nvmrc|22|runtime|engines))'
flags: i
target: last_message
weight: 1
---

Seed CD-DS-06c (parity/runtime-drift, apps/worker/Dockerfile:2): a finding whose opening line cites Dockerfile:2±6 first and which, before the next line carrying a path, hits every `match:` pattern of CD-DS-06c in benchmarks/fixtures/ci-defects/DEFECTS.md — the rule benchmarks/score.py credits under --strict-line.
