{
  lib,
  ...
}:

{
  imports = builtins.filter (lib.strings.hasSuffix ".nix") (
    map toString (builtins.filter (p: p != ./default.nix) (lib.filesystem.listFilesRecursive ./.))
  );
}
