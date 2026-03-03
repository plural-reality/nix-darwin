---
name: lp-hero-video
description: >
  ランディングページにプロダクトデモを組み込むスキル。
  CSSアニメーションによるプロダクトUIモック、ヒーロー動画、カード内動画など、
  Webサイトへのデモ演出パターンを実装する。
  トリガー例: "動画を入れて", "ヒーロー動画", "デモ動画を埋め込み",
  "hero video", "product video", "LP動画", "ランディングページに動画",
  "プロダクトデモ", "アニメーションで見せたい", "UIモック"
---

# LP Hero Video Skill

ランディングページやWebサイトにプロダクトデモ動画を効果的に組み込むためのガイド。

## 対応パターン

1. **Hero Background Video** — ページ上部の全面背景動画
2. **Product Demo Section** — プロダクト紹介セクションにインライン動画
3. **Floating Device Mockup** — デバイスフレーム内に動画を表示
4. **Lightbox / Modal Video** — クリックで拡大再生

---

## Step 0: 事前確認チェックリスト

動画を組み込む前に、以下を確認する:

### 動画素材の確認
- [ ] 動画ファイルは用意済みか？（まだなら先にプレースホルダーUIを作成）
- [ ] フォーマット: `.mp4`（H.264）+ `.webm`（VP9）の2形式が理想
- [ ] 解像度: Hero用は 1920x1080 推奨、カード内は 1280x720 で十分
- [ ] ファイルサイズ: Hero用は 5-15MB 目安、カード内は 2-5MB
- [ ] 長さ: 自動再生は 10-30秒のループが最適

### 動画素材の作り方（Screen Studioなどで録画する場合）
1. プロダクトの最も印象的な操作フローを 15-30秒で録画
2. 解像度は 1920x1080 以上で録画
3. エクスポート時に以下を設定:
   - MP4 (H.264): 品質 Medium-High、ビットレート 4-8 Mbps
   - WebM (VP9): 同等品質で追加エクスポート（対応ツールの場合）
4. ffmpeg での変換コマンド:

```bash
# MP4 最適化（Web向け、faststart付き）
ffmpeg -i input.mov -c:v libx264 -crf 23 -preset slow \
  -movflags +faststart -an -vf scale=1920:-2 output.mp4

# WebM 変換
ffmpeg -i input.mov -c:v libvpx-vp9 -crf 30 -b:v 0 \
  -an -vf scale=1920:-2 output.webm

# カード用（小さめ）
ffmpeg -i input.mov -c:v libx264 -crf 26 -preset slow \
  -movflags +faststart -an -vf scale=1280:-2 output-card.mp4
```

### ホスティング
- **ローカル（`/public/videos/`）**: 小規模サイト、Vercel / Netlify デプロイ向け
- **CDN / Object Storage**: 大規模、複数動画の場合（Cloudflare R2, AWS S3 + CloudFront）
- **YouTube / Vimeo embed**: SEO重視、外部共有したい場合

---

## Pattern 1: Hero Background Video

ページ最上部に全面でプロダクトデモ動画を表示。テキストオーバーレイ付き。

### React コンポーネント

```tsx
interface HeroVideoProps {
  /** MP4 動画のパス */
  videoSrc: string;
  /** WebM 動画のパス（省略可） */
  videoSrcWebm?: string;
  /** 動画ロード前に表示するポスター画像 */
  posterSrc?: string;
  /** オーバーレイの子要素（見出しなど） */
  children?: React.ReactNode;
  /** オーバーレイの暗さ (0-1, デフォルト 0.4) */
  overlayOpacity?: number;
}

function HeroVideo({
  videoSrc,
  videoSrcWebm,
  posterSrc,
  children,
  overlayOpacity = 0.4,
}: HeroVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null);

  return (
    <div className="relative h-screen w-full overflow-hidden bg-black">
      {/* Background Video */}
      <video
        ref={videoRef}
        autoPlay
        muted
        loop
        playsInline
        poster={posterSrc}
        className="absolute inset-0 w-full h-full object-cover"
      >
        {videoSrcWebm && <source src={videoSrcWebm} type="video/webm" />}
        <source src={videoSrc} type="video/mp4" />
      </video>

      {/* Dark Overlay */}
      <div
        className="absolute inset-0"
        style={{ backgroundColor: `rgba(0, 0, 0, ${overlayOpacity})` }}
      />

      {/* Gradient fade to page background */}
      <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-background to-transparent" />

      {/* Content */}
      {children && (
        <div className="absolute inset-0 z-10 flex items-end">
          <div className="container pb-16 md:pb-24">{children}</div>
        </div>
      )}
    </div>
  );
}
```

