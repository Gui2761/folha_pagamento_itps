$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open('C:\Users\Guilh\folha_pagamento_itps\01 JANEIRO - 2026.xlsx')
$sheetBC = $workbook.Sheets.Item("Cadastro de BC - Servidores")

$searchName = "Antonio Carlos Porto"
$found = $false

for ($row = 1; $row -le 300; $row++) {
    $name = $sheetBC.Cells.Item($row, 4).Value2
    if ($name -match $searchName) {
        $percentual = $sheetBC.Cells.Item($row, 12).Value2
        $sipesInss = $sheetBC.Cells.Item($row, 18).Value2
        $sipesIr = $sheetBC.Cells.Item($row, 28).Value2
        $inssDevido = $sheetBC.Cells.Item($row, 20).Value2
        $irrfDevido = $sheetBC.Cells.Item($row, 29).Value2
        $temInss = $sheetBC.Cells.Item($row, 10).Value2
        $temIrrf = $sheetBC.Cells.Item($row, 11).Value2
        $vinculo = $sheetBC.Cells.Item($row, 9).Value2
        
        Write-Host "FOUND: $name"
        Write-Host "ROW: $row"
        Write-Host "VINCULO: $vinculo"
        Write-Host "PERCENTUAL: $percentual"
        Write-Host "SIPES_INSS: $sipesInss"
        Write-Host "SIPES_IR: $sipesIr"
        Write-Host "INSS_DEVIDO: $inssDevido"
        Write-Host "IRRF_DEVIDO: $irrfDevido"
        Write-Host "TEM_INSS: $temInss"
        Write-Host "TEM_IRRF: $temIrrf"
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Host "Antonio Carlos Porto not found in first 100 rows."
}

$workbook.Close($false)
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
