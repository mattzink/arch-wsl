param(
    [string]$DistroName = "arch",
    [string]$UserName = $ENV:UserName.ToLowerInvariant(),
    [string]$WslInstallDir = "$HOME\wsl-disks",
    [switch]$Force,
    [string]$DockerfileUrl = "https://gitlab.archlinux.org/archlinux/archlinux-docker/-/raw/releases/Dockerfile.base?ref_type=heads",
    [string]$RootFsFilename = "arch-rootfs.tar.zst",    
    [string]$LogoFilename = "archlinux-icon-36x18.sixel"
)

$ErrorActionPreference = "Stop"

function FailOnError {
    param (
        [scriptblock]$block
    )
    try {
        $global:LASTEXITCODE = 0
        Invoke-Command -ScriptBlock $block
        if ($LASTEXITCODE -ne 0) {
            throw "Exit code $LASTEXITCODE"
        }
    } catch {
        $blockString = $ExecutionContext.InvokeCommand.ExpandString($block)
        Write-Error "Command '$blockString' failed: $_"
    }
}

function RunWslCommand {
    param (
        [string]$command
    )
    FailOnError { wsl -d $DistroName --cd ~ -- /bin/bash -c "$command" }
}

# Download RootFS image if a local cached version doesn't exist
$rootFsPath = "$PSScriptRoot\$RootFsFilename"
if (!(Test-Path -Path $rootFsPath)) {
    # Parse the Dockerfile contents to find the URL of the latest rootfs.tar.zst file
    $dockerfile = Invoke-WebRequest -Uri "$DockerfileUrl"
    if (!($dockerfile -imatch 'https://gitlab\.archlinux\.org/api/.*\.tar\.zst')) {
        Write-Error "No RootFS URL found in Dockerfile"
    }
    $rootFsUrl = $matches[0]
    Write-Host "Downloading RootFS image '$rootFsUrl' to '$rootFsPath'" -ForegroundColor Yellow
    Invoke-WebRequest -Uri "$rootFsUrl" -OutFile "$rootFsPath"
}

# Check if the distro already exists
$wslDistroExists = [bool](wsl --list --quiet | Where-Object {$_.Replace("`0","") -match "^$DistroName`$"})
if ($wslDistroExists) {
    if ($Force) {
        Write-Host "Removing existing WSL distro '$DistroName'" -ForegroundColor Yellow
        FailOnError { wsl --unregister $DistroName }
    }
    else {
        Write-Error "WSL distro '$DistroName' already exists, use '-Force' to replace it"
    }
}

$wslDistroDir = "$WslInstallDir\$DistroName"
Write-Host "Creating new WSL distro '$DistroName' in '$wslDistroDir'" -ForegroundColor Yellow
FailOnError { wsl --import $DistroName "$wslDistroDir" "$rootFsPath" --version 2 }

$UserName = $UserName -replace '[^-a-zA-Z0-9]', '-' -replace '--+', '-'
Write-Host "Creating user '$UserName' and setting up environment..." -ForegroundColor Yellow
RunWslCommand "echo `"LANG=C.UTF-8`" >> /etc/default/locale"
RunWslCommand "sed -i 's/#Color/Color/' /etc/pacman.conf"
RunWslCommand "sed -i 's/NoProgressBar/#NoProgressBar/' /etc/pacman.conf"
RunWslCommand "mkdir /etc/pacman.d/hooks"
RunWslCommand "echo `"[Trigger]`nOperation = Upgrade`nOperation = Install`nOperation = Remove`nType = Package`nTarget = *`n`n[Action]`nDescription = Cleaning pacman cache...`nWhen = PostTransaction`nExec = /usr/bin/bash -c 'rm -f /var/cache/pacman/pkg/*'`" > /etc/pacman.d/hooks/clean_package_cache.hook" 
RunWslCommand "pacman-key --init && pacman-key --populate"
RunWslCommand "pacman -Syyuu --noconfirm"
RunWslCommand "pacman -S --noconfirm sudo"
RunWslCommand "useradd -m -G wheel $UserName"
RunWslCommand "sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers"
RunWslCommand "touch /etc/machine-id"
RunWslCommand "echo `"[boot]`nsystemd=true`n`n[user]`ndefault=$UserName`n`n[network]`nhostname=$DistroName`n`n[interop]`nenabled=false`nappendWindowsPath=false`" >> /etc/wsl.conf"
FailOnError { wsl --terminate $DistroName }

# Everything below this point runs as non-root user and with systemd running

Write-Host "Installing yay package manager..." -ForegroundColor Yellow
RunWslCommand "sudo pacman -S --noconfirm glibc base-devel git"
RunWslCommand "sudo sed -i 's/ debug lto/ !debug lto/' /etc/makepkg.conf"
RunWslCommand "(git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -sirc --noconfirm); rm -rf yay"

Write-Host "Installing utilities..." -ForegroundColor Yellow
RunWslCommand "yay -S --removemake --answerclean A --noconfirm oh-my-posh-bin fastfetch vim"
RunWslCommand "sudo cp ``wslpath -a `"$PSScriptRoot/$LogoFilename`"`` /usr/share/fastfetch/arch.sixel"
RunWslCommand "fastfetch --raw /usr/share/fastfetch/arch.sixel --logo-width 35 --logo-height 18 --logo-padding-top 2 --gen-config"
RunWslCommand "echo '`neval `"\`$(oh-my-posh init bash --config /usr/share/oh-my-posh/themes/tiwahu.omp.json)`"`nfastfetch' >> .bash_profile"
RunWslCommand "sudo ln -s /usr/bin/vim /usr/bin/vi"

Write-Host "Cleaning up files..." -ForegroundColor Yellow
RunWslCommand "yay -Scc --noconfirm"
RunWslCommand "sudo rm -rf ~/.cache/go-build ~/.config/go"
