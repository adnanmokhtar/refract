#!/usr/bin/env python3
"""token-map.py — design-token-audit (ui-ux): the token table per theme, and the EXACT / NEAREST / NONE
classifier for a literal. Owned by ui-ux (it owns AL-05..AL-10); the align pack's sweep gate calls it, when
the ui-ux pack is installed, for V-07 (value round-trip) and V-08 (emitted names exist).

Why a script and not rg: "is 13px a token?" needs the token's RESOLVED value in every theme (var() aliases,
DTCG {alias} references, a Tailwind 4 @theme block beside a .dark override) and the PROPERTY FAMILY of both
sides. `padding: 13px` equals `--font-size-sm: 13px` byte for byte, and swapping it is still a visible change
the day the type scale moves: a cross-family match is never EXACT.

Usage:  python3 -I token-map.py <root> [--json]                       the token table (summary; --json = rows)
        python3 -I token-map.py <root> --scan [--max=N] [--json]      classify every literal site in <root>
        python3 -I token-map.py <root> --lookup=<value> --family=<f>|--prop=<css-prop> [--site=<relpath>] [--json]
        python3 -I token-map.py <root> --resolve=<token-name> [--json] its value per theme (V-07)
        python3 -I token-map.py <root> --names                       every declared name, one per line (V-08)
        python3 -I token-map.py --self-test
Options: --rem=16 (px per rem for NEAREST distances only; rem never equals px EXACTLY, see below)
         --site=<relpath> (lookup) scope the table to the package that holds that file (see SCOPE)

TOKEN SOURCES (P-04 — these files are definitions, never drift):
  CSS/SCSS/Less  custom properties in root-ish blocks: :root, html, :host, @theme / @theme inline / @theme
                 static (Tailwind 4), and theme blocks .dark, html.dark, :root.dark, [data-theme=X],
                 .theme-X, @media (prefers-color-scheme: dark). At-rules are tokenised, so a statement such as
                 `@custom-variant dark (&:where(.dark, .dark *));` never swallows the next block. A custom
                 property in a component selector (.card { --x: }) is local, not a token. SCSS `$name: v;` and
                 Less `@name: v;` at depth 0 are tokens of the light theme.
  DTCG / SD      *.tokens.json, tokens.json, design-tokens*.json, any .json under a tokens/ directory:
                 `$value`/`$type` (DTCG 2025.10) or `value`/`type` (Style Dictionary), nested groups joined
                 with `-` (`color.brand.500` -> `color-brand-500`), `{group.token}` aliases resolved per theme.
                 A file or directory named for a theme (`dark.tokens.json`, `tokens/dark/…`) is that theme.
                 LINEAGE: a DTCG token and the CSS custom property built from it (`color.danger` ->
                 `--color-danger`, same package, same value in every theme) are one token: the DTCG row
                 folds into the CSS row (`lineage` column), so it is never a second EXACT candidate.
  TS/JS objects  tokens.*, theme.*, design-tokens.*, *.tokens.* and files under tokens/ or theme/:
                 `export const X = { … }` / `export default { … }` with static values (dotted names
                 `theme.colors.primary`); tailwind.config.* `theme` / `theme.extend` (colors, spacing,
                 borderRadius, fontSize, fontWeight, zIndex, boxShadow …).
  Theme names: the base (root) block is `light`; a theme the source never overrides inherits light's value.

SCOPE: tokens are tagged with the nearest package directory (package.json / pyproject.toml / pubspec.yaml)
  that declares them. A site is measured against its own package's tokens plus the root's; a package with
  none of its own falls back to shared-looking packages (ui, tokens, design-system, theme, styles), then to
  the whole repo. The `scope` column says which (package | shared | repo). A name declared in two packages
  keeps one value per package (a closed app theme's `--color-primary` is not the design system's); aliases
  resolve in the declaring package first, then the root, then a shared package.

FAMILIES: color, space, radius, font-size, font-weight, line-height, shadow, z, duration, easing, size,
  width (border / outline / ring / divide / decoration thickness), font-family, other. A token's family comes from its value first (a colour value is `color` whatever its
  name), then its name (Tailwind 4 namespaces are definitive: --color-*, --spacing*, --radius-*, --text-*,
  --font-weight-*, --leading-*, --shadow-*, --ease-*, --z-index-*). A literal's family comes from its
  property (CSS name, camelCase style key, or Tailwind utility prefix).

CLASSES (--scan, --lookup):
  EXACT    the normalised literal equals a token's resolved value in the SAME family. `candidates` counts
           them; `eq=yes` only when there is exactly one candidate AND it holds that value in every shipped
           theme (a token whose dark value differs is a visible change in dark: VC, not EQ).
  NEAREST  no same-family exact match, but the family has tokens: the nearest one and its distance (px
           for lengths at --rem, ms, weight steps, or dE = OKLab distance x 100 for colours). 13px vs a 4px
           scale is NEAREST, never mechanical (P-07). A rem/px pair equal at --rem is NEAREST with
           `note=unit-equivalent` (rem follows the user's font size, px does not).
  NONE     the family has no tokens (fixed layout geometry with no size scale is P-30), or the value cannot
           be compared.
  EXEMPT   values tokens do not cover by design (P-05): 0, auto, %, 1px hairline (unless a border-width
           family exists), transparent, inherit, currentColor, none, calc()/var()/clamp() bodies.
  Every row also carries `xfam=<token>` when the value matches a token of ANOTHER family (P-27).

SCAN CARRIERS: CSS/SCSS/Less declarations (and the same `prop: value;` lines inside styled/emotion
  templates and Vue/Svelte <style>), JS object styles incl. ternary / ?? / || branches and every string
  literal of the value expression (`color: failed ? '#d92d20' : 'var(--x)'`), React inline numbers for
  space/radius/font-size/z, JSX/SVG colour attributes (fill=, stroke=, color=), Tailwind arbitrary values
  (`p-[13px]`, `bg-[#2563eb]`, v3 `!` prefix and v4 `!` suffix).
EXCLUDED (root-relative — a root that itself sits under benchmarks/fixtures/ is still scanned):
  node_modules, dist, build, .next, coverage, vendor, test/tests/__tests__/e2e/fixtures/__mocks__/stories
  directories, *.test.* *.spec.* *.stories.* *.test-data.* *.fixture(s).* *.d.ts, the token sources
  themselves, and P-06 contexts (emails/, *.email.*, print.css / *.print.*, opengraph-image.*, *.svg).

Output: TSV with a `# KIND\tcolumns` header (TOKEN / SITE / LOOKUP / RESOLVE), or --json. Summary on stderr.
Exit:   0 ran (--scan: no EXACT/NEAREST site) · 1 --scan found EXACT or NEAREST sites / --lookup found no
        EXACT / --resolve found no token · 2 usage · 3 self-test failed.
Stdlib only, Python >= 3.8, `python3 -I` safe; reads files, never writes into <root>. The self-test writes a
mktemp -d tree under $TMPDIR and removes it.
"""
import json, math, os, re, shutil, sys, tempfile

SKIP_DIRS = {'node_modules', '.git', 'dist', 'build', 'out', '.next', '.nuxt', '.output', '.svelte-kit', 'coverage',
             'vendor', 'third_party', '.turbo', '.cache', 'storybook-static', 'test', 'tests', '__tests__', 'e2e',
             'fixtures', '__fixtures__', '__mocks__', 'mocks', 'stories', '__snapshots__', 'playwright-report',
             '.venv', 'venv', '__pycache__'}
SKIP_FILE = re.compile(r'\.(?:test|spec|stories|story|test-data|fixtures?|e2e|d)\.[a-z]+$|\.email\.[a-z]+$|'
                       r'(?:^|/)print\.(?:s?css|less)$|\.print\.[a-z]+$|(?:^|/)opengraph-image\.|(?:^|/)twitter-image\.')
CSS_EXT = ('.css', '.scss', '.less', '.pcss', '.postcss')
CODE_EXT = ('.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.vue', '.svelte', '.astro', '.html')
FAMILIES = ('color', 'space', 'radius', 'font-size', 'font-weight', 'line-height', 'shadow', 'z', 'duration',
            'easing', 'size', 'width', 'font-family', 'other')

