#!/usr/bin/env python3
"""Versioned corporate evidence -> bounded Docs edits -> verified newsletter draft."""
import argparse, contextlib, datetime as dt, difflib, fcntl, hashlib, json, os
from pathlib import Path
import re, signal, subprocess, tempfile, time
DEADLINE = time.monotonic()+1200


def data(v): return (json.dumps(v, ensure_ascii=False, sort_keys=True, indent=2)+'\n').encode()
def sha(v): return hashlib.sha256(data(v)).hexdigest()
def now(): return dt.datetime.now(dt.timezone.utc).isoformat()
def save(p,v):
    p.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    fd,tmp=tempfile.mkstemp(prefix='.partial-',dir=p.parent)
    try:
        with os.fdopen(fd,'wb') as f: f.write(data(v)); f.flush(); os.fsync(f.fileno())
        os.replace(tmp,p)
    finally: Path(tmp).unlink(missing_ok=True)
def store(root,kind,v):
    key=sha(v); p=root/kind/(key+'.json')
    if p.exists() and p.read_bytes()!=data(v): raise ValueError('corrupt_existing_object')
    if not p.exists(): save(p,v)
    return key
def read(root,kind,key):
    if not re.fullmatch('[0-9a-f]{64}',key): raise ValueError('invalid_id')
    p=root/kind/(key+'.json')
    if p.is_symlink(): raise ValueError('symlink_forbidden')
    v=json.loads(p.read_text())
    if sha(v)!=key: raise ValueError('hash_mismatch')
    return v

def run(args):
    if time.monotonic()>=DEADLINE: raise RuntimeError('collection_deadline')
    p=subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
    try: out,_=p.communicate(timeout=max(0,min(90,DEADLINE-time.monotonic())))
    except subprocess.TimeoutExpired:
        with contextlib.suppress(ProcessLookupError): os.killpg(p.pid,signal.SIGKILL)
        p.communicate(); raise RuntimeError('source_timeout') from None
    if p.returncode: raise RuntimeError('command_failed_'+str(p.returncode))
    return json.loads(out)
def gws(service,resource,method,params,body=None):
    args=['gws',service,resource,method,'--params',json.dumps(params)]
    return run(args+(['--json',json.dumps(body)] if body is not None else []))
def doc_get(doc): return gws('docs','documents','get',{'documentId':doc,'includeTabsContent':True})
def tabs(doc):
    def walk(items):
        return [y for x in items for y in [x]+walk(x.get('childTabs',[]))]
    return {x['tabProperties']['tabId']:x for x in walk(doc.get('tabs',[]))}
def paragraphs(tab):
    # Only direct body paragraphs are editable; tables and embedded content stay untouched.
    return [{'start':x['startIndex'],'end':x['endIndex'],
             'text':''.join(e.get('textRun',{}).get('content','') for e in x['paragraph']['elements']),
             'editable':all('textRun' in e for e in x['paragraph']['elements'])}
            for x in tab['documentTab']['body']['content'] if 'paragraph' in x and 'startIndex' in x]
def plain(tab): return ''.join(p['text'] for p in paragraphs(tab))

