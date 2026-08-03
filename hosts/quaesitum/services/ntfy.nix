{
  lib,
  ...
}:

let
  # Declarative user/ACL/token provisioning, in systemd EnvironmentFile format:
  #
  #   NTFY_AUTH_USERS=nox:$2a$10$...:admin,archivum:$2a$10$...:user
  #   NTFY_AUTH_ACCESS=archivum:alerts:wo
  #   NTFY_AUTH_TOKENS=archivum:tk_...:archivum alerts
  #
  # ntfy reads these on every start and reconciles user.db against them, so the
  # database is a cache rather than the source of truth. See the README for how
  # to generate the hashes and the token.
  provisionFile = ../secrets/ntfy.env;
  provisioned = builtins.pathExists provisionFile;
in
{
  warnings = lib.optional (!provisioned) ''
    ntfy on quaesitum has no users: hosts/quaesitum/secrets/ntfy.env does not
    exist, and auth-default-access is deny-all, so nothing can publish or read.
  '';

  # Deliberately on quaesitum rather than archivum. An alerting system that
  # lives on the machine it alerts about only works while that machine does -
  # and "archivum is unreachable" is exactly the message that has to get out.
  # quaesitum is a Hetzner VPS on someone else's power and someone else's
  # uplink, which is the entire point.
  services.ntfy-sh = {
    enable = true;

    environmentFile = lib.mkIf provisioned (toString provisionFile);

    settings = {
      base-url = "https://ntfy.nox.onl";
      listen-http = "127.0.0.1:2586";

      # Rate limiting has to see the real client, not nginx.
      behind-proxy = true;

      # Nothing is public. Publishing and subscribing both require a credential
      # from ntfy.env; an unauthenticated request gets 403 regardless of how
      # well it guessed the topic name.
      auth-default-access = "deny-all";
      auth-access-cache = true;
      enable-signup = false;
      enable-login = true;

      # How long a message stays retrievable for a phone that was off or out of
      # signal. Alerts are small; a day of them is nothing.
      cache-duration = "24h";

      # Alerts are text. Attachments are only enabled when a cache dir is set,
      # so clearing the module's default turns the upload path off entirely -
      # unlike a size limit of zero, which just makes uploads fail.
      attachment-cache-dir = "";

      # iOS only receives instant pushes for self-hosted servers if the server
      # forwards a poll request to ntfy.sh, which then wakes the app via APNS.
      # Only a hash of the topic leaves this box - never the message - but it
      # is still traffic to a third party, so it is opt-in rather than default.
      # upstream-base-url = "https://ntfy.sh";
    };
  };

  services.nginx.virtualHosts."ntfy.nox.onl" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:2586";
      proxyWebsockets = true;
      extraConfig = ''
        # Subscribers hold a connection open indefinitely and expect to be
        # streamed to. Buffering or a normal 60s read timeout would break
        # exactly the case this server exists for.
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_redirect off;
        proxy_connect_timeout 3m;
        proxy_send_timeout 3m;
        proxy_read_timeout 3m;
      '';
    };
  };
}
