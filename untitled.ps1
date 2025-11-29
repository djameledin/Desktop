# Check if the script is running as Administrator
$runAsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $runAsAdmin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = [System.Environment]::GetCommandLineArgs()
    Start-Process powershell -ArgumentList $args -Verb runAs
    exit
}

# Remove shortcut files (.lnk) from Desktop for all users
Get-ChildItem 'C:\Users' -Directory | ForEach-Object {
    $desktopPath = Join-Path $_.FullName 'Desktop'
    if (Test-Path $desktopPath) {
        Get-ChildItem "$desktopPath\*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# Ensure the 'Pictures' directory exists
$picturesPath = "C:\Users\Public\Pictures"
if (-not (Test-Path $picturesPath)) {
    try {
        New-Item -ItemType Directory -Path $picturesPath | Out-Null
        Write-Host "Pictures directory created."
    } catch {
        Write-Host "Failed to create Pictures directory. Check your permissions."
        exit
    }
}

# Download the wallpaper image if it doesn't exist
$wallpaperPath = "$picturesPath\wallpaper.jpg"
if (-not (Test-Path $wallpaperPath)) {
    try {
        # Attempt to download the wallpaper image
        Invoke-WebRequest 'https://microsoft.design/wp-content/uploads/2025/07/Brand-Flowers-Static-1.png' -OutFile $wallpaperPath -ErrorAction Stop
        Write-Host "Wallpaper downloaded successfully."
    } catch {
        Write-Host "Failed to download the wallpaper. Please check the URL or your network connection."
        exit
    }
}

# Verify if the wallpaper exists now
if (Test-Path $wallpaperPath) {
    Write-Host "The wallpaper file exists at: $wallpaperPath"
} else {
    Write-Host "Failed to verify that the wallpaper was downloaded."
    exit
}

# Set the downloaded image as wallpaper
Add-Type @'
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
$setWallpaperResult = [Wallpaper]::SystemParametersInfo(20, 0, $wallpaperPath, 3)

# Verify wallpaper change result
if ($setWallpaperResult) {
    Write-Host "Wallpaper set successfully."
} else {
    Write-Host "Failed to set the wallpaper."
}

# Set the theme based on the current hour
$currentHour = (Get-Date).Hour
$themePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

if ($currentHour -ge 6 -and $currentHour -lt 18) {
    Set-ItemProperty -Path $themePath -Name AppsUseLightTheme -Value 1
    Set-ItemProperty -Path $themePath -Name SystemUsesLightTheme -Value 1
    Set-ItemProperty -Path $themePath -Name EnableTransparency -Value 1
    Write-Host "Light theme applied."
} else {
    Set-ItemProperty -Path $themePath -Name AppsUseLightTheme -Value 0
    Set-ItemProperty -Path $themePath -Name SystemUsesLightTheme -Value 0
    Set-ItemProperty -Path $themePath -Name EnableTransparency -Value 1
    Write-Host "Dark theme applied."
}

# Restart Explorer to apply changes
Write-Host "Restarting Explorer..."
Start-Sleep -Milliseconds 300
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
Write-Host "Explorer restarted successfully."

# Add the names of applications you want to KEEP
$Exclusions = @(
    "Microsoft Edge",
    "Windows Terminal",
    "Microsoft .NET",
    "Windows",
    "NVIDIA",
    "Intel",
    "Realtek",
    "Microsoft OneDrive",
    "Microsoft Store"
)

# Get all installed apps using winget
$allApps = winget list | Select-String "^\S" | ForEach-Object {
    ($_ -split '\s{2,}')[0]
}

# Filter apps that are NOT in the exclusion list
$appsToRemove = $allApps | Where-Object {
    $app = $_
    -not ($Exclusions | ForEach-Object { $app -like "*$_*" })
}

Write-Host "The following apps will be removed automatically:" -ForegroundColor Yellow
$appsToRemove | ForEach-Object { Write-Host " - $_" }

# Auto uninstall without confirmation
foreach ($app in $appsToRemove) {
    Write-Host "Uninstalling: $app" -ForegroundColor Red
    winget uninstall --exact --silent --name "$app"
}

Write-Host "Uninstallation process completed." -ForegroundColor Green


winget source update
$appList = @('XP89DCGQ3K6VLD', '9P8LTPGCBZXD', '9NV4BS3L1H4S', '9PDXGNCFSCZV')
function Install-App {
    param([string]$appID)

    $isInstalled = Get-AppxPackage | Where-Object { $_.PackageFamilyName -like "*$appID*" }

    if ($isInstalled) {
        Write-Host "$appID is already installed."
        return
    }

    try {
        Write-Host "Installing $appID ..."
        winget install --id=$appID --source=msstore --silent --accept-package-agreements --accept-source-agreements
        Write-Host "$appID installed successfully."
    }
    catch {
        Write-Host "Failed to install $appID."
    }
}
foreach ($app in $appList) {
    Install-App -appID $app
}