def collect(root,cfg,start,end):
    dt.date.fromisoformat(start);dt.date.fromisoformat(end)
    if start>end: raise ValueError('invalid_period')
    pages={};gaps=[]
    for project in cfg['projects']:
        try:
            result=run(['cosense-fetch','-s',project['query'],'-p','plural-reality','-l','100'])
            candidates=result.get('pages',[])
            if len(candidates)>=100:gaps.append(project['id']+':search_limit')
            candidates=sorted(candidates,key=lambda x:x.get('updated',0),reverse=True)
            if len(candidates)>12:gaps.append(project['id']+':bounded_to_12_recent_pages')
            for item in candidates[:12]:
                if item['id'] in pages:
                    pages[item['id']]['projects']=sorted(set(pages[item['id']]['projects']+[project['id']]))
                    continue
                raw=run(['cosense-fetch','-r',item['title'],'-p','plural-reality'])
                value={'id':raw['id'],'title':raw['title'],'updated':raw.get('updated'),
                       'lines':[{'id':x['id'],'text':x['text']} for x in raw['lines']]}
                key=store(root,'objects',value)
                pages[raw['id']]={'source':'scrapbox','id':raw['id'],'hash':key,'title':raw['title'],'projects':[project['id']]}
        except (RuntimeError,KeyError,ValueError,OSError) as e:gaps.append(project['id']+':'+type(e).__name__)
    docs={}
    for name,target in cfg['targets'].items():
        if not target.get('documentId'):gaps.append(name+':target_unconfigured');continue
        current=doc_get(target['documentId'])
        docs[name]={'documentId':target['documentId'],'hash':store(root,'docs',current)}
    old_index=root/'latest.json'
    old=read(root,'inputs',json.loads(old_index.read_text())['input']) if old_index.exists() else {'pages':[]}
    before={p['id']:p['hash'] for p in old['pages']};after={p['id']:p['hash'] for p in pages.values()}
    value={'period':{'from':start,'to':end},'observedAt':now(),'configHash':sha(cfg),'pages':sorted(pages.values(),key=lambda x:x['id']),
           'docs':docs,'gaps':gaps,'diff':{'added':[k for k in after if k not in before],
           'changed':[k for k in after if k in before and after[k]!=before[k]],
           'notObserved':[k for k in before if k not in after]},
           'boundary':'Recent corporate pages are evidence candidates, not proof of activity during the period. Other providers are not directly connected; follow only explicitly related references.'}
    key=store(root,'inputs',value);save(old_index,{'input':key})
    return {'input':key,'pages':len(pages),'gaps':gaps,'docs':list(docs),'diff':value['diff']}

def validate(root,cfg,proposal):
    source=read(root,'inputs',proposal['input']);known={p['hash'] for p in source['pages']}
    if source['configHash']!=sha(cfg):raise ValueError('configuration_changed')
    edits=proposal['edits']
    if not isinstance(edits,list) or len(edits)>30:raise ValueError('too_many_edits')
    seen=set()
    for target,tab in {(e['target'],e['tab']) for e in edits}:
        if len({e['mode'] for e in edits if e['target']==target and e['tab']==tab})>1:raise ValueError('mixed_modes_in_tab')
    for e in edits:
        if e['target'] not in source['docs']:raise ValueError('target_not_in_input')
        if not e.get('evidence') or not set(e['evidence'])<=known:raise ValueError('unknown_evidence')
        if e.get('certainty') not in ['supported','qualified']:raise ValueError('unsupported_claim')
        if e.get('audienceChecked') is not True:raise ValueError('audience_not_checked')
        if e['mode'] not in ['replace-paragraph','prepend']:raise ValueError('invalid_mode')
        if not isinstance(e['text'],str) or not e['text'].strip() or len(e['text'])>12000:raise ValueError('invalid_text')
        target=source['docs'][e['target']];doc=read(root,'docs',target['hash']);tt=tabs(doc)
        if e['tab'] not in tt:raise ValueError('tab_not_in_input')
        signature=(e['target'],e['tab'],'prepend' if e['mode']=='prepend' else e.get('old',''))
        if signature in seen:raise ValueError('overlapping_edits')
        seen.add(signature)
        if e['mode']=='replace-paragraph':
            matches=[p for p in paragraphs(tt[e['tab']]) if p['text']==e.get('old')]
            if len(matches)!=1:raise ValueError('paragraph_not_unique')
            if not matches[0]['editable']:raise ValueError('non_text_paragraph_read_only')
    return source

