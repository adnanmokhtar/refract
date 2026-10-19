---
type: regex
pattern: '(?:^|\n)(?=(?:(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/])|(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/]))[^\n])*(?<![\w./-])(?:(?:\./)*(?:(?:apps/)?worker/)?Dockerfile|(?:[\w.@-]+/)+apps\/worker\/Dockerfile):(?:14|15|16|17|18|19|20|21|22|23|24|25|26)(?![\w/]))(?=(?:[^\n]|\n(?!(?:[^\n]*(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/])|[^\n]*(?<![\w./-])(?:[\w.@-]+/)*(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9}):\d+(?![\w/])|[ \t\f\v\r>*+#|`\[(\d.-]*(?<![\w./-])(?!(?<![\w./-])(?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5}(?::\d+)?(?![\w/]))(?:[\w.@-]+/)+(?:(?:dockerfile|containerfile|jenkinsfile|caddyfile|makefile|justfile|codeowners|procfile|gemfile|rakefile|brewfile|vagrantfile|tiltfile)(?:\.[\w-]+)?|\.env(?:\.[\w-]+)?|[\w@-][\w.@-]*\.[A-Za-z][A-Za-z0-9]{6,9})(?::\d+)?(?![\w/])))){0,4000}?(?:port|3000|8081|HEALTHCHECK))'
flags: i
target: last_message
weight: 1
---

Seed CD-CB-06b (container/healthcheck-wrong-port, apps/worker/Dockerfile:20): a finding whose opening line cites Dockerfile:20±6 first and which, before the next line carrying a path, hits every `match:` pattern of CD-CB-06b in benchmarks/fixtures/ci-defects/DEFECTS.md — the rule benchmarks/score.py credits under --strict-line.
