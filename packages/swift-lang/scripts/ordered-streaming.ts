// Native-only ordered publication. No new language token or application-data
// marker: pending identity and source syntax live in private metadata.
import { tokenComplete, tagReady, sourceComplete } from './readiness';

const pendingValue = Object.freeze({});
const ownsSyntax = new WeakMap<object, boolean>();
const parseMetadata = new WeakMap<object, { pendingStates: Set<string>; streaming: boolean }>();
export const pending = () => pendingValue;
export const isPending = (value: any) => value === pendingValue;
export const ordered = (context: any) => context?.__swiftOrderedRendering === true;
export const orderedCatalog = (catalog: any) => catalog?.__swiftOrderedRendering === true;

function ownComplete(value: any): boolean {
  return value && typeof value === 'object'
    ? (ownsSyntax.get(value) ?? tokenComplete(value)) : true;
}
export const syntaxReady = ownComplete;

export function orderedMaterialized<T>(value: T, node: any, context: any): T {
  if (orderedCatalog(context.cat) && value && typeof value === 'object') {
    ownsSyntax.set(value, ownComplete(value) && tokenComplete(node));
  }
  return value;
}

export function orderedClone<T>(value: T, source: any, context: any): T {
  if (ordered(context) && value && typeof value === 'object') ownsSyntax.set(value, ownComplete(source));
  return value;
}

export function awaitingReference(target: any, context: any): boolean {
  return orderedCatalog(context.cat) && !tokenComplete(target) && target.k !== 'Comp' && target.k !== 'Arr';
}

export function parsed(result: any, symbols: Map<string, any>, catalog: any): any {
  if (orderedCatalog(catalog)) parseMetadata.set(result, {
    pendingStates: new Set(Object.keys(result.stateDeclarations).filter(name => !symbols.has(name) || !tokenComplete(symbols.get(name)))),
    streaming: false,
  });
  return result;
}

export function streamResult(result: any, complete: boolean): any {
  const metadata = parseMetadata.get(result);
  if (!metadata) return result;
  const snapshot = { ...result };
  parseMetadata.set(snapshot, { ...metadata, streaming: !complete });
  return snapshot;
}

export function evaluation(context: any, library: any, result?: any): any {
  if (library?.__swiftOrderedRendering !== true) return context;
  const metadata = result && parseMetadata.get(result);
  const pendingStates = metadata?.streaming ? metadata.pendingStates : new Set<string>();
  return { ...context, __swiftOrderedRendering: true, __swiftPendingStates: pendingStates,
    getState: (name: string) => name !== '$value' && pendingStates.has(name) ? pendingValue : context.getState(name),
  };
}

export function dataReady(value: any, context: any, seen = new Set<any>()): boolean {
  if (isPending(value)) return false;
  if (!value || typeof value !== 'object' || seen.has(value)) return true;
  if (!ownComplete(value)) return false;
  seen.add(value);
  if (value.__reactive === 'assign' && context?.__swiftPendingStates?.has(value.target)) return false;
  if (Array.isArray(value.steps) && !sourceComplete(value)) return false;
  return Object.values(value).every(child => dataReady(child, context, seen));
}

export function guarded(args: any, context: any, run: () => any): any {
  return ordered(context) && !dataReady(args, context) ? pendingValue : run();
}

export function copiedArray(value: any[], source: any, context: any): any[] {
  return orderedClone(value, source, context);
}

type Published = { value: any; available: boolean; complete: boolean };
function project(value: any, context: any): Published {
  if (isPending(value)) return { value: undefined, available: false, complete: false };
  if (Array.isArray(value)) {
    const items: any[] = [];
    let complete = ownComplete(value);
    for (const child of value) {
      const item = project(child, context);
      if (item.available) items.push(item.value);
      if (!item.complete) { complete = false; break; }
    }
    return { value: items, available: true, complete };
  }
  if (value?.type === 'element' && typeof value.typeName === 'string' && value.props) {
    const props: Record<string, any> = {};
    let complete = ownComplete(value);
    for (const [key, child] of Object.entries(value.props)) {
      // A flow's children can expose their ready prefix. Other properties
      // (markers, data, ids, action, etc.) must be resolved before the block.
      if (key === 'children' && Array.isArray(child)) {
        const part = project(child, context); props[key] = part.value;
        complete &&= part.complete;
      } else {
        if (!dataReady(child, context)) return { value: undefined, available: false, complete: false };
        props[key] = child;
      }
    }
    return { value: tagReady({ ...value, props }, complete), available: true, complete };
  }
  return { value, available: true, complete: dataReady(value, context) };
}

export function publishRoot(value: any, context: any): any {
  if (!ordered(context)) return value;
  const published = project(value, context);
  return published.available ? published.value : null;
}
