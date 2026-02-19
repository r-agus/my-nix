{ ... }:
{
  imports = [
    ./hardware.nix
    ../../common/base.nix
    ../../common/network.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  my.vpn.ipv4 = "10.10.20.3/24";
  networking.hostName = "PC-nixos";

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false; # GTX 1060: Use nvidia old drivers (propertary)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
