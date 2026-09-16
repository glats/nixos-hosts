{ lib }:

let
  members = {
    macm5 = { user = "juan"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGX9n6Xva9Lpuf4Fn4rTqLl+3zbfSN2jzJQW7V54J1mu juan@CLFTCLGV2FHWW0W-lan"; comment = "juan@CLFTCLGV2FHWW0W-lan"; fingerprint = "SHA256:dGchDHoVqgTTvF7PafEYb4aRJaaGYxryV0Cpmq+DQdg"; verifiedOn = "2026-09-16"; hostName = "CLFTCLGV2FHWW0W.local"; identityFile = "id_ed25519_lan"; };
    oneplus5 = { user = "glats"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAg7nR2ugN5GproFRCXSC2LcoLfn00e1vFUYbBXj/zvD glats@oneplus5-lan"; comment = "glats@oneplus5-lan"; fingerprint = "SHA256:hZLmKIISKxNV4jaHR1yhKuUQ/Zknq7AvT6SZ7xCjVGc"; verifiedOn = "2026-09-16"; hostName = "oneplus5.local"; identityFile = "id_ed25519_lan"; };
    rog = { user = "glats"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID47wBmPxBXhRq8uxOABpd+G72Gyizn+hDU/B5Z6xAkT glats@rog-lan"; comment = "glats@rog-lan"; fingerprint = "SHA256:Q5lpc7wmLtuEQcBMS498KRDzuJiCB8uxiWOtYtptVRw"; verifiedOn = "2026-09-16"; hostName = "rog.local"; identityFile = "id_ed25519_lan"; };
    t14 = { user = "glats"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILjmQmDCgrLLPpd9dpvWnB2Uqi25kTvj9Bycp0rKQt+R glats@t14-lan"; comment = "glats@t14-lan"; fingerprint = "SHA256:rkMW1xYiWF9TRp8bR1lWWlm7axKlPOtF41bFFpTZQfU"; verifiedOn = "2026-09-16"; hostName = "t14.local"; identityFile = "id_ed25519_lan"; };
    thinkcentre = { user = "glats"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSehpAzNhKa87/oag3V60HqcmO4/ix6IbOjyXEQM8s6 glats@thinkcentre-lan"; comment = "glats@thinkcentre-lan"; fingerprint = "SHA256:VxKH+PuTiSwVMeBflQ7RBkT+RFwRC5wWHsw9jEv3L8Q"; verifiedOn = "2026-09-16"; hostName = "thinkcentre.local"; identityFile = "id_ed25519_lan"; };
  };
  names = builtins.attrNames members;
  records = builtins.attrValues members;
  validRecord = member: lib.hasPrefix "ssh-ed25519 " member.publicKey && !(lib.hasInfix "PRIVATE" member.publicKey) && member.comment != "" && member.fingerprint != "" && member.verifiedOn != "";
in
assert lib.assertMsg (builtins.length names == 5) "LAN SSH mesh must contain exactly five members";
assert lib.assertMsg (builtins.length (lib.unique (map (member: member.publicKey) records)) == 5) "LAN SSH mesh public keys must be unique";
assert lib.assertMsg (lib.all validRecord records) "LAN SSH mesh records must be verified public identities";
{
  inherit members;
  peerKeys = target: map (name: members.${name}.publicKey) (builtins.filter (name: name != target) names);
  sshSettingsFor =
    { source, sshDir }:
    lib.listToAttrs (
      lib.concatMap
        (
          target:
          let
            member = members.${target};
            value = {
              HostName = member.hostName;
              User = member.user;
              IdentityFile = "${sshDir}/${members.${source}.identityFile}";
              IdentitiesOnly = true;
            };
          in
          [
            {
              name = target;
              inherit value;
            }
            {
              name = "${target}.local";
              inherit value;
            }
          ]
        )
        (builtins.filter (name: name != source) names)
    );
}
