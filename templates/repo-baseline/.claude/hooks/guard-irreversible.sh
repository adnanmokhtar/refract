#!/usr/bin/env bash
# PreToolUse hook for Bash — the H3 gate (architecture proposal §4.4): an IRREVERSIBLE step against
# shared infrastructure, a deploy target or a shared database is approved by a human, every time.
#
# What it catches (per command segment, so `npm test && kubectl delete …` is caught):
#   IaC apply/destroy   terraform · tofu · terragrunt apply|destroy|import|taint|state rm|mv|push|test,
#                       pulumi up|destroy|refresh|import, cdk deploy|destroy, serverless deploy|remove,
#                       ansible-playbook without --check
#   clusters            kubectl / oc apply|create|delete|replace|patch|edit|scale|set|label|drain|exec…
#                       and rollout undo|restart|pause|resume — against ANY context, a local one included;
#                       helm install|upgrade|uninstall|rollback|push, helmfile apply|sync|destroy,
#                       argocd app sync|delete|rollback…, flux reconcile|suspend|delete…,
#                       kubectl argo rollouts promote|abort|undo…
#   cloud CLIs          aws <op> create-*|delete-*|update-*|put-*… and s3 rm|rb|mv|cp|sync to s3://,
#                       gcloud / gsutil / az / doctl / flyctl mutating verbs, vercel --prod|promote|
#                       rollback, netlify deploy --prod, heroku releases:rollback|ps:scale|config:set…,
#                       railway up|down, wrangler deploy|rollback|secret put, firebase deploy,
#                       docker push|stack deploy|service update, crane / skopeo copy|push|delete
#   shared databases    a migrate / rollback / drop / reset / push from prisma, alembic, manage.py,
#                       rails, knex, sequelize, typeorm, flyway, liquibase, goose, migrate, dbmate,
#                       sqlx, diesel, atlas, drizzle-kit, mikro-orm, dotnet ef, artisan, ecto, supabase,
#                       redis-cli flushall — ONLY when the target is not local: a non-local host in a
#                       URL on the command line, a production/staging environment marker
#                       (RAILS_ENV=production, --env prod …), or, with neither, a non-local
#                       $DATABASE_URL in this hook's environment. `supabase db push` targets the
#                       linked remote by default and is asked unless --local or a local --db-url.
#   release tags        git push of a tag (--tags, --follow-tags, refs/tags/, a v1.2.3-shaped ref,
#                       a tag delete), gh release create|delete|edit|upload
# What it allows: plan / diff / preview / template / lint / validate / get / describe / list / logs /
# status / history, `--dry-run` (client, server or bare — never `--dry-run=none`), `--dryrun`,
# `what-if`, `ansible-playbook --check`, preview deploys (vercel without --prod, netlify without
# --prod), a local migration, a local `git tag`, and any mention inside echo / printf / a commit message.
#
# THE SPLIT WITH guard-destructive.sh (no command is blocked twice). guard-destructive owns LOCAL and
# git-history destruction and literal SQL: rm -rf, dd/mkfs, chmod 777, curl|sh, git reset --hard /
# clean -f / branch -D, push to a protected branch, force push, DROP/TRUNCATE/DELETE-without-WHERE,
# npm/cargo/gem/twine publish. It DENIES. This hook owns REMOTE state changes and ASKS. Neither
# re-implements the other's rules; a command that trips both (a tag pushed together with a protected
# branch) is denied, because Claude Code ranks PreToolUse decisions deny > defer > ask > allow.
#
# THE DECISION (approval path = H3). Facts read 2026-10-19 from code.claude.com/docs/en/hooks and
# /permission-modes: a PreToolUse hook's `permissionDecision: "ask"` prompts the user and its reason is
# shown in the prompt; in auto mode a hook "ask" forces the prompt (the classifier can still deny, it
# cannot approve silently; since v2.1.211); dontAsk auto-denies anything that would prompt;
# bypassPermissions shows no prompt; exit 2 routes like "deny" with stderr as the reason.
#   main session, prompts on            → "ask" (exit 0, JSON on stdout): the human approves or not
#   permission_mode bypassPermissions | dontAsk → deny (exit 2): nobody would see the prompt
#   inside a subagent (agent_type set)  → deny (exit 2): a subagent hands the exact command back to
#                                         the main session; it never runs an irreversible step itself
#   REFRACT_IRREVERSIBLE=deny           → deny everywhere (CI, unattended runs)
# Malformed input: the command is recovered from the raw payload and judged the same way, so a
# payload that cannot be parsed still asks on `terraform apply` and stays silent on `ls`.
#
# Honest limits: a wrapper that hides the tool (`make deploy`, `npm run release`, a script file) is
# not opened — the step inside it is not seen; a DB URL that lives only in a .env file the tool reads
# is not seen either (the environment marker and $DATABASE_URL are). Static text, not intent: a
# heredoc body that spells `terraform apply` on its own line is asked about.
#
# Opt out per project: .claude/.no-guard-irreversible
# Tests: tests/hooks/run.sh § guard-irreversible (ask / allow / block / malformed cases).
set -uo pipefail

