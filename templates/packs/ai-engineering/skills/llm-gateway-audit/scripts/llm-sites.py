#!/usr/bin/env python3
"""llm-sites.py — the shared LLM call-site inventory every ai-engineering detector reads first.
Stdlib only, Python 3.8+, run with `python3 -I -B`. Reads files; writes only under --out.

Why a script and not one rg: an LLM feature can call its provider through an SDK, through a framework,
or over raw HTTP to an OpenAI-compatible gateway with no SDK in the lockfile. A provider-name grep sees
the first, matches `cohere` inside "coherence", and misses the third entirely. This script finds call
sites by four lanes and records, per site, the budget and output properties the detectors grade.

Lanes (every match is word-bounded):
  sdk        provider SDK calls, guarded by the file's import where the call name is generic
             (`messages.create` counts only beside an Anthropic import or a `max_tokens`, so a Twilio
             `client.messages.create({ to, from })` is not a site)
  framework  Vercel AI SDK, LangChain / LangGraph, LlamaIndex, OpenAI Agents SDK, Anthropic tool
             runner, LiteLLM, Ollama, Bedrock runtime
  wire       request-body keys only LLM APIs use (`max_tokens`, `tool_choice`, `response_format`,
             `stream_options`, ...) and endpoint paths (`/chat/completions`, `/v1/responses`,
             `:generateContent`); `/v1/messages` counts only with `max_tokens` or `anthropic-version`
             beside it (an SMS `/v1/messages` client is not a site); hits within 15 lines are one site
  config     model / provider env reads (`*_MODEL`, `OPENAI_*`, `ANTHROPIC_*`, ...), tagged
             client-exposed when the name carries a bundler prefix (NEXT_PUBLIC_, VITE_, ...)
Kinds: call · client (client construction) · prompt (a role literal with content) · import (an SDK
  import in a file with no call) · config.
Per call site: provider, api, framework, model source (literal / env / config / ident / param),
  output cap, timeout and retries (an OpenAI or Anthropic SDK site with none prints
  `sdk-default:600s` / `sdk-default:2`, a number, not an absence), stream, include_usage, tools,
  tool_choice (auto / required / forced / none), strict, stop-reason read, refusal read, usage read,
  schema validation, the enclosing loop and its cap (or the framework that owns the loop), seam.
  The call-level columns are read in the call's window (30 lines above, 40 below); timeout, retries,
  stop / refusal / usage reads and validation are file-level, because clients and parsers sit beside
  the call, not in it. Every column is a CANDIDATE property: the detector reads the code.

Usage:  python3 -I -B llm-sites.py <root> [<root> ...] [--out=<dir>] [--seam=<glob>[,<glob>]]
            [--models[=<lifecycle.tsv>]] [--evals] [--strict] [--today=YYYY-MM-DD]
            [--include-tests] [--quiet]
        python3 -I -B llm-sites.py --self-test
  --models   join every model id in code (quoted), `.env*`, YAML / JSON / TOML / Terraform / Bicep
             config and eval configs against the dated table (default: model-lifecycle.tsv beside
             this script). Rows: RETIRED (date on or before --today), DEPRECATED (days left),
             PLATFORM (Bedrock / Vertex / Azure: read the platform's card), UNLISTED (verify
             against the provider's model list), plus `alias` for `-latest`. The table is STALE when
             its newest checked_on is more than 90 days before --today. CHANGELOG, docs, migrations
             and tests are never read (a retired id there is not MV-1).
  --evals    eval configs and code (promptfoo, DeepEval, Ragas, Inspect, LangSmith, Braintrust,
             pytest eval markers), datasets (rows, adversarial tags), CI jobs that run an eval (masked
             by `|| true` or `continue-on-error`, telemetry opt-out, pinned version, thresholds,
             `paths:` filters) and sunsetting platform calls from the table's `api` rows; adds the
             `eval_ref` column to sites (a site's file or folder named in an eval config or dataset).
             Test folders are read in this lane.
  --seam     the gateway module(s); sites outside are `out`. Without it the folder holding the most
             call and client sites is inferred and printed, never assumed.
  --strict   exit 4 when a RETIRED model row, a DEPRECATED row due within 30 days, a STALE table or
             a masked eval gate exists (the T-family oracle exit for V532 / V536).
Output: a summary and the tables on stdout; `sites.tsv`, `models.tsv`, `evals.tsv`, `versions.tsv`,
  `summary.txt` under --out (an --out inside a scanned root is refused). Stderr: unreadable paths.
Exit:   0 ran (sites or none) · 1 usage · 2 blocked: a root missing or unreadable, a directory under it
        unreadable (the output is partial), --out inside a root, or no file read · 3 self-test
        failed · 4 --strict gate fired.
"""
import datetime, fnmatch, json, os, re, shutil, subprocess, sys, tempfile

VERSION = "1.0.0"
CODE_EXT = ('.ts', '.tsx', '.mts', '.cts', '.js', '.jsx', '.mjs', '.cjs', '.py', '.go', '.rb', '.java',
            '.kt', '.cs', '.php', '.vue', '.svelte')
CONF_EXT = ('.yaml', '.yml', '.json', '.toml', '.tf', '.tfvars', '.bicep', '.ini', '.cfg', '.properties')
SKIP_DIRS = {'node_modules', 'vendor', 'dist', 'build', 'out', 'target', 'coverage', '.next', '.nuxt',
             '.turbo', '.cache', '.venv', 'venv', '__pycache__', 'generated', '__generated__', '.git',
             'storybook-static', 'migrations', 'migration', 'locales', 'locale', 'i18n', 'translations',
             'docs', '.claude', 'ai', 'Pods', '.dart_tool', 'bin', 'obj'}
TEST_DIRS = {'test', 'tests', '__tests__', 'spec', 'specs', 'e2e', 'fixtures', '__fixtures__', 'mocks',
             '__mocks__', 'testdata', 'cypress', 'playwright'}
TEST_FILE = re.compile(r'\.(spec|test|e2e-spec|stories|test-data|fixture|fixtures|d)\.[a-z]+$|^test_.*\.py$|'
                       r'_test\.(py|go)$|^conftest\.py$')
LOCK_FILE = {'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock', 'poetry.lock', 'uv.lock', 'Cargo.lock',
             'go.sum', 'composer.lock', 'Gemfile.lock', 'bun.lockb', 'package.json', 'tsconfig.json'}
MAX_BYTES = 2_000_000

IMPORTS = {  # tag -> import regex (word-bounded; `cohere` never matches "coherence")
    'openai': r'''(?:from\s+openai\b|import\s+openai\b|from\s+['"]openai['"]|require\(\s*['"]openai['"]|"github\.com/(?:openai/openai-go|sashabaranov/go-openai)|\bAzureOpenAI\b)''',
    'anthropic': r'''(?:from\s+anthropic\b|import\s+anthropic\b|['"]@anthropic-ai/sdk['"]|"github\.com/anthropics/anthropic-sdk-go|langchain[_-]anthropic)''',
    'gemini': r'''(?:from\s+google\s+import\s+genai|google\.genai\b|google\.generativeai\b|['"]@google/(?:genai|generative-ai)['"]|"google\.golang\.org/genai"|\bvertexai\b)''',
    'bedrock': r'''(?:bedrock-runtime|client-bedrock-runtime|BedrockRuntime)''',
    'mistral': r'''(?:from\s+mistralai\b|import\s+mistralai\b|['"]@mistralai/mistralai['"])''',
    'cohere': r'''(?:from\s+cohere\b|import\s+cohere\b|['"]cohere-ai['"])''',
    'ollama': r'''(?:from\s+ollama\b|import\s+ollama\b|['"]ollama['"])''',
    'litellm': r'''(?:from\s+litellm\b|import\s+litellm\b)''',
    'ai-sdk': r'''(?:from\s+['"]ai['"]|require\(\s*['"]ai['"]|['"]@ai-sdk/[\w-]+['"])''',
    'langchain': r'''(?:\blangchain[\w.]*\b|['"]@langchain/[\w-]+['"]|['"]langchain(?:/[\w/-]+)?['"]|\blangchaingo\b)''',
    'langgraph': r'''(?:\blanggraph\b|['"]@langchain/langgraph['"])''',
    'llamaindex': r'''(?:\bllama_index\b|['"]llamaindex['"])''',
    'openai-agents': r'''(?:from\s+agents\s+import|import\s+agents\b|['"]@openai/agents['"])''',
}
IMPORTS = {k: re.compile(v) for k, v in IMPORTS.items()}
IMPORT_LIT = {'openai': ('openai', 'OpenAI'), 'anthropic': ('anthropic',), 'gemini': ('genai', 'generativeai', 'vertexai'),
              'bedrock': ('edrock',), 'mistral': ('mistral',), 'cohere': ('cohere',), 'ollama': ('ollama',),
              'litellm': ('litellm',), 'ai-sdk': ("'ai'", '"ai"', '@ai-sdk/'), 'langchain': ('langchain',),
              'langgraph': ('langgraph',), 'llamaindex': ('llama_index', 'llamaindex'), 'openai-agents': ('agents',)}
