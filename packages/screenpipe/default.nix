# Screenpipe: 24/7 Screen & Audio Recording with AI
# Requires rust-overlay applied to pkgs (for pkgs.rust-bin.nightly)
{ pkgs, screenpipe-src }:
let
  rustToolchain = pkgs.rust-bin.nightly.latest.default;
  rustPlatform = pkgs.makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };

  # cidre's build.rs invokes `xcodebuild` to compile pomace/ — a set of
  # trivial Objective-C files (one .h/.m pair per Apple-framework target).
  # nixpkgs' xcbuild can't handle the project (object version 55, SPM deps,
  # unwritable HOME for DerivedData). No real Xcode is needed: the .m files
  # are single-#import stubs compilable with plain clang + ar.
  #
  # This shim parses the xcodebuild CLI args cidre passes, then for each
  # -target compiles pomace/<target>/<target>.m → lib<target>.a into SYMROOT.
  xcodebuildShim = pkgs.writeShellScriptBin "xcodebuild" ''
    set -euo pipefail
    SDK="macosx"; ARCH="arm64"; CFG="Release"; SYMROOT=""
    DEPLOY_FLAGS=()
    TARGETS=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -project)       shift 2 ;;
        -sdk)           SDK="$2"; shift 2 ;;
        -arch)          ARCH="$2"; shift 2 ;;
        -configuration) CFG="$2"; shift 2 ;;
        -target)        TARGETS+=("$2"); shift 2 ;;
        -derivedDataPath) shift 2 ;;
        build)          shift ;;
        SYMROOT=*)      SYMROOT="''${1#SYMROOT=}"; shift ;;
        MACOSX_DEPLOYMENT_TARGET=*)
          DEPLOY_FLAGS+=("-mmacosx-version-min=''${1#MACOSX_DEPLOYMENT_TARGET=}")
          shift ;;
        *)              shift ;;
      esac
    done
    OUTDIR="$SYMROOT/$CFG"
    mkdir -p "$OUTDIR"
    SDK_PATH="$(xcrun --show-sdk-path --sdk "$SDK" 2>/dev/null || true)"
    for T in "''${TARGETS[@]}"; do
      SRC="./pomace/$T/$T.m"
      [[ -f "$SRC" ]] || { echo "xcodebuild-shim: skip $T (no source)" >&2; continue; }
      clang -c \
        -arch "$ARCH" \
        ''${SDK_PATH:+-isysroot "$SDK_PATH"} \
        -fobjc-arc -fmodules -Wno-undef-prefix \
        "''${DEPLOY_FLAGS[@]}" \
        -I "./pomace/$T" \
        -o "$OUTDIR/$T.o" "$SRC"
      ar rcs "$OUTDIR/lib$T.a" "$OUTDIR/$T.o"
      rm -f "$OUTDIR/$T.o"
    done
  '';

  # Several crates vendor C/C++ libs as git submodules that
  # allowBuiltinFetchGit doesn't resolve, leaving empty dirs.
  # Fetch pinned commits separately and inject in preBuild.
  whisperCppSrc = pkgs.fetchFromGitHub {
    owner = "ggerganov";
    repo = "whisper.cpp";
    rev = "fc45bb86251f774ef817e89878bb4c2636c8a58f";
    hash = "sha256-BEpdr8sSvB+84H4m7Ekov+mjzwo/Vn5QMevya0ugNjA=";
  };

  kaldiNativeFbankSrc = pkgs.fetchFromGitHub {
    owner = "csukuangfj";
    repo = "kaldi-native-fbank";
    rev = "af5968505a23dfe139540d20d435290b31e8a013";
    hash = "sha256-9l/4mmHYXCiS9Vs1MsFfzrMfxwAF2ULzvULhzzEd52c=";
  };

