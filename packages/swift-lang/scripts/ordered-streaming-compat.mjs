import { replaceOnce } from './compat.mjs';

export function orderedStreaming(source, kind, path) {
  const imports = `import * as nativeOrder from ${JSON.stringify(path)};\n`;
  if (kind === 'materialize') {
    source = source.replaceAll('return mode === "expr" ? { k: "Ph", n: name } : null;', 'return mode === "expr" || nativeOrder.orderedCatalog(ctx.cat) ? { k: "Ph", n: name } : null;');
    source = replaceOnce(source, '  const target = ctx.syms.get(name)!;', '  const target = ctx.syms.get(name)!;\n  if (nativeOrder.awaitingReference(target, ctx)) return { k: "Ph", n: name };');
    source = replaceOnce(source, '    case "Ph":\n      return null;', '    case "Ph":\n      return nativeOrder.orderedCatalog(ctx.cat) ? node : null;');
    source = replaceOnce(source, 'if (e.k === "Ph") continue;', 'if (e.k === "Ph" && !nativeOrder.orderedCatalog(ctx.cat)) continue;');
    source = replaceOnce(source, 'return nativeTagReady(nativeBudget(ctx,()=>nativeMaterializeValue(node,ctx),null),nativeASTComplete(node,ctx));', 'return nativeOrder.orderedMaterialized(nativeTagReady(nativeBudget(ctx,()=>nativeMaterializeValue(node,ctx),null),nativeASTComplete(node,ctx)),node,ctx);');
    source = replaceOnce(source, 'return nativeTagReady(nativeBudget(ctx,()=>nativeMaterializeExpr(node,ctx,scopedRefs),{k:"Null"}),nativeASTComplete(node,ctx,scopedRefs));', 'return nativeOrder.orderedMaterialized(nativeTagReady(nativeBudget(ctx,()=>nativeMaterializeExpr(node,ctx,scopedRefs),{k:"Null"}),nativeASTComplete(node,ctx,scopedRefs)),node,ctx);');
  } else if (kind === 'parser') {
    source = replaceOnce(source, '  return map;\n}', '  (map as any).__swiftOrderedRendering = (schema as any).__swiftOrderedRendering === true;\n  return map;\n}');
    source = replaceOnce(source, '  return {\n    root,', '  return nativeOrder.parsed({\n    root,');
    source = replaceOnce(source, '    mutationStatements,\n  };\n}', '    mutationStatements,\n  }, syms, cat);\n}');
  } else if (kind === 'evaluator') {
    source = replaceOnce(source, 'return node.els.map((el) => evaluate(el, context));', 'return nativeOrder.copiedArray(node.els.map((el) => evaluate(el, context)), node, context);');
    source = replaceOnce(source, 'return Object.fromEntries(node.entries.map(([k, v]) => [k, evaluate(v, context)]));', 'return nativeOrder.orderedClone(Object.fromEntries(node.entries.map(([k, v]) => [k, evaluate(v, context)])), node, context);');
    source = replaceOnce(source, 'if (builtin.lazy) return evaluateLazyBuiltin(node.name, node.args, context, schemaCtx);', 'if (builtin.lazy) {\n          if (nativeOrder.ordered(context) && !nativeOrder.syntaxReady(node)) return nativeOrder.pending();\n          return evaluateLazyBuiltin(node.name, node.args, context, schemaCtx);\n        }');
    source = replaceOnce(source, '        return result;\n      }\n      // After materializeValue', '        return nativeOrder.orderedClone(result, node, context);\n      }\n      // After materializeValue');
    source = replaceOnce(source, '    case "Ph":\n      return null;', '    case "Ph":\n      return nativeOrder.ordered(context) ? nativeOrder.pending() : null;');
    source = replaceOnce(source, 'return builtin.fn!(evaluateArgs(node, context));', 'const nativeArgs = evaluateArgs(node, context);\n        return nativeOrder.guarded(nativeArgs, context, () => builtin.fn!(nativeArgs));');
    source = source.replaceAll('const left = evaluate(node.left, context);', 'const left = evaluate(node.left, context);\n        if (nativeOrder.ordered(context) && nativeOrder.isPending(left)) return nativeOrder.pending();');
    source = replaceOnce(source, 'const right = evaluate(node.right, context);', 'const right = evaluate(node.right, context);\n      if (nativeOrder.ordered(context) && nativeOrder.isPending(right)) return nativeOrder.pending();');
    source = replaceOnce(source, 'return !evaluate(node.operand, context);', 'const value = evaluate(node.operand, context);\n        return nativeOrder.ordered(context) && nativeOrder.isPending(value) ? nativeOrder.pending() : !value;');
    source = replaceOnce(source, 'return -toNumber(evaluate(node.operand, context));', 'const value = evaluate(node.operand, context);\n        return nativeOrder.ordered(context) && nativeOrder.isPending(value) ? nativeOrder.pending() : -toNumber(value);');
    source = replaceOnce(source, 'const cond = evaluate(node.cond, context);', 'const cond = evaluate(node.cond, context);\n      if (nativeOrder.ordered(context) && nativeOrder.isPending(cond)) return nativeOrder.pending();');
    source = source.replaceAll('const obj = evaluate(node.obj, context) as any;', 'const obj = evaluate(node.obj, context) as any;\n      if (nativeOrder.ordered(context) && !nativeOrder.dataReady(obj, context)) return nativeOrder.pending();');
    source = replaceOnce(source, 'const idx = evaluate(node.index, context);', 'const idx = evaluate(node.index, context);\n      if (nativeOrder.ordered(context) && nativeOrder.isPending(idx)) return nativeOrder.pending();');
    source = replaceOnce(source, '  const raw = callArgs(node, context, def.params);', '  const raw = callArgs(node, context, def.params);\n  if (nativeOrder.ordered(context) && !nativeOrder.dataReady(raw, context)) return nativeOrder.pending();');
    source = replaceOnce(source, '    if (!Array.isArray(arr)) return [];', '    if (nativeOrder.ordered(context) && nativeOrder.isPending(arr)) return nativeOrder.pending();\n    if (!Array.isArray(arr)) return [];');
    source = replaceOnce(source, '    return arr.map((item, _idx) => {', '    return nativeOrder.copiedArray(arr.map((item, _idx) => {\n      if (nativeOrder.ordered(context) && !nativeOrder.dataReady(item, context)) return nativeOrder.pending();');
    source = replaceOnce(source, '      return result;\n    });\n  }\n  return null;\n}', '      return result;\n    }), arr, context);\n  }\n  return null;\n}');
    source = replaceOnce(source, 'return nativeTagReady({ ...el, props: evaluated }, nativeSourceComplete(el));', 'return nativeOrder.orderedClone(nativeTagReady({ ...el, props: evaluated }, nativeSourceComplete(el)), el, context);');
  } else if (kind === 'evaluate-tree') {
    source = replaceOnce(source, 'return nativeTagReady({ ...el, props: evaluated }, nativeSourceComplete(el));', 'return nativeOrder.orderedClone(nativeTagReady({ ...el, props: evaluated }, nativeSourceComplete(el)), el, evalCtx.ctx);');
  } else if (kind === 'evaluate-prop') {
    source = replaceOnce(source, 'return value.map((v) => callbacks.recurse(v, reactiveSchema));', 'return nativeOrder.copiedArray(value.map((v) => callbacks.recurse(v, reactiveSchema)), value, context);');
    source = replaceOnce(source, 'return result.map((item) =>\n        isElementNode(item) ? callbacks.recurseElement(item as ElementNode) : item,\n      );', 'return nativeOrder.copiedArray(result.map((item) =>\n        isElementNode(item) ? callbacks.recurseElement(item as ElementNode) : item,\n      ), result, context);');
  }
  return imports + source;
}
