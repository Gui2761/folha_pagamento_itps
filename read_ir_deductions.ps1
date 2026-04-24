$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open('C:\Users\Guilh\folha_pagamento_itps\01 JANEIRO - 2026.xlsx')
$sheet = $workbook.Sheets.Item("Tabelas INSS e IR")

Write-Host "--- SHEET: Tabelas INSS e IR (Col 7-10) ---"
for ($row = 3; $row -le 10; $row++) {
    $line = ""
    for ($col = 7; $col -le 11; $col++) {
        $val = $sheet.Cells.Item($row, $col).Value2
        $line += "$val | "
    }
    Write-Host $line
}

$workbook.Close($false)
$excel.Quit()