# Literal tokens one of which every lane needs; a file with none (and no provider import) is never read line by line.
QUICK = ('completions', 'ChatCompletion', 'generateText', 'streamText', 'generateObject', 'streamObject', 'ToolLoopAgent',
         'Experimental_Agent', 'max_tokens', 'max_completion_tokens', 'max_output_tokens', 'tool_choice', 'response_format',
         'stream_options', 'maxOutputTokens', 'toolChoice', '/v1/', 'enerateContent', "'system'", '"system"',
         "'developer'", '"developer"', "'tool'", '"tool"', 'SystemMessage', 'system_instruction', 'instructions=')
ENV_HINT = re.compile(r'(?:AI|LLM|OPENAI|ANTHROPIC|CLAUDE|GEMINI|GENAI|GPT|BEDROCK|MISTRAL|COHERE|GROQ|OLLAMA|OPENROUTER|LITELLM)_|_MODEL\b|\bMODEL_|\bMODEL\b')
SDK_PROVIDERS = {'openai', 'anthropic'}

# (regex, api, provider, framework, required import tags or None, extra guard regex on the window)
CALLS = [
    (r'\.chat\.completions\.(?:create|parse|stream)\s*\(', 'chat', 'openai', 'openai', None, None),
    (r'\bChat\.Completions\.New\w*\s*\(|\bCreateChatCompletion\w*\s*\(', 'chat', 'openai', 'openai', None, None),
    (r'\.responses\.(?:create|parse|stream)\s*\(|\bResponses\.New\s*\(', 'responses', 'openai', 'openai', {'openai'}, None),
    (r'\bopenai\.ChatCompletion\.create\s*\(', 'chat', 'openai', 'openai', None, None),
    (r'\.embeddings\.create\s*\(', 'embed', 'openai', 'openai', {'openai'}, None),
    (r'\.messages\.(?:create|stream|count_tokens)\s*\(|\bMessages\.New\s*\(', 'messages', 'anthropic', 'anthropic', {'anthropic'}, None),
    (r'\.messages\.(?:create|stream)\s*\(', 'messages', 'anthropic', 'anthropic', None, r'\bmax_tokens\b'),
    (r'\.beta\.messages\.tool_runner\s*\(|\btoolRunner\s*\(', 'tool-runner', 'anthropic', 'anthropic-tool-runner', {'anthropic'}, None),
    (r'\.(?:generate_content|generateContent|generate_content_stream|generateContentStream)\s*\(', 'generate', 'gemini', 'gemini', {'gemini'}, None),
    (r'\.(?:invoke_model|invoke_model_with_response_stream|converse|converse_stream)\s*\(|\bnew\s+(?:InvokeModel|Converse)(?:Stream)?Command\s*\(', 'bedrock', 'bedrock', 'bedrock', {'bedrock'}, None),
    (r'\b(?:generateText|streamText|generateObject|streamObject)\s*\(', 'ai-sdk', 'ai-sdk', 'ai-sdk', None, None),
    (r'\b(?:embed|embedMany)\s*\(', 'embed', 'ai-sdk', 'ai-sdk', {'ai-sdk'}, None),
    (r'\bnew\s+(?:ToolLoopAgent|Experimental_Agent)\s*\(', 'agent', 'ai-sdk', 'ai-sdk', None, None),
    (r'\b(?:create_react_agent|create_agent|create_tool_calling_agent|create_openai_tools_agent)\s*\(|\bAgentExecutor\s*\(', 'agent', 'langchain', 'langchain', {'langchain', 'langgraph'}, None),
    (r'\.(?:invoke|ainvoke|stream|astream|batch|abatch)\s*\(', 'chain', 'langchain', 'langchain', {'langchain', 'langgraph'}, r'\b(?:Chat\w+|llm|model|chain|agent|graph|app)\b'),
    (r'\bRunner\.run(?:_sync|_streamed)?\s*\(|\brun\(\s*\w+\s*,', 'agent', 'openai', 'openai-agents', {'openai-agents'}, None),
    (r'\.(?:complete|chat|acomplete|achat|query)\s*\(', 'llamaindex', 'llamaindex', 'llamaindex', {'llamaindex'}, r'\b(?:llm|query_engine|chat_engine|index)\b'),
    (r'\b(?:litellm\.)?a?completion\s*\(', 'chat', 'litellm', 'litellm', {'litellm'}, None),
    (r'\bollama\.(?:chat|generate)\s*\(', 'chat', 'ollama', 'ollama', {'ollama'}, None),
    (r'\.chat\.(?:complete|stream)\s*\(', 'chat', 'mistral', 'mistral', {'mistral'}, None),
    (r'\bco\.chat\s*\(|\.chat\s*\(', 'chat', 'cohere', 'cohere', {'cohere'}, r'\bmodel\b'),
]
CALLS = [(re.compile(a), b, c, d, e, re.compile(f) if f else None) for a, b, c, d, e, f in CALLS]
CLIENTS = [
    (r'\bnew\s+(?:OpenAI|AzureOpenAI)\s*\(|\b(?:Async)?(?:Azure)?OpenAI\s*\(|\bopenai\.NewClient\s*\(|\bcreateOpenAI\s*\(', 'openai', {'openai', 'ai-sdk'}),
    (r'\bnew\s+Anthropic\s*\(|\b(?:Async)?Anthropic(?:Vertex|Bedrock)?\s*\(|\banthropic\.NewClient\s*\(|\bcreateAnthropic\s*\(', 'anthropic', {'anthropic', 'ai-sdk'}),
    (r'\bnew\s+GoogleGenAI\s*\(|\bgenai\.(?:Client|NewClient)\s*\(|\bGenerativeModel\s*\(', 'gemini', {'gemini'}),
    (r'\bnew\s+BedrockRuntimeClient\s*\(|client\(\s*["\']bedrock-runtime', 'bedrock', {'bedrock'}),
    (r'\b(?:ChatOpenAI|AzureChatOpenAI|ChatAnthropic|ChatGoogleGenerativeAI|ChatVertexAI|ChatBedrock\w*|ChatMistralAI|ChatOllama|ChatCohere)\s*\(', 'langchain', {'langchain'}),
]
CLIENTS = [(re.compile(a), b, c) for a, b, c in CLIENTS]
WIRE = re.compile(r'''\b(?:max_tokens|max_completion_tokens|max_output_tokens|tool_choice|response_format|stream_options|maxOutputTokens|toolChoice)\b\s*['"]?\s*[:=]|/chat/completions\b|/v1/responses\b|:(?:stream)?generateContent\b''')
V1_MESSAGES = re.compile(r'/v1/messages\b')
V1_GUARD = re.compile(r'\bmax_tokens\b|anthropic-version')
ROLE = re.compile(r'''\brole\s*:\s*['"](system|developer|tool)['"]|["']role["']\s*:\s*["'](system|developer|tool)["']|\bSystemMessage\s*\(|(?<![\w$.])\(\s*["']system["']\s*,|\bsystem_instruction\s*=|\binstructions\s*=\s*(?:f?["']|\w)''')
ROLE_UNION = re.compile(r'''['"](?:system|developer|tool|user|assistant)['"]\s*\|''')
CONTENT = re.compile(r'\bcontent\b|SystemMessage|system_instruction|instructions|(?<![\w$.])\(\s*["\']system["\']\s*,')
ENV_READ = re.compile(r'''(?:process\.env\.|process\.env\[\s*['"]|import\.meta\.env\.|os\.environ(?:\.get)?\s*[\[(]\s*['"]|os\.getenv\(\s*['"]|getenv\(\s*['"]|\bEnv\(\s*['"]|config(?:Service)?\.get(?:OrThrow)?\s*(?:<[^>]*>)?\(\s*['"]|\b(?:env|ENV|settings|config)\.(?=[A-Z][A-Z0-9_]*\b))([A-Za-z_][\w.]*)''')
SCHEMA_KEY = re.compile(r'''^\s*['"]?([A-Z][A-Z0-9_]*MODEL[A-Z0-9_]*)['"]?\s*:\s*[\w.(]''')
ENV_NAME = re.compile(r'(?:^|_)(?:AI|LLM|OPENAI|ANTHROPIC|CLAUDE|GEMINI|GOOGLE_GENAI|GPT|BEDROCK|MISTRAL|COHERE|GROQ|OLLAMA|OPENROUTER|LITELLM|AZURE_OPENAI)(?:_|$)|_MODEL(?:_|$)|^MODEL(?:_|$)', re.I)
EXPOSED = re.compile(r'^(?:NEXT_PUBLIC_|VITE_|EXPO_PUBLIC_|REACT_APP_|PUBLIC_|NUXT_PUBLIC_|GATSBY_)')

