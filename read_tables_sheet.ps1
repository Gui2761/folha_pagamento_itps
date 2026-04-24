$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open('C:\Users\Guilh\folha_pagamento_itps\01 JANEIRO - 2026.xlsx')
$sheet = $workbook.Sheets.Item("Tabelas INSS e IR")

Write-Host "--- SHEET: Tabelas INSS e IR ---"
for ($row = 1; $row -le 20; $row++) {
    $line = ""
    for ($col = 1; $col -le 10; $col++) {
        $val = $sheet.Cells.Item($row, $col).Value2
        $line += "$val | "
    }
    Write-Host $line
}

$workbook.Close($false)
$excel.Quit()