NAMED = {'black': '#000000', 'white': '#ffffff', 'red': '#ff0000', 'green': '#008000', 'blue': '#0000ff',
         'gray': '#808080', 'grey': '#808080', 'silver': '#c0c0c0', 'maroon': '#800000', 'purple': '#800080',
         'fuchsia': '#ff00ff', 'magenta': '#ff00ff', 'lime': '#00ff00', 'olive': '#808000', 'yellow': '#ffff00',
         'navy': '#000080', 'teal': '#008080', 'aqua': '#00ffff', 'cyan': '#00ffff', 'orange': '#ffa500',
         'rebeccapurple': '#663399', 'pink': '#ffc0cb', 'gold': '#ffd700', 'crimson': '#dc143c',
         'tomato': '#ff6347', 'coral': '#ff7f50', 'salmon': '#fa8072', 'indigo': '#4b0082', 'violet': '#ee82ee',
         'brown': '#a52a2a', 'tan': '#d2b48c', 'beige': '#f5f5dc', 'ivory': '#fffff0', 'khaki': '#f0e68c',
         'lavender': '#e6e6fa', 'darkgray': '#a9a9a9', 'darkgrey': '#a9a9a9', 'lightgray': '#d3d3d3',
         'lightgrey': '#d3d3d3', 'whitesmoke': '#f5f5f5', 'gainsboro': '#dcdcdc', 'dimgray': '#696969',
         'slategray': '#708090', 'steelblue': '#4682b4', 'royalblue': '#4169e1', 'dodgerblue': '#1e90ff',
         'firebrick': '#b22222', 'darkred': '#8b0000', 'orangered': '#ff4500', 'seagreen': '#2e8b57'}
EXEMPT_WORDS = {'transparent', 'inherit', 'currentcolor', 'none', 'initial', 'unset', 'revert', 'auto', '0',
                'normal', 'solid', 'dashed', 'dotted'}

# ---------------------------------------------------------------- value normalisation
NUM = r'[-+]?(?:\d+\.?\d*|\.\d+)'
COLOR_FN = re.compile(r'\b(rgba?|hsla?|oklch|oklab)\(\s*([^()]*)\)', re.I)
HEX = re.compile(r'(?<![\w&])#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})(?![\w-])')
LEN = re.compile(r'(?<![\w.#-])(' + NUM + r')(px|rem|em)\b')
DUR = re.compile(r'^(' + NUM + r')(ms|s)$')


def fmt(x):
    s = ('%.4f' % x).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def _hex(rgb, a=1.0):
    r, g, b = [max(0, min(255, int(round(c)))) for c in rgb]
    s = '#%02x%02x%02x' % (r, g, b)
    if a < 0.9999:
        s += '%02x' % max(0, min(255, int(round(a * 255))))
    return s


def _split_args(body):
    body = body.replace('/', ' / ').replace(',', ' ')
    parts = body.split()
    alpha = 1.0
    if '/' in parts:
        i = parts.index('/')
        alpha = _alpha(parts[i + 1]) if i + 1 < len(parts) else 1.0
        parts = parts[:i]
    return parts, alpha


def _alpha(t):
    return float(t[:-1]) / 100 if t.endswith('%') else float(t)


def _gamma(v):
    v = max(0.0, min(1.0, v))
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def oklab_to_rgb(L, a, b):
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return [_gamma(r) * 255, _gamma(g) * 255, _gamma(bb) * 255]


def rgb_to_oklab(rgb):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = [lin(c) for c in rgb]
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def parse_color(v):
    """A CSS colour -> '#rrggbb' / '#rrggbbaa', or None. oklch/oklab compare after an 8-bit sRGB round trip
    (raystack's rule; the precision of out-of-gamut values is not asserted)."""
    v = v.strip().lower()
    if v in NAMED:
        return NAMED[v]
    m = re.fullmatch(r'#([0-9a-f]{3,8})', v)
    if m:
        h = m.group(1)
        if len(h) in (3, 4):
            h = ''.join(c * 2 for c in h)
        if len(h) == 8 and h.endswith('ff'):
            h = h[:6]
        return '#' + h if len(h) in (6, 8) else None
    m = COLOR_FN.fullmatch(v)
    if not m:
        return None
    fn, body = m.group(1), m.group(2)
    if 'var(' in body or 'calc(' in body:
        return None
    try:
        parts, alpha = _split_args(body)
        if fn.startswith('rgb'):
            if len(parts) == 4:
                alpha = _alpha(parts.pop())
            rgb = [float(p[:-1]) * 2.55 if p.endswith('%') else float(p) for p in parts[:3]]
            return _hex(rgb, alpha)
        if fn.startswith('hsl'):
            if len(parts) == 4:
                alpha = _alpha(parts.pop())
            h = float(re.sub(r'deg$', '', parts[0])) % 360 / 360
            s, l = float(parts[1].rstrip('%')) / 100, float(parts[2].rstrip('%')) / 100
            def hue(p, q, t):
                t %= 1
                if t < 1 / 6: return p + (q - p) * 6 * t
                if t < 1 / 2: return q
                if t < 2 / 3: return p + (q - p) * (2 / 3 - t) * 6
                return p
            q = l * (1 + s) if l < 0.5 else l + s - l * s
            p = 2 * l - q
            return _hex([hue(p, q, h + 1 / 3) * 255, hue(p, q, h) * 255, hue(p, q, h - 1 / 3) * 255], alpha)
        L = float(parts[0][:-1]) / 100 if parts[0].endswith('%') else float(parts[0])
        if fn == 'oklch':
            c = float(parts[1].rstrip('%')) * (0.004 if parts[1].endswith('%') else 1)
            h = math.radians(float(re.sub(r'deg$', '', parts[2])) if parts[2] != 'none' else 0)
            a, b = c * math.cos(h), c * math.sin(h)
        else:
            a, b = float(parts[1]), float(parts[2])
        return _hex(oklab_to_rgb(L, a, b), alpha)
    except (ValueError, IndexError):
        return None


def norm_value(raw, family=None):
    """Normalise one token or literal value. Colours -> hex; lengths -> '13px' / '0.875rem';
    durations -> ms; weights -> numbers; other values -> collapsed whitespace with colours normalised."""
    v = re.sub(r'\s*!important\s*$', '', str(raw).strip().strip('\'"`')).strip()
    lv = v.lower()
    c = parse_color(lv)
    if c:
        return c
    m = re.fullmatch(r'(' + NUM + r')(px|rem|em)?', lv)
    if m:
        n, unit = float(m.group(1)), m.group(2)
        if unit is None:
            if family in ('space', 'radius', 'font-size', 'size', 'width') and n != 0:
                unit = 'px'                      # React inline / RN numbers are px
            else:
                return fmt(n)
        return fmt(n) + unit if n != 0 else '0'
    m = DUR.fullmatch(lv)
    if m:
        return fmt(float(m.group(1)) * (1000 if m.group(2) == 's' else 1)) + 'ms'
    if lv in ('bold', 'bolder'):
        return '700'
    if lv == 'normal' and family == 'font-weight':
        return '400'
    out = HEX.sub(lambda mm: parse_color('#' + mm.group(1)) or mm.group(0), lv)
    out = COLOR_FN.sub(lambda mm: parse_color(mm.group(0)) or mm.group(0), out)
    return re.sub(r'\s+', ' ', re.sub(r'\s*,\s*', ', ', out))


def value_kind(nv):
    if re.fullmatch(r'#[0-9a-f]{6}(?:[0-9a-f]{2})?', nv):
        return 'color'
    if re.fullmatch(NUM + r'(?:px|rem|em)', nv):
        return 'length'
    if re.fullmatch(NUM + r'ms', nv):
        return 'duration'
    if re.fullmatch(NUM, nv):
        return 'number'
    if 'cubic-bezier' in nv or nv in ('ease', 'ease-in', 'ease-out', 'ease-in-out', 'linear'):
        return 'easing'
    if len(LEN.findall(nv)) >= 2 and (HEX.search(nv) or 'rgb' in nv):
        return 'shadow'
    return 'other'


def px_of(nv, rem):
    m = re.fullmatch(r'(' + NUM + r')(px|rem|em)', nv)
    if not m:
        return 0.0 if nv == '0' else None
    return float(m.group(1)) * (1 if m.group(2) == 'px' else rem)


# ---------------------------------------------------------------- families
TW_NS = [('color-', 'color'), ('spacing', 'space'), ('radius', 'radius'), ('text-', 'font-size'),
         ('font-weight', 'font-weight'), ('leading', 'line-height'), ('shadow', 'shadow'),
         ('inset-shadow', 'shadow'), ('drop-shadow', 'shadow'), ('ease', 'easing'), ('z-index', 'z'),
         ('container', 'size'), ('breakpoint', 'size'), ('font-', 'font-family'), ('animate', 'other')]