# Prefilter: the unguarded call shapes plus the wire, role and config lanes. A file that imports a provider
# or framework is read line by line with every pattern; any other file only on lines this matches.
ANY = re.compile('|'.join(['(?:%s)' % x[0].pattern for x in CALLS if x[4] is None and x[5] is None]
                          + ['(?:%s)' % r.pattern for r in (WIRE, V1_MESSAGES, ROLE, ENV_READ, SCHEMA_KEY)]), re.M)
P_MODEL = re.compile(r'''\b(?:model|modelId|model_id|modelName|model_name|Model)\b\s*[:=]\s*([^,\n}]+)|\b(?:model)\s*(?:[,}]|$)''')
P_CAP = re.compile(r'''\b(max_tokens|max_completion_tokens|max_output_tokens|maxOutputTokens|maxTokens|max_new_tokens|maxCompletionTokens|MaxTokens)\b\s*['"]?\s*[:=]\s*([\w.]+)''')
P_TIMEOUT = re.compile(r'''\b(AbortSignal\.timeout|timeout|timeoutMs|timeout_ms|request_timeout|requestTimeout|abortSignal|signal|WithRequestTimeout)\b\s*['"]?\s*[:=(]\s*([\w.]*)''')
P_RETRY_N = re.compile(r'''\b(max_retries|maxRetries|WithMaxRetries)\b\s*[:=(]\s*([\w.]+)''')
P_RETRY = re.compile(r'\b(?:retry|retries|attempts|tenacity|pRetry|p-retry|backoff|with_retry|ModelRetryMiddleware|RetryPolicy)\b', re.I)
P_STREAM = re.compile(r'''\bstream\s*['"]?\s*[:=]\s*(?:true|True)\b|\b(?:streamText|streamObject)\s*\(|\.messages\.stream\s*\(|\.stream\s*\(|stream_options|\bastream\b|_streamed\s*\(''')
P_USAGE_INC = re.compile(r'\binclude_usage\b')
P_TOOLS = re.compile(r'''\btools\s*['"]?\s*[:=]|\btool_choice\b|\btoolChoice\b|\bfunction_declarations\b|\bbind_tools\s*\(|@tool\b|\bfunctions\s*[:=]''')
P_TOOL_CHOICE = re.compile(r'''\b(?:tool_choice|toolChoice)\b\s*['"]?\s*[:=]\s*(?:(['"])(\w+)\1|(\{))''')
P_STRICT = re.compile(r'''\bstrict\s*['"]?\s*[:=]\s*(?:true|True)\b''')
P_STOP = re.compile(r'''\b(?:finish_reason|finishReason|stop_reason|stopReason|incomplete_details|FinishReason|StopReason)\b|status\s*={2,3}\s*['"]incomplete['"]''')
P_REFUSAL = re.compile(r'\brefusal\b')
P_USAGE = re.compile(r'\b(?:usage|prompt_tokens|completion_tokens|input_tokens|output_tokens|usage_metadata|totalUsage|cache_read_input_tokens|cached_tokens)\b')
P_VALIDATE = re.compile(r'''\b(?:safeParse|parseAsync|model_validate(?:_json)?|parse_obj|parse_raw|TypeAdapter|ajv|zodResponseFormat|zodTextFormat|Output\.object|generateObject|streamObject|response_model|with_structured_output|validate)\b|(?<!JSON)(?<!json)\.parse\(|\.validate\(''')
P_LOOP_HEAD = re.compile(r'^(\s*)(?:(?:async\s+)?(?:while|for)\b|do\s*\{|loop\s*\{|for\s*\{)')
P_LOOP_UNBOUNDED = re.compile(r'''while\s*\(?\s*(?:true|True|1)\s*\)?\s*[:{]?\s*$|for\s*\(\s*;\s*;\s*\)|^\s*for\s*\{\s*$|while\s*\(?\s*\w+(?:\.\w+)*\s*(?:===?|==)\s*['"]tool_use['"]''')
P_LOOP_CAP = re.compile(r'''\b(?:MAX_\w*(?:ITER|STEP|ROUND|TURN|LOOP|CALL|HOP)\w*|max_iterations|maxIterations|maxSteps|max_steps|stopWhen|stepCountIs|isStepCount|max_turns|maxTurns|recursion_limit|recursionLimit|ModelCallLimitMiddleware|ToolCallLimitMiddleware|max_iter)\b''')
FW_LOOP = [(re.compile(r'\bnew\s+ToolLoopAgent\b'), 'ai-sdk ToolLoopAgent'),
           (re.compile(r'\bstopWhen\b|\bmaxSteps\b'), 'ai-sdk stopWhen'),
           (re.compile(r'\bcreate_react_agent\b|\bStateGraph\b|@langchain/langgraph'), 'langgraph'),
           (re.compile(r'\bcreate_agent\b'), 'langchain-v1 create_agent'),
           (re.compile(r'\bAgentExecutor\b'), 'langchain AgentExecutor'),
           (re.compile(r'\bRunner\.run'), 'openai-agents Runner'),
           (re.compile(r'\btool_runner\b|\btoolRunner\b'), 'anthropic tool_runner')]

MID = (r'(?:anthropic\.claude-[\w.:-]+|claude-[a-z0-9][\w.@-]*|chatgpt-[\w.-]+|gpt-image-[\w.-]+|gpt-[0-9][\w.-]*'
       r'|o[134](?:-(?:mini|pro|preview|deep-research)(?:-[\w.-]+)?|-\d{4}-\d{2}-\d{2})?|codex-mini-latest'
       r'|computer-use-preview[\w.-]*|dall-e-[23]|text-(?:embedding|moderation)-[\w.-]+|(?:babbage|davinci)-002'
       r'|tts-1(?:-hd)?|whisper-1|sora-2[\w.-]*|gemini-[0-9a-z][\w.-]*|embedding-(?:001|gecko-001|2-preview)'
       r'|imagen-[\d.]+-[\w.-]+|veo-[\d.]+-[\w.-]+|(?:open-)?mistral-[\w.-]+|(?:meta-)?llama-?[\d.]+[\w.-]*)')
MODEL_QUOTED = re.compile(r'''["'`](?:[\w-]+[:/])*?(''' + MID + r''')["'`]''')
MODEL_BARE = re.compile(r'''(?<![\w.-])(?:[\w-]+[:/])*?(''' + MID + r''')(?![\w.@-])''')
MODEL_HINT = re.compile(r'claude-|gpt-|chatgpt-|\bo[134]\b|\bo[134]-|gemini-|dall-e|text-embedding|text-moderation|babbage|davinci|tts-1|whisper-1|sora-2|embedding-|imagen-|veo-|mistral-|llama|codex-mini|computer-use')
CONF_KEY = re.compile(r'(?i)model|provider|engine|deployment|llm|judge|grader|(?:openai|anthropic|google|vertex|bedrock|azureopenai|gemini)\s*:')

EVAL_CODE = [('deepeval', re.compile(r'\bfrom\s+deepeval\b|\bimport\s+deepeval\b|["\']deepeval["\']')),
             ('ragas', re.compile(r'\bfrom\s+ragas\b|\bimport\s+ragas\b')),
             ('inspect', re.compile(r'\bfrom\s+inspect_ai\b|\bimport\s+inspect_ai\b')),
             ('langsmith', re.compile(r'langsmith(?:\.|/)evaluation|from\s+langsmith\s+import\s+[^\n]*\bevaluate\b')),
             ('braintrust', re.compile(r'\bfrom\s+braintrust\b|["\']braintrust["\']')),
             ('pytest-eval', re.compile(r'@pytest\.mark\.eval\b')),
             ('promptfoo', re.compile(r'["\']promptfoo["\']|\bpromptfoo\.evaluate\s*\('))]
EVAL_CMD = re.compile(r'\b(promptfoo(?:@[\w.^~-]+)?\s+(?:eval|redteam)|deepeval\s+test\s+run|inspect\s+eval|pytest\b[^\n]*-m\s+["\']?evals?\b|braintrust\s+eval|oaieval|ragas\b[^\n]*\beval)')
DATASET_DIR = re.compile(r'(?:^|/)(?:evals?|eval[-_]?sets?|llm[-_]?evals?|prompt[-_]?tests?)(?:/|$)', re.I)  # not golden/: business goldens are not eval sets
DATASET_NAME = re.compile(r'(?:golden|eval|dataset|testcases?)[\w.-]*\.(?:jsonl|json|ya?ml|csv)$', re.I)
ADV_TAG = re.compile(r'(?i)prompt[-_ ]?injection|jailbreak|adversarial|red[-_ ]?team|\binjection\b')
CI_FILES = re.compile(r'(?:^|/)(?:\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.ya?ml|\.circleci/config\.ya?ml|azure-pipelines\.ya?ml|bitbucket-pipelines\.ya?ml|Jenkinsfile|\.buildkite/[^/]+\.ya?ml)$')

