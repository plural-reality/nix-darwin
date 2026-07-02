言われたことだけじゃなくて、コードベースが汚くならないように、常に冷静な、視野を広く前提を見据えてください。

「違うものに違う名前をつける」のは当たり前です。緩くする意味はありません。

write code with functional way;
- All the variables are immutable. Use const, readonly.
- Don't use async/await. use callback instead.
- Use expressions, not statements. No if statement. Use ternaly operator and match() from ts-pattern. No while/for/forEach. Use map, filter, find, reduce and flatMap.
- don't use "function" keyword. Use Arrow function everywhere.

haskellのビルドはcabalではなく、nixで行っています。
ghcの言語拡張は `.hs` ファイルではなく `.cabal` ファイルに書いてください。

純粋関数型コーディングの教義と100パターンの詳細カタログ（三項演算子・ts-pattern・Result/Option モナド・関数合成・代数的構造・FRP・型による正当性証明）は `functional-style` skill に分離した。TypeScript / Haskell / Rust のコードを書く・レビューするときに自動でロードされる。always-on の負荷を避けつつ、コード作業時には完全な教義が手に入る。

### SSH key の管理について(重要)
SSH 秘密鍵は SOPS で暗号化し、git リポジトリで管理する。鍵の粒度は **role** のみ。
人・端末・プロジェクトの次元は不要（人の識別は AWS IAM/KMS 層が担う）。

```
secrets/ssh/
  operator.yaml   ← 人間が EC2 に SSH する用 (SOPS encrypted)
  deploy.yaml     ← colmena / self-deploy 用 (SOPS encrypted)
```

- 鍵はディスクに平文で保存しない。`sops exec-file secrets/ssh/operator.yaml 'ssh-add {}'` で agent に読み込む。
- 参加/離脱は `locals.tf` の KMS 権限で制御。SSH 鍵自体のローテーションは原則不要。
- 詳細は sktc-deploy スキルを参照。
