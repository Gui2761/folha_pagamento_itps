$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open('C:\Users\Guilh\folha_pagamento_itps\01 JANEIRO - 2026.xlsx')
$sheetBC = $workbook.Sheets.Item("Cadastro de BC - Servidores")

$row = 49
Write-Host "DATA FOR ROW $row (Antonio Carlos Porto de Andrade):"
for ($col = 1; $col -le 40; $col++) {
    $val = $sheetBC.Cells.Item($row, $col).Value2
    $header = $sheetBC.Cells.Item(1, $col).Value2
    Write-Host "Col $col ($header): $val"
}

$workbook.Close($false)
$excel.Quit()