PKGS_NPM = ['ai', '@ai-sdk/openai', '@ai-sdk/anthropic', 'openai', '@anthropic-ai/sdk', '@google/genai',
            '@google/generative-ai', 'langchain', '@langchain/core', '@langchain/langgraph', '@langchain/openai',
            '@langchain/anthropic', 'llamaindex', '@openai/agents', '@modelcontextprotocol/sdk',
            '@mistralai/mistralai', 'cohere-ai', 'ollama', 'promptfoo']
PKGS_PY = ['openai', 'anthropic', 'google-genai', 'google-generativeai', 'langchain', 'langchain-core', 'langgraph',
           'llama-index', 'openai-agents', 'litellm', 'instructor', 'mcp', 'fastmcp', 'deepeval', 'ragas',
           'inspect-ai', 'langsmith', 'mistralai', 'cohere']
PKGS_GO = ['github.com/openai/openai-go', 'github.com/anthropics/anthropic-sdk-go', 'google.golang.org/genai',
           'github.com/sashabaranov/go-openai', 'github.com/tmc/langchaingo']


class Ctx:
    def __init__(self, roots, include_tests=False):
        self.roots = roots
        self.include_tests = include_tests
        self.unreadable = []
        self.files_read = 0
        self.skipped_big = 0
        self.cache = {}
        self.cached_bytes = 0


def walk(ctx, root, want, tests=False):
    def onerr(e):
        ctx.unreadable.append(getattr(e, 'filename', str(e)))
    for dp, dns, fns in os.walk(root, onerror=onerr):
        keep = []
        for d in dns:
            if d in SKIP_DIRS:
                continue
            if d in TEST_DIRS and not (tests or ctx.include_tests):
                continue
            keep.append(d)
        dns[:] = sorted(keep)
        for n in sorted(fns):
            if not (tests or ctx.include_tests) and TEST_FILE.search(n):
                continue
            p = os.path.join(dp, n)
            if want(p, n):
                yield p


def read(ctx, path):
    if path in ctx.cache:
        return ctx.cache[path]
    try:
        if os.path.getsize(path) > MAX_BYTES:
            ctx.skipped_big += 1
            return None
        with open(path, encoding='utf-8', errors='replace') as fh:
            t = fh.read()
        ctx.files_read += 1
        if ctx.cached_bytes < 400_000_000:
            ctx.cache[path] = t
            ctx.cached_bytes += len(t)
        return t
    except OSError:
        ctx.unreadable.append(path)
        return None


def rel(root, p):
    return os.path.relpath(p, root)


def is_code(p, n):
    return n.endswith(CODE_EXT) and not n.endswith('.d.ts') and '.min.' not in n


def indent(s):
    return len(s) - len(s.lstrip(' \t'))


def model_source(window):
    for ln in window:
        m = P_MODEL.search(ln)
        if not m:
            continue
        val = (m.group(1) or 'model').strip().rstrip(',;)')
        q = MODEL_QUOTED.search(ln)
        if q:
            return 'literal:' + q.group(1)
        e = ENV_READ.search(val)
        if e:
            return 'env:' + e.group(1)
        if re.search(r'(?i)config|settings|cfg|gateway|options|opts', val):
            return 'config:' + val[:40]
        if re.match(r'^[A-Za-z_][\w.]*$', val):
            return 'ident:' + val[:40]
        return 'expr:' + val[:40]
    return '-'


def site_props(lines, i, imports, provider, text):
    lo, hi = max(0, i - 30), min(len(lines), i + 41)
    w = lines[lo:hi]
    wt = '\n'.join(w)
    near = '\n'.join(lines[max(0, i - 2):min(len(lines), i + 25)])
    p = {}
    p['model'] = model_source(lines[max(0, i - 5):min(len(lines), i + 30)])
    m = P_CAP.search(near) or P_CAP.search(wt)
    p['output_cap'] = '%s=%s' % (m.group(1), m.group(2)) if m else '-'
    sdk = provider in SDK_PROVIDERS and (imports & SDK_PROVIDERS)
    t = P_TIMEOUT.search(near) or next((m for m in (P_TIMEOUT.search(x) for x in lines if not x.lstrip().startswith(('//', '#', '*', '/*'))) if m), None)
    p['timeout'] = ('%s%s' % (t.group(1), ('=' + t.group(2)) if t.group(2) else '')) if t else ('sdk-default:600s' if sdk else '-')
    r = P_RETRY_N.search(text)
    p['retries'] = '%s=%s' % (r.group(1), r.group(2)) if r else ('y' if P_RETRY.search(text) else ('sdk-default:2' if sdk else '-'))
    p['stream'] = 'y' if P_STREAM.search(near) else '-'
    p['include_usage'] = 'y' if P_USAGE_INC.search(wt) else '-'
    p['tools'] = 'y' if P_TOOLS.search(near) else '-'
    tc = P_TOOL_CHOICE.search(near)
    if tc:
        val = tc.group(2) or ''
        p['tool_choice'] = 'forced' if tc.group(3) or val in ('any', 'tool') else (val or '?')
    else:
        p['tool_choice'] = '-'
    p['strict'] = 'y' if P_STRICT.search(wt) else '-'
    p['stop_read'] = 'y' if P_STOP.search(text) else '-'
    p['refusal_read'] = 'y' if P_REFUSAL.search(text) else '-'
    p['usage_read'] = 'y' if P_USAGE.search(text) else '-'
    p['validate'] = 'y' if P_VALIDATE.search(text) else '-'
    # enclosing loop: nearest header above with smaller indentation, within 80 lines
    loop, cap = '-', '-'
    base = indent(lines[i])
    for j in range(i - 1, max(-1, i - 81), -1):
        ln = lines[j]
        if not ln.strip():
            continue
        if indent(ln) < base:
            if P_LOOP_HEAD.match(ln):
                loop = 'L%d%s' % (j + 1, ':unbounded-header' if P_LOOP_UNBOUNDED.search(ln) else '')
                break
            base = indent(ln)
            if re.match(r'\s*(?:export\s+)?(?:async\s+)?(?:def|function|func|class)\b', ln):
                break
    c = P_LOOP_CAP.search(wt) or (P_LOOP_CAP.search(text) if loop != '-' else None)
    if c:
        cap = c.group(0)
    fw = [name for rx, name in FW_LOOP if rx.search(wt)]
    if fw and loop == '-':
        loop = 'fw:' + '+'.join(fw)
    p['loop'] = loop
    p['loop_cap'] = cap
    p['tenant'] = 'y' if P_TENANT.search(wt) else '-'
    return p


def guess_provider(wt):
    if re.search(r'/chat/completions|tool_choice\s*:\s*\{\s*type\s*:\s*[\'"]function|response_format|max_completion_tokens|\bchoices\b|tool_calls', wt):
        return 'openai-compatible'
    if re.search(r'anthropic-version|/v1/messages', wt):
        return 'anthropic'
    if re.search(r'generateContent', wt):
        return 'gemini'
    if re.search(r'/v1/responses|max_output_tokens', wt):
        return 'openai'
    return 'unknown'


