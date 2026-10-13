{ pkgs, ... }:
let
  # Upstream BlueZ commit 066a164a524e4983b850f5659b921cb42f84a0e0.
  # Keep the small backport local so builds do not depend on GitHub's generated
  # patch representation remaining byte-for-byte stable.
  bluezA2dpProfileOrderPatch = pkgs.writeText "bluez-a2dp-connect-source-after-sink.patch" ''
    diff --git a/profiles/audio/a2dp.c b/profiles/audio/a2dp.c
    index 7a37003a2b..c7e0fc75c0 100644
    --- a/profiles/audio/a2dp.c
    +++ b/profiles/audio/a2dp.c
    @@ -3770,2 +3770,5 @@ static struct btd_profile a2dp_source_profile = {
     ''\t.adapter_probe''\t= a2dp_sink_server_probe,
     ''\t.adapter_remove''\t= a2dp_sink_server_remove,
    +
    +''\t/* Connect source after sink, to prefer sink when conflicting */
    +''\t.after_services = BTD_PROFILE_UUID_CB(NULL, A2DP_SINK_UUID),
  '';
in
{
  imports = [
    ./hardware.nix
    ../../common/base.nix
    ../../common/network.nix
    ../../common/ai.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  services.upower.enable = true;
  services.hardware.bolt.enable = true;
  services.xserver.videoDrivers = [ "displaylink" "modesetting" ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez.overrideAttrs (old: {
      # Fix BlueZ 5.86 A2DP profile ordering for devices that expose both
      # source and sink roles, such as the Sony HT-SF150 soundbar. BlueZ 5.87
      # and newer contain this upstream, so stop applying the backport then.
      patches = (old.patches or [ ]) ++ pkgs.lib.optional (
        pkgs.lib.versionAtLeast old.version "5.86"
        && pkgs.lib.versionOlder old.version "5.87"
      ) bluezA2dpProfileOrderPatch;
    });
  };
  hardware.graphics.extraPackages = with pkgs; [
    intel-compute-runtime
    intel-media-driver
  ];

  my.syncthing.deviceName = "portatil";
  my.vpn.ipv4 = "10.10.20.5/24";
  networking.hostName = "Portatil-nixos";

  home-manager.users.ruben = { pkgs, osConfig, ... }:
  let
    niri = osConfig.programs.niri.package;
  in {
    services.kanshi.settings = [
      {
        profile.name = "portatil";
        profile.outputs = [ { criteria = "eDP-1"; status = "enable"; } ];
      }
      {
        profile.name = "casa-hdmi";
        profile.outputs = [
          { criteria = "eDP-1"; status = "disable"; }
          { criteria = "HDMI-A-1"; status = "enable"; }
        ];
      }
      {
        profile.name = "casa-dock";
        profile.outputs = [
          { criteria = "eDP-1"; status = "disable"; }
          { criteria = "Samsung Electric Company S34CG50 HNBWB03239"; status = "enable"; }
        ];

      }
    ];
  };
}
