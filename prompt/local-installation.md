何かのツールを入れるときは、基本的に nix home manager で全て管理してください。
nixpkgsにない場合は、githubとかでflakeが直接提供されているものを利用するのが良いと思います。例えば、kimi-code/claude-code-flake など。
全員に必要なツールは plural-reality/nix-darwin の base module に入れて、個人ごとに必要なツールは 個人/nix-darwin の personal.nix に入れてください。(当然それぞれの local repo ね。)
破壊的なインストールがある場合は、それを削除した上で Nix に変えてしまって問題ないです。
