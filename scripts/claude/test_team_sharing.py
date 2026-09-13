import importlib.util,unittest,tempfile,json
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('sharing',Path(__file__).with_name('team-sharing.py'));a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
def doc(text='Old\n',revision='r1'):
 return {'revisionId':revision,'tabs':[{'tabProperties':{'tabId':'t.0'},'documentTab':{'body':{'content':[{'startIndex':1,'endIndex':1+len(text.encode('utf-16-le'))//2,'paragraph':{'elements':[{'textRun':{'content':text}}]}}]}}}]}
class Tests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
  self.cfg={'projects':[],'targets':{'koso':{'documentId':'doc','label':'Koso'}},'newsletter':{'to':'test@example.invalid'}}
  self.object=a.store(self.root,'objects',{'text':'evidence'})
  self.before=a.store(self.root,'docs',doc())
  self.input=a.store(self.root,'inputs',{'configHash':a.sha(self.cfg),'pages':[{'hash':self.object}],'docs':{'koso':{'documentId':'doc','hash':self.before}},'gaps':[],'period':{'from':'2026-09-07','to':'2026-09-13'}})
  self.edit={'target':'koso','tab':'t.0','mode':'replace-paragraph','old':'Old\n','text':'New','evidence':[self.object],'certainty':'supported','audienceChecked':True}
  self.proposal={'input':self.input,'edits':[self.edit]}
 def test_unknown_evidence(self):
  with self.assertRaisesRegex(ValueError,'unknown_evidence'):a.validate(self.root,self.cfg,{**self.proposal,'edits':[{**self.edit,'evidence':['x']}]})
 def test_unchecked_audience(self):
  with self.assertRaisesRegex(ValueError,'audience_not_checked'):a.validate(self.root,self.cfg,{**self.proposal,'edits':[{**self.edit,'audienceChecked':False}]})
 def test_target_and_tab_rejected(self):
  for patch in [{'target':'elsewhere'},{'tab':'other'}]:
   with self.assertRaises(ValueError):a.validate(self.root,self.cfg,{**self.proposal,'edits':[{**self.edit,**patch}]})
 def test_utf16_api_indices(self):
  requests=a.requests_for(doc('😀\n'),[{**self.edit,'old':'😀\n'}]);self.assertEqual(requests[0]['deleteContentRange']['range']['endIndex'],3)
 def test_revision_conflict_no_write(self):
  key=a.stage(self.root,self.cfg,self.proposal)['plan']
  with patch.object(a,'doc_get',return_value=doc(revision='changed')),patch.object(a,'gws') as writer:
   with self.assertRaisesRegex(RuntimeError,'document_changed'):a.apply(self.root,self.cfg,key)
   writer.assert_not_called()
 def test_success_replay_never_writes_twice(self):
  key=a.stage(self.root,self.cfg,self.proposal)['plan']
  with patch.object(a,'doc_get',side_effect=[doc(),doc('New\n','r2')]),patch.object(a,'gws') as writer:
   a.apply(self.root,self.cfg,key);a.apply(self.root,self.cfg,key);self.assertEqual(writer.call_count,1)
  self.assertEqual(a.newsletter(self.root,self.cfg,key)['verifiedTargets'],['koso'])
 def test_uncertain_write_never_retried(self):
  key=a.stage(self.root,self.cfg,self.proposal)['plan']
  with patch.object(a,'doc_get',return_value=doc()),patch.object(a,'gws',side_effect=RuntimeError('timeout')):
   with self.assertRaises(RuntimeError):a.apply(self.root,self.cfg,key)
  with patch.object(a,'gws') as writer:
   with self.assertRaisesRegex(RuntimeError,'uncertain'):a.apply(self.root,self.cfg,key)
   writer.assert_not_called()
  self.assertEqual(a.newsletter(self.root,self.cfg,key)['verifiedTargets'],[])
 def test_mismatch_not_reported_as_success(self):
  key=a.stage(self.root,self.cfg,self.proposal)['plan']
  with patch.object(a,'doc_get',side_effect=[doc(),doc('Different\n','r2')]),patch.object(a,'gws'):
   with self.assertRaisesRegex(RuntimeError,'readback'):a.apply(self.root,self.cfg,key)
 def test_plan_immutable(self):
  first=a.stage(self.root,self.cfg,self.proposal)['plan'];self.assertEqual(first,a.stage(self.root,self.cfg,self.proposal)['plan'])
 def test_mixed_modes_rejected(self):
  with self.assertRaisesRegex(ValueError,'mixed_modes'):a.stage(self.root,self.cfg,{**self.proposal,'edits':[self.edit,{**self.edit,'mode':'prepend','old':'','text':'Header'}]})
 def test_new_plan_blocked_by_uncertain_target(self):
  key=a.stage(self.root,self.cfg,self.proposal)['plan']
  a.save(self.root/'receipts'/('other-koso.json'),{'status':'applying','documentId':'doc'})
  with patch.object(a,'gws') as writer:
   with self.assertRaisesRegex(RuntimeError,'target_has_uncertain'):a.apply(self.root,self.cfg,key)
   writer.assert_not_called()
 def test_non_text_paragraph_rejected(self):
  current=doc();current['tabs'][0]['documentTab']['body']['content'][0]['paragraph']['elements'].append({'inlineObjectElement':{'inlineObjectId':'image'}})
  key=a.store(self.root,'docs',current);source=a.read(self.root,'inputs',self.input);source['docs']['koso']['hash']=key
  version=a.store(self.root,'inputs',source)
  with self.assertRaisesRegex(ValueError,'non_text'):a.stage(self.root,self.cfg,{**self.proposal,'input':version})
 def test_parallel_replacement_expectation(self):
  current=doc('A\n');current['tabs'][0]['documentTab']['body']['content'].append({'startIndex':3,'endIndex':5,'paragraph':{'elements':[{'textRun':{'content':'B\n'}}]}})
  edits=[{**self.edit,'old':'A\n','text':'B'},{**self.edit,'old':'B\n','text':'C'}]
  self.assertEqual(a.expected_tabs(current,edits)['t.0'],'B\nC\n')
 def test_period_replay_guard(self):
  proposal={**self.proposal,'edits':[{**self.edit,'mode':'prepend','old':'','text':'Header'}]};key=a.stage(self.root,self.cfg,proposal)['plan']
  op=a.operation_ids(a.read(self.root,'inputs',self.input),proposal['edits'],'doc')[0];a.save(self.root/'operations'/(op+'.json'),{'plan':'previous'})
  with self.assertRaisesRegex(RuntimeError,'period_already'):a.apply(self.root,self.cfg,key)
 def test_reconcile_after_lost_reply(self):
  key=a.stage(self.root,self.cfg,self.proposal)['plan'];a.save(self.root/'receipts'/(key+'-koso.json'),{'status':'applying','documentId':'doc','plan':key})
  with patch.object(a,'doc_get',return_value=doc('New\n','r2')):self.assertEqual(a.reconcile(self.root,self.cfg,key)['results'][0]['status'],'verified')
if __name__=='__main__':unittest.main()
