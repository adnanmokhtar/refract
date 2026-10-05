// measure.ts: the render measurements in ../references/measured-from-the-render.md.
//   § A floatingSurfaces: a container no border, shadow or surface step separates (verb 12)
//   § B controlRows: same-row controls whose height or centre disagree (verb 7)
//   § C navigateInApp / sweep: route through the app's own history, never a goto per route
// Every row is a CANDIDATE for the verb's procedure. It is read with its screenshot, never
// applied blind. Copy next to the project's Playwright specs; it needs @playwright/test only.
import type { Page } from '@playwright/test';

export type Kind = 'text' | 'action' | 'binary' | 'icon';
export interface Opts {
  ready: (page: Page, route: string) => Promise<void>; // waits for THIS route's own content marker, never networkidle
  loginPath?: RegExp;                      // final URL matching it = RENDER BLOCKED (redirected-to-login)
  themes?: string[];                       // e.g. ['light', 'dark']; § A is measured in each one
  applyTheme?: (page: Page, theme: string) => Promise<void>;
  steps?: Partial<Record<Kind, number[]>>; // declared control-height scale per class (§ B, step 3)
  controlClass?: string;                   // CSS selector of the project's control wrapper (§ B, composite)
}
export interface SurfaceRow { theme: string; selector: string; role: string; fill: string; outside: string; ratio: number; shadow: 'none' | 'faint'; verdict: 'floating' | 'review' }
export interface ControlRow { region: string; a: string; b: string; kind: 'same-role' | 'size' | 'centre'; ha: number; hb: number; delta: number; scale: 'declared' | 'none' }
export interface RouteResult { route: string; status: 'scanned' | 'blocked'; reason?: string; navigation: 'first-load' | 'in-app' | 'full-boot'; surfaces: SurfaceRow[]; controls: ControlRow[] }

