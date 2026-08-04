{
  lib,
  pkgs,
  ...
}:

let
  ntfyUrlFile = ../secrets/ntfy-url;
  ntfyTokenFile = ../secrets/ntfy-token;
  hasNtfy = builtins.pathExists ntfyUrlFile;
  hasToken = builtins.pathExists ntfyTokenFile;

  # fake mail transport for zed/smartd
  notify = pkgs.writeShellApplication {
    name = "notify-mail";
    runtimeInputs = [
      pkgs.curl
      pkgs.util-linux
    ];
    text = ''
      subject="archivum alert"
      while [ "$#" -gt 0 ]; do
        if [ "$1" = "-s" ] && [ "$#" -gt 1 ]; then
          subject="$2"
          shift 2
        else
          shift   # -i, recipients, whatever else the caller passes
        fi
      done

      body="$(cat)"

      # journal as backup
      printf '%s\n%s\n' "$subject" "$body" \
        | logger --tag notify-mail --priority daemon.warning

      ${lib.optionalString hasNtfy ''
        url="$(tr -d '[:space:]' < ${toString ntfyUrlFile})"
        ${lib.optionalString hasToken ''token="$(tr -d '[:space:]' < ${toString ntfyTokenFile})"''}
        if [ -n "$url" ]; then
          curl --fail --silent --show-error --max-time 20 \
            --header "Title: $subject" \
            --header "Priority: high" \
            --header "Tags: warning" \
            ${lib.optionalString hasToken ''--header "Authorization: Bearer $token" \''}
            --data-binary "$body" \
            "$url" >/dev/null \
            || logger --tag notify-mail --priority daemon.err -- "failed to deliver: $subject"
        fi
      ''}
    '';
  };
in
{
  warnings =
    lib.optional (!hasNtfy) ''
      archivum alerts (restic, smartd, zfs) only go to the journal:
      secrets/ntfy-url does not exist, so nothing is pushed anywhere.
    ''
    ++ lib.optional (hasNtfy && !hasToken) ''
      archivum pushes alerts to ntfy without a token: secrets/ntfy-token does
      not exist. quaesitum's ntfy runs auth-default-access = deny-all, so this
      will 403 unless the topic is on a server that allows anonymous publish.
    '';

  systemd.services."notify-failure@" = {
    description = "Alert about the failure of %i";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    scriptArgs = "%i";
    script = ''
      ${pkgs.systemd}/bin/systemctl status --full --lines=50 -- "$1" 2>&1 \
        | ${lib.getExe notify} -s "archivum: $1 failed"
    '';
  };

  services.smartd.notifications.mail = {
    enable = true;
    sender = "smartd@archivum";
    recipient = "root";
    mailer = lib.getExe notify;
  };

  services.zfs.zed.settings = {
    ZED_EMAIL_ADDR = [ "root" ];
    ZED_EMAIL_PROG = lib.getExe notify;
    ZED_EMAIL_OPTS = "-s '@SUBJECT@' @ADDRESS@";
    ZED_NOTIFY_VERBOSE = true;
  };

  environment.systemPackages = [ notify ];
}
