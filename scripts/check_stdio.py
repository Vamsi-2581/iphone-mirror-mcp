#!/usr/bin/env python3
"""Exercise the actual restricted binary without approval, capture, or phone input."""
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
binary = Path(sys.argv[1]) if len(sys.argv) > 1 else root / '.build/debug/iphone-mirror-mcp'
env = dict(os.environ)
for name in ['MIRROR_MCP_LIVE', 'MIRROR_APPROVAL_FILE']:
    env.pop(name, None)
with subprocess.Popen([str(binary)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                      stderr=subprocess.DEVNULL, env=env) as proc:
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    request_id = 0
    def request(method, params):
        global request_id
        request_id += 1
        proc.stdin.write((json.dumps({'jsonrpc':'2.0','id':request_id,'method':method,'params':params})+'\n').encode())
        proc.stdin.flush()
        if not selector.select(5):
            raise AssertionError('MCP response timed out')
        response = json.loads(proc.stdout.readline())
        assert response.get('id') == request_id, 'Unexpected response ID'
        assert 'error' not in response, 'Unexpected protocol error'
        return response['result']
    try:
        initialized = request('initialize', {'protocolVersion':'2025-11-25','capabilities':{},
                              'clientInfo':{'name':'restricted-offline-check','version':'1'}})
        assert initialized['serverInfo']['version'] == '1.0.1-restricted.1'
        proc.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        proc.stdin.flush()
        tools = request('tools/list', {})['tools']
        assert {t['name'] for t in tools} == {'status','read_screen','navigate','stop'}
        calls = 0
        for name in ['tap','swipe','type_text','paste_text','read_clipboard','open_url',
                     'record_screen','record_start','screenshot','mirror_launch','batch',
                     'device_install','sim_privacy','run_on_iphone','read_screen']:
            result = request('tools/call', {'name':name,'arguments':{}})
            assert result.get('isError') is True, name
            calls += 1
        for args in [{}, {'step_id':'invented'}, {'step_id':'invented','x':100,'y':100}]:
            assert request('tools/call', {'name':'navigate','arguments':args}).get('isError') is True
            calls += 1
        for name in ['status','stop']:
            assert not request('tools/call', {'name':name,'arguments':{}}).get('isError', False)
            calls += 1
        assert request('tools/call', {'name':'read_screen','arguments':{}}).get('isError') is True
        calls += 1
        print(f'PASS: stdio initialize, exact four-tool catalog, {calls} tool calls; no approval, capture, or device input.')
    finally:
        selector.close()
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)
