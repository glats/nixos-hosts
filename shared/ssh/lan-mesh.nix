{ lib }:

let
  members = {
    macm5 = { user = "juan"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGX9n6Xva9Lpuf4Fn4rTqLl+3zbfSN2jzJQW7V54J1mu juan@CLFTCLGV2FHWW0W-lan"; comment = "juan@CLFTCLGV2FHWW0W-lan"; fingerprint = "SHA256:dGchDHoVqgTTvF7PafEYb4aRJaaGYxryV0Cpmq+DQdg"; verifiedOn = "2026-09-16"; hostName = "CLFTCLGV2FHWW0W.local"; identityFile = "id_ed25519_lan"; hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK77Gn36BBUcfxW5TBs2txvZv7UWgRXSDXaWIc7MGw//"; hostKeyFingerprint = "SHA256:nR0C5OZn/sUiNGl6ozzCDAjmR8ygNf449uUXD9p7sWQ"; };
    oneplus5 = { user = "glats"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAg7nR2ugN5GproFRCXSC2LcoLfn00e1vFUYbBXj/zvD glats@oneplus5-lan"; comment = "glats@oneplus5-lan"; fingerprint = "SHA256:hZLmKIISKxNV4jaHR1yhKuUQ/Zknq7AvT6SZ7xCjVGc"; verifiedOn = "2026-09-16"; hostName = "oneplus5.local"; identityFile = "id_ed25519_lan"; hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGs1GXmartmM039fxPo+SCCB7A9YM0YK5Ub2nIgjc104"; hostKeyFingerprint = "SHA256:r1+/bkfm8rb8ygeMipmFX4K5yTgJuqHrK61S1hXuwHg"; };
    rog = { user = "glats"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID47wBmPxBXhRq8uxOABpd+G72Gyizn+hDU/B5Z6xAkT glats@rog-lan"; comment = "glats@rog-lan"; fingerprint = "SHA256:Q5lpc7wmLtuEQcBMS498KRDzuJiCB8uxiWOtYtptVRw"; verifiedOn = "2026-09-16"; hostName = "rog.local"; identityFile = "id_ed25519_lan"; hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKYlN8cTRboRfFLK1QT7m7Qkvz8w0UK82LEVNpwcEcG"; hostKeyFingerprint = "SHA256:yBS1rqTxc5CVUDysJYW/ScqBKqiJyypPTjovlhrL2io"; };
    t14 = { user = "glats"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILjmQmDCgrLLPpd9dpvWnB2Uqi25kTvj9Bycp0rKQt+R glats@t14-lan"; comment = "glats@t14-lan"; fingerprint = "SHA256:rkMW1xYiWF9TRp8bR1lWWlm7axKlPOtF41bFFpTZQfU"; verifiedOn = "2026-09-16"; hostName = "t14.local"; identityFile = "id_ed25519_lan"; hostPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQClXRE8cc229bb+f1dr/rR59UK0J95NpXqfMgwFbU8DFRBUqwLpBBhen3dJIc1O/c2WPdhXwKkk8EuUD16adhRb4rvALbJfMqrLrrG4yoUPANt5qWX5mZJOB7Z7/Tl5UhD7f6Uflx2FrkDhJcleB7WpkTkG4y4e2jQJzfFSNWnW16yNavJW3wTK+1tPf4iw3hTmvQO2XBLjZvArpDhtgmSQEeHPtG6+MjMIqxvL7AahMA5jFoHbKPz3lgeoUAYuTQRS8mu87iW1vSoplFPf2BpXlCWYiwMVimsFYjBEK3IN6g5lYMVv0Hj9MNWy/NEtEu9kuBkv3DGboMIJV8AUk5xUZ3iXWsWpdk9O13bsUohJ0y0x/59hniwjKiSa8j5vDOHB1YDrCPAf4Gx8uEyHBsXPlZVFAI94NSBGM7oHNnF/J5y359t/ZvQZlzQfhzD9+u4Po4IeDmICePjcscGzHvtlixCuQ5+3k/QOHdWy1bOwK9iRBBGrYK3M2uybr62Aj5VNuQKdV9QvwELdAALXRBdgzOx1iKDsQDk4ylUVAYba5BiBapqc2O6I1MEoB9qh130S/dG9Fqw4a0nAdWx4Ksf2wqkO540ZPwRIkal1rp7sBtHSYFXdp70DX+FVExczFhVzlwYv6kdFdyuxC2PyPDWjgkOJPiCNq+BvAyO5I91vrw=="; hostKeyFingerprint = "SHA256:+WPEFc72jPKnpO24lyyrOR/2ExTNJ5FfpypXyOmjUFE"; };
    thinkcentre = { user = "glats"; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSehpAzNhKa87/oag3V60HqcmO4/ix6IbOjyXEQM8s6 glats@thinkcentre-lan"; comment = "glats@thinkcentre-lan"; fingerprint = "SHA256:VxKH+PuTiSwVMeBflQ7RBkT+RFwRC5wWHsw9jEv3L8Q"; verifiedOn = "2026-09-16"; hostName = "thinkcentre.local"; identityFile = "id_ed25519_lan"; hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONq9Dy8wonglOcdhoQhJEcTB7PK13K0p8U4bkEWLj5N"; hostKeyFingerprint = "SHA256:FNVpTbaoCOiL5ZWszL5t2ekMswJRRcKQYvQeGY7hGYk"; };
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
  knownHosts = lib.mapAttrs
    (
      name: member: {
        publicKey = member.hostPublicKey;
        hostNames = lib.unique [ name "${name}.local" member.hostName ];
      }
    )
    (lib.filterAttrs (_: member: member ? hostPublicKey) members);
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
