{
  inputs,
  ...
}:

{
  nixpkgs.overlays = [
    inputs.claude-code.overlays.default
  ];
}
