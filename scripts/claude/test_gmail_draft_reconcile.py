import base64
import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('reconcile', Path(__file__).with_name('gmail-draft-reconcile.py'))
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
NOW = 1800000000
ACCOUNT = 'owner@example.com'
TEXT = ('次回の地域会議についてご相談です。先日お話しした活動紹介の資料をまとめました。'
        'これまでに取り組んだことと、今後みなさんと一緒に取り組みたいことを説明する内容です。'
        '当日は資料をもとに話し合い、ご意見をいただいたうえで今後の進め方を決められればと思います。'
        '会場の準備と参加者へのご案内について、ご都合のよい進め方を教えていただけますと幸いです。')


def part(body, mime='text/plain', filename=''):
    raw = body.encode()
    return {'mimeType': mime, 'filename': filename, 'body': {'size': len(raw), 'data': base64.urlsafe_b64encode(raw).decode()}}


def message(mid, text=TEXT, sent=False, timestamp=None, **extra_headers):
    h = {'From': ACCOUNT, 'To': 'recipient@example.org', 'Subject': '地域会議のご相談', **extra_headers}
    return {'id': mid, 'threadId': 'thread1', 'internalDate': str(int((timestamp if timestamp is not None else NOW - (300 if sent else 600)) * 1000)),
            'labelIds': ['SENT' if sent else 'DRAFT'], 'payload': {**part(text), 'headers': [{'name': k, 'value': v} for k, v in h.items()]}}


class FakeAPI:
    def __init__(self, draft=None, sent=None):
        self.d = draft or message('draft-message')
        self.s = sent or message('sent-message', sent=True)
        self.active = True
        self.calls = []
        self.on_draft_get = None
        self.gets = 0
        self.before_trash = None
        self.timeout_after_trash = False
        self.email = ACCOUNT
        self.attachment_data = {}

    def call(self, resource, operation=None, **params):
        self.calls.append((resource, operation, params))
        if resource == 'getProfile':
            return {'emailAddress': self.email}
        if (resource, operation) == ('drafts', 'list'):
            return {'drafts': [{'id': 'draft1', 'message': {'id': self.d['id']}}] if self.active else []}
        if (resource, operation) == ('drafts', 'get'):
            self.gets += 1
            if self.on_draft_get:
                self.on_draft_get(self)
            return {'message': copy.deepcopy(self.d)}
        if (resource, operation) == ('messages', 'list'):
            return {'messages': [{'id': self.s['id']}]}
        if (resource, operation) == ('messages', 'get'):
            return copy.deepcopy(self.s if params['id'] == self.s['id'] else self.d)
        if (resource, operation) == ('messages', 'trash'):
            if self.before_trash:
                self.before_trash()
            assert params['id'] == self.d['id']
            self.d['labelIds'] += ['TRASH']
            self.active = False
            if self.timeout_after_trash:
                raise r.StopRun('gmail_request_failed')
            return copy.deepcopy(self.d)
        raise AssertionError((resource, operation, params))

    def attachment(self, mid, aid):
        return self.attachment_data[(mid, aid)]

    @property
    def mutations(self):
        return [x for x in self.calls if x[1] == 'trash']


def state(api, stable=True):
    return {'schema': 1, 'account': ACCOUNT, 'observed': {'draft1': {'version': r.version(api.d), 'since': NOW - 200}} if stable else {}, 'receipts': []}