def family_of_token(name, nv):
    n = name.lower().lstrip('-$@').replace('.', '-').replace('_', '-')
    kind = value_kind(nv)
    if kind == 'color':
        return 'color'
    if kind == 'shadow' or 'shadow' in n or 'elevation' in n:
        return 'shadow'
    if kind == 'duration' or re.search(r'duration|delay|transition-time', n):
        return 'duration'
    if kind == 'easing' or re.search(r'(?:^|-)eas(?:e|ing)', n):
        return 'easing'
    if re.search(r'(?:^|-)z(?:-index)?(?:-|$)|zindex|(?:^|-)layer(?:-|$)', n) and kind == 'number':
        return 'z'
    if re.search(r'font-?weight|(?:^|-)weight', n):
        return 'font-weight'
    if re.search(r'line-?height|leading', n):
        return 'line-height'
    if re.search(r'radius|rounded|(?:^|-)corner', n):
        return 'radius'
    if re.search(r'font-?size|(?:^|-)text-|(?:^|-)type-|(?:^|-)fs-|fontsize', n) and kind in ('length', 'number'):
        return 'font-size'
    if re.search(r'(?:^|-)font(?:-|$)', n):
        return 'font-size' if kind == 'length' else 'font-family'
    if re.search(r'space|spacing|(?:^|-)gap|gutter|inset|padding|margin|(?:^|-)sp-', n):
        return 'space'
    if kind in ('length', 'number') and re.search(r'(?:border|outline|ring|divide|stroke|rule)-?width|(?:^|-)hairline|thickness', n):
        return 'width'
    if re.search(r'(?:^|-)(?:size|width|height|container|breakpoint|screen)(?:-|$)', n):
        return 'size'
    if re.search(r'colou?r|(?:^|-)(?:bg|fg|text|border|surface|brand|accent|primary|danger)(?:-|$)', n):
        return 'color'
    return 'other'


def family_of_prop(prop):
    p = re.sub(r'([a-z])([A-Z])', r'\1-\2', prop.strip()).lower().replace('_', '-')
    if p in ('fill', 'stroke', 'background', 'outline-color', 'caret-color', 'accent-color', 'stop-color',
             'flood-color', 'lighting-color', 'text-decoration-color', 'column-rule-color') or p.endswith('color'):
        return 'color'
    if p in ('border', 'border-top', 'border-right', 'border-bottom', 'border-left', 'outline', 'border-block',
             'border-inline', 'border-block-start', 'border-block-end', 'border-inline-start', 'border-inline-end'):
        return 'color'                       # the shorthand's colour part; its width is a hairline (P-05)
    if re.match(r'(?:border(?:-(?:top|right|bottom|left|block|inline)(?:-(?:start|end))?)?|outline|column-rule|'
                r'-webkit-text-stroke)-width$|^text-decoration-thickness$|^stroke-width$', p):
        return 'width'                       # a thickness: its own family, never a size or a font-size token
    if 'radius' in p:
        return 'radius'
    if p in ('font-size',):
        return 'font-size'
    if p == 'font-weight':
        return 'font-weight'
    if p == 'line-height':
        return 'line-height'
    if 'shadow' in p:
        return 'shadow'
    if p == 'z-index':
        return 'z'
    if re.match(r'(?:transition|animation)-(?:duration|delay)$', p):
        return 'duration'
    if re.match(r'(?:transition|animation)-timing-function$', p):
        return 'easing'
    if re.match(r'(?:margin|padding|gap|row-gap|column-gap|grid-gap|scroll-margin|scroll-padding|text-indent)(?:-|$)', p):
        return 'space'
    if re.match(r'(?:min-|max-)?(?:width|height|inline-size|block-size)$|^flex-basis$|^grid-template|^grid-auto|^size$|'
                r'^(?:inset|top|right|bottom|left)(?:-|$)', p):        # position offsets are layout geometry
        return 'size'
    return 'other'


TW_PREFIX = [(r'(?:bg|from|via|to|accent|caret|fill|placeholder)', 'color?'),
             (r'(?:text)', 'color|font-size'),
             (r'(?:border(?:-[trblxyse])?|outline|decoration|ring|ring-offset|divide(?:-[xy])?|stroke)', 'color|width'),
             (r'(?:-?(?:p|px|py|pt|pr|pb|pl|ps|pe|m|mx|my|mt|mr|mb|ml|ms|me|gap|gap-x|gap-y|space-x|space-y|'
              r'inset|inset-x|inset-y|top|right|bottom|left|indent|scroll-m|scroll-p))', 'space'),
             (r'(?:rounded(?:-[trblse]{1,2})?)', 'radius'), (r'(?:shadow)', 'shadow'), (r'(?:z)', 'z'),
             (r'(?:font)', 'font-weight'), (r'(?:leading)', 'line-height'), (r'(?:duration|delay)', 'duration'),
             (r'(?:ease)', 'easing'), (r'(?:w|h|min-w|max-w|min-h|max-h|size|basis)', 'size')]


def family_of_tw(prefix, nv):
    kind = value_kind(nv)
    for rx, fam in TW_PREFIX:
        if re.fullmatch(rx, prefix):
            if fam == 'color?':
                return 'color'
            if fam == 'color|font-size':
                return 'color' if kind == 'color' else 'font-size'
            if fam == 'color|width':         # border-[1.5px] / outline-[2px] / decoration-[1.5px]: a thickness
                return 'color' if kind == 'color' else 'width' if kind in ('length', 'number') else 'other'
            return fam
    return None


# ---------------------------------------------------------------- tiny JS object-literal reader
JS_TOK = re.compile(r'''\s+|//[^\n]*|/\*.*?\*/|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|'''
                    r'''(-?\d+\.?\d*(?:e-?\d+)?)|([A-Za-z_$][\w$]*)|(\.\.\.|[{}\[\](),:;=?<>!&|+\-*/.%])''', re.S)


def js_tokens(src):
    out, pos = [], 0
    while pos < len(src):
        m = JS_TOK.match(src, pos)
        if not m:
            out.append(('p', src[pos])); pos += 1; continue
        pos = m.end()
        if m.group(1) is not None:
            s = m.group(1)
            out.append(('s', None if s[0] == '`' and '${' in s else s[1:-1]))
        elif m.group(2) is not None:
            out.append(('n', m.group(2)))
        elif m.group(3) is not None:
            out.append(('i', m.group(3)))
        elif m.group(4) is not None:
            out.append(('p', m.group(4)))
    return out


def js_value(toks, i):
    """Parse a value at toks[i]; return (value, next_index). Objects -> dict, arrays -> list, strings and
    numbers -> str; anything dynamic -> None (consumed up to the next , ] } at depth 0)."""
    if i >= len(toks):
        return None, i
    k, v = toks[i]
    if k == 'p' and v == '{':
        d, i = {}, i + 1
        while i < len(toks) and toks[i] != ('p', '}'):
            k2, v2 = toks[i]
            if (k2, v2) == ('p', '...'):
                _, i = js_value(toks, i + 1)
                d.setdefault('...', []).append(None)
            elif k2 in ('i', 's', 'n') and i + 1 < len(toks) and toks[i + 1] == ('p', ':'):
                val, i = js_value(toks, i + 2)
                d[str(v2)] = val
            elif k2 == 'p' and v2 == '[':        # computed key
                depth = 0
                while i < len(toks):
                    if toks[i] == ('p', '['): depth += 1
                    elif toks[i] == ('p', ']'):
                        depth -= 1
                        if depth == 0: break
                    i += 1
                i += 1
                if i < len(toks) and toks[i] == ('p', ':'):
                    _, i = js_value(toks, i + 1)
            else:
                i += 1                            # shorthand property, method, stray token
                continue
            if i < len(toks) and toks[i] == ('p', ','):
                i += 1
        return d, i + 1
    if k == 'p' and v == '[':
        arr, i = [], i + 1
        while i < len(toks) and toks[i] != ('p', ']'):
            val, i = js_value(toks, i)
            arr.append(val)
            if i < len(toks) and toks[i] == ('p', ','):
                i += 1
        return arr, i + 1
    if k in ('s', 'n') and (i + 1 >= len(toks) or toks[i + 1] in (('p', ','), ('p', '}'), ('p', ']'), ('p', ';'), ('p', ')'))):
        return v, i + 1
    if k == 'i' and v in ('true', 'false', 'null', 'undefined') and (i + 1 >= len(toks) or toks[i + 1][1] in ',}];)'):
        return v, i + 1
    depth = 0                                     # dynamic: skip to the end of the expression
    while i < len(toks):
        kk, vv = toks[i]
        if kk == 'p' and vv in '([{':
            depth += 1
        elif kk == 'p' and vv in ')]}':
            if depth == 0:
                break
            depth -= 1
        elif kk == 'p' and vv in ',;' and depth == 0:
            break
        i += 1
    return None, i