def requests_for(doc,edits):
    tt=tabs(doc);ops=[]
    for e in edits:
        text=e['text'].rstrip('\n')+'\n'
        if e['mode']=='prepend':ops.append((1,[{'insertText':{'location':{'index':1,'tabId':e['tab']},'text':text+'\n'}}]));continue
        p=next(p for p in paragraphs(tt[e['tab']]) if p['text']==e['old'])
        # Google Docs indices are UTF-16; use API-provided indices, preserve final newline.
        if p['end']-p['start']<=1:raise ValueError('empty_paragraph')
        ops.append((p['start'],[{'deleteContentRange':{'range':{'startIndex':p['start'],'endIndex':p['end']-1,'tabId':e['tab']}}},
                   {'insertText':{'location':{'index':p['start'],'tabId':e['tab']},'text':text[:-1]}}]))
    return [r for _,group in sorted(ops,key=lambda x:x[0],reverse=True) for r in group]

def stage(root,cfg,proposal):
    source=validate(root,cfg,proposal);diffs=[]
    for e in proposal['edits']:
        diffs.append({'target':e['target'],'tab':e['tab'],'diff':''.join(difflib.unified_diff(e.get('old','').splitlines(True),(e['text'].rstrip()+'\n').splitlines(True),fromfile='before',tofile='after'))})
    key=store(root,'plans',proposal)
    return {'plan':key,'edits':len(proposal['edits']),'diffs':diffs,'inputGaps':source['gaps']}

def expected_tabs(before,edits):
    result={}
    for tabid in {e['tab'] for e in edits}:
        subset=[e for e in edits if e['tab']==tabid]
        original=paragraphs(tabs(before)[tabid])
        replacements={e['old']:e['text'].rstrip('\n')+'\n' for e in subset if e['mode']=='replace-paragraph'}
        prefix=''.join(e['text'].rstrip('\n')+'\n\n' for e in subset if e['mode']=='prepend')
        result[tabid]=prefix+''.join(replacements.get(p['text'],p['text']) for p in original)
    return result

def operation_ids(source,edits,target):
    return [sha({'document':target,'tab':e['tab'],'period':source['period']}) for e in edits if e['mode']=='prepend']

def apply(root,cfg,key):
    proposal=read(root,'plans',key);source=validate(root,cfg,proposal);results=[]
    for name in sorted({e['target'] for e in proposal['edits']}):
        receipt_path=root/'receipts'/(key+'-'+name+'.json')
        if receipt_path.exists():
            previous=json.loads(receipt_path.read_text())
            if previous['status']=='verified':results.append(previous);continue
            if previous['status']!='no_effect':raise RuntimeError('previous_attempt_uncertain_inspect_before_retry')
        target=source['docs'][name]
        for pending_path in (root/'receipts').glob('*.json'):
            pending=json.loads(pending_path.read_text())
            if pending.get('documentId')==target['documentId'] and pending.get('status')=='applying':raise RuntimeError('target_has_uncertain_attempt')
        edits=[e for e in proposal['edits'] if e['target']==name]
        operations=operation_ids(source,edits,target['documentId'])
        if any((root/'operations'/(op+'.json')).exists() for op in operations):raise RuntimeError('period_already_written_use_paragraph_update')
        before=read(root,'docs',target['hash']);current=doc_get(target['documentId'])
        if current['revisionId']!=before['revisionId']:raise RuntimeError('document_changed_recollect_and_replan')
        edits=[e for e in proposal['edits'] if e['target']==name]
        save(receipt_path,{'status':'applying','at':now(),'documentId':target['documentId'],'plan':key})
        for op in operations:save(root/'operations'/(op+'.json'),{'plan':key,'documentId':target['documentId']})
        gws('docs','documents','batchUpdate',{'documentId':target['documentId']},{'writeControl':{'requiredRevisionId':before['revisionId']},'requests':requests_for(before,edits)})
        after=doc_get(target['documentId']);tt=tabs(after)
        for tabid,expected in expected_tabs(before,edits).items():
            if plain(tt[tabid])!=expected: raise RuntimeError('readback_mismatch')
        result={'status':'verified','at':now(),'documentId':target['documentId'],'plan':key,'before':target['hash'],'after':store(root,'docs',after),'target':name}
        save(receipt_path,result)
        for op in operations:save(root/'operations'/(op+'.json'),{'plan':key,'documentId':target['documentId']})
        results.append(result)
    return {'plan':key,'results':results}

