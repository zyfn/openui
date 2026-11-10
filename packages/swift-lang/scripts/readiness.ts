// Native presentation metadata. Syntax marks live only on parser-owned ASTs;
// evaluated values use a WeakMap so application data (including frozen values)
// gains no properties. Neither channel is part of the OpenUI protocol.
import { getCallDefs } from '../../lang-core/src/parser/builtins';
const syntax = Symbol('native.source.syntax');
const closedSyntax = new WeakMap<object, boolean>();
type Placeholder = { name: string; id?: string; props: Record<string, string | number | boolean> };
type Presentation = { complete: boolean; closed: boolean; count?: number; queries?: string[]; observed?: boolean; children?: Record<string, Presentation>; slots?: (number | null)[]; pending?: Record<string, Presentation>; placeholder?: Placeholder };
const presentation = new WeakMap<object, Presentation>();
const ready = new WeakMap<object, boolean>();
const nativeValues = new WeakMap<object, boolean>();
const memo = Symbol('native.source.memo');
const path = Symbol('native.source.path');
// This memo belongs to a materialization context, never to a protocol value.
const materialized = Symbol('native.presentation.materialized');
const emptyScope: ReadonlySet<string> = new Set();

export function tokenComplete(token: any): boolean { return token?.[syntax] !== false; }
export function tagSyntax<T extends object>(value: T, complete: boolean): T {
  if (!closedSyntax.has(value)) closedSyntax.set(value, complete);
  (value as any)[syntax] = complete; return value;
}
export function tagReady<T>(value: T, complete: boolean): T {
  if (value && typeof value === 'object') ready.set(value as object, complete);
  return value;
}
export function tagNativeSource<T extends object>(value: T, complete: boolean, details?: Presentation): T {
  if (details) presentation.set(value, details);
  nativeValues.set(value, complete); return tagReady(value, complete);
}
export function sourceComplete(value: any): boolean {
  return (value && typeof value === 'object' ? ready.get(value) : undefined) ?? value?.[syntax] ?? !value?.partial;
}

// Advisory source boundaries only. Kept out of enumerable values, AST/wire
// serialization and schema validation. Unknown expressions remain conservative.
export function sourcePresentation(value: any): Presentation {
  return (value && typeof value === 'object' ? presentation.get(value) : undefined)
    ?? { complete: sourceComplete(value), closed: sourceComplete(value) };
}
export function copyPresentation<T>(from: any, to: T, observed?: Set<string>): T {
  const previous = sourcePresentation(from);
  const details = observed ? { ...previous,
    queries: [...new Set([...(previous.observed ? previous.queries ?? [] : []), ...observed])], observed: true } : previous;
  if (to && typeof to === 'object') presentation.set(to as object, details);
  return tagReady(to, sourceComplete(from));
}
export function observeQueries(source: any, context: any): { context: any; queries: Set<string> } {
  const candidates = new Set(sourcePresentation(source).queries ?? []);
  if (source?.k === 'RuntimeRef' && source.refType === 'query') candidates.add(source.n);
  const queries = new Set<string>();
  if (!candidates.size) return { context, queries };
  return { queries, context: { ...context, resolveRef: (name: any) => {
    if (typeof name === 'string' && candidates.has(name)) queries.add(name);
    return context.resolveRef(name);
  } } };
}
export function finishMaterialization(node: any, ctx: any, value: any, scope: ReadonlySet<string> = emptyScope): any {
  const records: WeakMap<object, any> = ctx[materialized] ??= new WeakMap();
  if (node && typeof node === 'object') records.set(node, value);
  tagReady(value, astComplete(node, ctx, scope));
  if (!value || typeof value !== 'object') return value;
  presentation.set(value, describeSource(node, ctx, value, scope));
  return value;
}

export function recordResult(result: any, ctx: any, node: any, id?: string): any {
  if (result.root) presentation.set(result, sourcePresentation(result.root));
  else if (node && ctx[materialized]?.has(node) && ctx[materialized].get(node) === null) {
    const details = describeSource(node, ctx, null);
    if (details.placeholder && id) details.placeholder = { ...details.placeholder, id };
    presentation.set(result, details);
  }
  return result;
}