# ---------------------------------------------------------------- token map
class Tok(object):
    __slots__ = ('name', 'theme', 'raw', 'value', 'family', 'source', 'pkg', 'lineage')

    def __init__(self, name, theme, raw, source):
        self.name, self.theme, self.raw, self.source = name, theme, raw, source
        self.value, self.family, self.pkg, self.lineage = None, None, '', ''


def rel(root, p):
    return os.path.relpath(p, root).replace(os.sep, '/')


def walk(root):
    for d, dirs, files in os.walk(root):
        rd = rel(root, d)
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not (x.startswith('.') and x not in ('.storybook',)))
        for f in sorted(files):
            rp = f if rd == '.' else rd + '/' + f
            yield os.path.join(d, f), rp


def read(p):
    try:
        with open(p, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError:
        return ''


THEME_SEL = re.compile(r'^(?:html|:root|:host|body)?((?:\.[\w-]+|\[data-(?:theme|mode|color-scheme)\s*=\s*[\'"]?[\w-]+[\'"]?\]|'
                       r':root|:where\([^)]*\))*)$')


THEME_CLASS = re.compile(r'^(?:dark|light|dim|high-contrast|hc|theme-[\w-]+|[\w-]+-(?:theme|mode))$')


def theme_of(prelude):
    """Return the theme a block prelude declares, 'light' for root-ish, or None for a component scope."""
    p = re.sub(r'\s+', ' ', prelude.strip())
    if p.startswith('@'):
        if re.match(r'@theme\b', p):
            return 'light'
        if re.match(r'@media\b', p):
            return 'dark' if re.search(r'prefers-color-scheme\s*:\s*dark', p) else ('' if 'print' not in p else None)
        if re.match(r'@(?:layer|supports|container)\b', p):
            return ''
        return None
    themes = set()
    for part in p.split(','):
        part = part.strip().replace(' ', '')
        if not part:
            continue
        m = THEME_SEL.match(part)
        if not m or not part:
            return None
        body = m.group(1) or ''
        classes = re.findall(r'\.([\w-]+)', body)
        if any(not THEME_CLASS.match(c) for c in classes):
            return None                               # .card, html.js: a component or state scope
        names = classes + re.findall(r'data-[\w-]+=[\'"]?([\w-]+)', body)
        names = [re.sub(r'^theme-|-(?:theme|mode)$', '', n) for n in names]
        if not names and not re.match(r'(?:html|:root|:host|body)', part):
            return None
        themes.add(names[-1] if names else 'light')
    if not themes:
        return None
    return sorted(themes)[0] if len(themes) == 1 else ('light' if 'light' in themes else sorted(themes)[0])


def strip_css_comments(src):
    return re.sub(r'/\*.*?\*/', lambda m: re.sub(r'[^\n]', ' ', m.group(0)), src, flags=re.S)


def css_tokens(src, rp, out):
    """Walk the CSS character by character: preludes reset at ; { }, so an at-rule statement never leaks."""
    src = strip_css_comments(src)
    stack, buf, line, buf_line = [], '', 1, 1
    i = 0
    while i < len(src):
        ch = src[i]
        if ch in '"\'':
            j = src.find(ch, i + 1)
            j = len(src) - 1 if j < 0 else j
            buf += src[i:j + 1]; line += src[i:j + 1].count('\n'); i = j + 1; continue
        if ch == '{':
            stack.append(buf.strip()); buf = ''
        elif ch == '}':
            decl(buf, stack, buf_line, rp, out); buf = ''
            if stack: stack.pop()
        elif ch == ';':
            decl(buf, stack, buf_line, rp, out); buf = ''
        else:
            if not buf.strip():
                buf_line = line
            buf += ch
        if ch == '\n':
            line += 1
        i += 1


def decl(text, stack, line, rp, out):
    t = text.strip()
    m = re.match(r'^(--[\w-]+)\s*:\s*(.+)$', t, re.S)
    if m and stack:
        themes = [theme_of(p) for p in stack]
        if any(x is None for x in themes):
            return                                   # component-scoped custom property
        named = [x for x in themes if x and x != 'light']
        theme = named[-1] if named else 'light'
        out.append(Tok(m.group(1), theme, m.group(2).strip(), '%s:%d' % (rp, line)))
        return
    m = re.match(r'^([$@][\w-]+)\s*:\s*([^;{}]+?)(?:\s*!default)?$', t)
    if m and not stack and not re.match(r'@(?:import|use|forward|charset|media|include|tailwind|apply|plugin|source|'
                                         r'custom-variant|variant|utility|config|layer|reference)\b', t):
        out.append(Tok(m.group(1), 'light', m.group(2).strip(), '%s:%d' % (rp, line)))


def flatten(obj, prefix, sep, out):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == '...':
                continue
            flatten(v, prefix + [k], sep, out)
    elif obj is not None and not isinstance(obj, list):
        out.append((sep.join(prefix), obj))


def dtcg_tokens(src, rp, out):
    try:
        data = json.loads(src)
    except ValueError:
        return
    lm = re.search(r'(?:^|[/._-])(dark|light|high-contrast|hc)(?:[/._-]|$)', rp.lower())
    theme = lm.group(1) if lm else 'light'

    def visit(node, path):
        if not isinstance(node, dict):
            return
        val = node.get('$value', node.get('value') if not any(k.startswith('$') for k in node) else None)
        if val is not None and not isinstance(val, dict) and path:
            raw = val
            if isinstance(val, list):
                raw = ' '.join(str(x) for x in val)
            t = Tok('-'.join(path), theme, str(raw), rp + ':1')
            t.family = {'color': 'color', 'fontweight': 'font-weight', 'duration': 'duration', 'shadow': 'shadow',
                        'cubicbezier': 'easing', 'fontfamily': 'font-family'}.get(str(node.get('$type', node.get('type', ''))).lower().replace('-', ''))
            out.append(t)
            return
        for k, v in node.items():
            if not k.startswith('$'):
                visit(v, path + [k])
    visit(data, [])


TS_TOKEN_FILE = re.compile(r'(?:^|/)(?:tokens?|theme|design-tokens|colors|palette)\.(?:ts|js|mjs|cjs)$|\.tokens\.(?:ts|js)$|'
                           r'(?:^|/)(?:tokens|theme)/[^/]+\.(?:ts|js|mjs)$')
TW_CONFIG = re.compile(r'(?:^|/)tailwind\.config\.(?:js|cjs|mjs|ts)$')


def ts_tokens(src, rp, out):
    toks = js_tokens(src)
    i = 0
    while i < len(toks):
        if toks[i] == ('i', 'export') or (toks[i] == ('i', 'const') and i > 0 and toks[i - 1] == ('i', 'export')):
            j = i
            while j < len(toks) and toks[j] != ('p', '=') and toks[j] != ('i', 'default') and j < i + 8:
                j += 1
            if j < len(toks) and toks[j] in (('p', '='), ('i', 'default')):
                name = toks[j - 1][1] if toks[j] == ('p', '=') else 'default'
                k = j + 1
                if k < len(toks) and toks[k] == ('p', '{'):
                    obj, k2 = js_value(toks, k)
                    if isinstance(obj, dict):
                        flat = []
                        flatten(obj, [name], '.', flat)
                        line = src.count('\n', 0, src.find('{', 0)) + 1
                        for n, v in flat:
                            out.append(Tok(n, 'dark' if re.search(r'dark', n, re.I) else 'light', str(v), '%s:%d' % (rp, line)))
                    i = k2
                    continue
        i += 1


def tw_config_tokens(src, rp, out):
    toks = js_tokens(src)
    for i, t in enumerate(toks):
        if t == ('i', 'theme') and i + 2 < len(toks) and toks[i + 1] == ('p', ':') and toks[i + 2] == ('p', '{'):
            obj, _ = js_value(toks, i + 2)
            if not isinstance(obj, dict):
                continue
            sections = dict(obj)
            sections.update(obj.get('extend') or {})
            fam = {'colors': 'color', 'spacing': 'space', 'borderRadius': 'radius', 'fontSize': 'font-size',
                   'fontWeight': 'font-weight', 'lineHeight': 'line-height', 'zIndex': 'z', 'boxShadow': 'shadow',
                   'transitionDuration': 'duration', 'transitionTimingFunction': 'easing', 'width': 'size',
                   'borderWidth': 'width', 'outlineWidth': 'width', 'ringWidth': 'width', 'strokeWidth': 'width'}
            for key, f in fam.items():
                flat = []
                flatten(sections.get(key), [key], '.', flat)
                for n, v in flat:
                    tk = Tok(n, 'light', str(v), rp + ':1')
                    tk.family = f
                    out.append(tk)
            return


def package_dirs(root):
    out = set()
    for p, rp in walk(root):
        if rp.endswith(('/package.json', '/pyproject.toml', '/pubspec.yaml')) or rp in ('package.json',):
            out.add(rp.rsplit('/', 1)[0] if '/' in rp else '')
    return out


def pkg_of(rp, pkgs):
    """The nearest package directory above a root-relative path ('' = the root)."""
    d = rp.rsplit('/', 1)[0] if '/' in rp else ''
    while d:
        if d in pkgs:
            return d
        d = d.rsplit('/', 1)[0] if '/' in d else ''
    return ''


SHARED_PKG = re.compile(r'(?:^|/)(?:ui|tokens|design-system|ds|theme|styles)(?:/|$)')


def rows_for(rows, pkg):
    """Tokens a site in `pkg` can use: its own package's, then the root's; a package with none of its own
    falls back to shared-looking packages (ui, tokens, design-system, theme), then to every token."""
    own = [t for t in rows if t.pkg == pkg or (t.pkg == '' and pkg != '')]
    if any(t.pkg == pkg for t in rows):
        return own, 'package'
    shared = [t for t in rows if SHARED_PKG.search(t.pkg) or t.pkg == '']
    if shared:
        return shared, 'shared'
    return rows, 'repo'


def build_map(root):
    """Return (rows, sources, themes, pkgs): resolved Tok rows (one per name x theme), tagged with the
    package directory that declares them, so a monorepo app is never measured against another app's scale."""
    raw, sources = [], []
    pkgs = package_dirs(root)
    for p, rp in walk(root):
        low = rp.lower()
        if low.endswith(CSS_EXT):
            n = len(raw)
            css_tokens(read(p), rp, raw)
            if len(raw) > n:
                sources.append(rp)
        elif low.endswith('.json') and (re.search(r'(?:\.tokens|(?:^|/)tokens|design-tokens[^/]*)\.json$', low) or '/tokens/' in '/' + low):
            n = len(raw)
            dtcg_tokens(read(p), rp, raw)
            if len(raw) > n:
                sources.append(rp)
        elif TW_CONFIG.search(low):
            n = len(raw)
            tw_config_tokens(read(p), rp, raw)
            if len(raw) > n:
                sources.append(rp)
        elif TS_TOKEN_FILE.search(low) and not SKIP_FILE.search(low):
            n = len(raw)
            ts_tokens(read(p), rp, raw)
            if len(raw) > n:
                sources.append(rp)
    by = {}
    for t in raw:
        by[(pkg_of(t.source.rsplit(':', 1)[0], pkgs), t.name, t.theme)] = t   # a later declaration wins (cascade)
    ents = {}                                       # (package, name) -> {theme: Tok}: a name is scoped per package
    for (pk, n, th), t in by.items():
        ents.setdefault((pk, n), {})[th] = t
    pks_of = {}
    for pk, n in ents:
        pks_of.setdefault(n, []).append(pk)
    dotted = {}
    for _, n in ents:
        dotted[n.replace('-', '.')] = n

    def lookup(name, pk):
        """The declaration of `name` a token in package `pk` sees: its own package's, the root's, a shared
        package's, then any (aliases cross files and packages)."""
        cands = pks_of.get(name)
        if not cands:
            return None, None
        if pk in cands:
            q = pk
        elif '' in cands:
            q = ''
        else:
            q = sorted(cands, key=lambda x: (not SHARED_PKG.search(x), x))[0]
        return ents[(q, name)], q

    def resolve(name, theme, pk, seen):
        ent, q = lookup(name, pk)
        if not ent:
            return None
        t = ent.get(theme) or ent.get('light') or next(iter(ent.values()))
        val = t.raw
        if (q, name, theme) in seen:
            return None
        seen = seen | {(q, name, theme)}
        def sub_var(m):
            r = resolve(m.group(1), theme, q, seen)
            return r if r is not None else (m.group(2).strip() if m.group(2) else m.group(0))
        val = re.sub(r'var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*))?\)', sub_var, val)
        def sub_alias(m):
            key = m.group(1)
            target = dotted.get(key) or (key.replace('.', '-') if key.replace('.', '-') in pks_of else None)
            r = resolve(target, theme, q, seen) if target else None
            return r if r is not None else m.group(0)
        val = re.sub(r'\{([\w.-]+)\}', sub_alias, val)
        return val

    themes = sorted({th for ent in ents.values() for th in ent}, key=lambda x: (x != 'light', x))
    rows = []
    for (pk, n), ent in ents.items():
        for th in themes:
            t = ent.get(th) or ent.get('light')      # an undeclared theme inherits light (aliases re-resolve)
            if t is None:
                continue
            r = resolve(n, th, pk, frozenset())
            nt = Tok(n, th, t.raw, t.source)
            nt.pkg = pk
            fam_hint = t.family
            nt.value = norm_value(r if r is not None else t.raw, fam_hint)
            nt.family = fam_hint or family_of_token(n, nt.value)
            if nt.family in ('space', 'radius', 'font-size', 'size', 'width') and re.fullmatch(NUM, nt.value) and nt.value != '0':
                nt.value = nt.value + 'px'
            rows.append(nt)
    # Lineage: a DTCG / Style Dictionary token and the CSS custom property built from it (`color.danger` ->
    # `--color-danger`, same package, same value in every theme the DTCG source declares) are ONE token, not
    # two candidates. The CSS name is the one code references; the DTCG row folds into it (`lineage` names the
    # source). A CSS-only theme layer ([data-theme=dark] overrides) stays on the CSS row and still reads
    # theme-differs; a value that disagrees in a declared theme (a stale build) is not folded.
    val = {}
    for t in rows:
        val.setdefault((t.pkg, t.name), {})[t.theme] = t.value
    folded = set()
    for (pk, n), ent in ents.items():
        if n.startswith('--') or not all(x.source.rsplit(':', 1)[0].lower().endswith('.json') for x in ent.values()):
            continue
        twin = (pk, '--' + n)
        mine = val.get((pk, n), {})
        if twin in val and all(val[twin].get(th) == mine.get(th) for th in ent):
            folded.add((pk, n))
            src = next(iter(ent.values())).source.rsplit(':', 1)[0]
            for t in rows:
                if (t.pkg, t.name) == twin:
                    t.lineage = '%s %s' % (src, n)
    rows = [t for t in rows if (t.pkg, t.name) not in folded]
    return rows, sources, themes


def value_in(rows, name, theme):
    light = None
    for t in rows:
        if t.name == name:
            if t.theme == theme:
                return t.value
            if t.theme == 'light':
                light = t.value
    return light


# ---------------------------------------------------------------- classification
def distance(a, b, fam, rem):
    ka, kb = value_kind(a), value_kind(b)
    if ka == kb == 'color':
        ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
        cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
        la, lb = rgb_to_oklab(ca), rgb_to_oklab(cb)
        aa = int(a[7:9], 16) / 255.0 if len(a) == 9 else 1.0
        ab = int(b[7:9], 16) / 255.0 if len(b) == 9 else 1.0
        return round(100 * math.sqrt(sum((x - y) ** 2 for x, y in zip(la, lb))) + 100 * abs(aa - ab), 2), 'dE'
    pa, pb = px_of(a, rem), px_of(b, rem)
    if pa is not None and pb is not None:
        return round(abs(pa - pb), 3), 'px'
    try:
        return round(abs(float(a.rstrip('ms')) - float(b.rstrip('ms'))), 3), ('ms' if fam == 'duration' else 'n')
    except ValueError:
        return None, None


def classify(rows, themes, nv, fam, rem=16.0):
    """Classify one normalised literal of family `fam` against the light table."""
    res = {'class': 'NONE', 'candidates': '', 'eq': 'no', 'nearest': '', 'distance': '', 'xfam': '', 'note': ''}
    if nv in EXEMPT_WORDS or nv == '0' or re.search(r'(?:%|vh|vw|dvh|svh|lvh|vmin|vmax|fr)$', nv) or re.search(r'\b(?:var|calc|clamp|min|max|env)\(', nv):
        res['class'], res['note'] = 'EXEMPT', 'P-05'
        return res
    if nv == '1px' and not any(t.family == 'width' or t.family == 'size' and 'border' in t.name for t in rows):
        res['class'], res['note'] = 'EXEMPT', 'P-05 hairline'
        return res
    light = [t for t in rows if t.theme == 'light']
    same = sorted({t.name for t in light if t.family == fam and t.value == nv})
    other = sorted({t.name for t in light if t.family != fam and t.value == nv})
    if other:
        res['xfam'] = ','.join(other[:3])
    if same:
        res['class'], res['candidates'] = 'EXACT', ','.join(same)
        differs = []
        for n in same:
            for th in themes:
                if th != 'light' and value_in(rows, n, th) != nv:
                    differs.append('%s@%s' % (n, th))
        if differs:
            res['note'] = 'theme-differs:' + ','.join(differs[:4])
        res['eq'] = 'yes' if len(same) == 1 and not differs else 'no'
        return res
    fam_rows = [t for t in light if t.family == fam]
    if not fam_rows:
        res['note'] = 'P-30 layout geometry, no size tokens' if fam == 'size' else 'no %s tokens' % fam
        return res
    best = None
    for t in fam_rows:
        d, unit = distance(nv, t.value, fam, rem)
        if d is not None and (best is None or d < best[0]):
            best = (d, unit, t)
    if best is None:
        res['note'] = 'not comparable'
        return res
    res['class'] = 'NEAREST'
    res['nearest'] = '%s=%s' % (best[2].name, best[2].value)
    res['distance'] = '%s%s' % (fmt(best[0]), best[1])
    if best[0] == 0 and best[1] == 'px':
        res['note'] = 'unit-equivalent'
    return res


# ---------------------------------------------------------------- literal scan
CSS_DECL = re.compile(r'(?:^|[{;\s])([a-zA-Z-]+)\s*:\s*([^;{}]+?)\s*(?:;|$)')
JS_PROP = re.compile(r'(?<![\w$.])([a-zA-Z][\w]*|\'[a-z-]+\'|"[a-z-]+")\s*:\s*')
STR = re.compile(r'\'((?:\\.|[^\'\\])*)\'|"((?:\\.|[^"\\])*)"|`([^`$]*)`')
TW_ARB = re.compile(r'(?<![\w-])!?(-?[a-z][a-z-]*?)-\[([^\]\s\'"]+)\]!?')
ATTR_COLOR = re.compile(r'\b(fill|stroke|color|stop-color|bgcolor)\s*=\s*["\']([^"\']+)["\']')


def literals_in(text):
    """Literal values inside a CSS value or a JS expression: colours and lengths."""
    out = []
    for m in COLOR_FN.finditer(text):
        out.append(m.group(0))
    t2 = COLOR_FN.sub(' ', text)
    t2 = re.sub(r'\b(?:var|calc|clamp|min|max|env)\([^()]*(?:\([^()]*\)[^()]*)*\)', ' ', t2)
    for m in HEX.finditer(t2):
        out.append('#' + m.group(1))
    for m in LEN.finditer(t2):
        out.append(m.group(1) + m.group(2))
    return out


def expr_end(line, start):
    depth, i, q = 0, start, None
    while i < len(line):
        c = line[i]
        if q:
            if c == '\\':
                i += 2; continue
            if c == q: q = None
        elif c in '\'"`':
            q = c
        elif c in '([{':
            depth += 1
        elif c in ')]}':
            if depth == 0: return i
            depth -= 1
        elif c in ',;' and depth == 0:
            return i
        i += 1
    return i


def scan_sites(root, rows, themes, source_files, rem=16.0):
    sites, files, exempt_files = [], 0, 0
    src_set = set(source_files)
    pkgs, cache = package_dirs(root), {}
    for p, rp in walk(root):
        low = rp.lower()
        if not low.endswith(CSS_EXT + CODE_EXT):
            continue
        if SKIP_FILE.search(low) or re.search(r'(?:^|/)(?:emails?|mail|email-templates)/', low):
            exempt_files += 1
            continue
        if rp in src_set and low.endswith(CSS_EXT) is False:
            continue                                  # a TS/JSON token source is a definition (P-04)
        files += 1
        pk = pkg_of(rp, pkgs)
        if pk not in cache:
            cache[pk] = rows_for(rows, pk)
        prow, scope = cache[pk]
        is_css = low.endswith(CSS_EXT)
        for ln, line in enumerate(read(p).split('\n'), 1):
            s = line.strip()
            if not s or s.startswith(('//', '*', '/*', '<!--', 'import ', '@import')):
                continue
            found = []
            if re.match(r'^\s*--[\w-]+\s*:', line) or re.match(r'^\s*[$@][\w-]+\s*:', line) and is_css:
                continue                              # a token definition (P-04)
            if is_css or re.match(r'^\s*[a-z-]+\s*:\s*[^:]*;\s*$', line):
                for m in CSS_DECL.finditer(line):
                    prop, val = m.group(1), m.group(2)
                    if prop.startswith('--') or prop in ('src', 'content', 'url', 'grid-area', 'font-family'):
                        continue
                    fam = family_of_prop(prop)
                    if fam == 'shadow':
                        found.append((prop, val, fam))
                        continue
                    for lit in literals_in(val):
                        if value_kind(norm_value(lit)) == 'length' and fam in ('color', 'other'):
                            continue                  # a width inside a colour shorthand, or a non-token axis
                        found.append((prop, lit, fam))
            if not is_css:
                for m in JS_PROP.finditer(line):
                    prop = m.group(1).strip('\'"')
                    fam = family_of_prop(prop)
                    end = expr_end(line, m.end())
                    expr = line[m.end():end]
                    for sm in STR.finditer(expr):
                        body = next(g for g in sm.groups() if g is not None)
                        if fam == 'shadow' and body.strip():
                            found.append((prop, body, fam)); continue
                        for lit in literals_in(body):
                            if fam == 'other' and not (lit.startswith('#') and len(lit) in (7, 9) or lit.startswith(('rgb', 'hsl', 'okl'))):
                                continue
                            found.append((prop, lit, 'color' if fam == 'other' else fam))
                    nm = re.fullmatch(r'\s*(-?\d+(?:\.\d+)?)\s*', expr)
                    if nm and fam in ('space', 'radius', 'font-size', 'z', 'size', 'width') and re.search(r'style|StyleSheet|sx|css', line + ' ' + rp, re.I):
                        found.append((prop, nm.group(1), fam))
                for m in ATTR_COLOR.finditer(line):
                    if parse_color(m.group(2)):
                        found.append((m.group(1), m.group(2), 'color'))
                for m in TW_ARB.finditer(line):
                    nv0 = norm_value(m.group(2))
                    fam = family_of_tw(m.group(1).lstrip('-'), nv0)
                    if fam and not m.group(2).startswith(('var(', '--', 'calc(', 'theme(')):
                        found.append((m.group(1) + '-[]', m.group(2), fam))
            seen = set()
            for prop, lit, fam in found:
                nv = norm_value(lit, fam)
                key = (prop, nv)
                if key in seen:
                    continue
                seen.add(key)
                r = classify(prow, themes, nv, fam, rem)
                sites.append(dict(site='%s:%d' % (rp, ln), prop=prop, literal=lit.strip(), value=nv, family=fam,
                                  scope=scope, **r))
    return sites, files, exempt_files


# ---------------------------------------------------------------- CLI
COLS_TOKEN = ['name', 'theme', 'family', 'value', 'raw', 'source', 'pkg', 'lineage']
COLS_SITE = ['site', 'prop', 'literal', 'value', 'family', 'class', 'candidates', 'eq', 'nearest', 'distance', 'xfam',
             'note', 'scope']


def tsv(kind, cols, recs):
    lines = ['# %s\t%s' % (kind, '\t'.join(cols))]
    for r in recs:
        lines.append('\t'.join(str(r.get(c, '')).replace('\t', ' ').replace('\n', ' ') for c in cols))
    return '\n'.join(lines)


def main(argv):
    if argv == ['--self-test']:
        return self_test()
    opts = {'json': False, 'scan': False, 'names': False, 'max': 0, 'rem': 16.0}
    root = None
    for a in argv:
        if a == '--json': opts['json'] = True
        elif a == '--scan': opts['scan'] = True
        elif a == '--names': opts['names'] = True
        elif a.startswith('--max='): opts['max'] = int(a[6:])
        elif a.startswith('--rem='): opts['rem'] = float(a[6:])
        elif a.startswith('--lookup='): opts['lookup'] = a[9:]
        elif a.startswith('--family='): opts['family'] = a[9:]
        elif a.startswith('--prop='): opts['prop'] = a[7:]
        elif a.startswith('--resolve='): opts['resolve'] = a[10:]
        elif a.startswith('--site='): opts['site'] = a[7:]
        elif a.startswith('-'):
            sys.stderr.write('token-map: unknown option %s\n' % a); return 2
        elif root is None: root = a
        else:
            sys.stderr.write('token-map: one root only\n'); return 2
    if not root or not os.path.isdir(root):
        sys.stderr.write(__doc__.split('\n\n')[2] + '\n'); return 2
    rows, sources, themes = build_map(root)
    sys.stderr.write('token-map: %d tokens (%d names) · themes %s · sources %s\n' % (
        len(rows), len({t.name for t in rows}), '+'.join(themes) or '-', ', '.join(sources) or 'none'))
    if opts['names']:
        for n in sorted({t.name for t in rows}):
            print(n)
        return 0
    if 'resolve' in opts:
        recs = [dict(name=t.name, theme=t.theme, family=t.family, value=t.value, raw=t.raw, source=t.source, pkg=t.pkg,
                     lineage=t.lineage) for t in rows if t.name == opts['resolve']]
        print(json.dumps(recs, indent=1) if opts['json'] else tsv('RESOLVE', COLS_TOKEN, recs))
        return 0 if recs else 1
    if 'lookup' in opts:
        fam = opts.get('family') or (family_of_prop(opts['prop']) if 'prop' in opts else None)
        if fam not in FAMILIES:
            sys.stderr.write('token-map: --lookup needs --family=<%s> or --prop\n' % '|'.join(FAMILIES)); return 2
        nv = norm_value(opts['lookup'], fam)
        prow, scope = rows, 'repo'
        if 'site' in opts:
            prow, scope = rows_for(rows, pkg_of(opts['site'].split(':')[0], package_dirs(root)))
        r = classify(prow, themes, nv, fam, opts['rem'])
        rec = dict(site=opts.get('site', '-'), prop=opts.get('prop', '-'), literal=opts['lookup'], value=nv, family=fam,
                   scope=scope, **r)
        print(json.dumps(rec, indent=1) if opts['json'] else tsv('LOOKUP', COLS_SITE, [rec]))
        return 0 if r['class'] == 'EXACT' else 1
    if opts['scan']:
        sites, nfiles, nex = scan_sites(root, rows, themes, sources, opts['rem'])
        counts = {}
        for s in sites:
            counts[s['class']] = counts.get(s['class'], 0) + 1
        xf = sum(1 for s in sites if s['xfam'] and s['class'] != 'EXACT')
        eq = sum(1 for s in sites if s['eq'] == 'yes')
        sys.stderr.write('token-map --scan: matched %d files (%d exempt by path) · sites %d · EXACT %d (eq %d) · '
                         'NEAREST %d · NONE %d · EXEMPT %d · cross-family %d\n' % (
                             nfiles, nex, len(sites), counts.get('EXACT', 0), eq, counts.get('NEAREST', 0),
                             counts.get('NONE', 0), counts.get('EXEMPT', 0), xf))
        shown = [s for s in sites if s['class'] != 'EXEMPT']
        if opts['max']:
            shown = shown[:opts['max']]
        print(json.dumps(shown, indent=1) if opts['json'] else tsv('SITE', COLS_SITE, shown))
        return 1 if counts.get('EXACT') or counts.get('NEAREST') else 0
    recs = [dict(name=t.name, theme=t.theme, family=t.family, value=t.value, raw=t.raw, source=t.source, pkg=t.pkg,
                 lineage=t.lineage) for t in rows]
    if opts['json']:
        print(json.dumps({'themes': themes, 'sources': sources, 'tokens': recs}, indent=1))
    else:
        fam = {}
        for t in rows:
            fam.setdefault(t.theme, {}).setdefault(t.family, 0)
            fam[t.theme][t.family] += 1
        for th in themes:
            sys.stderr.write('  %s: %s\n' % (th, ' '.join('%s=%d' % kv for kv in sorted(fam.get(th, {}).items()))))
        print(tsv('TOKEN', COLS_TOKEN, recs))
    return 0


# ---------------------------------------------------------------- self-test
def self_test():
    base = tempfile.mkdtemp(prefix='token-map-', dir=os.environ.get('TMPDIR') or None)
    root = os.path.join(base, 'benchmarks', 'fixtures', 'app')          # lesson (a): an absolute /fixtures/ path
    files = {
        'src/styles/tokens.css': ':root {\n  --color-danger: #d92d20;\n  --color-primary: #2563eb;\n  --space-2: 8px;\n'
                                 '  --space-3: 12px;\n  --font-size-sm: 13px;\n  --radius-md: 8px;\n  --gap-sm: 8px;\n'
                                 '  --brand: var(--color-primary);\n  --z-overlay: 40;\n  --ease-std: cubic-bezier(0.2, 0, 0, 1);\n}\n'
                                 '[data-theme="dark"] {\n  --color-primary: #818cf8;\n}\n.card { --local: #123456; }\n',
        'src/app/globals.css': '@import "tailwindcss";\n@custom-variant dark (&:where(.dark, .dark *));\n'
                               '@theme {\n  --color-ink: oklch(0.21 0.034 264.665);\n  --text-xs: 0.75rem;\n}\n'
                               '.dark {\n  --color-ink: #f9fafb;\n}\n@media (prefers-color-scheme: dark) {\n  :root { --space-9: 99px; }\n}\n'
                               '.box {\n  padding: 13px;\n  border: 1px solid #e4e7ec;\n  margin: 0;\n  width: 100%;\n  color: rgb(217 45 32);\n}\n',
        'tokens/brand.tokens.json': json.dumps({'color': {'base': {'red': {'$value': '#d92d20', '$type': 'color'}},
                                                          'alert': {'$value': '{color.base.red}', '$type': 'color'}}}),
        'src/theme.ts': "export const theme = {\n  colors: { ink: '#101828', muted: '#667085' },\n  space: { 4: 16 },\n} as const;\n",
        'src/components/Row.tsx': "export function Row({ s }) {\n"
                                  "  return <td style={{ padding: '13px', minWidth: 420 }}>\n"
                                  "    <span style={{ color: s === 'failed' ? '#d92d20' : 'var(--color-text-muted)' }} />\n"
                                  "    <div className=\"p-[8px] bg-[#2563eb] text-[13px]\" />\n"
                                  "    <a href=\"#add\" style={{ gap: '8px', borderColor: '#1a73e9' }} />\n"
                                  "    <svg><path fill=\"#2563eb\" /></svg>\n  </td>;\n}\n",
        'src/components/Row.test.tsx': "const x = { color: '#d92d20' };\n",
        'emails/receipt.html': '<td style="color:#d92d20">x</td>\n',
    }
    for f, c in files.items():
        p = os.path.join(root, f)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w') as fh:
            fh.write(c)
    bad, total = [], 0

    def check(name, cond, extra=''):
        nonlocal_total[0] += 1
        if not cond:
            bad.append(name + (' — ' + extra if extra else ''))
    nonlocal_total = [0]
    try:
        rows, sources, themes = build_map(root)
        names = {t.name for t in rows}
        check('themes light+dark', themes[:1] == ['light'] and 'dark' in themes)
        check('local custom property is not a token', '--local' not in names)
        check('@custom-variant does not swallow @theme', any(t.name == '--text-xs' and t.theme == 'light' for t in rows))
        check('.dark override read', value_in(rows, '--color-ink', 'dark') == '#f9fafb')
        check('var() alias resolves', value_in(rows, '--brand', 'light') == '#2563eb')
        check('alias follows dark', value_in(rows, '--brand', 'dark') == '#818cf8')
        check('DTCG {alias} resolves', value_in(rows, 'color-alert', 'light') == '#d92d20')
        check('TS object read, number -> px', value_in(rows, 'theme.space.4', 'light') == '16px')
        check('oklch converts to hex', re.fullmatch(r'#[0-9a-f]{6}', value_in(rows, '--color-ink', 'light') or '') is not None)
        check('z family', any(t.name == '--z-overlay' and t.family == 'z' for t in rows))
        check('easing family', any(t.name == '--ease-std' and t.family == 'easing' for t in rows))
        check('prefers-color-scheme dark', any(t.name == '--space-9' and t.theme == 'dark' for t in rows))
        c = classify(rows, themes, norm_value('13px', 'space'), 'space')
        check('13px padding is NOT exact (cross-family)', c['class'] == 'NEAREST' and '--font-size-sm' in c['xfam'])
        c = classify(rows, themes, norm_value('13px', 'font-size'), 'font-size')
        check('13px font-size is EXACT', c['class'] == 'EXACT' and c['eq'] == 'yes')
        c = classify(rows, themes, norm_value('#2563eb', 'color'), 'color')
        check('primary differs in dark -> not eq', c['class'] == 'EXACT' and c['eq'] == 'no' and 'theme-differs' in c['note'])
        c = classify(rows, themes, norm_value('8px', 'space'), 'space')
        check('8px space has two candidates -> not eq', c['class'] == 'EXACT' and c['eq'] == 'no' and ',' in c['candidates'])
        c = classify(rows, themes, norm_value('#d92d20', 'color'), 'color')
        check('#d92d20 exact (css + dtcg names)', c['class'] == 'EXACT' and '--color-danger' in c['candidates'])
        c = classify(rows, themes, norm_value('rgb(217 45 32)', 'color'), 'color')
        check('rgb() normalises to the hex token', c['class'] == 'EXACT')
        c = classify(rows, themes, norm_value('#1a73e9', 'color'), 'color')
        check('#1a73e9 nearest primary', c['class'] == 'NEAREST' and c['nearest'].startswith('--color-primary'))
        c = classify(rows, themes, norm_value('420px', 'size'), 'size')
        check('layout width NONE (P-30)', c['class'] == 'NONE' and 'P-30' in c['note'])
        c = classify(rows, themes, norm_value('0.8125rem', 'font-size'), 'font-size')
        check('rem vs px: NEAREST unit-equivalent', c['class'] == 'NEAREST' and c['note'] == 'unit-equivalent')
        check('1px hairline exempt', classify(rows, themes, '1px', 'color')['class'] == 'EXEMPT')
        # width family (measured 2026-10-18 on a real React app: 9 `border-[1.5px]` came out NEAREST to an ICON size token,
        # 4 `outline-[…]` / `decoration-[…]` thicknesses as colours, "not comparable")
        check('border/outline/decoration thickness is the width family',
              family_of_tw('border', '1.5px') == 'width' and family_of_tw('decoration', '1.5px') == 'width'
              and family_of_tw('outline', '2px') == 'width' and family_of_tw('outline', '#ffffff') == 'color'
              and family_of_prop('border-top-width') == 'width' and family_of_prop('textDecorationThickness') == 'width')
        check('a width token is the width family, not size', family_of_token('--border-width-thin', '1.5px') == 'width')
        c = classify(rows, themes, norm_value('1.5px', 'width'), 'width')
        check('a thickness with no width tokens is NONE, never NEAREST to another family', c['class'] == 'NONE' and 'no width tokens' in c['note'])
        sites, nfiles, nex = scan_sites(root, rows, themes, sources)
        by = {}
        for s in sites:
            by.setdefault((s['site'], s['value']), s)
        check('root-relative exclusions still scan a /fixtures/ root', nfiles >= 2)
        check('test file and email excluded', nex == 2 and not any('test' in s['site'] or 'receipt' in s['site'] for s in sites))
        check('ternary hex found and EXACT', by.get(('src/components/Row.tsx:3', '#d92d20'), {}).get('class') == 'EXACT')
        check('inline 13px NEAREST with xfam', by.get(('src/components/Row.tsx:2', '13px'), {}).get('xfam', '').find('--font-size-sm') >= 0)
        check('minWidth 420 NONE', by.get(('src/components/Row.tsx:2', '420px'), {}).get('class') == 'NONE')
        check('tailwind p-[8px] EXACT', by.get(('src/components/Row.tsx:4', '8px'), {}).get('class') == 'EXACT')
        check('tailwind text-[13px] font-size EXACT', by.get(('src/components/Row.tsx:4', '13px'), {}).get('eq') == 'yes')
        check('href="#add" is not a colour', not any(s['value'] == '#aadddd' for s in sites))
        check('svg fill colour found', by.get(('src/components/Row.tsx:6', '#2563eb'), {}).get('class') == 'EXACT')
        check('css shorthand colour found, its width skipped', by.get(('src/app/globals.css:15', '#e4e7ec'), {}).get('class') == 'NEAREST'
              and ('src/app/globals.css:15', '1px') not in by)
        check('css 13px padding NEAREST', by.get(('src/app/globals.css:14', '13px'), {}).get('class') == 'NEAREST')
        check('css rgb() literal', by.get(('src/app/globals.css:18', '#d92d20'), {}).get('class') == 'EXACT')
        check('token definitions are not sites', not any(s['site'].startswith('src/styles/tokens.css') for s in sites))
        check('TS token source is not a site', not any(s['site'].startswith('src/theme.ts') for s in sites))
        # a monorepo: DTCG source + the CSS built from it in packages/ui; a closed admin theme reusing a name
        mono = os.path.join(base, 'mono')
        for f, c in {
            'package.json': '{"name": "mono", "private": true}',
            'packages/ui/package.json': '{"name": "@acme/ui"}',
            'packages/ui/src/tokens.json': json.dumps({'color': {'$type': 'color', 'danger': {'$value': '#d92d20'},
                                                                 'primary': {'$value': '#1a73e8'}, 'success': {'$value': '#12b76a'}}}),
            'packages/ui/src/tokens.css': ':root {\n  --color-danger: #d92d20;\n  --color-primary: #1a73e8;\n  --color-success: #12b76b;\n}\n'
                                          '[data-theme="dark"] {\n  --color-surface: #101828;\n  --color-primary: #818cf8;\n}\n',
            'apps/admin/package.json': '{"name": "admin"}',
            'apps/admin/src/theme.css': '@theme {\n  --color-primary: #2563eb;\n}\n',
            'apps/admin/src/Filters.vue': '<template>\n  <div class="bg-[#2563eb]" />\n</template>\n',
            'apps/web/package.json': '{"name": "web"}',
            'apps/web/src/Badge.tsx': "export const B = () => <span style={{ color: '#d92d20' }} />;\n",
        }.items():
            fp = os.path.join(mono, f)
            os.makedirs(os.path.dirname(fp), exist_ok=True)
            with open(fp, 'w') as fh:
                fh.write(c)
        mrows, msrc, mthemes = build_map(mono)
        msites, _, _ = scan_sites(mono, mrows, mthemes, msrc)
        mby = {s['site']: s for s in msites}
        web = mby.get('apps/web/src/Badge.tsx:1', {})
        check('DTCG token + the CSS var built from it = one candidate, eq=yes (lineage)',
              web.get('class') == 'EXACT' and web.get('candidates') == '--color-danger' and web.get('eq') == 'yes', str(web))
        check('lineage names the DTCG source', any(t.name == '--color-danger' and 'tokens.json' in t.lineage for t in mrows))
        check('a stale build (values differ) is not folded', any(t.name == 'color-success' for t in mrows))
        check('a CSS-only dark layer still folds; the CSS row keeps its dark value',
              not any(t.name == 'color-primary' for t in mrows)
              and value_in([t for t in mrows if t.pkg == 'packages/ui'], '--color-primary', 'dark') == '#818cf8')
        adm = mby.get('apps/admin/src/Filters.vue:2', {})
        check('a name declared in two packages keeps each package value (admin bg-[#2563eb] EXACT)',
              adm.get('class') == 'EXACT' and adm.get('candidates') == '--color-primary' and adm.get('eq') == 'yes', str(adm))
        check('both --color-primary values survive', {t.value for t in mrows if t.name == '--color-primary' and t.theme == 'light'}
              == {'#2563eb', '#1a73e8'})
    finally:
        shutil.rmtree(base, ignore_errors=True)
    total = nonlocal_total[0]
    for b in bad:
        sys.stderr.write('  FAIL %s\n' % b)
    print('token-map --self-test: %d/%d %s' % (total - len(bad), total, 'OK' if not bad else 'FAIL'))
    return 0 if not bad else 3


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
