import test from 'node:test';
import assert from 'node:assert/strict';
import { parseAX, selectCandidates, buildRequest, evaluate } from './core.mjs';
import { runPhase } from './runtime.mjs';
import { requestDecision, credential, ENDPOINT } from './client.mjs';

const ax = 'Window: Calculator\n1 button Five\n2 button Six\n3 button 送信\n4 button Seven (disabled)\n5 button Mode, Secondary Actions: Delete';
const targets = [{ role: 'button', label: 'Five' }, { role: 'button', label: 'Six' }];
const answer = { choice: 'i2', confidence: 1, probabilities: { i1: 0, i2: 1, none: 0 } };
const decision = async () => ({ ok: true, answer, model: 'jev-1.13.0' });
const fixture = (overrides = {}) => {
  const events = [];
  const observations = [ax, ax, 'result=6'];
  const driver = { observe: async () => observations.shift() ?? 'result=6', click: async i => events.push(i), setValue: async (i,v) => events.push([i,v]) };
  return { events, observations, config: { driver, goal: 'Enter six', targets, verify: a => a === 'result=6', execute: true, authorized: true, egressApproved: true, decide: decision, ...overrides } };
};

test('AX excludes disabled elements and secondary-action metadata', () => {
  assert.deepEqual(parseAX(ax).map(e => e.label), ['Five','Six','送信','Mode']);
  assert.equal(parseAX('2 ボタン 六')[0].role, 'button');
});
test('only exact approved labels become candidates', () => assert.equal(selectCandidates(ax, targets).length, 2));
test('request excludes unrelated AX and offers none', () => {
  const body = buildRequest({goal: 'Enter six', candidates: selectCandidates(ax, targets)});
  assert.equal(body.model, 'jev-1.13.0');
  assert.ok(body.questions.target.criteria.none);
  assert.ok(!JSON.stringify(body).includes('送信'));
});
test('confidence and probability are independently checked', () => {
  const candidates = selectCandidates(ax, targets);
  assert.equal(evaluate({ answer, candidates }).status, 'selected');
  assert.equal(evaluate({answer: {...answer, confidence: 0.7}, candidates}).status, 'escalate');
  assert.equal(evaluate({answer: {...answer, probabilities: {i1:0.3,i2:0.7,none:0}}, candidates}).status, 'escalate');
  assert.equal(evaluate({answer: {...answer, confidence: NaN}, candidates}).status, 'blocked');
});
test('verified actual result is necessary and sufficient', async () => {
  const f=fixture(); const r=await runPhase(f.config);
  assert.equal(r.verified,true); assert.equal(r.status,'done'); assert.deepEqual(f.events,[2]);
});
test('already done does not request API or mutate', async () => {
  const f=fixture({verify: () => true, decide: () => assert.fail()});
  assert.equal((await runPhase(f.config)).steps,0); assert.deepEqual(f.events,[]);
});
test('preview does not mutate', async () => {
  const f=fixture({execute:false}); assert.equal((await runPhase(f.config)).status,'preview'); assert.deepEqual(f.events,[]);
});
test('missing action authorization stops before observation', async () => {
  const f=fixture({authorized:false}); assert.equal((await runPhase(f.config)).reason,'action_not_authorized'); assert.equal(f.observations.length,3);
});
test('missing egress authorization prevents request', async () => {
  const f=fixture({egressApproved:false,decide:()=>assert.fail()}); assert.equal((await runPhase(f.config)).reason,'egress_not_authorized');
});
test('Japanese consequential labels never reach API or execution', async () => {
  const f=fixture({targets:[{role:'button',label:'送信'}],decide:()=>assert.fail()}); assert.equal((await runPhase(f.config)).reason,'consequential_action');
});
test('required verifier and bounded options', async () => {
  for (const override of [{verify:undefined},{maxSteps:100},{maxMs:Infinity},{action:'pressKey'},{threshold:0.1},{targets:[]}]) {
    const f=fixture(override); assert.equal((await runPhase(f.config)).reason,'invalid_phase'); assert.deepEqual(f.events,[]);
  }
});
test('changed state after inference invalidates indices', async () => {
  const f=fixture(); f.observations[1]=ax.replace('2 button Six','8 button Six');
  assert.equal((await runPhase(f.config)).reason,'state_changed'); assert.deepEqual(f.events,[]);
});
test('duplicate matching controls stop before choice', async () => {
  const f=fixture({decide:()=>assert.fail()}); f.observations[0]+='\n9 button Six';
  assert.equal((await runPhase(f.config)).reason,'ambiguous_targets');
});
test('no matching controls escalates without calling model', async () => {
  const f=fixture({decide:()=>assert.fail()}); f.observations[0]='0 button Other';
  assert.equal((await runPhase(f.config)).reason,'no_candidates');
});
test('unchanged result is not retried', async () => {
  const f=fixture(); f.observations[2]=ax;
  assert.equal((await runPhase(f.config)).reason,'no_change'); assert.deepEqual(f.events,[2]);
});
test('action exception still reads back and does not duplicate effect', async () => {
  const f=fixture(); f.config.driver.click=async()=>{throw Error('possibly acted');};
  assert.equal((await runPhase(f.config)).verified,true);
});
test('uncertain action failure is not replayed', async () => {
  const f=fixture(); f.config.driver.click=async()=>{throw Error();}; f.observations[2]='unknown';
  assert.equal((await runPhase(f.config)).reason,'action_failed_do_not_retry');
});
test('API errors do not become raw user-facing error bodies', async () => {
  const result=await requestDecision({goal:'x',candidates:[],key:'test-only',fetchImpl:async(url,options)=>{
    assert.equal(url,ENDPOINT);assert.equal(options.redirect,'error'); return {ok:false,status:429};
  }}); assert.deepEqual(result,{ok:false,reason:'rate_limited'});
});
test('response model mismatch fails closed', async () => {
  const r=await requestDecision({goal:'x',candidates:[],key:'test-only',fetchImpl:async()=>({ok:true,json:async()=>({model:'changed',answers:{target:answer}})})});
  assert.equal(r.reason,'invalid_response');
});
test('credential unavailable is represented without scanning', async()=> assert.deepEqual(await credential({env:{}}),{ok:false,reason:'key_unavailable'}));