// § A. Thresholds are the calibrated ones from the reference: pair < 1.2:1, border >= 3:1,
// page = >= 95 % of the viewport width and >= 90 % of its height. minW/minH and the faint-shadow
// alpha are candidate floors, not calibrated values: a 'review' row is read on the screenshot.
export async function floatingSurfaces(page: Page, theme = 'default', minW = 64, minH = 32, faint = 0.05): Promise<SurfaceRow[]> {
  return page.evaluate(({ theme, minW, minH, faint }) => {
    const cv = document.createElement('canvas'); cv.width = cv.height = 1;
    const cx = cv.getContext('2d', { willReadFrequently: true })!;
    const rgba = (c: string): number[] => {             // any CSS colour (oklch, color(), hex) to sRGB 0-255 + alpha 0-1
      cx.clearRect(0, 0, 1, 1); cx.fillStyle = '#000'; cx.fillStyle = c; cx.fillRect(0, 0, 1, 1);
      const d = cx.getImageData(0, 0, 1, 1).data; return [d[0], d[1], d[2], d[3] / 255];
    };
    const over = (t: number[], b: number[]) => [0, 1, 2].map(i => t[i] * t[3] + b[i] * (1 - t[3])).concat(1);
    const lum = (c: number[]) => { const f = (v: number) => { v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); };
    const ratio = (a: number[], b: number[]) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
    const fillBelow = (el: Element | null): number[] => {  // the nearest PAINTED ancestor, composited to opaque
      const stack: number[][] = [];
      for (let n = el; n; n = n.parentElement) { const c = rgba(getComputedStyle(n).backgroundColor); if (c[3] > 0) stack.push(c); if (c[3] >= 1) break; }
      return stack.reverse().reduce((b, t) => over(t, b), [255, 255, 255, 1]);
    };
    const hex = (c: number[]) => '#' + c.slice(0, 3).map(v => Math.round(v).toString(16).padStart(2, '0')).join('');
    const sel = (el: Element) => { const p: string[] = []; for (let n: Element | null = el; n && p.length < 3 && n !== document.body; n = n.parentElement) p.unshift(n.tagName.toLowerCase() + (n.id ? '#' + n.id : [...n.classList].slice(0, 2).map(c => '.' + c).join(''))); return p.join(' > '); };
    const layers = (s: string) => s === 'none' ? [] : s.split(/,(?![^(]*\))/);
    const out: any[] = [];
    for (const el of document.querySelectorAll('body *')) {
      const cs = getComputedStyle(el); const r = el.getBoundingClientRect();
      if (cs.display === 'inline' || cs.visibility !== 'visible' || r.width < minW || r.height < minH) continue;
      if (el.matches('button,a,input,select,textarea,label,option,[role=button],[role=link],img,svg,video,canvas')) continue;
      if (r.width >= 0.95 * innerWidth && r.height >= 0.9 * innerHeight) continue;          // step 0: the page is not a container
      const own = rgba(cs.backgroundColor); if (own[3] === 0 || cs.backgroundImage !== 'none') continue;
      const outside = fillBelow(el.parentElement); const fill = over(own, outside);
      if (fill.slice(0, 3).every((v, i) => Math.abs(v - outside[i]) <= 1)) continue;      // a layout box, not a surface
      const pair = ratio(fill, outside); if (pair >= 1.2) continue;
      const edge = ['Top', 'Right', 'Bottom', 'Left'].some(s => parseFloat((cs as any)[`border${s}Width`]) >= 1 && !/none|hidden/.test((cs as any)[`border${s}Style`]) && ratio(over(rgba((cs as any)[`border${s}Color`]), outside), outside) >= 3)
        || (parseFloat(cs.outlineWidth) >= 1 && cs.outlineStyle !== 'none' && ratio(over(rgba(cs.outlineColor), outside), outside) >= 3);
      if (edge) continue;
      const lift = layers(cs.boxShadow).filter(l => !/inset/.test(l)).map(l => {
        const col = rgba((l.match(/(?:rgba?|oklch|oklab|lab|lch|hsla?|color)\([^)]*\)|#[0-9a-f]{3,8}\b/i) || ['#000'])[0]);
        const len = (l.replace(/\([^)]*\)/g, '').match(/-?[\d.]+px/g) || []).map(parseFloat);
        return len.some(v => v !== 0) ? col[3] : 0;
      }).concat(cs.filter.includes('drop-shadow') ? [1] : []);
      const alpha = Math.max(0, ...lift); if (alpha >= faint) continue;                      // an elevation cue survives
      out.push({ theme, selector: sel(el), role: el.tagName.toLowerCase() + [...el.classList].slice(0, 2).sort().map(c => '.' + c).join(''),
        fill: hex(fill), outside: hex(outside), ratio: Math.round(pair * 1000) / 1000, shadow: alpha > 0 ? 'faint' : 'none', verdict: alpha > 0 ? 'review' : 'floating' });
    }
    return out;
  }, { theme, minW, minH, faint });
}

// § B. A row = same landmark region AND centres within 6 px AND a horizontal gap under 64 px.
// Same class + same role: any height difference. Same class (text-entry and action count as one,
// they ride one control-height scale): >= 2 px unless both sit on a declared step. Any two controls: centres >= 2 px apart. Table rows and brand marks are excluded,
// and a composite control is measured at its wrapper.
export async function controlRows(page: Page, o: Pick<Opts, 'steps' | 'controlClass'> = {}): Promise<ControlRow[]> {
  return page.evaluate(({ steps, controlClass }) => {
    const REGION = 'nav,aside,header,main,footer,dialog,[role=dialog],[role=navigation],[role=banner],[role=main],[role=contentinfo],[role=complementary]';
    const TEXT = /^(text|email|search|number|password|tel|url|date|datetime-local|month|time|week)$/;
    const kindOf = (el: HTMLElement): string | null => {
      const t = el.tagName, ty = (el.getAttribute('type') || 'text').toLowerCase(), role = el.getAttribute('role') || '';
      if (/^(checkbox|radio|switch)$/.test(role) || (t === 'INPUT' && /^(checkbox|radio)$/.test(ty))) return 'binary';
      if (t === 'SELECT' || (t === 'INPUT' && TEXT.test(ty)) || (t === 'TEXTAREA' && Number(el.getAttribute('rows') || 2) <= 1) || /^(combobox|textbox|searchbox|spinbutton)$/.test(role)) return 'text';
      if (t === 'BUTTON' || role === 'button' || (t === 'INPUT' && /^(submit|button|reset)$/.test(ty))) return (el.textContent || '').trim() || (el as HTMLInputElement).value ? 'action' : 'icon';
      return null;
    };
    const boxOf = (el: HTMLElement): HTMLElement => {                                       // composite: measure the wrapper
      if (kindOf(el) !== 'text') return el;
      for (let n = el.parentElement, i = 0; n && i < 3; n = n.parentElement, i++) {
        if (controlClass && n.matches(controlClass)) return n;
        const cs = getComputedStyle(n);
        if (parseFloat(cs.borderTopWidth) >= 1 && parseFloat(cs.paddingLeft) > 0 && n.querySelectorAll('input,select,textarea').length === 1) return n;
      }
      return el;
    };
    const regions = new Map<Element | null, string>();
    const items = [...document.querySelectorAll<HTMLElement>('input,select,textarea,button,[role]')].flatMap(el => {
      const kind = kindOf(el); if (!kind) return [];
      if (el.closest('td,th,[role=row],[role=gridcell]') || el.matches('[class*=logo i],[class*=brand i]') || el.querySelector('[class*=logo i],img[alt*=logo i]')) return [];
      const box = boxOf(el); const r = box.getBoundingClientRect(); const cs = getComputedStyle(box);
      if (!r.width || !r.height || cs.visibility !== 'visible' || el.getAttribute('aria-hidden') === 'true') return [];
      const reg = el.closest(REGION); if (!regions.has(reg)) regions.set(reg, reg ? reg.tagName.toLowerCase() + '#' + regions.size : 'document');
      const name = (el.getAttribute('aria-label') || el.textContent || el.getAttribute('placeholder') || el.getAttribute('name') || el.tagName).trim().slice(0, 30);
      return [{ kind, role: el.getAttribute('role') || el.tagName.toLowerCase(), region: regions.get(reg)!, name, box, l: r.left, r: r.right, h: r.height, cy: r.top + r.height / 2 }];
    }).filter((x, i, all) => !all.some((y, j) => j !== i && y.box !== x.box && y.box.contains(x.box)) && all.findIndex(y => y.box === x.box) === i);
    const root = items.map((_, i) => i); const find = (i: number): number => root[i] === i ? i : (root[i] = find(root[i]));
    items.forEach((a, i) => items.forEach((b, j) => {
      if (j <= i || a.region !== b.region || Math.abs(a.cy - b.cy) > 6) return;
      if (Math.max(b.l - a.r, a.l - b.r) < 64) root[find(i)] = find(j);
    }));
    const out: any[] = [];
    items.forEach((a, i) => items.forEach((b, j) => {
      if (j <= i || find(i) !== find(j)) return;
      const ha = Math.round(a.h), hb = Math.round(b.h), dy = Math.abs(a.cy - b.cy);
      const st = (steps as any)?.[a.kind] || (steps as any)?.[b.kind] ? [...((steps as any)?.[a.kind] || []), ...((steps as any)?.[b.kind] || [])] as number[] : undefined;
      const base = { region: a.region, a: `${a.role} "${a.name}"`, b: `${b.role} "${b.name}"`, ha, hb, scale: st ? 'declared' : 'none' };
      const same = a.kind === b.kind || (/^(text|action)$/.test(a.kind) && /^(text|action)$/.test(b.kind)); // text + action share the control-height scale
      if (a.kind === b.kind && a.role === b.role && ha !== hb) out.push({ ...base, kind: 'same-role', delta: Math.abs(ha - hb) });
      else if (same && Math.abs(ha - hb) >= 2 && !(st && st.includes(ha) && st.includes(hb))) out.push({ ...base, kind: 'size', delta: Math.abs(ha - hb) });
      if (dy >= 2) out.push({ ...base, kind: 'centre', delta: Math.round(dy * 10) / 10 });
    }));
    return out;
  }, { steps: o.steps, controlClass: o.controlClass });
}

// § C. Push the route through the app's own history. Clicks a same-origin link to it when the
// page has one, else pushState + popstate. A boot token on window tells an in-app render from a
// reload; a router that ignores the push gets a goto, recorded as 'full-boot' so the ledger shows it.
export async function navigateInApp(page: Page, path: string, o: Opts): Promise<'in-app' | 'full-boot'> {
  const token = Math.random().toString(36).slice(2);
  await page.evaluate(t => { (window as any).__measureBoot = t; }, token);
  await page.evaluate(p => {
    const a = [...document.querySelectorAll<HTMLAnchorElement>('a[href]')].find(x => { const u = new URL(x.href, location.href); return u.origin === location.origin && u.pathname + u.search === p && !x.target && !x.hasAttribute('download'); });
    if (a) a.click(); else { history.pushState(null, '', p); dispatchEvent(new PopStateEvent('popstate', { state: null })); }
  }, path);
  try {
    await page.waitForURL(u => u.pathname + u.search === path || !!o.loginPath?.test(u.href), { timeout: 5000 });
    await o.ready(page, path);
    if (await page.evaluate(t => (window as any).__measureBoot === t, token)) return 'in-app';
  } catch { await page.goto(path); await o.ready(page, path).catch(() => undefined); }
  return 'full-boot';
}

export async function sweep(page: Page, routes: string[], o: Opts): Promise<{ results: RouteResult[]; summary: string }> {
  const results: RouteResult[] = [];
  for (const [i, route] of routes.entries()) {
    let navigation: RouteResult['navigation'] = 'first-load';
    if (i === 0) { await page.goto(route); await o.ready(page, route).catch(() => undefined); } else navigation = await navigateInApp(page, route, o);
    if (o.loginPath?.test(page.url())) { results.push({ route, status: 'blocked', reason: 'redirected-to-login', navigation, surfaces: [], controls: [] }); continue; }
    const surfaces: SurfaceRow[] = [];
    for (const theme of o.themes ?? ['default']) { if (o.applyTheme) await o.applyTheme(page, theme); surfaces.push(...await floatingSurfaces(page, theme)); }
    results.push({ route, status: 'scanned', navigation, surfaces, controls: await controlRows(page, o) });
  }
  const n = (f: (r: RouteResult) => boolean) => results.filter(f).length;
  const summary = `routes ${routes.length} = scanned ${n(r => r.status === 'scanned')} + blocked ${n(r => r.status === 'blocked')} · navigation: in-app ${n(r => r.navigation === 'in-app')}, full-boot ${n(r => r.navigation === 'full-boot')}`;
  return { results, summary };
}
