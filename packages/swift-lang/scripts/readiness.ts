// Native presentation metadata. Syntax marks live only on parser-owned ASTs;
// evaluated values use a WeakMap so application data (including frozen values)
// gains no properties. Neither channel is part of the OpenUI protocol.
import { getCallDefs } from '../../lang-core/src/parser/builtins';
const syntax = Symbol('native.source.syntax');
const closedSyntax = new WeakMap<object, boolean>();
type Presentation = { complete: boolean; closed: boolean; count?: number; queries?: string[]; children?: Record<string, Presentation> };
const presentation = new WeakMap<object, Presentation>();
const ready = new WeakMap<object, boolean>();
const nativeValues = new WeakMap<object, boolean>();
const memo = Symbol('native.source.memo');
const path = Symbol('native.source.path');
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
export function copyPresentation<T>(from: any, to: T): T {
  if (to && typeof to === 'object') presentation.set(to as object, sourcePresentation(from));
  return tagReady(to, sourceComplete(from));
}
export function finishMaterialization(node: any, ctx: any, value: any, scope: ReadonlySet<string> = emptyScope): any {
  tagReady(value, astComplete(node, ctx, scope));
  if (!value || typeof value !== 'object') return value;
  let budget = 0;
  const seen = new Set<any>();
  const pending: Presentation = { complete: false, closed: false };
  const shape = (n: any, v: any): Presentation => {
    if (!n || typeof n !== 'object') return pending;
    if (++budget > 100000 || seen.size > 256 || seen.has(n)) return pending;
    const complete = astComplete(n, ctx, scope);
    if (complete) return { complete: true, closed: true };
    seen.add(n);
    try {
      if ((n.k === 'Ref' || n.k === 'StateRef') && ctx.syms?.has(n.n))
        return n[syntax] === false ? pending : shape(ctx.syms.get(n.n), v);
      const result: Presentation = { complete: false, closed: closedSyntax.get(n) === true };
      const children: Record<string, Presentation> = Object.create(null);
      if (n.k === 'Arr') {
        result.count = n.els.length;
        // Materialization can prune unresolved elements. Never assign an AST
        // item's boundary to another value after such a positional shift.
        if (Array.isArray(v) && v.length === n.els.length)
          n.els.forEach((child: any, i: number) => { children[String(i)] = shape(child, v[i]); });
      } else if (n.k === 'Obj') {
        for (const [key, child] of n.entries) children[key] = shape(child, v?.[key]);
      } else if (n.k === 'Comp' && v?.type === 'element') {
        const def = ctx.cat?.get(n.name);
        def?.params.forEach((param: any, i: number) => {
          children[param.name] = i < n.args.length ? shape(n.args[i], v.props?.[param.name])
            : { complete: result.closed, closed: result.closed };
        });
      }
      if (Object.keys(children).length) result.children = children;
      return result;
    } finally { seen.delete(n); }
  };
  const result = shape(node, value);
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
  if (queries.size) result.queries = [...queries];
  presentation.set(value, result);
  return value;
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

export function finishEvaluation(node: any, value: any): any {
  const complete = sourceComplete(node) && (value && typeof value === 'object' ? nativeValues.get(value) ?? true : true);
  tagReady(value, complete);
  if (value && typeof value === 'object') {
    const known = presentation.get(node);
    presentation.set(value, complete ? { complete: true, closed: true, queries: known?.queries }
      : known ?? { complete: false, closed: false });
  }
  // A lazy template can be closed while its input declaration is unfinished.
  // Its generated controls must wait for that input, including nested controls.
  if (node.k === 'Comp' && node.name === 'Each' && !complete) {
    const invalidate = (item: any) => {
      if (!item || typeof item !== 'object') return;
      tagReady(item, false);
      presentation.set(item, { complete: false, closed: false });
      if (Array.isArray(item)) item.forEach(invalidate);
      else if (item.type === 'element') Object.values(item.props).forEach(invalidate);
    };
    invalidate(value);
  }
  return value;
}
