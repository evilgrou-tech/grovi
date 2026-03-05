# ПРОСТЕЙШИЙ ТЕСТ
$testFile = "$env:TEMP\simple_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
"Скрипт запущен" | Out-File $testFile
