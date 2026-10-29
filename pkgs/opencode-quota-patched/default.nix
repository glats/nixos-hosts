{
  lib,
  buildNpmPackage,
  nodejs,
}:

buildNpmPackage {
  pname = "opencode-quota-patched";
  version = "5.0.3";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./enterprise-spend-limit.patch
      ./enterprise-spend-limit.test.mjs
      ./provider-null-windows.test.mjs
      ./response-headers.patch
      ./anthropic-response-headers.mjs
      ./anthropic-response-headers.test.mjs
    ];
  };

  npmDepsHash = "sha256-+s5BwaMjms71NJYor3uBaAsa07ZjVFs43xSLZ1LO5R8=";
  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    plugin=node_modules/@slkiser/opencode-quota
    mkdir -p "$out"
    cp -R "$plugin"/. "$out/"
    rm -rf "$plugin" node_modules/.bin/opencode-quota
    cp -R node_modules "$out/node_modules"
    patch -d "$out" -p1 --forward --no-backup-if-mismatch < ${./enterprise-spend-limit.patch}
    patch -d "$out" -p1 --forward --no-backup-if-mismatch < ${./response-headers.patch}
    cp ${./anthropic-response-headers.mjs} "$out/dist/lib/anthropic-response-headers.mjs"
    printf 'export { default } from "./dist/index.js";\n' > "$out/index.js"
    printf 'export { default } from "./dist/tui.js";\n' > "$out/tui.js"
    for hostProvided in effect @opencode/plugin; do
      if [ -e "$out/node_modules/$hostProvided" ]; then
        echo "host-provided module vendored: $hostProvided" >&2
        exit 1
      fi
    done
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${lib.getExe nodejs} ${./enterprise-spend-limit.test.mjs} "$out"
    ${lib.getExe nodejs} ${./provider-null-windows.test.mjs} "$out"
    ${lib.getExe nodejs} ${./anthropic-response-headers.test.mjs} "$out"
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "@slkiser/opencode-quota 5.0.3 with Claude Enterprise and passive response-header quota";
    homepage = "https://github.com/slkiser/opencode-quota";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