[ -f ".claude/.no-guard-irreversible" ] && exit 0

payload=$(cat)
[ -z "$payload" ] && exit 0

cmd=""; mode=""; agent=""; parsed=0
if command -v jq >/dev/null 2>&1 && printf '%s' "$payload" | jq -e 'type == "object"' >/dev/null 2>&1; then
  parsed=1
  cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)
  mode=$(printf '%s' "$payload" | jq -r '.permission_mode // empty' 2>/dev/null)
  agent=$(printf '%s' "$payload" | jq -r '.agent_type // empty' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  out=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(3)
if not isinstance(d, dict):
    sys.exit(3)
ti = d.get("tool_input") or {}
c = ti.get("command") if isinstance(ti, dict) else ""
for v in (d.get("permission_mode") or "", d.get("agent_type") or ""):
    print(str(v).replace("\n", " "))
print(c or "")
' 2>/dev/null) && { parsed=1; mode=$(printf '%s\n' "$out" | sed -n 1p); agent=$(printf '%s\n' "$out" | sed -n 2p); cmd=$(printf '%s\n' "$out" | sed -n '3,$p'); }
fi
if [ "$parsed" = 0 ]; then
  # Not JSON (or no parser): recover what we can from the raw text, never assume it is safe.
  # the value up to its closing unescaped quote, or to the end of a truncated payload
  cmd=$(printf '%s' "$payload" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n1)
  [ -z "$cmd" ] && cmd=$(printf '%s' "$payload" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*).*/\1/p' | head -n1)
  cmd=$(printf '%s' "$cmd" | sed 's/\\"/"/g')
  [ -z "$cmd" ] && cmd=$(printf '%s' "$payload" | tr '{}[],' '\n\n\n\n\n')
  mode=$(printf '%s' "$payload" | sed -n 's/.*"permission_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  agent=$(printf '%s' "$payload" | sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi
[ -z "$cmd" ] && exit 0

# Fast path: no tool this hook knows is named anywhere → nothing to judge.
TOOLS='terraform|tofu|terragrunt|pulumi|cdk|serverless|sls|ansible-playbook|kubectl|oc|helm|helmfile|argocd|flux|aws|gcloud|gsutil|az|doctl|flyctl|fly|vercel|netlify|heroku|railway|wrangler|firebase|docker|podman|crane|skopeo|prisma|alembic|manage\.py|django-admin|rails|rake|knex|sequelize|typeorm|flyway|liquibase|goose|migrate|dbmate|sqlx|diesel|atlas|drizzle-kit|mikro-orm|ef|artisan|mix|supabase|redis-cli|git|gh'
printf '%s' "$cmd" | grep -qE "(^|[^A-Za-z0-9_.-])($TOOLS)([^A-Za-z0-9_-]|$)" || exit 0

LOCAL_HOST='^(localhost|127\.[0-9.]+|0\.0\.0\.0|::1|\[::1\]|host\.docker\.internal|[A-Za-z0-9_-]+|[A-Za-z0-9.-]+\.(localhost|local|internal\.test))$'
PROD_HINT='(^|[[:space:]])([A-Z_]*(ENV|ENVIRONMENT|STAGE)=|--(env|environment|stage)[=[:space:]]+|-e[[:space:]]+|--settings=[^[:space:]]*|DJANGO_SETTINGS_MODULE=[^[:space:]]*)(prod|production|staging|stg|live)([^A-Za-z0-9]|$)'

# ── helpers over the current segment ($rest = the tool's arguments, space-padded) ──────────────────
rest=""; seg_full=""
tok() { local w; for w in "$@"; do case " $rest " in *" $w "*) return 0 ;; esac; done; return 1; }
rx()  { printf ' %s ' "$rest" | grep -qE "$1"; }
words() { printf '%s\n' $rest | grep -v '^-' ; }           # non-flag tokens, in order
first_word_in() {                                           # first non-flag token that is in the list
  local w l
  for w in $(words); do for l in "$@"; do [ "$w" = "$l" ] && { printf '%s' "$w"; return 0; }; done; done
  return 1
}
dry_run() {
  rx '[[:space:]]--dry-run=(none|false)[[:space:]]' && return 1
  rx '[[:space:]](--dry-run(=(client|server|true|all))?|--dryrun|--what-if|--preview-only)[[:space:]]'
}

# Is the database this segment targets a shared one?
db_remote() {
  local urls u h
  urls=$(printf '%s\n' "$seg_full" | grep -oE '[A-Za-z][A-Za-z0-9+.-]*://[^[:space:]]+')
  if [ -n "$urls" ]; then
    for u in $urls; do
      case "$u" in sqlite*|file:*) continue ;; esac
      h=$(printf '%s' "$u" | sed -E 's#^[A-Za-z][A-Za-z0-9+.-]*://##; s#^[^@/]*@##; s#^\[([^]]*)\].*#[\1]#; s#[:/?].*$##')
      [ -z "$h" ] && continue
      printf '%s' "$h" | grep -qE "$LOCAL_HOST" || return 0
    done
    return 1
  fi
  printf ' %s ' "$seg_full" | grep -qE "$PROD_HINT" && return 0
  if [ -n "${DATABASE_URL:-}" ]; then
    h=$(printf '%s' "$DATABASE_URL" | sed -E 's#^[A-Za-z][A-Za-z0-9+.-]*://##; s#^[^@/]*@##; s#[:/?].*$##')
    case "$DATABASE_URL" in sqlite*|file:*) return 1 ;; esac
    [ -n "$h" ] && ! printf '%s' "$h" | grep -qE "$LOCAL_HOST" && return 0
  fi
  return 1
}

