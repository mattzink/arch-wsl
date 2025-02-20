![ConsolePic](arch-wsl.jpg)

# Arch Linux on WSL
Poweshell script I use to build an Arch Linux WSL 2 distribution from scratch.

Configures:
- Latest minimal Arch kernel-less distro
- System locale
- Non-root user with password-less sudo
- systemd
- yay package manager with package caching disabled
- fastfetch w/ sixel logo (Requires Windows Terminal to see)
- oh-my-posh BASH prompt

## Usage

1. Ensure WSL is configured correctly
    - Use the latest WSL version (`wsl --update`)
    - For systemd to work correctly, legacy [cgroups v1 must be disabled ](https://github.com/spurin/wsl-cgroupsv2/blob/main/README.md)
    - Use the newer `Mirrored` networking mode (Not `NAT`) to access WSL services across your LAN

    Therefore, the contents of your `$HOME/.wslconfig` file should include:
    ```ini
    [wsl2]
    kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
    networkingMode=mirrored
    ```

2. For proper glyph support, configure your terminal to use a [Nerd Font](https://www.nerdfonts.com/font-downloads). I like `CaskaydiaCove Nerd Font`.

2. Unzip the [archive file](https://github.com/mattzink/arch-wsl/archive/refs/heads/main.zip) from this repo

3. From a Powershell prompt, run `create-arch-distro.ps1` (see [the script](create-arch-distro.ps1) for all supported parameters)

    ```pwsh
    .\create-arch-distro.ps1 -DistroName myarch -Force
    ```

4. If successfull, then you should be able run the distro

    ```pwsh
    wsl -d myarch
    ```
