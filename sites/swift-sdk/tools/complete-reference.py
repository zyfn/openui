"""Build the reader's data from SDK-owned definitions, tokens and article rows."""
import json, re, hashlib, subprocess, sys
from pathlib import Path
site=Path(__file__).resolve().parents[1]
root=site.parents[1]
out=site/'public/generated'
article=(root/'packages/swift-ui/SDK-REFERENCE.zh-CN.md').read_text()
catalog=json.loads((root/'packages/swift-ui/Sources/OpenUISwiftUI/Resources/upstream-catalog.json').read_text())
library=json.loads((out/'library.json').read_text())
source_manifest=json.loads((out/'source-manifest.json').read_text())
for path,digest in source_manifest['files'].items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest, f'SDK source changed: {path}; run npm run generate on macOS'
roles={}
for line in article.splitlines():
    if line.startswith('| ') and not line.startswith('| ---'):
        cells=[c.strip() for c in line.strip('|').split('|')]
        if len(cells)>=3 and cells[0] in library['components']: roles[cells[0]]={'purpose':cells[1], 'treatment':'｜'.join(cells[2:])}
groups={name:g['name'] for g in catalog['componentGroups'] for name in g['components']}
groups.update({'Map':'Map & SVG','MapPoint':'Map & SVG','SVG':'Map & SVG'})
examples=[{**e,'origin':'组件能力标本'} for e in json.loads((site/'src/specimens.json').read_text())]
for i,text in enumerate(catalog['promptOptions']['examples']):
    start=text.find('root')
    if start>=0: examples.append({'id':f'official-{i}', 'name':text.splitlines()[0].rstrip(':'), 'source':text[start:].strip().removeprefix('```openui-lang').removesuffix('```').strip(), 'origin':'固定上游范例'})
manifest=json.loads((root/'examples/agent-cases/manifest.json').read_text())
for case in manifest['cases']:
    if case['number']>7: continue
    source=(root/'examples/agent-cases'/case['file']).read_text()
    examples.append({'id':f"case-{case['number']:02}", 'name':f"Case {case['number']:02} · "+case['file'].removesuffix('.openui').split('-',2)[-1], 'source':source, 'origin':'SDK 标准用例'})
components=[]
for name,definition in library['components'].items():
    matching=[e['id'] for e in sorted(examples,key=lambda e:len(e['source'])) if re.search(r'\b'+name+r'\(',e['source'])]
    components.append({'name':name,'group':groups.get(name,'Content'),**definition,**roles.get(name,{}),'examples':matching})
# Reading-role leading comes from the implementation, not a second design table.
style=(root/'packages/swift-ui/Sources/OpenUISwiftUI/Theme/NativeComponentStyle.swift').read_text()
leading={}
for cases,value in re.findall(r'case ([^:]+): return ([0-9]+(?:\.[0-9]+)?)',style):
    for role in re.findall(r'\.(\w+)',cases): leading[role]=float(value)
data={'components':components,'examples':examples,'leading':leading,'sourceFingerprint':source_manifest['fingerprint'],'upstreamRevision':catalog['revision']}
text=json.dumps(data,ensure_ascii=False,indent=2)+'\n'
if '--check' in sys.argv:
    saved=json.loads((out/'reference.json').read_text());saved.pop('sourceRevision',None);data.pop('sourceRevision',None)
    if saved!=data: raise SystemExit('Generated reference is stale; run npm run generate')
else: (out/'reference.json').write_text(text)
assert len(components)==87
assert all(c.get('treatment') for c in components), [c['name'] for c in components if not c.get('treatment')]
print(f'Reference: {len(components)} components, {len(examples)} examples; article and contract are SDK-owned.')