# judge <tool> → prints the reason and returns 0 when the segment is irreversible.
judge() {
  local t="$1" v
  case "$t" in
    terraform|tofu|terragrunt)
      v=$(first_word_in apply destroy import taint untaint force-unlock test state workspace run-all run plan init validate fmt show output graph providers version console login get refresh) || return 1
      case "$v" in
        apply|destroy|import|taint|untaint|force-unlock|refresh) echo "$t $v changes real infrastructure state"; return 0 ;;
        test) echo "$t test applies real resources unless every run block uses command = plan or a mock provider"; return 0 ;;
        state) tok rm mv push replace-provider && { echo "$t state rm|mv|push rewrites shared state"; return 0; } ;;
        workspace) tok delete && { echo "$t workspace delete"; return 0; } ;;
        run-all|run) tok apply destroy && { echo "$t $v apply|destroy across modules"; return 0; } ;;
      esac ;;
    pulumi)
      v=$(first_word_in up update destroy refresh import cancel state stack preview) || return 1
      case "$v" in
        up|update|destroy|refresh|import|cancel) echo "pulumi $v changes a stack"; return 0 ;;
        state) tok delete unprotect rename move repair edit && { echo "pulumi state edit"; return 0; } ;;
        stack) tok rm && { echo "pulumi stack rm"; return 0; } ;;
      esac ;;
    cdk)          first_word_in deploy destroy bootstrap import rollback >/dev/null && { echo "cdk deploy/destroy changes CloudFormation stacks"; return 0; } ;;
    serverless|sls)
      v=$(first_word_in deploy remove rollback) && { echo "serverless $v"; return 0; } ;;
    ansible-playbook)
      rx '[[:space:]](--check|-C|--syntax-check|--list-hosts|--list-tasks|--list-tags)[[:space:]]' && return 1
      echo "ansible-playbook without --check changes the hosts it targets"; return 0 ;;
    kubectl|oc|kubectl-argo-rollouts)
      dry_run && return 1
      if [ "$t" = kubectl-argo-rollouts ] || tok argo; then
        tok promote abort retry undo restart set pause resume create terminate && { echo "argo rollouts mutation"; return 0; }
        return 1
      fi
      v=$(first_word_in apply create delete replace patch edit scale autoscale set label annotate taint cordon uncordon drain expose run cp exec attach debug certificate rollout get describe logs top explain diff kustomize version api-resources api-versions config auth cluster-info events wait port-forward proxy plugin completion) || return 1
      case "$v" in
        apply|create|delete|replace|patch|edit|scale|autoscale|set|label|annotate|taint|cordon|uncordon|drain|expose|run|cp|exec|attach|debug|certificate)
          echo "$t $v against a cluster (any context)"; return 0 ;;
        rollout) tok undo restart pause resume && { echo "$t rollout undo|restart|pause|resume"; return 0; } ;;
      esac ;;
    helm)
      dry_run && return 1
      v=$(first_word_in install upgrade uninstall delete del un rollback push template lint list ls status history get show diff search repo dependency dep version package pull verify env create plugin) || return 1
      case "$v" in install|upgrade|uninstall|delete|del|un|rollback|push) echo "helm $v changes a release"; return 0 ;; esac ;;
    helmfile)
      v=$(first_word_in apply sync destroy delete diff template lint build list status) || return 1
      case "$v" in apply|sync|destroy|delete) echo "helmfile $v"; return 0 ;; esac ;;
    argocd)
      dry_run && return 1
      tok sync delete rollback set create patch terminate-op add rm actions && { echo "argocd mutation"; return 0; } ;;
    flux)
      v=$(first_word_in reconcile suspend resume delete create bootstrap install uninstall get diff tree logs check stats export trace events build) || return 1
      case "$v" in reconcile|suspend|resume|delete|create|bootstrap|install|uninstall) echo "flux $v"; return 0 ;; esac ;;
    aws)
      dry_run && return 1
      case "$(words | head -n1)" in configure|help|sso|login|"") return 1 ;; esac
      if tok s3; then
        tok rm rb mv && { echo "aws s3 delete/move"; return 0; }
        if tok cp sync; then
          v=$(words | tail -n1); case "$v" in s3://*) echo "aws s3 write to $v"; return 0 ;; esac
        fi
        return 1
      fi
      for v in $(words); do
        printf '%s' "$v" | grep -qE '^(create|delete|update|put|terminate|stop|start|reboot|modify|run|deregister|register|attach|detach|associate|disassociate|remove|revoke|authorize|restore|deploy|publish|invoke|execute|cancel|reset|replace|set|tag|untag|enable|disable|import|copy|promote|failover|apply|send|purge|rotate|change|batch|upload|reject|accept|release|allocate|increase|decrease|swap|rollback|continue|abort|complete|initiate|submit|signal|suspend|resume|assign|unassign|merge|admin|force)(-|$)' \
          && { echo "aws $v"; return 0; }
      done ;;
    gcloud)
      case "$(words | head -n1)" in config|auth|info|help|version|components|topic|"") return 1 ;; esac
      tok create delete update deploy patch resize start stop reset restart suspend resume import rollback promote failover restore apply replace submit remove add set unset attach detach migrate upgrade cancel rm mv \
        add-iam-policy-binding remove-iam-policy-binding set-iam-policy set-traffic update-traffic && { echo "gcloud mutation"; return 0; }
      if tok cp rsync; then v=$(words | tail -n1); case "$v" in gs://*) echo "gcloud storage write to $v"; return 0 ;; esac; fi ;;
    gsutil)
      tok rm rb mv setmeta ch acl iam lifecycle retention && { echo "gsutil mutation"; return 0; }
      if tok cp rsync; then v=$(words | tail -n1); case "$v" in gs://*) echo "gsutil write to $v"; return 0 ;; esac; fi ;;
    az)
      rx '[[:space:]](--what-if|what-if)[[:space:]]' && return 1
      case "$(words | head -n1)" in account|login|logout|config|extension|version|cloud|find|feedback|interactive|upgrade|bicep|"") return 1 ;; esac
      tok create delete update set deploy start stop restart purge import swap scale restore failover apply remove add assign up config-zip invoke run-command && { echo "az mutation"; return 0; } ;;
    doctl)
      for v in $(words); do
        printf '%s' "$v" | grep -qE '^(create|delete|update|deploy|apply|resize|power-off|power-on|power-cycle|reboot|restore|rebuild|snapshot|attach|detach|tag|untag|add|remove|destroy|upgrade|migrate|reset|set|unset|retry|cancel|rollback|promote|scale)(-|$)' \
          && { echo "doctl $v"; return 0; }
      done ;;
    flyctl|fly)
      tok deploy destroy scale launch restart stop start update create delete remove rm attach detach import extend fork suspend resume unset set promote failover rollback clone move swap kill release && { echo "$t mutation"; return 0; } ;;
    vercel)
      rx '[[:space:]](--prod|--production|--target(=|[[:space:]]+)production)[[:space:]]' && { echo "vercel production deploy"; return 0; }
      tok promote rollback rm remove redeploy && { echo "vercel promote/rollback/remove"; return 0; }
      tok alias domains dns env && tok set add rm remove import && { echo "vercel alias/domain/env change"; return 0; } ;;
    netlify)
      tok deploy && rx '[[:space:]](--prod|--prod-if-unlocked)[[:space:]]' && { echo "netlify production deploy"; return 0; }
      rx '[[:space:]](sites:delete|env:set|env:unset|env:import|env:clone)[[:space:]]' && { echo "netlify site/env change"; return 0; } ;;
    heroku)
      rx '[[:space:]](releases:rollback|rollback|ps:scale|scale|ps:restart|restart|config:set|config:unset|config:add|apps:destroy|destroy|pg:reset|pg:promote|pg:killall|pg:backups:restore|addons:create|addons:destroy|maintenance:on|maintenance:off|pipelines:promote|container:release|container:push|domains:add|domains:remove|features:enable|features:disable)[[:space:]]' \
        && { echo "heroku change"; return 0; } ;;
    railway)      first_word_in up down redeploy delete >/dev/null && { echo "railway deploy/delete"; return 0; } ;;
    wrangler)
      dry_run && return 1
      v=$(first_word_in deploy publish delete rollback versions secret d1 kv r2) || return 1
      case "$v" in
        deploy|publish|delete|rollback) echo "wrangler $v"; return 0 ;;
        versions) tok deploy && { echo "wrangler versions deploy"; return 0; } ;;
        secret) tok put delete bulk && { echo "wrangler secret change"; return 0; } ;;
        d1) tok --remote && tok execute apply && { echo "wrangler d1 against the remote database"; return 0; } ;;
        kv|r2) tok put delete && ! tok --local && { echo "wrangler $v write"; return 0; } ;;
      esac ;;
    firebase)
      rx '[[:space:]]hosting:channel:deploy[[:space:]]' && return 1
      rx '[[:space:]](deploy|hosting:disable|[a-z]+(:[a-z]+)*:delete|database:(set|update|push|remove)|auth:import|remoteconfig:rollback)[[:space:]]' && { echo "firebase deploy/delete"; return 0; } ;;
    docker|podman)
      v=$(first_word_in push image buildx stack service) || return 1
      case "$v" in
        push) echo "$t push overwrites a registry tag"; return 0 ;;
        image) tok push && { echo "$t image push"; return 0; } ;;
        buildx) tok --push && { echo "$t buildx --push"; return 0; }; rx '[[:space:]]--output[=[:space:]][^[:space:]]*push=true' && { echo "$t buildx push"; return 0; } ;;
        stack) tok deploy up rm remove && { echo "$t stack deploy/rm"; return 0; } ;;
        service) tok create update rm remove scale rollback && { echo "$t service change"; return 0; } ;;
      esac ;;
    crane)        first_word_in push copy cp tag delete mutate append rebase flatten >/dev/null && { echo "crane registry write"; return 0; } ;;
    skopeo)       first_word_in copy delete sync >/dev/null && { echo "skopeo registry write"; return 0; } ;;
    git)
      [ "$(words | head -n1)" = push ] || return 1
      rx '[[:space:]](--tags|--follow-tags)[[:space:]]|refs/tags/|[[:space:]]:?v?[0-9]+\.[0-9]+(\.[0-9]+)?([.+-][A-Za-z0-9.+-]*)?[[:space:]]' \
        && { echo "git push of a release tag"; return 0; } ;;
    gh)
      [ "$(words | head -n1)" = release ] && tok create delete edit upload && { echo "gh release change"; return 0; } ;;
    # ── shared databases: only when the target is not local ──────────────────────────────────────
    prisma)
      { { tok migrate && tok deploy dev reset resolve; } || { tok db && tok push execute seed; }; } && db_remote && { echo "prisma migrate/db push against a non-local database"; return 0; } ;;
    alembic)      tok upgrade downgrade stamp && db_remote && { echo "alembic against a non-local database"; return 0; } ;;
    manage.py|django-admin)
      tok migrate flush && db_remote && { echo "django migrate/flush against a non-local database"; return 0; } ;;
    rails|rake)
      rx '[[:space:]]db:(migrate|rollback|drop|reset|schema:load|setup|prepare|purge|truncate_all|seed)' && db_remote && { echo "rails db task against a non-local database"; return 0; } ;;
    knex)         rx '[[:space:]](migrate:(latest|rollback|up|down|unlock)|seed:run)[[:space:]]' && db_remote && { echo "knex migrate against a non-local database"; return 0; } ;;
    sequelize|sequelize-cli)
      rx '[[:space:]]db:(migrate|drop|seed)' && db_remote && { echo "sequelize db task against a non-local database"; return 0; } ;;
    typeorm|typeorm-ts-node-commonjs|typeorm-ts-node-esm)
      rx '[[:space:]](migration:(run|revert)|schema:(drop|sync))[[:space:]]' && db_remote && { echo "typeorm against a non-local database"; return 0; } ;;
    flyway)       tok migrate clean undo repair baseline && db_remote && { echo "flyway against a non-local database"; return 0; } ;;
    liquibase)
      for v in $(words); do
        case "$v" in *-sql|*Sql|*SQL) continue ;; esac
        printf '%s' "$v" | grep -qE '^(update|rollback|drop-?all|dropAll|changelog-?sync|changelogSync|clear-?check-?sums|clearCheckSums)' && db_remote && { echo "liquibase $v against a non-local database"; return 0; }
      done ;;
    goose)        tok up up-by-one up-to down down-to redo reset && db_remote && { echo "goose against a non-local database"; return 0; } ;;
    migrate)      tok up down drop force goto && db_remote && { echo "migrate against a non-local database"; return 0; } ;;
    dbmate)       tok up down drop rollback migrate create && db_remote && { echo "dbmate against a non-local database"; return 0; } ;;
    sqlx)         { { tok migrate && tok run revert; } || { tok database && tok drop reset create setup; }; } && db_remote && { echo "sqlx against a non-local database"; return 0; } ;;
    diesel)       { { tok migration && tok run revert redo; } || { tok database && tok reset drop setup; }; } && db_remote && { echo "diesel against a non-local database"; return 0; } ;;
    atlas)
      dry_run && return 1
      { { tok migrate && tok apply down; } || { tok schema && tok apply clean; }; } && db_remote && { echo "atlas apply against a non-local database"; return 0; } ;;
    drizzle-kit)  tok push migrate drop && db_remote && { echo "drizzle-kit against a non-local database"; return 0; } ;;
    mikro-orm)    rx '[[:space:]](migration:(up|down|fresh)|schema:(drop|update|fresh|create))[[:space:]]' && db_remote && { echo "mikro-orm against a non-local database"; return 0; } ;;
    ef)           tok database && tok update drop && db_remote && { echo "ef database update/drop against a non-local database"; return 0; } ;;
    artisan)      rx '[[:space:]](migrate(:fresh|:rollback|:reset|:refresh)?|db:wipe|db:seed)[[:space:]]' && db_remote && { echo "artisan migrate against a non-local database"; return 0; } ;;
    mix)          rx '[[:space:]]ecto\.(migrate|rollback|drop|reset)[[:space:]]' && db_remote && { echo "ecto against a non-local database"; return 0; } ;;
    supabase)
      if tok db && tok push; then
        rx '[[:space:]]--local[[:space:]]' && return 1
        if printf '%s' "$seg_full" | grep -q -- '--db-url'; then db_remote || return 1; fi
        echo "supabase db push targets the linked remote project"; return 0
      fi
      { { tok db && tok reset; } || { tok migration && tok up repair; }; } && { tok --linked || db_remote; } && { echo "supabase against the remote database"; return 0; } ;;
    redis-cli)
      rx '[[:space:]](flushall|flushdb|FLUSHALL|FLUSHDB)[[:space:]]' || return 1
      if rx '[[:space:]]-h[[:space:]]+'; then
        rx '[[:space:]]-h[[:space:]]+(localhost|127\.0\.0\.1)[[:space:]]' && return 1
      else
        db_remote || return 1
      fi
      echo "redis-cli flush on a non-local server"; return 0 ;;
  esac
  return 1
}

