{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage {
  pname = "mcp-supermercados-cl";
  version = "1.4.9";

  src = fetchFromGitHub {
    owner = "NLACE-COM";
    repo = "mcp-supermercados-cl";
    rev = "82e6bf8d94e58ec9655c0a0ab031614517bda0c1";
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
}