function describeSource(node: any, ctx: any, value: any, scope: ReadonlySet<string> = emptyScope): Presentation {
  const records: WeakMap<object, any> = ctx[materialized] ?? new WeakMap();
  const layoutProps = new Set(['height', 'imageSize', 'size', 'iconSize', 'variant', 'appearance', 'layout', 'direction', 'gap', 'align', 'justify', 'wrap', 'id', 'key', 'resourceId', 'category', 'name']);
  let budget = 0;
  const seen = new Set<any>();
  const pending: Presentation = { complete: false, closed: false };
  const shape = (n: any, v: any): Presentation => {
    if (!n || typeof n !== 'object') return pending;
    if (++budget > 100000 || seen.size > 256 || seen.has(n) || ctx.nativeLimit) return pending;
    const complete = astComplete(n, ctx, scope);
    seen.add(n);
    try {
      if ((n.k === 'Ref' || n.k === 'StateRef') && ctx.syms?.has(n.n)) {
        if (n[syntax] === false) return pending;
        const target = shape(ctx.syms.get(n.n), v);
        return target.placeholder && n.k === 'Ref'
          ? { ...target, placeholder: { ...target.placeholder, id: n.n } } : target;
      }
      const component = n.k === 'Comp' && !getCallDefs(ctx.cat).has(n.name) ? ctx.cat?.get(n.name) : undefined;
      const omitted = n.k === 'Arr' && Array.isArray(v) && n.els.length !== v.length;
      if (complete && !omitted && !(component && v === null)) return { complete: true, closed: true };
      const result: Presentation = { complete, closed: complete || closedSyntax.get(n) === true };
      const children: Record<string, Presentation> = Object.create(null);
      if (n.k === 'Arr') {
        result.count = n.els.length;
        // Observe the already performed materialization; never evaluate a
        // missing node again, repair the Lang array or suppress diagnostics.
        const drops = n.els.map((child: any) => child.k === 'Ph'
          || (['Comp', 'Ref'].includes(child.k) && records.has(child) && records.get(child) === null));
        const known = n.els.every((child: any) => child.k === 'Ph' || records.has(child));
        if (Array.isArray(v) && known && drops.filter((drop: boolean) => !drop).length === v.length) {
          const slots: (number | null)[] = [];
          const missing: Record<string, Presentation> = Object.create(null);
          let index = 0;
          n.els.forEach((child: any, sourceIndex: number) => {
            if (drops[sourceIndex]) {
              slots.push(null);
              const detail = shape(child, null);
              if (detail.placeholder) missing[String(sourceIndex)] = detail;
            } else {
              slots.push(index);
              children[String(index)] = shape(child, v[index]);
              index++;
            }
          });
          if (omitted) result.slots = slots;
          if (Object.keys(missing).length) result.pending = missing;
        } else if (Array.isArray(v) && v.length === n.els.length) {
          n.els.forEach((child: any, i: number) => { children[String(i)] = shape(child, v[i]); });
        }
      } else if (n.k === 'Obj') {
        for (const [key, child] of n.entries) children[key] = shape(child, v?.[key]);
      } else if (component && (v?.type === 'element' || v === null)) {
        const props: Record<string, string | number | boolean> = Object.create(null);
        component.params.forEach((param: any, i: number) => {
          const supplied = i < n.args.length;
          const actual = v?.type === 'element' ? v.props?.[param.name]
            : supplied ? records.get(n.args[i]) : param.defaultValue;
          children[param.name] = supplied ? shape(n.args[i], actual)
            : { complete: result.closed, closed: result.closed };
          if (layoutProps.has(param.name) && children[param.name].complete
            && (typeof actual === 'string' || typeof actual === 'boolean' || (typeof actual === 'number' && Number.isFinite(actual)))) props[param.name] = actual;
        });
        if (v === null) {
          result.placeholder = { name: n.name, props };
          result.queries = queryDependencies(n, ctx, scope);
        }
      }
      if (Object.keys(children).length) result.children = children;
      return result;
    } finally { seen.delete(n); }
  };
  const result = shape(node, value);
  const queries = queryDependencies(node, ctx, scope);
  if (queries.length) result.queries = queries;
  return result;
}

function queryDependencies(node: any, ctx: any, scope: ReadonlySet<string> = emptyScope): string[] {
  const queries = new Set<string>();
  const visited = new Set<any>();
  const collect = (n: any, local: ReadonlySet<string>, depth = 0) => {
    if (!n || typeof n !== 'object' || depth > 256 || visited.has(n) || visited.size >= 100000) return;
    visited.add(n);
    if (n.k === 'RuntimeRef') { if (n.refType === 'query') queries.add(n.n); return; }
    if (n.k === 'Ref' && !local.has(n.n)) {
      const target = ctx.syms?.get(n.n);
      if (target?.k === 'Comp' && target.name === 'Query') queries.add(n.n);
      else collect(target, local, depth + 1);
      return;
    }
    if (n.k === 'Comp') {
      const call = getCallDefs(ctx.cat).get(n.name);
      // A deferred action can retry a failed Query. It is not a dependency of
      // the currently displayed data and must not turn its owner into loading.
      if (call?.kind === 'action') return;
      const def = call ?? ctx.cat?.get(n.name);
      const variable = n.args?.[1];
      const name = variable?.k === 'Str' ? variable.v : variable?.k === 'Ref' ? variable.n : undefined;
      const nested = call?.lazy && name ? new Set([...local, name]) : local;
      (def ? n.args.slice(0, def.params.length) : []).forEach((arg: any, index: number) => {
        if (!(call?.lazy && index === 1)) collect(arg, index > 1 ? nested : local, depth + 1);
      });
      return;
    }
    for (const child of Object.values(n)) {
      if (Array.isArray(child)) child.forEach(v => Array.isArray(v) ? v.forEach(x => collect(x, local, depth + 1)) : collect(v, local, depth + 1));
      else if (child && typeof child === 'object' && 'k' in child) collect(child, local, depth + 1);
    }
  };
  collect(node, scope);
  return [...queries];
}

