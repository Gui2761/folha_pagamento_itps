$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open('C:\Users\Guilh\folha_pagamento_itps\01 JANEIRO - 2026.xlsx')
foreach ($s in $workbook.Sheets) { Write-Host $s.Name }
$workbook.Close($false)
$excel.Quit()
