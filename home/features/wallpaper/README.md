# Generated wallpapers

[`images.nix`](images.nix) builds the desktop and lock-screen images with
[lunik1/nix-wallpaper](https://github.com/lunik1/nix-wallpaper). The generator
source is pinned in `flake.lock` and uses the system's Nixpkgs packages.

Both images use the palette in [`home/theme.nix`](../../theme.nix) and a logo size of 44.25% of the
image height. The desktop uses six accent colors; the lock screen alternates
`blue` and `blueDim`.

## Resolution

The shared default is **1920 × 1080 (Full HD)**. A new host can omit
`wallpaperResolution` entirely and both images will use that default.

A host can optionally set `home-manager.extraSpecialArgs.wallpaperResolution`
to use another size. The laptop uses the shared default without an override.
For example, a host that needs a sharper image on a 4K monitor can set:

```nix
home-manager.extraSpecialArgs.wallpaperResolution = {
  width = 3840;
  height = 2160;
};
```

Only add this override when a host needs another size. The shared generator
then creates both images at that size. Builds also work on another machine or
without a display; the build does not inspect connected monitors.

[`default.nix`](default.nix) sends the generated desktop image to swaybg and the lock-screen
image to swaylock. PNG files are build outputs in the Nix store, not repository
assets. The existing session services manage displaying and locking.

## Build an image

Run either command from the repository root. These aliases use the laptop host's configuration:

```bash
nix build .#wallpaper-desktop --out-link /tmp/nix-wallpaper-desktop
nix build .#wallpaper-lockscreen --out-link /tmp/nix-wallpaper-lockscreen
```

Each output contains `share/wallpapers/nixos-wallpaper.png`.

## Attribution

The generator code is licensed under the
[BSD-2-Clause Plus Patent License](https://github.com/lunik1/nix-wallpaper/blob/master/LICENSE).
The NixOS logo by Simon Frankau, Tim Cuthbertson, and Daniel Baker, maintained
by the NixOS Marketing Team, comes from
[nixos/branding](https://github.com/NixOS/branding) and is licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

See the [configuration notes](../../../docs/README.md) for general usage and maintenance.