class MatchingTests(unittest.TestCase):
    def check(self, d, s, expected, reason=None):
        result = r.comparable(d, s, ACCOUNT, NOW)
        self.assertEqual(result[0], expected, result)
        if reason:
            self.assertEqual(result[1], reason)

    def test_exact_and_edited_old_version(self):
        self.check(message('d'), message('s', sent=True), True, 'exact')
        edited = TEXT.replace('資料をまとめました', '資料を作成いたしました').replace('説明する内容です', 'ご紹介する内容です')
        self.check(message('d'), message('s', edited, sent=True), True, 'similar')

    def test_cc_added_by_sender_is_allowed(self):
        self.check(message('d'), message('s', sent=True, Cc='team@example.com'), True)

    def test_preserves_recipient_bcc_parent_and_subject_changes(self):
        for h in ({'To': 'another@example.org'}, {'Subject': '別の相談'}, {'In-Reply-To': '<different>'}):
            self.check(message('d'), message('s', sent=True, **h), False)
        self.check(message('d', Bcc='hidden@example.org'), message('s', sent=True), False)
        self.check(message('d', Cc='team@example.com'), message('s', sent=True), False)

    def test_new_draft_is_preserved(self):
        self.check(message('d', timestamp=NOW-200), message('s', sent=True), False, 'chronology')

    def test_recent_send_waits(self):
        self.check(message('d'), message('s', sent=True, timestamp=NOW-20), False, 'chronology')

    def test_quoted_previous_mail_does_not_create_similarity(self):
        quote = '\nOn Monday, User wrote:\n' + TEXT * 5
        self.check(message('d', '新しい別の企画に関して、追加の費用をお願いできますか。' + quote),
                   message('s', '日程の変更について了解しました。当日はどうぞよろしくお願いします。' + quote, sent=True), True, 'similar')

    def test_signature_does_not_create_similarity(self):
        self.check(message('d', '新しい用件です。\n---\n' + TEXT * 5), message('s', '別の用件です。\n---\n' + TEXT * 5, sent=True), True, 'similar')

    def test_numeric_or_link_change_is_held(self):
        self.check(message('d', TEXT+'予算は100万円です。'), message('s', TEXT+'予算は200万円です。', sent=True), False, 'numbers_changed')
        self.check(message('d', TEXT+' https://example.com/a'), message('s', TEXT+' https://example.com/b', sent=True), False, 'links_changed')

    def test_html_blockquote_is_ignored(self):
        d=message('d');s=message('s', sent=True)
        d['payload']={**part('<p>新しい未送信の用件についてご相談させてください。</p><blockquote>'+TEXT*8+'</blockquote>', 'text/html'), 'headers': d['payload']['headers']}
        s['payload']={**part('<p>以前の用件についてご連絡いただきありがとうございました。</p><blockquote>'+TEXT*8+'</blockquote>', 'text/html'), 'headers': s['payload']['headers']}
        self.check(d,s,False)

    def test_reply_to_and_number_order(self):
        self.check(message('d'), message('s', sent=True, **{'Reply-To':'other@example.org'}), False, 'reply_to_mismatch')
        self.check(message('d',TEXT+'交通費3000円、宿泊費9000円。'), message('s',TEXT+'交通費9000円、宿泊費3000円。',sent=True),False,'numbers_changed')

    def test_suffixes_are_not_exact(self):
        for separator in ('\n---\n', '\n--\n', '\nOn Monday, User wrote:\n'):
            result=r.comparable(message('d',TEXT+separator+'別の依頼です。'),message('s',TEXT+separator+'了解しました。',sent=True),ACCOUNT,NOW)
            self.assertNotEqual(result[1],'exact')

    def test_html_alternative_extra_request_is_not_exact(self):
        d=message('d');s=message('s',sent=True)
        for m, suffix in [(d,'追加の依頼があります。'),(s,'')]:
            p=m['payload'];m['payload']={'headers':p['headers'],'mimeType':'multipart/alternative','parts':[p,part('<p>'+TEXT+suffix+'</p>','text/html')]}
        self.assertNotEqual(r.comparable(d,s,ACCOUNT,NOW)[1],'exact')

    def test_compound_attachment_is_unsupported(self):
        d=message('d');d['payload']['parts']=[{'mimeType':'message/rfc822','filename':'mail.eml','parts':[part(TEXT)]}]
        with self.assertRaisesRegex(r.StopRun,'compound_attachment'):
            r.representations(d)

    def test_html_mailto_and_images_not_lost(self):
        for markup in ('<a href="mailto:{}">担当者</a>','<img src="https://example.com/{}" alt="資料">'):
            d=message('d');s=message('s',sent=True)
            for m,value in [(d,'first'),(s,'other')]:
                m['payload']={**part('<p>'+TEXT+'</p>'+markup.format(value),'text/html'),'headers':m['payload']['headers']}
            self.check(d,s,False,'links_changed')

    def test_classifier_failure_is_hold_and_capabilities_removed(self):
        with patch.object(r.subprocess,'run') as run:
            run.return_value.returncode=0
            run.return_value.stdout=r.json.dumps({'is_error':False,'result':r.json.dumps({'same_intent':True,'no_unsent_request':True,'no_contradiction':True})})
            gate=r.MeaningGate('/safe/claude')
            self.assertTrue(gate(message('d'),message('s',sent=True)))
            argv=run.call_args.args[0]
            self.assertEqual(argv[argv.index('--tools')+1],'')
            self.assertEqual(argv[argv.index('--disallowedTools')+1],'*')
            self.assertIn('--restricted',argv)
            self.assertIn('--no-session-persistence',argv)
            run.return_value.stdout='{"is_error":false,"structured_output":{"same_intent":"true"}}'
            self.assertFalse(gate(message('d'),message('s',sent=True)))
            run.side_effect=r.subprocess.TimeoutExpired('claude',45)
            self.assertFalse(gate(message('d'),message('s',sent=True)))


