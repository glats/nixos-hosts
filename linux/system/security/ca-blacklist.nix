# Distrust for the eMudhra intermediate CA compromise (Oct 2026): eight
# intermediates chain to these roots. https://emudhra.we-have-a-problem.com/
{
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];
}
