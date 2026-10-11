#!/usr/bin/env python3
"""Static regression checks. These do not compile or execute the server."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
core = root / 'Sources/MirrorCore'
server = (root / 'Sources/MirrorServer/MirrorMCPServer.swift').read_text()
tools = (root / 'Sources/MirrorServer/RestrictedMirroringTools.swift').read_text()
source = '\n'.join(f.read_text() for f in (root / 'Sources').rglob('*.swift'))
assert not re.search(r'CGRequest\w*Access\s*\(|AXIsProcessTrustedWithOptions|NSAppleScript', source)
assert 'attemptResume(' not in source
capture = (core / 'MirrorCapture.swift').read_text()
assert 'captureWithCLI' not in capture
assert 'ProcessRunner.run' not in capture
assert 'FileManager' not in capture
assert 'process.run' not in capture
assert 'onScreenWindowsOnly: true' in capture
assert 'RestrictedMirroringTools.all' in server
assert 'MirroringTools.all(' not in server.replace('RestrictedMirroringTools.all(', '')
assert 'XcodeToolCatalog.all' not in server
assert set(re.findall(r'RegisteredTool\(name: "([^"]+)"', tools)) == {'status', 'read_screen', 'navigate', 'stop'}
assert 'step_id' in tools and 'try args.only' in tools
assert 'MirrorSession().doctor()' not in (root / 'Sources/MirrorServer/CommandLine.swift').read_text()
assert 'swift build' not in (root / 'install.sh').read_text()
assert 'exit 2' in (root / 'install.sh').read_text()
assert not (root / 'server.json').exists()
print('Static restricted-surface checks passed. Device behavior remains unverified.')
