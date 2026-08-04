# Quaesitum

Small Hetzner VPS running searxng and ntfy.sh.

## ntfy

`services/ntfy.nix` runs [ntfy](https://ntfy.sh) on `https://ntfy.nox.onl`

### Provisioning

Users, ACLs and tokens are declared in `hosts/quaesitum/secrets/ntfy.env`.

```bash
# Generating password hash
nix run nixpkgs#ntfy-sh -- user hash

# Generating a token
nix run nixpkgs#ntfy-sh -- token generate
```

## searxng

`services/searxng.nix` and `services/ngingx.nix`, serving `sx.nox.onl` with
`s.nox.onl` redirecting to it. Secrets in `secrets/searxng.env` and
`secrets/searxng-secret`.