export function astComplete(node: any, ctx: any, scope: ReadonlySet<string> = emptyScope, seen: Set<any> = ctx[path] ??= new Set()): boolean {
  if (!node || typeof node !== 'object') return true;
  if (seen.size > 256 || ctx.nativeLimit) return false;
  if (node[syntax] === false || node.k === 'Ph') return false;
  const key = scope.size ? [...scope].sort().join('\0') : '';
  const groups: Map<string, WeakMap<object, boolean>> = ctx[memo] ??= new Map();
  let cache = groups.get(key);
  if (!cache) groups.set(key, cache = new WeakMap());
  const known = cache.get(node);
  if (known !== undefined) return known;
  if (seen.has(node)) return false;
  seen.add(node);
  const child = (value: any, local = scope): boolean => astComplete(value, ctx, local, seen);
  let result = true;
  if (node.k === 'Ref' || node.k === 'StateRef') {
    // Opaque native captures and a control's injected $value are already bound.
    if (typeof node.n !== 'string' || scope.has(node.n) || node.n === '$value') result = true;
    else if (node.k === 'StateRef' && !ctx.syms?.has(node.n)) result = true;
    else result = ctx.syms ? ctx.syms.has(node.n) && child(ctx.syms.get(node.n)) : true;
  } else if (node.k === 'Comp') {
    const call = getCallDefs(ctx.cat).get(node.name);
    const definition = call ?? ctx.cat?.get(node.name);
    const lazy = call?.lazy;
    const variable = node.args?.[1];
    const name = variable?.k === 'Str' ? variable.v : variable?.k === 'Ref' ? variable.n : undefined;
    const nested = lazy && name ? new Set([...scope, name]) : scope;
    // Validation drops unsupported calls and excess arguments. Their unused
    // data must not become an unrelated control's readiness dependency.
    const args = definition ? node.args.slice(0, definition.params.length) : [];
    result = args.every((value: any, index: number) => lazy && name && index === 1 ? true : child(value, index > 1 ? nested : scope));
  } else {
    const visit = (value: any): boolean => Array.isArray(value)
      ? value.every(visit) : value && typeof value === 'object' && typeof value.k === 'string' ? child(value) : true;
    result = Object.values(node).every(visit);
  }
  seen.delete(node);
  cache.set(node, result);
  return result;
}

export function finishEvaluation(node: any, value: any, observed?: Set<string>): any {
  const complete = sourceComplete(node) && (value && typeof value === 'object' ? nativeValues.get(value) ?? true : true);
  tagReady(value, complete);
  if (value && typeof value === 'object') {
    const known = sourcePresentation(node);
    const queries = observed ? [...observed] : known.queries;
    presentation.set(value, complete ? { complete: true, closed: true, queries, observed: observed !== undefined }
      : { ...known, complete: false, queries, observed: observed !== undefined });
    // Generated elements depend on the collection that produced them, even
    // when the template only reads its local iterator rather than Query refs.
    if (node.k === 'Comp' && node.name === 'Each' && queries?.length) {
      const seen = new Set<any>();
      const inherit = (item: any, depth = 0) => {
        if (!item || typeof item !== 'object' || depth > 256 || seen.has(item)) return;
        seen.add(item);
        if (Array.isArray(item)) item.forEach(v => inherit(v, depth + 1));
        else if (item.type === 'element') {
          const own = sourcePresentation(item);
          presentation.set(item, { ...own, queries: [...new Set([...(own.queries ?? []), ...queries])], observed: true });
          Object.values(item.props).forEach(v => inherit(v, depth + 1));
        }
      };
      inherit(value);
    }
  }
  // A lazy template can be closed while its input declaration is unfinished.
  // Its generated controls must wait for that input, including nested controls.
  if (node.k === 'Comp' && node.name === 'Each' && !complete) {
    const invalidate = (item: any) => {
      if (!item || typeof item !== 'object') return;
      tagReady(item, false);
      const own = sourcePresentation(item);
      presentation.set(item, { complete: false, closed: false, queries: own.queries, observed: own.observed });
      if (Array.isArray(item)) item.forEach(invalidate);
      else if (item.type === 'element') Object.values(item.props).forEach(invalidate);
    };
    invalidate(value);
  }
  return value;
}
