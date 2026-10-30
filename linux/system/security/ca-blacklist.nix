# Distrust for the eMudhra intermediate CA compromise (Oct 2026): eight
# intermediates chain to these roots. https://emudhra.we-have-a-problem.com/
{ lib, pkgs, ... }:
{
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ]
  ++ lib.optional (lib.versionOlder pkgs.cacert.version "3.131.1") "emSign ECC Root CA - G3";
}
