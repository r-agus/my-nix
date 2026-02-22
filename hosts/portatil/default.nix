{ ... }:
{
  imports = [
    ./hardware.nix
    ../../common/base.nix
    ../../common/network.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  services.upower.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  my.vpn.ipv4 = "10.10.20.2/24";
  networking.hostName = "Portatil-nixos";
}