def scan_sites(ctx, root):
    sites = []
    for path in walk(ctx, root, is_code):
        text = read(ctx, path)
        if text is None:
            continue
        imports = {k for k, rx in IMPORTS.items() if any(l in text for l in IMPORT_LIT[k]) and rx.search(text)}
        if not imports and not any(t in text for t in QUICK) and not ENV_HINT.search(text):
            continue
        lines = text.split('\n')
        f = rel(root, path)
        calls, wires, other = [], [], []
        for i, ln in enumerate(lines):
            s = ln.lstrip()
            if s.startswith(('//', '#', '*', '/*')) and not s.startswith('#['):
                continue
            if not imports and not ANY.search(ln):
                continue
            hit = False
            for rx, api, prov, fw, need, guard in CALLS:
                if not rx.search(ln):
                    continue
                if need is not None and not (imports & need):
                    continue
                if guard is not None and not guard.search('\n'.join(lines[max(0, i - 3):i + 15])):
                    continue
                calls.append((i, api, prov, fw, 'sdk' if fw in ('openai', 'anthropic', 'gemini', 'bedrock', 'mistral', 'cohere') else 'framework'))
                hit = True
                break
            if hit:
                continue
            for rx, prov, need in CLIENTS:
                if rx.search(ln) and imports & need:
                    other.append(('client', i, prov, '-'))
                    hit = True
                    break
            if hit:
                continue
            if WIRE.search(ln):
                wires.append(i)
            elif V1_MESSAGES.search(ln) and V1_GUARD.search('\n'.join(lines[max(0, i - 15):i + 15])):
                wires.append(i)
            if ROLE.search(ln) and not ROLE_UNION.search(ln) and CONTENT.search('\n'.join(lines[i:i + 3])):
                other.append(('prompt', i, '-', '-'))
            seen = set()
            for e in ENV_READ.finditer(ln):
                name = e.group(1).split('.')[-1]
                if ENV_NAME.search(name) and name not in seen:
                    seen.add(name)
                    other.append(('config', i, 'exposed' if EXPOSED.search(name) else '-', name))
            sk = SCHEMA_KEY.match(ln)
            if sk and sk.group(1) not in seen:
                other.append(('config', i, '-', sk.group(1) + ' (schema key)'))
        # cluster wire hits; a wire hit inside a call's window joins the call
        clusters = []
        for i in wires:
            if any(abs(i - c[0]) <= 15 for c in calls):
                continue
            if clusters and i - clusters[-1][-1] <= 15:
                clusters[-1].append(i)
            else:
                clusters.append([i])
        for c in clusters:
            i = c[0]
            wt = '\n'.join(lines[max(0, i - 30):i + 40])
            calls.append((i, 'http', guess_provider(wt), 'raw-http', 'wire'))
        for i, api, prov, fw, lane in sorted(calls):
            row = {'file': f, 'line': i + 1, 'kind': 'call', 'lane': lane, 'provider': prov, 'api': api,
                   'framework': fw, 'detail': '-'}
            row.update(site_props(lines, i, imports, prov, text))
            sites.append(row)
        for kind, i, prov, detail in other:
            sites.append({'file': f, 'line': i + 1, 'kind': kind, 'lane': 'sdk' if kind == 'client' else kind,
                          'provider': prov, 'api': '-', 'framework': '-', 'detail': detail})
        provs = imports & {'openai', 'anthropic', 'gemini', 'bedrock', 'mistral', 'cohere', 'ollama', 'litellm',
                           'ai-sdk', 'langchain', 'langgraph', 'llamaindex', 'openai-agents'}
        if provs and not calls and not any(o[0] == 'client' for o in other):
            for k in sorted(provs):
                m = IMPORTS[k].search(text)
                ln = text.count('\n', 0, m.start()) + 1
                sites.append({'file': f, 'line': ln, 'kind': 'import', 'lane': 'sdk', 'provider': k, 'api': '-',
                              'framework': k, 'detail': 'import with no recognised call'})
    return sites


COLS = ['file', 'line', 'kind', 'lane', 'provider', 'api', 'framework', 'model', 'output_cap', 'timeout', 'retries',
        'stream', 'include_usage', 'tools', 'tool_choice', 'strict', 'stop_read', 'refusal_read', 'usage_read',
        'validate', 'loop', 'loop_cap', 'seam', 'eval_ref', 'detail', 'tenant']
# COLUMN CONTRACT (finops IR-4, 2026-10-19): sites.tsv is read by header NAME by sibling skills and by
# finops spend-path-scan § 0 (provider · file:line · tenant dimension). Names never change and never
# move meaning; a new column is appended at the end. `tenant` = 'y' when a tenant / workspace / org /
# account / customer id is in the call's window (a per-tenant dimension a meter or cap could key on).
P_TENANT = re.compile(r'\b(?:tenant|workspace|org|organization|account|customer)_?[Ii][Dd]s?\b')


def apply_seam(sites, seams):
    callers = [s for s in sites if s['kind'] in ('call', 'client')]
    inferred = None
    if not seams:
        counts = {}
        for s in callers:
            d = os.path.dirname(s['file'])
            counts[d] = counts.get(d, 0) + 1
        if counts:
            top = max(counts.values())
            best = sorted(d for d in counts if counts[d] == top)
            if len(best) == 1:
                inferred = best[0]
                seams = [inferred + '/*']
            else:
                inferred = 'ambiguous(%d folders x %d sites; pass --seam)' % (len(best), top)
    for s in sites:
        if s['kind'] not in ('call', 'client'):
            s['seam'] = '-'
        elif not seams:
            s['seam'] = '?'
        else:
            s['seam'] = 'in' if any(fnmatch.fnmatch(s['file'], g) or s['file'].startswith(g.rstrip('*').rstrip('/') + '/') for g in seams) else 'out'
    return inferred


def load_table(path):
    rows = []
    with open(path, encoding='utf-8') as fh:
        for ln in fh:
            if ln.startswith('#') or not ln.strip() or ln.startswith('provider\t'):
                continue
            c = ln.rstrip('\n').split('\t')
            if len(c) < 9:
                continue
            rows.append(dict(zip(['provider', 'id', 'match', 'status', 'date', 'replacement', 'source', 'checked_on', 'note'], c)))
    return rows


def parse_date(s):
    try:
        return datetime.date.fromisoformat(s)
    except (TypeError, ValueError):
        return None


def lookup(table, mid):
    best, blen = None, -1
    for r in table:
        m = r['match']
        if m == 'exact' and mid == r['id']:
            return r
        if m == 'prefix' and mid.startswith(r['id']) and len(r['id']) > blen:
            best, blen = r, len(r['id'])
        if m == 'regex' and re.search(r['id'], mid) and blen < 0:
            best, blen = r, 0
    return best


def classify(row, today):
    if row is None:
        return 'UNLISTED', '', ''
    if row['status'] == 'platform':
        return 'PLATFORM', '', ''
    d = parse_date(row['date'])
    if d is None:
        return ('RETIRED' if row['status'] == 'retired' else 'DEPRECATED'), row['date'] or 'TBA', ''
    if d <= today:
        return 'RETIRED', row['date'], ''
    return 'DEPRECATED', row['date'], str((d - today).days)


def scan_models(ctx, root, table, today):
    out = []

    def want(p, n):
        if n in LOCK_FILE or n.upper().startswith(('CHANGELOG', 'HISTORY', 'RELEASE')):
            return False
        return is_code(p, n) or n.endswith(CONF_EXT) or n.startswith('.env') or n == 'Dockerfile' or n.endswith('.dockerfile')
    for path in walk(ctx, root, want):
        n = os.path.basename(path)
        text = read(ctx, path)
        if text is None:
            continue
        if not MODEL_HINT.search(text):
            continue
        code = is_code(path, n)
        where = 'code' if code else ('env' if n.startswith('.env') else ('eval' if 'promptfoo' in n or DATASET_DIR.search(rel(root, path)) else 'config'))
        for i, ln in enumerate(text.split('\n')):
            if code:
                found = MODEL_QUOTED.findall(ln)
            elif CONF_KEY.search(ln) or (where == 'env' and re.search(r'MODEL', ln)):
                found = MODEL_BARE.findall(ln)
            else:
                continue
            for mid in dict.fromkeys(found):
                r = lookup(table, mid)
                st, date, days = classify(r, today)
                note = (r or {}).get('note', '')
                if mid.endswith('-latest'):
                    note = ('alias; ' + note).strip('; ')
                out.append({'file': rel(root, path), 'line': i + 1, 'id': mid, 'where': where,
                            'provider': (r or {}).get('provider', '-'), 'status': st, 'date': date or '-',
                            'days_left': days or '-', 'replacement': (r or {}).get('replacement', '') or '-',
                            'source': (r or {}).get('source', '-'), 'note': note or '-'})
    return out


MCOLS = ['file', 'line', 'id', 'where', 'provider', 'status', 'date', 'days_left', 'replacement', 'source', 'note']
ECOLS = ['file', 'line', 'kind', 'tool', 'detail']


