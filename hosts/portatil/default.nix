{ ... }:
{
  imports = [
    ./hardware.nix
    ../../common/base.nix
    ../../common/network.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  my.vpn.ipv4 = "10.10.20.2/24";
  networking.hostName = "Portatil-nixos";
}