### 使用例

```tsx
<HeroVideo
  videoSrc="/videos/product-demo.mp4"
  videoSrcWebm="/videos/product-demo.webm"
  posterSrc="/images/hero-poster.jpg"
  overlayOpacity={0.35}
>
  <h1 className="text-4xl md:text-6xl font-normal text-white tracking-tight">
    テクノロジーで、対話を再発明する。
  </h1>
</HeroVideo>
```

### Plural Reality LP での適用箇所

現在の `LifeGameHero` コンポーネントの代わりに、または共存させる形で:

```tsx
// Home.tsx での置き換えパターン
// Option A: 完全置換
<HeroVideo videoSrc="/videos/hero-demo.mp4" posterSrc="/images/IMG_5298.jpeg">
  <h1 ...>{h.heroTitle}</h1>
</HeroVideo>

// Option B: LifeGameHero を残しつつ、下に動画セクションを追加
<LifeGameHero>...</LifeGameHero>
<Section className="py-0">
  <HeroVideo videoSrc="/videos/product-overview.mp4" overlayOpacity={0.2}>
    <h2>プロダクト紹介</h2>
  </HeroVideo>
</Section>
```

---

## Pattern 2: Product Card Video

プロダクト一覧の各カードで、静止画の代わりにデモ動画をホバーで再生。

### React コンポーネント

```tsx
interface ProductCardVideoProps {
  videoSrc: string;
  posterSrc: string;
  alt: string;
  className?: string;
}

function ProductCardVideo({
  videoSrc,
  posterSrc,
  alt,
  className,
}: ProductCardVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null);

  const handleMouseEnter = () => {
    videoRef.current?.play();
  };

  const handleMouseLeave = () => {
    const video = videoRef.current;
    if (video) {
      video.pause();
      video.currentTime = 0;
    }
  };

  return (
    <div
      className={cn("relative aspect-video bg-muted overflow-hidden", className)}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      <video
        ref={videoRef}
        muted
        loop
        playsInline
        poster={posterSrc}
        preload="metadata"
        className="w-full h-full object-cover"
      >
        <source src={videoSrc} type="video/mp4" />
      </video>
    </div>
  );
}
```

### 使用例（既存カードの画像を置換）

```tsx
// Before:
<ParallaxImage src="/images/kouchoai.png" alt={t.products.kouchouAI} />

// After:
<ProductCardVideo
  videoSrc="/videos/kouchou-ai-demo.mp4"
  posterSrc="/images/kouchoai.png"
  alt={t.products.kouchouAI}
/>
```

---

## Pattern 3: Device Mockup Video

ブラウザやスマホのフレーム内にデモ動画を表示（信頼感 UP）。

```tsx
function BrowserMockupVideo({
  videoSrc,
  posterSrc,
  title,
}: {
  videoSrc: string;
  posterSrc?: string;
  title?: string;
}) {
  return (
    <div className="border border-border bg-background overflow-hidden">
      {/* Browser chrome */}
      <div className="flex items-center gap-2 px-4 py-3 bg-secondary/30 border-b border-border">
        <div className="flex gap-1.5">
          <div className="w-3 h-3 rounded-full bg-muted-foreground/20" />
          <div className="w-3 h-3 rounded-full bg-muted-foreground/20" />
          <div className="w-3 h-3 rounded-full bg-muted-foreground/20" />
        </div>
        {title && (
          <div className="flex-1 text-center">
            <span className="text-xs text-muted-foreground font-mono">{title}</span>
          </div>
        )}
      </div>
      {/* Video content */}
      <div className="aspect-video">
        <video
          autoPlay
          muted
          loop
          playsInline
          poster={posterSrc}
          className="w-full h-full object-cover"
        >
          <source src={videoSrc} type="video/mp4" />
        </video>
      </div>
    </div>
  );
}
```

---

## Pattern 4: Lightbox Modal Video

サムネイルクリックで動画をモーダル表示。YouTube embed にも対応。

