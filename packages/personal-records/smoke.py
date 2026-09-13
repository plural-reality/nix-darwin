"""Bounded MCP protocol check; never prints result bodies or credentials."""
import json, os, selectors, subprocess, sys, tempfile, time

def call(proc, selector, message):
    proc.stdin.write(json.dumps(message)+'\n'); proc.stdin.flush()
    deadline=time.monotonic()+70
    while time.monotonic()<deadline:
        if selector.select(timeout=1):
            line=proc.stdout.readline()
            if not line: raise RuntimeError('MCP exited before replying')
            result=json.loads(line)
            if result.get('id')==message['id']: return result
    raise TimeoutError('MCP response timed out')

def check(binary, name):
    with tempfile.TemporaryDirectory() as home, tempfile.TemporaryFile(mode='w+') as errors:
        env={**os.environ,'HOME':home,'XDG_CACHE_HOME':home,'HATENA_USER':'smoke-test','GYAZO_ACCESS_TOKEN':'smoke-test','COSENSE_PAT':'smoke-test'}
        proc=subprocess.Popen([binary,'--mcp-server'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=errors,text=True,env=env,cwd=home)
        selector=selectors.DefaultSelector(); selector.register(proc.stdout,selectors.EVENT_READ)
        try:
            init=call(proc,selector,{'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'smoke','version':'1'}}})
            assert 'result' in init, 'initialize failed'
            proc.stdin.write(json.dumps({'jsonrpc':'2.0','method':'notifications/initialized'})+'\n');proc.stdin.flush()
            result=call(proc,selector,{'jsonrpc':'2.0','id':2,'method':'tools/list','params':{}})
            tools=result['result']['tools']; names=[t['name'] for t in tools]
            assert names and all(not any(word in n for word in ['upload','delete','edit','sync','login']) for n in names), names
            assert all(t.get('annotations',{}).get('readOnlyHint') is True for t in tools), 'missing readOnlyHint'
            rejected=call(proc,selector,{'jsonrpc':'2.0','id':3,'method':'tools/call','params':{'name':'delete_everything','arguments':{}}})
            assert 'error' in rejected or rejected.get('result',{}).get('isError'), 'unknown mutation accepted'
            if name=='cosensecli':
                rejected=call(proc,selector,{'jsonrpc':'2.0','id':4,'method':'tools/call','params':{'name':'cosense_list_projects','arguments':{'origin':'https://example.invalid'}}})
                assert 'error' in rejected or rejected.get('result',{}).get('isError'), 'foreign origin accepted'
            print(json.dumps({'name':name,'initialize':True,'tool_count':len(tools),'read_only':True,'unknown_mutation_rejected':True}))
        finally:
            proc.terminate()
            try: proc.wait(timeout=5)
            except subprocess.TimeoutExpired: proc.kill();proc.wait()
            selector.close()

for arg in sys.argv[1:]:
    name,binary=arg.split('=',1);check(binary,name)
