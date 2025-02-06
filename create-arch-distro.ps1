param(
    [string]$DistroName = "arch",
    [string]$UserName = "mattzink",
    [string]$WslInstallDir = "$HOME\wsl-disks",
    [switch]$Force,
    # Find RootFS in Dockerfile: https://gitlab.archlinux.org/archlinux/archlinux-docker/-/blob/releases/Dockerfile.base?ref_type=heads
    [string]$RootFsUrl = "https://gitlab.archlinux.org/api/v4/projects/10185/packages/generic/rootfs/20250204.0.304931/base-20250204.0.304931.tar.zst",
    [string]$RootFsFilename = "arch-rootfs.tar.zst",    
    [string]$LogoFilename = "archlinux-icon-36x18.sixel"
)

# Download RootFS image if it doesn't exist
$rootFsPath = "$PSScriptRoot\$RootFsFilename"
if (!(Test-Path -Path $rootFsPath)) {
    Write-Host "Downloading RootFS image to '$rootFsPath'" -ForegroundColor Yellow
    Invoke-WebRequest -Uri $RootFsUrl -OutFile "$rootFsPath"
}

$wslDistroExists = [bool](wsl --list --quiet | Where-Object {$_.Replace("`0","") -match "^$DistroName`$"})
if ($wslDistroExists -and $Force) {
    Write-Host "Removing existing WSL distro '$DistroName'" -ForegroundColor Yellow
    wsl --unregister $DistroName
}

$wslDistroDir = "$WslInstallDir\$DistroName"
Write-Host "Creating new WSL distro '$DistroName' in '$wslDistroDir'" -ForegroundColor Yellow
wsl --import $DistroName "$wslDistroDir" "$rootFsPath" --version 2

Write-Host "Creating user '$UserName' and setting up environment..." -ForegroundColor Yellow
wsl -d $DistroName -- bash -c "echo `"LANG=C.UTF-8`" >> /etc/default/locale"
wsl -d $DistroName -- bash -c "sed -i 's/#Color/Color/' /etc/pacman.conf"
wsl -d $DistroName -- bash -c "sed -i 's/NoProgressBar/#NoProgressBar/' /etc/pacman.conf"
wsl -d $DistroName -- bash -c "pacman -Syyuu --noconfirm"
wsl -d $DistroName -- bash -c "pacman -S --noconfirm sudo"
wsl -d $DistroName -- bash -c "useradd -m -G wheel $UserName"
wsl -d $DistroName -- bash -c "sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers"
wsl -d $DistroName -- bash -c "touch /etc/machine-id"
wsl -d $DistroName -- bash -c "echo `"[boot]`nsystemd=true`n`n[user]`ndefault=$UserName`n`n[network]`nhostname=$DistroName`n`n[interop]`nenabled=false`nappendWindowsPath=false`" >> /etc/wsl.conf"
wsl --terminate $DistroName

Write-Host "Installing yay..." -ForegroundColor Yellow
wsl -d $DistroName --cd ~ -- bash -c "sudo pacman -S --noconfirm glibc base-devel git"
wsl -d $DistroName --cd ~ -- bash -c "sudo sed -i 's/ debug lto/ !debug lto/' /etc/makepkg.conf"
wsl -d $DistroName --cd ~ -- bash -c "(git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -sirc --noconfirm); rm -rf yay"

Write-Host "Installing utilities..." -ForegroundColor Yellow
wsl -d $DistroName --cd ~ -- bash -c "yay -S --removemake --answerclean A --noconfirm oh-my-posh-bin fastfetch vim"
wsl -d $DistroName --cd ~ -- bash -c "sudo cp ``wslpath -a `"$PSScriptRoot/$LogoFilename`"`` /usr/share/fastfetch/arch.sixel"
wsl -d $DistroName --cd ~ -- bash -c "fastfetch --raw /usr/share/fastfetch/arch.sixel --logo-width 35 --logo-height 18 --logo-padding-top 2 --gen-config"
wsl -d $DistroName --cd ~ -- bash -c "echo '`neval `"\`$(oh-my-posh init bash --config /usr/share/oh-my-posh/themes/tiwahu.omp.json)`"`nfastfetch' >> .bash_profile"
wsl -d $DistroName --cd ~ -- bash -c "sudo ln -s /usr/sbin/vim /usr/sbin/vi"

wsl -d $DistroName --cd ~ -- bash -c "yay -Sc --noconfirm && sudo rm -f /var/cache/pacman/pkg/*"
