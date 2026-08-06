{ config, pkgs, lib, inputs, ... }:

let
  dcal = lib.getExe config.programs.dank-calendar.package;

  # Calendar UUIDs are generated locally, so match stable provider IDs when
  # applying local presentation overrides from the previous installation.
  dcalReconcile = pkgs.writeShellScript "dcal-reconcile" ''
    set -euo pipefail

    calendars=""
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      if calendars="$(${dcal} --json ipc calendars.list 2>/dev/null)"; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done

    if [ -z "''${calendars:-}" ]; then
      exit 0
    fi

    uc3m_id="$(${pkgs.coreutils}/bin/printf '%s' "$calendars" | ${pkgs.jq}/bin/jq -r \
      --arg remote_id "100578484@alumnos.uc3m.es" \
      'if type == "array" then . else (.calendars // []) end
       | map(select((.remoteId // .remote_id) == $remote_id))[0].id // empty')"

    if [ -n "$uc3m_id" ]; then
      ${dcal} ipc calendars.rename calendarId="$uc3m_id" name=uc3m
    fi
  '';

  dcalGoogleLogin = pkgs.writeShellScriptBin "dcal-google-login" ''
    set -euo pipefail

    export DANKCAL_GOOGLE_CLIENT_ID="$(${pkgs.coreutils}/bin/cat /run/secrets/google_client_id)"
    export DANKCAL_GOOGLE_CLIENT_SECRET="$(${pkgs.coreutils}/bin/cat /run/secrets/google_client_secret)"
    ${dcal} account add google "$@"
    exec ${dcalReconcile}
  '';

  dcalWithGoogleCredentials = pkgs.writeShellScript "dcal-with-google-credentials" ''
    set -euo pipefail

    export DANKCAL_GOOGLE_CLIENT_ID="$(${pkgs.coreutils}/bin/cat /run/secrets/google_client_id)"
    export DANKCAL_GOOGLE_CLIENT_SECRET="$(${pkgs.coreutils}/bin/cat /run/secrets/google_client_secret)"
    exec ${dcal} "$@"
  '';
in
{
  imports = [ inputs.dankcalendar.homeModules.dank-calendar ];

  accounts.email.accounts = {
    personal = {
      primary = true;
      realName = "Ruben Agustin";
      address = "r.agussglz@gmail.com";
      userName = "r.agussglz@gmail.com";
      flavor = "gmail.com";
      thunderbird.enable = true;
    };

    upm = {
      realName = "Ruben Agustin";
      address = "r.agustin@alumnos.upm.es";
      userName = "r.agustin";
      imap = {
        host = "correo.alumnos.upm.es";
        port = 993;
        tls.enable = true;
      };
      smtp = {
        host = "smtp.upm.es";
        port = 587;
        tls.enable = true;
        tls.useStartTls = true;
      };
      thunderbird.enable = true;
      thunderbird.profiles = [ "principal" ];
    };

    uc3m = {
      realName = "Ruben Agustin";
      address = "ruben.agustin@alumnos.uc3m.es";
      userName = "100578484@alumnos.uc3m.es";
      flavor = "gmail.com";
      thunderbird.enable = true;
    };
  };

  home.packages = with pkgs; [
    dcalGoogleLogin
    vdirsyncer
    vesktop
    telegram-desktop
  ];

  programs.thunderbird = {
    enable = true;
    profiles.principal = {
      isDefault = true;
      extraConfig = ''
        user_pref("mail.smtpserver.smtp_4986247086fa3cd1ffd75cba8eb115e207df8855f768a70ff7e8944c665da376.username", "r.agustin@alumnos.upm.es");
        user_pref("mail.smtpserver.smtp_4986247086fa3cd1ffd75cba8eb115e207df8855f768a70ff7e8944c665da376.authMethod", 3);
      '';
    };
  };

  programs.dank-calendar = {
    enable = true;
    systemd.enable = true;
    settings = {
      allDayReminderDaysBefore = 0;
      allDayReminderTime = "09:00";
      allDayReminders = false;
      closeBehavior = "minimize";
      colorSource = "auto";
      coreHoursEnabled = false;
      coreHoursEnd = 17;
      coreHoursStart = 9;
      customThemeFile = "";
      defaultEventDurationMinutes = 30;
      defaultReminderMinutes = 10;
      firstDayOfWeek = 1;
      lastView = "month";
      monthEventTitleLines = 1;
      monthShowAllEvents = false;
      notificationSounds = false;
      presetTheme = "purple";
      reminderPersist = true;
      remindersEnabled = true;
      showTasks = true;
      showTrayIcon = true;
      showWeekNumbers = false;
      sidebarCollapsed = false;
      sidebarWidth = 240;
      snoozeMinutes = 5;
      syncIntervalMinutes = 30;
      themeMode = "auto";
      timeFormat = "auto";
      use24HourClock = false;
      weekEventTitleLines = 1;
    };
  };

  # Read SOPS secrets only at runtime; their values never enter /nix/store.
  systemd.user.services.dcal.Service.ExecStart = lib.mkForce
    "${dcalWithGoogleCredentials} run --session --hidden";
  systemd.user.services.dcal.Service.ExecStartPost = [ dcalReconcile ];

  xdg.configFile."autostart/com.danklinux.dankcalendar.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Dank Calendar (managed by systemd)
      Hidden=true
    '';
  };

  xdg.configFile."vdirsyncer/config".text = ''
    [general]
    status_path = "~/.local/share/vdirsyncer/status/"

    [pair my_google]
    a = "google_calendar"
    b = "local_calendar"
    collections = ["from a", "from b"]

    [storage google_calendar]
    type = "google_calendar"
    token_file = "~/.local/share/vdirsyncer/google_token"
    client_id.fetch = ["command", "cat", "/run/secrets/google_client_id"]
    client_secret.fetch = ["command", "cat", "/run/secrets/google_client_secret"]

    [storage local_calendar]
    type = "filesystem"
    path = "~/.calendars/google/"
    fileext = ".ics"
  '';

  xdg.configFile."khal/config".text = ''
    [calendars]
    [[google]]
    path = ~/.calendars/google/
    type = discover

    [locale]
    timeformat = %H:%M
    dateformat = %d/%m/%Y
    longdateformat = %d/%m/%Y
    datetimeformat = %d/%m/%Y %H:%M
    longdatetimeformat = %d/%m/%Y %H:%M
  '';
}