test('input operations cannot target buttons', async () => {
  const f=fixture({action:'setValue',text:'x'});
  assert.equal((await runPhase(f.config)).reason,'invalid_input_target');
  assert.deepEqual(f.events,[]);
});
test('input values stay local and are read back', async () => {
  const events=[];
  const inputAx='1 text field Name\n2 text field Subject';
  const observations=[inputAx,inputAx,'value=approved'];
  const inputTargets=[{role:'text field',label:'Name'},{role:'text field',label:'Subject'}];
  const r=await runPhase({driver:{observe:async()=>observations.shift(),setValue:async(i,v)=>events.push([i,v])},goal:'Fill the subject field',targets:inputTargets,verify:a=>a==='value=approved',action:'setValue',text:'local-only-value',execute:true,authorized:true,egressApproved:true,decide:async input=>{assert.ok(!JSON.stringify(input).includes('local-only-value'));return decision();}});
  assert.equal(r.verified,true);assert.deepEqual(events,[[2,'local-only-value']]);
});
test('readback failure is never called completion', async () => {
  const f=fixture();f.config.driver.observe=async()=>{const x=f.observations.shift();if(x==='result=6')throw Error();return x;};
  assert.equal((await runPhase(f.config)).reason,'readback_failed_do_not_retry');
});
test('step budget prevents endless model-driven actions', async () => {
  const f=fixture({maxSteps:1});f.observations[2]='still pending';
  assert.equal((await runPhase(f.config)).reason,'step_budget');assert.deepEqual(f.events,[2]);
});
