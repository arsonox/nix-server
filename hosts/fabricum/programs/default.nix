{
  lib,
  pkgs,
  ...
}:

{
  imports = builtins.filter (lib.strings.hasSuffix ".nix") (
    map toString (builtins.filter (p: p != ./default.nix) (lib.filesystem.listFilesRecursive ./.))
  );

  environment.systemPackages = with pkgs; [
    nil
    nixfmt
    nixd
    package-version-server
    claude-code
    claude-code-router
    claude-code-acp
  ];
}