def reconcile(root,cfg,key):
    proposal=read(root,'plans',key);source=validate(root,cfg,proposal);results=[]
    for name in sorted({e['target'] for e in proposal['edits']}):
        p=root/'receipts'/(key+'-'+name+'.json')
        if not p.exists():continue
        previous=json.loads(p.read_text())
        if previous['status']!='applying':results.append(previous);continue
        target=source['docs'][name];before=read(root,'docs',target['hash']);current=doc_get(target['documentId'])
        edits=[e for e in proposal['edits'] if e['target']==name]
        matched=all(plain(tabs(current)[tab])==value for tab,value in expected_tabs(before,edits).items())
        if matched:
            result={**previous,'status':'verified','target':name,'before':target['hash'],'after':store(root,'docs',current),'at':now()}
        elif current['revisionId']==before['revisionId']:
            result={**previous,'status':'no_effect','at':now()}
            for op in operation_ids(source,edits,target['documentId']):(root/'operations'/(op+'.json')).unlink(missing_ok=True)
        else:raise RuntimeError('uncertain_external_changes_require_manual_reconciliation')
        save(p,result);results.append(result)
    return {'plan':key,'results':results}

def newsletter(root,cfg,key):
    proposal=read(root,'plans',key);source=validate(root,cfg,proposal);verified=[];pending=[]
    for name in sorted({e['target'] for e in proposal['edits']}):
        p=root/'receipts'/(key+'-'+name+'.json')
        receipt=json.loads(p.read_text()) if p.exists() else {'status':'not_applied'}
        (verified if receipt['status']=='verified' else pending).append(name)
    body=proposal.get('newsletterIntro','今週の活動共有の更新結果をお送りします。')+'\n\n'
    for name in verified:
        body+='【'+cfg['targets'][name]['label']+'】\n'
        for e in proposal['edits']:
            if e['target']==name:body+=e['text'].rstrip()+'\n\n'
        body+='https://docs.google.com/document/d/'+source['docs'][name]['documentId']+'/edit\n\n'
    body+='【未反映・確認事項】\n'+('\n'.join(pending+proposal.get('questions',[])+source['gaps']) or '追加の確認事項はありません。')+'\n'
    draft={'to':cfg['newsletter']['to'],'subject':'多元現実の活動共有｜'+source['period']['from']+'〜'+source['period']['to'],
           'body':body,'status':'draft-awaiting-send-approval','plan':key,'verifiedTargets':verified,'pendingTargets':pending}
    return {'draft':store(root,'newsletters',draft),**draft}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',required=True,type=Path);p.add_argument('--config',required=True,type=Path)
    sub=p.add_subparsers(dest='command',required=True)
    c=sub.add_parser('collect');c.add_argument('--from',dest='start',required=True);c.add_argument('--to',dest='end',required=True)
    s=sub.add_parser('stage');s.add_argument('--proposal',required=True,type=Path)
    for name in ['apply','newsletter','reconcile']:
        c=sub.add_parser(name);c.add_argument('--plan',required=True)
    a=p.parse_args();a.root.mkdir(parents=True,exist_ok=True,mode=0o700);cfg=json.loads(a.config.read_text())
    with (a.root/'.lock').open('w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if a.command=='collect':result=collect(a.root,cfg,a.start,a.end)
        elif a.command=='stage':result=stage(a.root,cfg,json.loads(a.proposal.read_text()))
        elif a.command=='apply':result=apply(a.root,cfg,a.plan)
        elif a.command=='reconcile':result=reconcile(a.root,cfg,a.plan)
        else:result=newsletter(a.root,cfg,a.plan)
        print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