# ── walk every segment of the command line ──────────────────────────────────────────────────────
set -f
BT='`'
segments=$(printf '%s\n' "$cmd" | tr -d "\"'" | tr ";&|()$BT" '\n\n\n\n\n\n')
reason=""; hit=""
while IFS= read -r seg; do
  [ -z "${seg// /}" ] && continue
  seg_full="$seg"
  # shellcheck disable=SC2086 # word-splitting the segment is the point (globbing is off: set -f)
  set -- $seg
  while [ $# -gt 0 ]; do
    case "$1" in
      sudo|doas|time|nohup|command|exec|builtin|nice|ionice|stdbuf|caffeinate|env|eval|xargs|then|do|else|'{'|'!') shift ;;
      [A-Za-z_]*=*) shift ;;
      -*) shift ;;
      bash|sh|zsh|dash|ksh)
        case "${2:-}" in -c|-lc|-ec|-xc|-cl|-ce) shift 2 ;; *) break ;; esac ;;
      npx|bunx|pnpx) shift ;;
      pnpm|yarn|npm|bun)
        case "${2:-}" in exec|dlx|x) shift 2 ;; *) break ;; esac ;;
      uv|poetry|pipenv|bundle|hatch|pdm)
        case "${2:-}" in run|exec) shift 2 ;; *) break ;; esac ;;
      python|python3|php)
        # `python manage.py migrate`, `python -m alembic upgrade`, `php artisan migrate`
        shift
        while [ $# -gt 0 ]; do case "$1" in -m) shift; break ;; -*) shift ;; *) break ;; esac; done ;;
      dotnet)
        if [ "${2:-}" = ef ]; then shift; else break; fi ;;
      *) break ;;
    esac
  done
  [ $# -eq 0 ] && continue
  t="${1##*/}"; shift
  rest="$*"
  if r=$(judge "$t"); then
    reason="$r"; hit="$seg_full"; break
  fi
done <<EOF
$segments
EOF
set +f

[ -z "$reason" ] && exit 0

excerpt=$(printf '%s' "$hit" | tr -s '[:space:]' ' ' | sed 's/^ //' | cut -c1-160)
deny() {
  echo "Blocked by guard-irreversible (H3): $reason — \`$excerpt\`." >&2
  echo "$1" >&2
  exit 2
}
if [ "${REFRACT_IRREVERSIBLE:-}" = deny ]; then
  deny "REFRACT_IRREVERSIBLE=deny is set: irreversible steps are refused in this environment. A human runs it from a terminal."
fi
if [ -n "$agent" ]; then
  deny "Subagent '$agent' never runs an irreversible step. Return the exact command (and its rollback) to the main session; the human runs or approves it there."
fi
case "$mode" in
  bypassPermissions|dontAsk)
    deny "Permission prompts are off in this session ($mode), and H3 needs a human to approve. Run it yourself in a terminal, or switch to a mode that prompts." ;;
esac

msg="H3 irreversible step — $reason: \`$excerpt\`. Approve only if this change to a shared environment is intended now and its rollback is known (/release and /rollback-deploy print both). guard-irreversible.sh"
if command -v jq >/dev/null 2>&1; then
  jq -cn --arg r "$msg" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
else
  esc=$(printf '%s' "$msg" | tr '\n\t' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$esc"
fi
exit 0
