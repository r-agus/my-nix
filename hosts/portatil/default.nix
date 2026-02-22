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

  home-manager.users.ruben = { pkgs, ... }: 
  let
    idleHandler = pkgs.writeShellScriptBin "idle-handler" ''
      AC_ONLINE=0
      BAT_CAP=""
      
      for supply in /sys/class/power_supply/*; do
        [ -f "$supply/type" ] || continue
        # Sanitizar saltos de línea
        type=$(cat "$supply/type" 2>/dev/null | tr -d '\n\r')
        
        if [ "$type" = "Mains" ]; then
          online=$(cat "$supply/online" 2>/dev/null | tr -d '\n\r')
          [ "$online" = "1" ] && AC_ONLINE=1
        elif [ "$type" = "Battery" ]; then
          # Bloquear periféricos falsos: solo guardamos la primera batería que evaluemos
          if [ -z "$BAT_CAP" ]; then
            BAT_CAP=$(cat "$supply/capacity" 2>/dev/null | tr -d '\n\r')
          fi
        fi
      done

      # Fallback por si acaso
      [ -z "$BAT_CAP" ] && BAT_CAP=100

      # Asignación de modo segura
      MODE="BAT"
      if [ "$AC_ONLINE" -eq 1 ] && [ "$BAT_CAP" -gt 60 ]; then
        MODE="AC"
      fi

      case "$1" in
        60)
          if [ "$MODE" = "AC" ]; then
            ${pkgs.niri}/bin/niri msg action spawn -- ${pkgs.kitty}/bin/kitty --class screensaver -e ${pkgs.cmatrix}/bin/cmatrix -ab
          else
            ${pkgs.niri}/bin/niri msg action spawn -- /run/current-system/sw/bin/dms ipc call lock lock
          fi
          ;;
        70)
          if [ "$MODE" = "BAT" ]; then
            ${pkgs.niri}/bin/niri msg action power-off-monitors
          fi
          ;;
        120)
          if [ "$MODE" = "AC" ]; then
            ${pkgs.niri}/bin/niri msg action spawn -- /run/current-system/sw/bin/dms ipc call lock lock
          fi
          ;;
        180)
          if [ "$MODE" = "AC" ]; then
            ${pkgs.niri}/bin/niri msg action power-off-monitors
          fi
          ;;
      esac
    '';

    idleResume = pkgs.writeShellScriptBin "idle-resume" ''
      ${pkgs.niri}/bin/niri msg action power-on-monitors
      ${pkgs.procps}/bin/pkill -x cmatrix || true
    '';

  in {
    services.kanshi.settings = [
      {
        profile.name = "portatil";
        profile.outputs = [ { criteria = "eDP-1"; status = "enable"; } ];
      }
      {
        profile.name = "casa";
        profile.outputs = [
          { criteria = "eDP-1"; status = "disable"; }
          { criteria = "HDMI-A-1"; status = "enable"; }
        ];
      }
    ];

    services.swayidle = {
      enable = true;
      events = {
        before-sleep = "${pkgs.niri}/bin/niri msg action spawn -- /run/current-system/sw/bin/dms ipc call lock lock";
      };
      timeouts = [
        { timeout = 60;  command = "${idleHandler}/bin/idle-handler 60";  resumeCommand = "${idleResume}/bin/idle-resume"; }
        { timeout = 70;  command = "${idleHandler}/bin/idle-handler 70";  resumeCommand = "${idleResume}/bin/idle-resume"; }
        { timeout = 120; command = "${idleHandler}/bin/idle-handler 120"; resumeCommand = "${idleResume}/bin/idle-resume"; }
        { timeout = 180; command = "${idleHandler}/bin/idle-handler 180"; resumeCommand = "${idleResume}/bin/idle-resume"; }
        { timeout = 300; command = "${pkgs.systemd}/bin/systemctl suspend"; }
      ];
    };
  };
}