def scan_evals(ctx, root, table, today):
    rows, corpus = [], []
    api_rows = [(re.compile(r['id']), r) for r in table if r['match'] == 'api' and r['provider'] != 'azure']

    def want(p, n):
        return n not in LOCK_FILE
    for path in walk(ctx, root, want, tests=True):
        f = rel(root, path)
        n = os.path.basename(path)
        is_ci = bool(CI_FILES.search(f))
        is_pf = n.startswith('promptfooconfig') or ('promptfoo' in n and n.endswith(('.yaml', '.yml', '.json')))
        is_ds = n.endswith(('.jsonl', '.json', '.yaml', '.yml', '.csv')) and (DATASET_DIR.search(os.path.dirname(f) + '/') or DATASET_NAME.search(n)) and not is_pf and not is_ci
        code = is_code(path, n)
        if not (is_ci or is_pf or is_ds or code):
            continue
        text = read(ctx, path)
        if text is None:
            continue
        if is_pf:
            rows.append({'file': f, 'line': 1, 'kind': 'config', 'tool': 'promptfoo', 'detail': 'tests=%d' % len(re.findall(r'(?m)^\s*-\s*(?:vars|description)\s*:', text))})
            corpus.append(text[:200000])
        if is_ds:
            nrows = text.count('\n') if n.endswith(('.jsonl', '.csv')) else len(re.findall(r'(?m)^\s*-\s', text)) or 1
            rows.append({'file': f, 'line': 1, 'kind': 'dataset', 'tool': '-', 'detail': 'rows~%d adversarial=%s' % (nrows, 'y' if ADV_TAG.search(text) else '-')})
            corpus.append(text[:200000])
        if code and re.search(r'deepeval|ragas|inspect_ai|langsmith|braintrust|pytest\.mark\.eval|promptfoo|evals|pmpt_|v1/prompts|assistants|threads', text):
            for tool, rx in EVAL_CODE:
                m = rx.search(text)
                if m:
                    rows.append({'file': f, 'line': text.count('\n', 0, m.start()) + 1, 'kind': 'config', 'tool': tool, 'detail': '-'})
                    corpus.append(text[:200000])
            for rx, r in api_rows:
                for m in rx.finditer(text):
                    st, date, days = classify(r, today)
                    rows.append({'file': f, 'line': text.count('\n', 0, m.start()) + 1, 'kind': 'platform', 'tool': r['provider'],
                                 'detail': '%s %s %s (%s) days_left=%s -> %s' % (m.group(0), st, date, r['note'], days or '-', r['replacement'] or '-')})
        if is_ci:
            lines = text.split('\n')
            paths = re.findall(r'(?m)^\s+-\s+["\']?([^"\'\n]+?)["\']?\s*$', '\n'.join(_paths_blocks(lines)))
            for i, ln in enumerate(lines):
                m = EVAL_CMD.search(ln)
                if not m:
                    continue
                masked = []
                if re.search(r'\|\|\s*(?:true|:|exit\s+0)|;\s*exit\s+0', ln):
                    masked.append('|| true')
                if _job_has(lines, i, r'continue-on-error:\s*true'):
                    masked.append('continue-on-error')
                if re.search(r'PROMPTFOO_FAILED_TEST_EXIT_CODE\s*[:=]\s*["\']?0\b|PROMPTFOO_PASS_RATE_THRESHOLD\s*[:=]\s*["\']?0\b', text):
                    masked.append('threshold 0')
                tel = 'y' if re.search(r'PROMPTFOO_DISABLE_TELEMETRY|DEEPEVAL_TELEMETRY_OPT_OUT|RAGAS_DO_NOT_TRACK|DO_NOT_TRACK', text) else '-'
                pin = 'y' if re.search(r'promptfoo@\d', ln) or 'promptfoo' not in ln else '-'
                rows.append({'file': f, 'line': i + 1, 'kind': 'ci-eval', 'tool': m.group(1).split()[0].split('@')[0],
                             'detail': 'masked=%s telemetry_off=%s pinned=%s paths=%s' % (','.join(masked) or '-', tel, pin, ','.join(paths[:8]) or '-')})
    return rows, '\n'.join(corpus).lower()


def _paths_blocks(lines):
    out, on, ind = [], False, 0
    for ln in lines:
        m = re.match(r'^(\s*)paths(?:-ignore)?\s*:\s*$', ln)
        if m:
            on, ind = True, len(m.group(1))
            continue
        if on:
            if ln.strip() and indent(ln) <= ind:
                on = False
            else:
                out.append(ln)
    return out


def _job_has(lines, i, pat):
    start = i
    while start > 0 and not re.match(r'^  [\w-]+:\s*$', lines[start]):
        start -= 1
    end = i + 1
    while end < len(lines) and not re.match(r'^  [\w-]+:\s*$', lines[end]):
        end += 1
    return bool(re.search(pat, '\n'.join(lines[start:end])))


def eval_ref(sites, corpus):
    for s in sites:
        if s['kind'] != 'call':
            s['eval_ref'] = '-'
            continue
        stem = re.split(r'[.]', os.path.basename(s['file']))[0].lower()
        parent = os.path.basename(os.path.dirname(s['file'])).lower()
        toks = {t for t in re.split(r'[-_]', stem) + [stem, parent] if len(t) > 3 and t not in ('index', 'main', 'service', 'route', 'port', 'http', 'infrastructure', 'src', 'app', 'apps', 'lib')}
        s['eval_ref'] = 'y' if corpus and any(t in corpus for t in toks) else '-'


def versions(ctx, root):
    out = []
    for path in walk(ctx, root, lambda p, n: n in ('package.json', 'pnpm-lock.yaml', 'package-lock.json', 'requirements.txt', 'pyproject.toml', 'poetry.lock', 'uv.lock', 'go.mod') or (n.startswith('requirements') and n.endswith('.txt'))):
        n = os.path.basename(path)
        text = read(ctx, path)
        if text is None:
            continue
        f = rel(root, path)
        if n == 'package.json':
            try:
                j = json.loads(text)
            except ValueError:
                continue
            for sec in ('dependencies', 'devDependencies', 'peerDependencies'):
                for k, v in (j.get(sec) or {}).items():
                    if k in PKGS_NPM:
                        out.append((k, str(v), f, 'range'))
        elif n == 'pnpm-lock.yaml':
            for k in PKGS_NPM:
                for m in re.finditer(r"\n\s+'?" + re.escape(k) + r"'?:\n\s+specifier: [^\n]+\n\s+version: ([^\s(]+)", text):
                    out.append((k, m.group(1), f, 'lock'))
        elif n == 'package-lock.json':
            try:
                j = json.loads(text)
            except ValueError:
                continue
            for k in PKGS_NPM:
                v = (j.get('packages') or {}).get('node_modules/' + k, {}).get('version')
                if v:
                    out.append((k, v, f, 'lock'))
        elif n in ('poetry.lock', 'uv.lock'):
            for k in PKGS_PY:
                m = re.search(r'name = "' + re.escape(k) + r'"\nversion = "([^"]+)"', text)
                if m:
                    out.append((k, m.group(1), f, 'lock'))
        elif n == 'go.mod':
            for k in PKGS_GO:
                m = re.search(re.escape(k) + r'(?:/v\d+)?\s+(v[\w.+-]+)', text)
                if m:
                    out.append((k, m.group(1), f, 'lock'))
        else:
            for k in PKGS_PY:
                m = re.search(r'(?im)^\s*["\']?' + re.escape(k) + r'(?:\[[^\]]*\])?\s*([=<>~!]=?\s*[\w.*]+)?', text)
                if m:
                    out.append((k, (m.group(1) or 'unpinned').replace(' ', ''), f, 'range'))
    return sorted(set(out))


def tsv(rows, cols):
    return '\n'.join(['\t'.join(cols)] + ['\t'.join(str(r.get(c, '-')).replace('\t', ' ') for c in cols) for r in rows])


def inside(child, parent):
    c, p = os.path.realpath(child), os.path.realpath(parent)
    return c == p or c.startswith(p.rstrip(os.sep) + os.sep)