class RunnerTests(unittest.TestCase):
    def run_it(self, api, st, apply=True):
        return r.reconcile(api, st, NOW, apply, lambda: None)

    def test_account_mismatch_fails_before_drafts_or_mutation(self):
        api=FakeAPI();api.email='other@example.com'
        with self.assertRaisesRegex(r.StopRun,'account_mismatch'):
            self.run_it(api,state(api))
        self.assertEqual(len(api.calls),1)

    def test_observe_then_apply_and_repeat_noop(self):
        api=FakeAPI();st=state(api,False)
        self.assertEqual(self.run_it(api,st)['actions'],[])
        self.assertTrue(api.active)
        st['observed']['draft1']['since']-=121
        self.assertEqual(len(self.run_it(api,st)['actions']),1)
        self.assertEqual(api.s['labelIds'],['SENT'])
        self.assertEqual(self.run_it(api,st)['actions'],[])
        self.assertEqual(len(api.mutations),1)

    def test_audit_never_trashes(self):
        api=FakeAPI();res=self.run_it(api,state(api),False)
        self.assertEqual(res['actions'][0]['status'],'would_trash')
        self.assertFalse(api.mutations)

    def test_changed_version_resets_observation(self):
        api=FakeAPI();st=state(api);api.d['payload']['body']=part(TEXT+'別の話もあります。')['body']
        self.assertEqual(self.run_it(api,st)['deferred'][0]['reason'],'settling')
        self.assertFalse(api.mutations)

    def test_concurrent_edit_is_held_even_if_message_id_is_unchanged(self):
        api=FakeAPI();st=state(api)
        def edit(a):
            if a.gets==2:
                a.d['payload']['body']=part(TEXT+'こちらは別の未送信依頼です。')['body']
        api.on_draft_get=edit
        self.assertEqual(self.run_it(api,st)['deferred'][0]['reason'],'changed_during_check')
        self.assertFalse(api.mutations)

    def test_attachment_difference_is_held(self):
        api=FakeAPI()
        for m, value in [(api.d,'draft bytes'),(api.s,'different sent bytes')]:
            p=m['payload'];m['payload']={'headers':p['headers'],'mimeType':'multipart/mixed','parts':[p,part(value,'application/pdf','report.pdf')]}
        self.assertEqual(self.run_it(api,state(api))['deferred'][0]['reason'],'attachment_difference')
        self.assertFalse(api.mutations)

    def test_unnamed_text_attachment_not_body(self):
        api=FakeAPI();p=api.d['payload'];attachment=part(TEXT)
        attachment['headers']=[{'name':'Content-Disposition','value':'attachment'}]
        api.d['payload']={'headers':p['headers'],'mimeType':'multipart/mixed','parts':[p,attachment]}
        self.assertEqual(self.run_it(api,state(api))['deferred'][0]['reason'],'attachment_difference')
        self.assertFalse(api.mutations)

    def test_attachment_content_matches_not_just_name(self):
        api=FakeAPI()
        for m in [api.d,api.s]:
            p=m['payload'];m['payload']={'headers':p['headers'],'mimeType':'multipart/mixed','parts':[p,part('same bytes','application/pdf','report.pdf')]}
        self.assertEqual(len(self.run_it(api,state(api))['actions']),1)

    def test_journal_precedes_mutation_and_interrupted_readback_recovers(self):
        api=FakeAPI();st=state(api);saved=[]
        api.before_trash=lambda:self.assertEqual(saved[-1]['receipts'][0]['status'],'intent')
        api.timeout_after_trash=True
        with self.assertRaises(r.StopRun):
            r.reconcile(api,st,NOW,True,lambda:saved.append(copy.deepcopy(st)))
        api.timeout_after_trash=False
        self.assertEqual(self.run_it(api,st)['actions'],[])
        self.assertEqual(st['receipts'][0]['status'],'verified')
        self.assertEqual(len(api.mutations),1)

    def test_fuzzy_requires_meaning_gate(self):
        for suffix in ('この役割はお引き受けできません。','\n---\n追加の依頼です。'):
            api=FakeAPI(message('d',TEXT+suffix),message('s',TEXT+'この役割はお引き受けいたします。',sent=True))
            result=self.run_it(api,state(api))
            self.assertEqual(result['deferred'][0]['reason'],'meaning_not_confirmed')
            self.assertFalse(api.mutations)
        api=FakeAPI(sent=message('s',TEXT.replace('資料をまとめました','資料を作成いたしました'),sent=True))
        result=r.reconcile(api,state(api),NOW,True,lambda:None,lambda d,s:True)
        self.assertEqual(len(result['actions']),1)

    def test_gws_attachment_argv(self):
        with patch.object(r.subprocess,'run') as run:
            run.return_value.returncode=0;run.return_value.stdout='{"data":"YQ"}'
            self.assertEqual(r.Gws('/safe/gws').attachment('m','a'),'YQ')
            self.assertEqual(run.call_args.args[0][:7],['/safe/gws','gmail','users','messages','attachments','get','--params'])


if __name__=='__main__':
    unittest.main()
