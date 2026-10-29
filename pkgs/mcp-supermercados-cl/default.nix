{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "mcp-supermercados-cl";
  version = "1.4.9";

  src = fetchFromGitHub {
    owner = "NLACE-COM";
    repo = "mcp-supermercados-cl";
    tag = "v${finalAttrs.version}";
    hash = "sha256-SP+lLV1zp2xdzobRmM2FdAnReIM9Epo/BI46i5tYR8E=";
  };

  npmDepsHash = "sha256-bNxYvb49gDzTugrcH8fzZxiNXpMF+evzhNb2/XLuft0=";

  meta = with lib; {
    description = "MCP server for Chilean supermarket product search and price comparison";
    homepage = "https://github.com/NLACE-COM/mcp-supermercados-cl";
    license = licenses.mit;
    mainProgram = "mcp-supermercados-cl";
    platforms = platforms.linux;
  };
})