```tsx
function VideoLightbox({
  thumbnailSrc,
  videoSrc,
  youtubeId,
  alt,
}: {
  thumbnailSrc: string;
  videoSrc?: string;
  youtubeId?: string;
  alt: string;
}) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <>
      <button
        onClick={() => setIsOpen(true)}
        className="relative group cursor-pointer aspect-video w-full overflow-hidden"
      >
        <img src={thumbnailSrc} alt={alt} className="w-full h-full object-cover" />
        {/* Play button overlay */}
        <div className="absolute inset-0 flex items-center justify-center bg-black/20 group-hover:bg-black/30 transition-colors">
          <div className="w-16 h-16 flex items-center justify-center bg-white/90 group-hover:bg-white transition-colors">
            <svg className="w-6 h-6 text-foreground ml-1" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          </div>
        </div>
      </button>

      {/* Modal */}
      {isOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80"
          onClick={() => setIsOpen(false)}
        >
          <div className="w-full max-w-5xl aspect-video" onClick={(e) => e.stopPropagation()}>
            {youtubeId ? (
              <iframe
                src={`https://www.youtube.com/embed/${youtubeId}?autoplay=1`}
                className="w-full h-full"
                allow="autoplay; encrypted-media"
                allowFullScreen
              />
            ) : (
              <video
                src={videoSrc}
                autoPlay
                controls
                className="w-full h-full object-contain bg-black"
              />
            )}
          </div>
        </div>
      )}
    </>
  );
}
```

---

## 実装チェックリスト

動画を追加する際は以下を確認:

### パフォーマンス
- [ ] `autoPlay muted loop playsInline` の4属性をセット（iOS対応必須）
- [ ] `poster` 属性で初期フレーム画像を指定（ロード中の体験向上）
- [ ] `preload="metadata"` でカード内動画の初期ロードを軽く
- [ ] 動画ファイルに `-movflags +faststart` を適用済み（プログレッシブ再生）
- [ ] MP4 + WebM の2形式を `<source>` で提供（ブラウザ互換性）

### レスポンシブ
- [ ] `object-cover` / `object-contain` で適切にフィット
- [ ] モバイルでは動画の代わりに静止画を表示する選択肢も検討
  ```tsx
  const isMobile = window.innerWidth < 768;
  // モバイルでは poster 画像のみ、動画はロードしない
  ```

### アクセシビリティ
- [ ] 自動再生動画は必ず `muted`（ユーザー操作なしの音声再生はブロックされる）
- [ ] `prefers-reduced-motion` に対応し、アニメーション無効時は静止画にフォールバック
  ```css
  @media (prefers-reduced-motion: reduce) {
    video { display: none; }
    .video-poster-fallback { display: block; }
  }
  ```

### デザイン（Plural Reality 準拠）
- [ ] 角丸なし（`border-radius: 0px`）
- [ ] ボーダー: `1px solid var(--border)`
- [ ] オーバーレイは黒グラデーション（モノクロマティック維持）
- [ ] 再生ボタンのアイコンは Lucide React の `Play` を使用

---

## ファイル配置規約

```
client/
  public/
    videos/
      hero-demo.mp4           # ヒーロー動画（MP4）
      hero-demo.webm           # ヒーロー動画（WebM）
      hero-poster.jpg           # ヒーロー動画のポスター画像
      kouchou-ai-demo.mp4      # 広聴AI デモ動画
      baisoku-survey-demo.mp4  # 倍速サーベイ デモ動画
      baisoku-kaigi-demo.mp4   # 倍速会議 デモ動画
  src/
    components/
      HeroVideo.tsx             # ヒーロー全面動画コンポーネント
      ProductCardVideo.tsx      # カード内ホバー再生コンポーネント
      BrowserMockupVideo.tsx    # ブラウザフレーム付き動画
      VideoLightbox.tsx         # モーダル動画コンポーネント
```

---

## よくある構成例

### SaaS / プロダクトLP（推奨構成）

```
Hero全面動画（15-30秒ループ、ミュート自動再生）
  ↓
テキストセクション（ミッション・バリュー）
  ↓
ブラウザモックアップ動画（メインプロダクトのデモ）
  ↓
プロダクトカード（ホバーで個別デモ動画再生）
  ↓
ケーススタディ / 実績
  ↓
