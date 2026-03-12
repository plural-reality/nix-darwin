## Architectural Decision Rules

- 常に、概念数・境界数・source of truth の数が最小の案を優先する。
- 一般的な best practice より、単一の canonical definition を優先する。
- 「どの config / secret が存在するか」という知識を複数 repo に分散させない。interface は app repo が持ち、他 repo は concrete value の binding のみを持つ。
- Nix で contract と profile layering を自然に一元化できるなら、TypeScript やドキュメントに同じ contract を再定義しない。
- TypeScript 側の validation は runtime assertion としてのみ許容する。canonical source of truth にしてはいけない。
- `local`, `staging`, `production` は、具体的な構造差が示されない限り、同じ抽象の profile として扱う。
- ユーザーが security と構造を分けて議論したいと言った場合、その前提を崩さない。
- familiarity, convention, DX, app team の慣れを理由に、概念や層を増やしてはいけない。
- 代替案を比較するときは、必ず次を明示する:
  - 導入される概念の数
  - canonical source of truth の数
  - 境界と adapter の数
  - その差が構造的なものか、単なる慣習か
- local path 依存は outermost launcher layer にだけ閉じ込める。app design 自体は checkout layout に依存してはいけない。
- ひとつのより単純なモデルで全環境を説明できるなら、それを優先する。

## Forbidden Reasoning Patterns

- 同じ contract を Nix, TypeScript, docs, infra に重複定義する提案
- `local` を最初から特別扱いする提案
- 「app に近い」「一般的」「DX がよい」といった、構造上の利点を示さない曖昧な主張
- value storage と interface definition を混同する提案
- 同じ結果をより少ない moving parts で達成できるのに、追加の layer / adapter / file を増やす提案