def run(argv, stdout=sys.stdout, stderr=sys.stderr):
    roots, opts = [], {'out': None, 'seam': None, 'models': None, 'evals': False, 'strict': False,
                       'today': None, 'tests': False, 'quiet': False}
    for a in argv:
        if a.startswith('--out='):
            opts['out'] = a[6:]
        elif a.startswith('--seam='):
            opts['seam'] = [g for g in a[7:].split(',') if g]
        elif a == '--models':
            opts['models'] = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'model-lifecycle.tsv')
        elif a.startswith('--models='):
            opts['models'] = a[9:]
        elif a == '--evals':
            opts['evals'] = True
        elif a == '--strict':
            opts['strict'] = True
        elif a.startswith('--today='):
            opts['today'] = a[8:]
        elif a == '--include-tests':
            opts['tests'] = True
        elif a == '--quiet':
            opts['quiet'] = True
        elif a.startswith('--root='):
            roots.append(a[7:])
        elif a.startswith('-'):
            print('usage: unknown option %s (see the docstring)' % a, file=stderr)
            return 1
        else:
            roots.append(a)
    if not roots:
        print(__doc__, file=stderr)
        return 1
    today = parse_date(opts['today']) if opts['today'] else datetime.date.today()
    if today is None:
        print('usage: --today must be YYYY-MM-DD', file=stderr)
        return 1
    for r in roots:
        if not os.path.isdir(r) or not os.access(r, os.R_OK | os.X_OK):
            print('blocked: root %s is missing or unreadable' % r, file=stderr)
            return 2
        if opts['out'] and inside(opts['out'], r):
            print('blocked: --out %s is inside the scanned root %s; this script never writes the tree' % (opts['out'], r), file=stderr)
            return 2
    table = []
    if opts['models'] or opts['evals']:
        tp = opts['models'] or os.path.join(os.path.dirname(os.path.abspath(__file__)), 'model-lifecycle.tsv')
        try:
            table = load_table(tp)
        except OSError:
            print('blocked: lifecycle table %s unreadable' % tp, file=stderr)
            return 2
    ctx = Ctx(roots, opts['tests'])
    sites, models, evals, vers, summ = [], [], [], [], []
    gate = []
    stale = ''
    if table:
        newest = max((parse_date(r['checked_on']) for r in table if parse_date(r['checked_on'])), default=None)
        if newest is None or (today - newest).days > 90:
            stale = 'STALE (newest checked_on %s, %s days before %s)' % (newest, (today - newest).days if newest else '?', today)
    for root in roots:
        s = scan_sites(ctx, root)
        corpus = ''
        if opts['evals']:
            e, corpus = scan_evals(ctx, root, table, today)
            evals += [dict(r, file=os.path.join(root, r['file']) if len(roots) > 1 else r['file']) for r in e]
        inferred = apply_seam(s, opts['seam'])
        for x in s:
            x.setdefault('eval_ref', '-')
        if opts['evals']:
            eval_ref(s, corpus)
        if len(roots) > 1:
            for x in s:
                x['file'] = os.path.join(root, x['file'])
        sites += s
        if opts['models']:
            models += scan_models(ctx, root, table, today)
        vers += [(root,) + v for v in versions(ctx, root)]
        calls = [x for x in s if x['kind'] == 'call']
        summ.append('root=%s call_sites=%d clients=%d prompts=%d imports_without_call=%d config_reads=%d seam=%s out_of_seam=%d' % (
            root, len(calls), sum(1 for x in s if x['kind'] == 'client'), sum(1 for x in s if x['kind'] == 'prompt'),
            sum(1 for x in s if x['kind'] == 'import'), sum(1 for x in s if x['kind'] == 'config'),
            (','.join(opts['seam']) if opts['seam'] else ('inferred:' + inferred if inferred else 'none')),
            sum(1 for x in s if x.get('seam') == 'out')))
    for m in models:
        if m['status'] == 'RETIRED' or (m['status'] == 'DEPRECATED' and m['days_left'] not in ('-', '') and int(m['days_left']) <= 30):
            gate.append('model %s at %s:%s is %s' % (m['id'], m['file'], m['line'], m['status']))
    if stale and opts['models']:
        gate.append('lifecycle table ' + stale)
    for e in evals:
        if e['kind'] == 'ci-eval' and 'masked=-' not in e['detail']:
            gate.append('eval gate masked at %s:%s' % (e['file'], e['line']))
    head = ['# llm-sites %s · today=%s · files_read=%d · unreadable=%d · skipped_over_2MB=%d' % (VERSION, today, ctx.files_read, len(ctx.unreadable), ctx.skipped_big)]
    head += ['# ' + x for x in summ]
    if opts['models']:
        head.append('# models: %d rows (%d RETIRED, %d DEPRECATED, %d UNLISTED, %d PLATFORM)%s' % (
            len(models), sum(m['status'] == 'RETIRED' for m in models), sum(m['status'] == 'DEPRECATED' for m in models),
            sum(m['status'] == 'UNLISTED' for m in models), sum(m['status'] == 'PLATFORM' for m in models), (' · table ' + stale) if stale else ''))
    if opts['evals']:
        head.append('# evals: %d configs, %d datasets, %d CI eval steps, %d platform calls' % (
            sum(e['kind'] == 'config' for e in evals), sum(e['kind'] == 'dataset' for e in evals),
            sum(e['kind'] == 'ci-eval' for e in evals), sum(e['kind'] == 'platform' for e in evals)))
    if vers:
        head.append('# versions: ' + '; '.join('%s %s (%s, %s)' % (k, v, f, how) for _, k, v, f, how in vers[:40]))
    if gate:
        head.append('# gate: ' + ' | '.join(gate[:20]))
    body = ['## sites', tsv(sites, COLS)]
    if opts['models']:
        body += ['## models', tsv(models, MCOLS)]
    if opts['evals']:
        body += ['## evals', tsv(evals, ECOLS)]
    for p in ctx.unreadable:
        print('unreadable: %s' % p, file=stderr)
    print('\n'.join(head), file=stdout)
    if not opts['quiet']:
        print('\n'.join(body), file=stdout)
    if opts['out']:
        os.makedirs(opts['out'], exist_ok=True)
        with open(os.path.join(opts['out'], 'sites.tsv'), 'w', encoding='utf-8') as fh:
            fh.write(tsv(sites, COLS) + '\n')
        if opts['models']:
            with open(os.path.join(opts['out'], 'models.tsv'), 'w', encoding='utf-8') as fh:
                fh.write(tsv(models, MCOLS) + '\n')
        if opts['evals']:
            with open(os.path.join(opts['out'], 'evals.tsv'), 'w', encoding='utf-8') as fh:
                fh.write(tsv(evals, ECOLS) + '\n')
        with open(os.path.join(opts['out'], 'versions.tsv'), 'w', encoding='utf-8') as fh:
            fh.write('root\tpackage\tversion\tfile\tsource\n' + '\n'.join('\t'.join(v) for v in vers) + '\n')
        with open(os.path.join(opts['out'], 'summary.txt'), 'w', encoding='utf-8') as fh:
            fh.write('\n'.join(head) + '\n')
    if ctx.unreadable or ctx.files_read == 0:
        print('blocked: %s' % ('no file read' if ctx.files_read == 0 else '%d unreadable path(s); output is partial' % len(ctx.unreadable)), file=stderr)
        return 2
    if opts['strict'] and gate:
        return 4
    return 0


SELF_TEST = {
    'apps/api/src/llm/gateway.ts': """const MAX_ROUNDS = 8;
export async function complete(messages: unknown[]) {
  const res = await fetch(`${process.env.AI_URL}/chat/completions`, {
    method: 'POST',
    signal: AbortSignal.timeout(30000),
    body: JSON.stringify({
      model: process.env.AI_GATEWAY_MODEL,
      messages,
      max_tokens: 1024,
      tool_choice: { type: 'function', function: { name: 'extract' } },
    }),
  });
  const body = await res.json();
  if (body.choices[0].finish_reason === 'length') throw new Error('truncated');
  return body;
}
""",
    'apps/api/src/reports/summary.ts': """import OpenAI from 'openai';
const client = new OpenAI();
export async function summarize(text: string) {
  while (true) {
    const r = await client.chat.completions.create({
      model: 'gpt-4-turbo',
      messages: [{ role: 'system', content: 'Summarize the report' }, { role: 'user', content: text }],
      stream: true,
    });
    for await (const c of r) { process.stdout.write(c.choices[0]?.delta?.content ?? ''); }
  }
}
""",
    'services/rag/app/answer.py': """import anthropic
client = anthropic.Anthropic(timeout=20.0, max_retries=0)

def answer(q, docs, tenant_id):
    msg = client.messages.create(
        model="claude-3-haiku-20240307",
        max_tokens=512,
        system="Answer from the documents only",
        messages=[{"role": "user", "content": q}],
    )
    if msg.stop_reason == "max_tokens":
        raise ValueError("truncated")
    return msg.content[0].text
""",
    'apps/edge/app/api/assistant/route.ts': """import { streamText, stepCountIs } from 'ai';
import { openai } from '@ai-sdk/openai';
export async function POST(req: Request) {
  const { messages } = await req.json();
  const result = streamText({ model: openai('gpt-4o-mini'), messages, abortSignal: req.signal, stopWhen: stepCountIs(5) });
  return result.toUIMessageStreamResponse();
}
""",
    'services/rag/app/agent.py': """from langgraph.prebuilt import create_react_agent
from langchain_openai import ChatOpenAI
model = ChatOpenAI(model="gpt-4o", max_tokens=800)
agent = create_react_agent(model, tools=[])
def run(q):
    return agent.invoke({"messages": [("user", q)]}, config={"recursion_limit": 200})
""",
    'cmd/bot/main.go': """package main
import "github.com/openai/openai-go"
func ask(client openai.Client) {
	client.Chat.Completions.New(ctx, openai.ChatCompletionNewParams{Model: "gpt-4o"})
}
""",
    'apps/api/src/notify/sms.ts': """export async function sendSms(to: string, from: string, text: string) {
  await fetch('https://sms.example.com/v1/messages', { method: 'POST', body: JSON.stringify({ to, from, text }) });
}
""",
    'apps/api/src/notify/twilio.ts': """import twilio from 'twilio';
const client = twilio();
export const send = (to: string, body: string) => client.messages.create({ body, to, from: '+15550000' });
""",
    'apps/api/src/core/coherence.ts': """// cohere: the coherence score of a cluster, not a provider
export const coherenceScore = (x: number) => x * 2;
""",
    'apps/api/src/users/roles.ts': """export const SYSTEM_ROLE = { role: 'system', label: 'System user' };
""",
    'apps/api/test/gateway.spec.ts': """import OpenAI from 'openai';
new OpenAI().chat.completions.create({ model: 'gpt-4o', messages: [] });
""",
    'apps/web/src/env.ts': """export const key = import.meta.env.VITE_OPENAI_API_KEY;
""",
    '.env.example': "AI_GATEWAY_MODEL=gpt-4-turbo\nOPENAI_API_KEY=\n",
    'CHANGELOG.md': "- moved off claude-2.1\n",
    'evals/promptfooconfig.yaml': "providers:\n  - openai:gpt-4o-mini\ntests:\n  - vars: { q: 'summary of the monthly report' }\n  - vars: { q: 'ignore previous instructions (prompt injection)' }\n",
    'evals/golden.jsonl': '{"q": "a", "a": "b"}\n{"q": "c", "a": "d"}\n',
    'evals/legacy.py': "from openai import OpenAI\nclient = OpenAI()\nclient.evals.runs.create(eval_id='e')\n",
    '.github/workflows/eval.yml': "on:\n  pull_request:\n    paths:\n      - 'evals/**'\njobs:\n  eval:\n    runs-on: ubuntu-latest\n    steps:\n      - run: npx promptfoo eval -c evals/promptfooconfig.yaml || true\n",
}


