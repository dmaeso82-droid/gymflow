$Root = "C:\Users\dmaes\gymflow"
$Dest = "C:\Users\dmaes\gymflow\temp"

Write-Host ""
Write-Host "Escribe nombres de archivo."
Write-Host "Ejemplo:"
Write-Host "chat_service"
Write-Host "trainer_home_page"
Write-Host ""
Write-Host "FIN para terminar."
Write-Host ""

$names = @()

while ($true)
{
    $name = Read-Host "Archivo"

    if ($name.Trim().ToUpper() -eq "FIN")
    {
        break
    }

    if ($name.Trim() -ne "")
    {
        $names += $name.Trim()
    }
}

foreach ($name in $names)
{
    $match = Get-ChildItem $Root -Recurse -Filter "$name.dart" | Select-Object -First 1

    if ($match)
    {
        Copy-Item `
            $match.FullName `
            (Join-Path $Dest "$name.txt") `
            -Force

        Write-Host "[OK] $name.txt" -ForegroundColor Green
    }
    else
    {
        Write-Host "[ERROR] $name.dart no encontrado" -ForegroundColor Red
    }
}