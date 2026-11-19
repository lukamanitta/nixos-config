{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Herdr ships a static-pie release binary (no dynamic dependencies); building
# it from source means a full Rust + zig toolchain, so fetch the pinned release
# instead. Update `version` together with the two hashes from
# https://herdr.dev/latest.json (`sha256.<asset>`, converted to SRI).
let
  version = "0.9.5";

  assets = {
    x86_64-linux = {
      asset = "linux-x86_64";
      hash = "sha256-FNnovItKngEY13wyJm921GHwm0A0LrI3UpYL2J9Zkp0=";
    };
    aarch64-linux = {
      asset = "linux-aarch64";
      hash = "sha256-F9dTby2lCFlSNoDvJ53/ysjkojX05G/o2mwuxEFBiXw=";
    };
  };

  target =
    assets.${stdenvNoCC.hostPlatform.system}
      or (throw "herdr: no release binary for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "herdr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-${target.asset}";
    inherit (target) hash;
  };

  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/herdr"
    runHook postInstall
  '';

  meta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames assets;
    mainProgram = "herdr";
  };
}
