#!/usr/bin/env node

import { spawn } from "node:child_process";

const cdpBase = "http://127.0.0.1:9222";
const chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const profile = `${process.env.HOME}/.chrome-automation-profile`;
const bankUrl = "https://bank.gmo-aozora.com/";
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const json = value => `${JSON.stringify(value)}\n`;
const emit = value => process.stdout.write(json(value));
const version = () => fetch(`${cdpBase}/json/version`).then(response =>
  response.ok ? response.json() : Promise.reject(new Error(`CDP HTTP ${response.status}`)));
const retry = (remaining, action) => action().catch(error =>
  remaining > 0 ? sleep(250).then(() => retry(remaining - 1, action)) : Promise.reject(error));
const launch = () => {
  const child = spawn(chrome, [
    "--headless=new",
    "--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=9222",
    `--user-data-dir=${profile}`,
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "about:blank",
  ], { detached: true, stdio: "ignore" });
  child.unref();
  return retry(40, version);
};
const ensureCdp = () => version().catch(() => launch());
const createTarget = () => fetch(`${cdpBase}/json/new?${encodeURIComponent(bankUrl)}`, { method: "PUT" })
  .then(response => response.ok ? response.json() : Promise.reject(new Error(`target HTTP ${response.status}`)));
const closeTarget = target => fetch(`${cdpBase}/json/close/${target.id}`).catch(() => undefined);
const evaluate = target => new Promise((resolve, reject) => {
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  const timer = setTimeout(() => (socket.close(), reject(new Error("CDP evaluation timeout"))), 20000);
  const expression = `(() => {
    const text = document.body?.innerText || "";
    const pick = values => values.find(value => text.includes(value)) || null;
    return JSON.stringify({
      url: location.href,
      title: document.title,
      login: /ログイン|ログオン|店番号|ユーザーID|パスワード/.test(text),
      challenge: /ワンタイム|OTP|パスキー|CAPTCHA|認証コード/.test(text),
      reviewStatus: pick(["追加書類が必要", "追加書類", "審査中", "手続き中", "変更完了", "完了"]),
      corporateInfo: /法人情報|登録情報|お客さま情報/.test(text),
      inquiry: /お問い合わせ|メッセージ/.test(text),
      importantNotice: /重要なお知らせ/.test(text)
    });
  })()`;
  socket.addEventListener("open", () => socket.send(JSON.stringify({
    id: 1, method: "Runtime.evaluate", params: { expression, returnByValue: true },
  })));
  socket.addEventListener("message", event => {
    const message = JSON.parse(event.data);
    return message.id === 1
      ? (clearTimeout(timer), socket.close(), resolve(JSON.parse(message.result.result.value)))
      : undefined;
  });
  socket.addEventListener("error", error => (clearTimeout(timer), reject(error)));
});
const normalize = observation => {
  const loginUrl = /sso\.gmo-aozora\.com|\/login(?:[/?]|$)/.test(observation.url);
  const authenticated = !loginUrl && !observation.login;
  return authenticated
    ? { ok: true, status: "取得済み", observation: {
        authenticated: true,
        reviewStatus: observation.reviewStatus,
        corporateInfoRead: observation.corporateInfo,
        inquiryRead: observation.inquiry,
        importantNoticeRead: observation.importantNotice,
        source: "dedicated-chrome-monitor-profile",
      } }
    : { ok: false, status: observation.challenge ? "認証が必要" : "認証が必要",
        reason: "専用Chromeの継続セッションが失効しています。自動ログインは行いません。" };
};

ensureCdp()
  .then(createTarget)
  .then(target => sleep(7000)
    .then(() => evaluate(target))
    .then(normalize)
    .finally(() => closeTarget(target)))
  .then(emit)
  .catch(error => (emit({ ok: false, status: "一時的に取得できません", reason: error.message }), process.exitCode = 1));