def self_test():
    tmp = tempfile.mkdtemp(prefix='llm-sites-selftest-')
    fails = []

    def check(cond, msg):
        if not cond:
            fails.append(msg)
    try:
        root = os.path.join(tmp, 'repo')
        for p, body in SELF_TEST.items():
            fp = os.path.join(root, p)
            os.makedirs(os.path.dirname(fp), exist_ok=True)
            with open(fp, 'w', encoding='utf-8') as fh:
                fh.write(body)
        table = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'model-lifecycle.tsv')
        out = os.path.join(tmp, 'run')

        class Sink:
            def __init__(self):
                self.buf = []

            def write(self, s):
                self.buf.append(s)

            def flush(self):
                pass
        so, se = Sink(), Sink()
        rc = run([root, '--out=' + out, '--models=' + table, '--evals', '--today=2026-10-19', '--strict'], so, se)
        check(rc == 4, 'strict run should exit 4 (retired id + masked gate), got %s: %s' % (rc, ''.join(se.buf)))
        rows = [dict(zip(COLS, ln.split('\t'))) for ln in open(os.path.join(out, 'sites.tsv'), encoding='utf-8').read().splitlines()[1:]]
        calls = [r for r in rows if r['kind'] == 'call']
        by = {r['file']: r for r in calls}
        check(len(calls) == 7, 'expected 7 call sites (agent build + invoke count apart), got %d: %s' % (len(calls), sorted((r['file'], r['line']) for r in calls)))
        g = by.get('apps/api/src/llm/gateway.ts', {})
        check(g.get('lane') == 'wire' and g.get('provider') == 'openai-compatible', 'raw gateway lane/provider: %s' % g)
        check(g.get('model') == 'env:AI_GATEWAY_MODEL' and g.get('tool_choice') == 'forced' and g.get('stop_read') == 'y', 'raw gateway props: %s' % g)
        check(g.get('output_cap') == 'max_tokens=1024' and g.get('timeout', '-') != '-', 'raw gateway cap/timeout: %s' % g)
        o = by.get('apps/api/src/reports/summary.ts', {})
        check(o.get('timeout') == 'sdk-default:600s' and o.get('retries') == 'sdk-default:2', 'sdk defaults: %s' % o)
        check(o.get('loop', '').endswith('unbounded-header') and o.get('stream') == 'y' and o.get('include_usage') == '-', 'loop/stream: %s' % o)
        check(o.get('model') == 'literal:gpt-4-turbo' and o.get('output_cap') == '-', 'model/cap: %s' % o)
        a = by.get('services/rag/app/answer.py', {})
        check(a.get('provider') == 'anthropic' and a.get('retries') == 'max_retries=0' and a.get('stop_read') == 'y', 'anthropic: %s' % a)
        check(a.get('tenant') == 'y' and g.get('tenant') == '-', 'tenant column (finops spend-path § 0): answer=%s gateway=%s' % (a.get('tenant'), g.get('tenant')))
        check(COLS[:25] == ['file', 'line', 'kind', 'lane', 'provider', 'api', 'framework', 'model', 'output_cap', 'timeout', 'retries', 'stream', 'include_usage', 'tools', 'tool_choice', 'strict', 'stop_read', 'refusal_read', 'usage_read', 'validate', 'loop', 'loop_cap', 'seam', 'eval_ref', 'detail'], 'sites.tsv column contract: names are append-only')
        v = by.get('apps/edge/app/api/assistant/route.ts', {})
        check(v.get('framework') == 'ai-sdk' and v.get('loop', '').startswith('fw:ai-sdk') and v.get('loop_cap') in ('stopWhen', 'stepCountIs'), 'ai-sdk: %s' % v)
        check(v.get('timeout', '').startswith('abortSignal') or v.get('timeout', '').startswith('signal'), 'ai-sdk abort: %s' % v)
        lg = by.get('services/rag/app/agent.py', {})
        check('langgraph' in lg.get('loop', '') and lg.get('loop_cap') == 'recursion_limit', 'langgraph: %s' % lg)
        check('cmd/bot/main.go' in by, 'go openai-go call missing')
        for decoy in ('apps/api/src/notify/sms.ts', 'apps/api/src/notify/twilio.ts', 'apps/api/src/core/coherence.ts', 'apps/api/test/gateway.spec.ts'):
            check(not any(r['file'] == decoy for r in rows), 'decoy produced a row: %s' % decoy)
        check(not any(r['file'] == 'apps/api/src/users/roles.ts' for r in rows), 'role without content produced a prompt row')
        check(any(r['kind'] == 'prompt' and r['file'] == 'apps/api/src/reports/summary.ts' for r in rows), 'prompt row missing')
        check(any(r['kind'] == 'config' and r['provider'] == 'exposed' for r in rows), 'client-exposed key row missing')
        models = [dict(zip(MCOLS, ln.split('\t'))) for ln in open(os.path.join(out, 'models.tsv'), encoding='utf-8').read().splitlines()[1:]]
        ms = {(m['file'], m['id']): m for m in models}
        check(ms.get(('apps/api/src/reports/summary.ts', 'gpt-4-turbo'), {}).get('status') == 'DEPRECATED', 'gpt-4-turbo should be DEPRECATED on 2026-10-19')
        check(ms.get(('services/rag/app/answer.py', 'claude-3-haiku-20240307'), {}).get('status') == 'RETIRED', 'claude-3-haiku should be RETIRED')
        check(ms.get(('.env.example', 'gpt-4-turbo'), {}).get('where') == 'env', '.env.example model missing')
        check(ms.get(('evals/promptfooconfig.yaml', 'gpt-4o-mini'), {}).get('status') == 'UNLISTED', 'promptfoo provider id missing')
        check(not any(m['file'] == 'CHANGELOG.md' for m in models), 'CHANGELOG read for model ids')
        ev = [dict(zip(ECOLS, ln.split('\t'))) for ln in open(os.path.join(out, 'evals.tsv'), encoding='utf-8').read().splitlines()[1:]]
        check(any(e['kind'] == 'ci-eval' and 'masked=|| true' in e['detail'] and 'telemetry_off=-' in e['detail'] for e in ev), 'masked CI eval not found: %s' % ev)
        check(any(e['kind'] == 'platform' and 'DEPRECATED' in e['detail'] for e in ev), 'evals platform row missing')
        check(any(e['kind'] == 'dataset' and e['file'] == 'evals/golden.jsonl' for e in ev), 'dataset row missing')
        check(by.get('apps/api/src/reports/summary.ts', {}).get('eval_ref') == 'y', 'eval_ref join failed for summary.ts')
        rc2 = run([root, '--out=' + os.path.join(root, 'x'), '--quiet'], Sink(), Sink())
        check(rc2 == 2 and not os.path.exists(os.path.join(root, 'x')), '--out inside root must exit 2 and write nothing')
        rc3 = run([os.path.join(tmp, 'missing'), '--quiet'], Sink(), Sink())
        check(rc3 == 2, 'missing root must exit 2')
        so4 = Sink()
        rc4 = run([root, '--models=' + table, '--today=2027-03-01', '--strict', '--quiet'], so4, Sink())
        check(rc4 == 4 and 'STALE' in ''.join(so4.buf), 'stale table must print STALE and exit 4')
        rc5 = run([root, '--quiet'], Sink(), Sink())
        check(rc5 == 0, 'plain run must exit 0, got %s' % rc5)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        print('SELF-TEST FAIL: ' + f, file=sys.stderr)
    print('self-test: %s (%d checks failed)' % ('PASS' if not fails else 'FAIL', len(fails)))
    return 0 if not fails else 3


if __name__ == '__main__':
    if sys.argv[1:] == ['--self-test']:
        sys.exit(self_test())
    sys.exit(run(sys.argv[1:]))