in
rustPlatform.buildRustPackage {
  pname = "screenpipe";
  version = "0.3.135";
  src = screenpipe-src;

  # cpal-0.15.3 exists both on crates.io (via rodio) and as a screenpipe
  # git fork. importCargoLock can't hold two entries with the same name-version.
  # The patch unifies both on the git fork and removes the unused half
  # [patch.crates-io] entry; the patched lockfile is stored locally to
  # avoid IFD (Import From Derivation).
  cargoPatches = [ ./patches/deduplicate-cpal.patch ];

  cargoLock = {
    lockFile = ./Cargo.lock; # pre-patched copy matching deduplicate-cpal.patch
    allowBuiltinFetchGit = true;
    outputHashes = {
      # github:eiz/accessibility
      "accessibility-0.2.0" = "sha256-PFN0CL+RWXMwpdHRQmAAadSDlHxKe/i5Dw25oolsjkU=";
      "accessibility-sys-0.2.0" = "sha256-PFN0CL+RWXMwpdHRQmAAadSDlHxKe/i5Dw25oolsjkU=";
      # github:huggingface/candle
      "candle-core-0.8.3" = "sha256-XFhcV6vkEmzfmvMLwzipm9nB38TL3l4Lh10OIk2KLlw=";
      "candle-kernels-0.8.3" = "sha256-XFhcV6vkEmzfmvMLwzipm9nB38TL3l4Lh10OIk2KLlw=";
      "candle-metal-kernels-0.8.3" = "sha256-XFhcV6vkEmzfmvMLwzipm9nB38TL3l4Lh10OIk2KLlw=";
      "candle-nn-0.8.3" = "sha256-XFhcV6vkEmzfmvMLwzipm9nB38TL3l4Lh10OIk2KLlw=";
      "candle-transformers-0.8.3" = "sha256-XFhcV6vkEmzfmvMLwzipm9nB38TL3l4Lh10OIk2KLlw=";
      # github:yury/cidre
      "cidre-0.14.0" = "sha256-rYr+cMUBEgItF9EeRalsdSZvXxXbFXQyUOrYADlSTyM=";
      # github:screenpipe/cpal (unified via patch — registry cpal removed)
      "cpal-0.15.3" = "sha256-F6NBQhURpeHmafup+SJe+jSFCiMZKByJ0LEBcrpUIro=";
      # github:nathanbabcock/ffmpeg-sidecar
      "ffmpeg-sidecar-2.0.5" = "sha256-qugJfEQlkSsL8EQrdg4euGL4wH43qxnZeFviVqLh2Ao=";
      # github:neo773/hf-hub
      "hf-hub-0.3.2" = "sha256-hTAdRgJKCN4kTyZXy4SOHPEhBY4/UX+tWJPoUroKLD0=";
      # github:Neptune650/knf-rs
      "knf-rs-0.2.4" = "sha256-17cTqd/H5gHnAiPq1FoJyWfq+iljR9aI+RtwsaFDsFk=";
      "knf-rs-sys-0.2.4" = "sha256-17cTqd/H5gHnAiPq1FoJyWfq+iljR9aI+RtwsaFDsFk=";
      # github:screenpipe/rusty-tesseract
      "rusty-tesseract-1.1.10" = "sha256-XT74zGn+DetEBUujHm4Soe2iorQcIoUeZbscTv+64hw=";
      # github:screenpipe/sck-rs
      "sck-rs-0.1.0" = "sha256-unTVi0HtUY4KPU8S9gPaZAs7v4Z8UMbz+T0EGVsm19o=";
      # github:screenpipe/vad-rs-1
      "vad-rs-0.2.0" = "sha256-F6jf1fhheeyGmmClUg3fzT1klhXRgfE0szjfG9J+Nl4=";
      # codeberg:tazz4843/whisper-rs
      "whisper-rs-0.15.1" = "sha256-hqo6GQQmIQQ0zAhOJsKWlDjQITzodnK+VaC8r4hVlBQ=";
      "whisper-rs-sys-0.14.1" = "sha256-hqo6GQQmIQQ0zAhOJsKWlDjQITzodnK+VaC8r4hVlBQ=";
    };
  };

  nativeBuildInputs = with pkgs; [
    makeWrapper
    pkg-config
    protobuf
    perl
    cmake
    clang
    git            # whisper.cpp's ggml CMake calls find_program(git)
    xcodebuildShim # compiles pomace .m files with clang (replaces xcodebuild)
    xcbuild        # provides xcrun for SDK path resolution
  ];

  buildInputs =
    with pkgs;
    [
      openssl
      sqlite
      ffmpeg
      bun
    ]
    ++ lib.optionals stdenv.isDarwin [
      pkgs.apple-sdk_15
    ];

  # cidre's build.rs also calls /usr/bin/clang for link search paths
  __noChroot = pkgs.stdenv.isDarwin;

  # Populate empty git submodule dirs in the writable vendor copy.
  # allowBuiltinFetchGit doesn't resolve submodules, leaving empty dirs.
  preBuild = ''
    vendorDir=$(echo "$NIX_BUILD_TOP"/cargo-vendor-dir*)

    whisperSys="$vendorDir/whisper-rs-sys-0.14.1"
    rm -rf "$whisperSys/whisper.cpp"
    cp -r ${whisperCppSrc} "$whisperSys/whisper.cpp"
    chmod -R u+w "$whisperSys/whisper.cpp"

    knfSys="$vendorDir/knf-rs-sys-0.2.4"
    rm -rf "$knfSys/knf"
    cp -r ${kaldiNativeFbankSrc} "$knfSys/knf"
    chmod -R u+w "$knfSys/knf"
  '';

  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/screenpipe \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.ffmpeg
          pkgs.bun
        ]
      }
  '';

  meta = with pkgs.lib; {
    description = "24/7 Screen & Audio Recording with AI";
    homepage = "https://github.com/screenpipe/screenpipe";
    license = licenses.mit;
  };
}
