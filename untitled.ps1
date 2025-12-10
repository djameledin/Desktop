# 1) Ensure script is running as Administrator
$admin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb runAs -ArgumentList $PSCommandPath
    exit
}

# 2) Apply Theme (Light/Dark) only if needed
function Apply-Theme {
    $currentHour = (Get-Date).Hour
    $themePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

    # Determine required theme based on time
    $requiredTheme = if ($currentHour -ge 6 -and $currentHour -lt 18) { 1 } else { 0 }

    # Get current system theme
    $currentTheme = (Get-ItemProperty -Path $themePath -Name AppsUseLightTheme).AppsUseLightTheme

    if ($currentTheme -eq $requiredTheme) {
        if ($requiredTheme -eq 1) { Write-Host "[THEME] Light mode already active. Skipping." }
        else { Write-Host "[THEME] Dark mode already active. Skipping." }
        return
    }

    # Apply theme change
    Set-ItemProperty -Path $themePath -Name AppsUseLightTheme -Value $requiredTheme
    Set-ItemProperty -Path $themePath -Name SystemUsesLightTheme -Value $requiredTheme

    if ($requiredTheme -eq 1) { Write-Host "[THEME] Switched to Light mode." }
    else { Write-Host "[THEME] Switched to Dark mode." }
}

# 3) Clean Desktop with exclusions
function Clean-Desktop {
    $Excluded = @("desktop.ini","This PC.lnk","Recycle Bin.lnk")
    $users = Get-ChildItem "C:\Users" -Directory

    foreach ($u in $users) {
        $desk = "$($u.FullName)\Desktop"
        if (Test-Path $desk) {
            $items = Get-ChildItem $desk -File
            if ($items.Count -eq 0) {
                Write-Host "[DESKTOP] No items to clean for $($u.Name). Skipping."
                continue
            }

            $toDelete = $items | Where-Object { $Excluded -notcontains $_.Name }
            if ($toDelete.Count -gt 0) {
                Write-Host "[DESKTOP] Cleaning $($u.Name) desktop..."
                $toDelete | Remove-Item -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host "[DESKTOP] All items excluded. Nothing removed."
            }
        }
    }
}

# 4) Download Wallpaper
function Download-Wallpaper {
    param([string]$URL, [string]$Path)

    if (Test-Path $Path) {
        Write-Host "[WALLPAPER] Already exists. Skipping download."
        return
    }

    try {
        Invoke-WebRequest -Uri $URL -OutFile $Path -ErrorAction Stop
        Write-Host "[WALLPAPER] Downloaded successfully."
    } catch {
        Write-Warning "[WALLPAPER] Failed to download."
    }
}

# 5) Set Wallpaper
function Set-Wallpaper {
    param([string]$ImagePath)

    if (-not (Test-Path $ImagePath)) {
        Write-Warning "[WALLPAPER] Image not found. Cannot apply."
        return
    }

    Add-Type @"
    using System.Runtime.InteropServices;
    public class WP {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@

    [WP]::SystemParametersInfo(20, 0, $ImagePath, 3) | Out-Null
    Write-Host "[WALLPAPER] Applied successfully."
}

# 7) Main Execution
$wallURL  = "https://microsoft.design/wp-content/uploads/2025/07/Brand-Flowers-Static-1.png"
$wallPath = "C:\Users\Public\Pictures\wallpaper.png"

Apply-Theme
Clean-Desktop
Download-Wallpaper -URL $wallURL -Path $wallPath

# Step 4: Restart Explorer
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe

Set-Wallpaper -ImagePath $wallPath

Write-Host "`n All tasks completed successfully with smart checks."
