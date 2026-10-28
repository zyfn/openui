#!/usr/bin/env python3
"""Prepare BPE byte boundaries for native TPS replay; never changes SDK input."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tiktoken

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
package = Path(__file__).resolve().parent.parent
build = Path(subprocess.check_output(['swift', 'build', '--package-path', str(package), '--show-bin-path'], text=True).strip())
target = json.loads(subprocess.check_output(['swiftc', '-print-target-info'], text=True))['target']['unversionedTriple'] + '13.0'
review = package / 'Tests/Review'
tools = args.output / 'TokenExportTool'
tools.mkdir(parents=True, exist_ok=True)
shutil.copy2(args.output / 'ReviewExamples.json', tools / 'ReviewExamples.json')
shutil.rmtree(tools / 'Localization', ignore_errors=True)
shutil.copytree(review / 'Fixtures/Localization', tools / 'Localization')
objects = []
for name in ('COpenUIRegExp', 'OpenUILang', 'OpenUISwiftUI', 'MarkdownUI',
             'NetworkImage', 'cmark_gfm', 'cmark_gfm_extensions'):
    target_build = build / f'{name}.build'
    file_map = target_build / 'output-file-map.json'
    if file_map.exists():
        # SwiftPM may leave .o files from removed sources in an incremental
        # build. Link only the current target outputs, never stale objects.
        outputs = json.loads(file_map.read_text()).values()
        objects.extend(entry['object'] for entry in outputs if 'object' in entry)
    else:
        objects.extend(str(path) for path in target_build.rglob('*.o'))
assert objects, 'Build the macOS Swift package before exporting review sources'
executable = tools / 'ReviewTokenExport'
subprocess.run(['swiftc', '-parse-as-library', '-target', target,
                '-I', str(build / 'Modules'), '-I', str(build / 'COpenUIRegExp.build'),
                str(review / 'Tools/ReviewTokenExport.swift'),
                str(review / 'Host/ReviewLanguage.swift'),
                *map(str, sorted((review / 'Catalog').rglob('*.swift'))),
                *objects, '-o', str(executable)], check=True)
sources_file = tools / 'Sources.json'
subprocess.run([str(executable), str(sources_file)], check=True)
encoding = tiktoken.get_encoding('o200k_base')
records = {}
for source in json.loads(sources_file.read_text()):
    original = source.encode('utf-8')
    pieces = [encoding.decode_single_token_bytes(token) for token in encoding.encode_ordinary(source)]
    assert b''.join(pieces) == original
    records[hashlib.sha256(original).hexdigest()] = [len(piece) for piece in pieces]
(args.output / 'ReviewTokenStreams.json').write_text(json.dumps({
    'encoding': encoding.name, 'byteLengths': records,
}, separators=(',', ':')))
print(f'Prepared {len(records)} source streams with {encoding.name}')
