# Run script as Administrator
$runAsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $runAsAdmin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = [System.Environment]::GetCommandLineArgs()
    Start-Process powershell -ArgumentList $args -Verb runAs
    exit
}

# Remove Desktop Shortcuts with Exceptions
function Remove-DesktopShortcuts {
    $DeleteShortcuts = $true
    $ExcludedShortcuts = @("desktop.ini","This PC.lnk","Recycle Bin.lnk")

    if (-not $DeleteShortcuts) { return }

    Get-ChildItem 'C:\Users' -Directory | ForEach-Object {
        $desktopPath = Join-Path $_.FullName 'Desktop'
        if (Test-Path $desktopPath) {
            Get-ChildItem "$desktopPath\*.lnk" -ErrorAction SilentlyContinue |
                Where-Object { $ExcludedShortcuts -notcontains $_.Name } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}
Remove-DesktopShortcuts

# Apply Theme Based on Current 
function Apply-ThemeBasedOnTime {
    $currentHour = (Get-Date).Hour
    $themePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

    if ($currentHour -ge 6 -and $currentHour -lt 18) {
        Set-ItemProperty -Path $themePath -Name AppsUseLightTheme -Value 1
        Set-ItemProperty -Path $themePath -Name SystemUsesLightTheme -Value 1
    } else {
        Set-ItemProperty -Path $themePath -Name AppsUseLightTheme -Value 0
        Set-ItemProperty -Path $themePath -Name SystemUsesLightTheme -Value 0
    }

    Set-ItemProperty -Path $themePath -Name AutoColorization -Value 1
}
Apply-ThemeBasedOnTime


# Download Wallpaper
function Download-Wallpaper {
    param(
        [string]$WallpaperURL = "https://microsoft.design/wp-content/uploads/2025/07/Brand-Flowers-Static-1.png"
    )

    $PicturesPath = "C:\Users\Public\Pictures"
    $WallpaperPath = "$PicturesPath\wallpaper.png"

    if (-not (Test-Path $PicturesPath)) {
        New-Item -ItemType Directory -Path $PicturesPath | Out-Null
    }

    try {
        Invoke-WebRequest -Uri $WallpaperURL -OutFile $WallpaperPath -ErrorAction Stop
        Write-Host "Wallpaper downloaded successfully."
    } catch {
        Write-Warning "Failed to download wallpaper. Please check your internet connection."
    }

    return $WallpaperPath
}

# Example: pass a custom wallpaper URL
$WallpaperPath = Download-Wallpaper -WallpaperURL "https://microsoft.design/wp-content/uploads/2025/07/Brand-Flowers-Static-1.png"

# Restart Explorer
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe

# Set Wallpaper
function Set-Wallpaper {
    param([string]$WallpaperPath)

    if (Test-Path $WallpaperPath) {
        Add-Type @'
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
        [Wallpaper]::SystemParametersInfo(20, 0, $WallpaperPath, 3) | Out-Null
    }
}

Set-Wallpaper -WallpaperPath $WallpaperPath


# Install Microsoft Store Apps via Winget
function Install-StoreApps {
    param(
        [string[]]$AppList = @('XP89DCGQ3K6VLD','9PDXGNCFSCZV')
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return }

    winget source update

    function Install-App {
        param([string]$appID)
        $installed = Get-AppxPackage | Where-Object { $_.PackageFamilyName -like "*$appID*" }
        if ($installed) { return }

        try {
            winget install --id=$appID --source=msstore --silent --accept-package-agreements --accept-source-agreements
        } catch {}
    }

    foreach ($app in $AppList) {
        Install-App -appID $app
    }
}

# Example: pass a custom app list
$CustomApps = @('XP89DCGQ3K6VLD','9PDXGNCFSCZV') 
Install-StoreApps -AppList $CustomApps