CTA
```

### コーポレートサイト（控えめ構成）

```
ヒーロー画像 + 再生ボタン（クリックでLightbox動画）
  ↓
テキストセクション
  ↓
プロダクトカード（静止画、詳細ページに動画）
```

---

## Pattern 5: CSSアニメーションによるプロダクトUIモック（推奨）

動画ファイルなしで、プロダクトの操作感をCSSアニメーション / SVG / Canvasで直接描画する。
Stripe、Linear、Vercel が採用しているアプローチ。

### メリット
- 動画ファイル不要（ゼロバイト追加）
- 完全レスポンシブ（どの画面サイズでも崩れない）
- ネイティブ描画でシャープ（圧縮アーティファクトなし）
- インタラクティブ対応可能（ホバー、クリックで変化）
- ダークモード/ライトモード自動対応

### 前提: 既存アニメーション資産

Plural Reality LP には `SolutionAnimations.tsx` に以下の高品質アニメーションが実装済み:

| コンポーネント | 内容 | 技術 |
|---|---|---|
| `NetworkOntologyAnimation` | 3層オントロジー（DATA→ONTOLOGY→APPLICATION） | SVG + framer-motion |
| `DataFlowAnimation` | 集める→整理→つなげる パイプライン | SVG + framer-motion |
| `ClusterAnimation` | 意見のクラスタリング可視化 | SVG + framer-motion |
| `ConversationBranchAnimation` | 深掘りインタビューの分岐ツリー | SVG + framer-motion |
| `FeedbackLoopAnimation` | 継続的対話サイクル | SVG + framer-motion |
| `IntegrationMeshAnimation` | プラットフォーム統合図 | SVG + framer-motion |
| `ParticleFieldAnimation` | パーティクルネットワーク | Canvas |
| `IsometricLayersAnimation` | 等角投影レイヤー構造 | SVG + framer-motion |

また、`LifeGameHero.tsx` に地球 → 日本の Canvas アニメーションがある。

### 共通デザイン原則

```
- 背景: 黒（#000000）、白要素で描画
- モノクロマティック（カラーは使わない or Brand Teal のみアクセント）
- フォント: var(--font-mono) でテックラベル、var(--font-sans) でUI要素
- 角丸なし: rx={0} / border-radius: 0px
- アニメーション: framer-motion の useInView + motion.* で scroll-triggered
- グリッド背景: 薄い白線グリッドパターン（GridBg ユーティリティ）
- グロー: feDropShadow で控えめな発光（GlowDef ユーティリティ）
```

### Pattern 5A: ブラウザ枠 + アニメーションUI

ブラウザのクロム（タイトルバー + ドット）の中に、アニメーションで動くモックUIを表示。

```tsx
function ProductDemoMock({
  title,
  children,
  className,
}: {
  title: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("border border-border bg-black overflow-hidden", className)}>
      {/* Browser chrome */}
      <div className="flex items-center gap-2 px-4 py-3 bg-[#1c1c1e] border-b border-border">
        <div className="flex gap-1.5">
          <div className="w-2.5 h-2.5 rounded-full bg-white/10" />
          <div className="w-2.5 h-2.5 rounded-full bg-white/10" />
          <div className="w-2.5 h-2.5 rounded-full bg-white/10" />
        </div>
        <div className="flex-1 text-center">
          <span className="text-[10px] text-white/40 font-mono">{title}</span>
        </div>
      </div>
      {/* Animated content */}
      <div className="aspect-video relative overflow-hidden">
        {children}
      </div>
    </div>
  );
}
```

### Pattern 5B: 広聴AI デモアニメーション

テキストデータが流れ込み → AI がクラスタリング → 結果が表示される流れ。

```tsx
// 概念設計（実装時にSolutionAnimationsのClusterAnimationを参考にする）
function KouchouAIDemoAnimation() {
  const [phase, setPhase] = useState<"input" | "processing" | "result">("input");

  useEffect(() => {
    const timers = [
      setTimeout(() => setPhase("processing"), 2000),
      setTimeout(() => setPhase("result"), 4000),
    ];
    const loop = setInterval(() => {
      setPhase("input");
      timers.push(setTimeout(() => setPhase("processing"), 2000));
      timers.push(setTimeout(() => setPhase("result"), 4000));
    }, 8000);
    return () => { timers.forEach(clearTimeout); clearInterval(loop); };
  }, []);

  return (
    <ProductDemoMock title="kouchou-ai.plural-reality.com">
      <svg viewBox="0 0 800 450" className="w-full h-full">
        {/* Phase 1: テキスト行が左からスライドイン */}
        {phase === "input" && (
          <g>
            {["交通が不便で困っている", "子育て支援を充実させてほしい", "防災対策が心配"].map((text, i) => (
              <motion.g
                key={text}
                initial={{ opacity: 0, x: -40 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.4 }}
              >
                <rect x={40} y={60 + i * 50} width={350} height={36} fill="white" fillOpacity={0.05} stroke="white" strokeWidth={0.5} />
                <text x={56} y={82 + i * 50} fill="white" fontSize={11} fontFamily="var(--font-sans)" opacity={0.8}>
                  {text}
                </text>
              </motion.g>
            ))}
          </g>
        )}

        {/* Phase 2: パーティクルが中央に集まる */}
        {phase === "processing" && (
          <motion.text x={400} y={225} textAnchor="middle" fill="white" fontSize={12} fontFamily="var(--font-mono)"
            initial={{ opacity: 0 }} animate={{ opacity: [0, 0.6, 0.6, 0] }} transition={{ duration: 2 }}>
            ANALYZING...
          </motion.text>
        )}

        {/* Phase 3: クラスタ結果が表示 */}
        {phase === "result" && (
          <g>
            {[
              { label: "交通", cx: 200, cy: 150, count: "42%" },
              { label: "子育て", cx: 400, cy: 200, count: "31%" },
              { label: "防災", cx: 600, cy: 160, count: "27%" },
            ].map((cluster, i) => (
              <motion.g
                key={cluster.label}
                initial={{ opacity: 0, scale: 0.5 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: i * 0.3 }}
              >
                <circle cx={cluster.cx} cy={cluster.cy} r={45} fill="white" fillOpacity={0.03} stroke="white" strokeWidth={0.5} />
                <text x={cluster.cx} y={cluster.cy - 5} textAnchor="middle" fill="white" fontSize={13} opacity={0.9}>{cluster.label}</text>
                <text x={cluster.cx} y={cluster.cy + 15} textAnchor="middle" fill="white" fontSize={18} fontWeight={700} opacity={0.8}>{cluster.count}</text>
              </motion.g>
            ))}
          </g>
        )}
      </svg>
    </ProductDemoMock>
  );
}
```

### Pattern 5C: 倍速会議 デモアニメーション

投票UIのモック → リアルタイム集計バーが伸びる → 合意/対立が表示。

```tsx
// 概念設計
// - 左: 質問カード + 5段階投票ボタンが並ぶ
// - 右: バーチャートがアニメーションで成長
// - 下: 「合意」「対立」ラベルがフェードイン
```

### Pattern 5D: 倍速サーベイ デモアニメーション

チャット風UIでメッセージが順に表示 → 深掘り質問が分岐。

```tsx
// 概念設計（ConversationBranchAnimationを参考にする）
// - チャットバブルが下から順に表示
// - AI の深掘り質問が表示される
// - 回答 → 更に深掘り のループ
```

### ホームページでの配置例

```tsx
// Home.tsx の Hero image セクション（L159-170）を置換
<Section className="py-0">
  <FadeIn>
    <ProductDemoMock title="plural-reality.com" className="mx-auto max-w-5xl">
      {/* メインプロダクト（広聴AI）のデモアニメーション */}
      <KouchouAIDemoAnimation />
    </ProductDemoMock>
  </FadeIn>
</Section>

// または、各プロダクトカード（L218-341）の ParallaxImage を置換
<ProductDemoMock title="kouchou-ai.plural-reality.com">
  <KouchouAIDemoAnimation />
</ProductDemoMock>
```

### 実装手順

1. `SolutionAnimations.tsx` の共通ユーティリティ（GridBg, GlowDef, Particle）を再利用
2. 各プロダクト用のデモアニメーションコンポーネントを `components/ProductDemos.tsx` に作成
3. `ProductDemoMock`（ブラウザ枠）でラップ
4. Home.tsx の該当セクションで使用
5. `prefers-reduced-motion` 対応: アニメーション無効時は静止画（既存の png）にフォールバック
