$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open('C:\Users\Guilh\folha_pagamento_itps\01 JANEIRO - 2026.xlsx')

$searchName = "Antonio Carlos"

foreach ($sheet in $workbook.Sheets) {
    # Write-Host "Searching in sheet: $($sheet.Name)"
    for ($row = 1; $row -le 300; $row++) {
        for ($col = 1; $col -le 10; $col++) {
            $val = $sheet.Cells.Item($row, $col).Value2
            if ($val -and "$val" -match $searchName) {
                Write-Host ("FOUND in " + $sheet.Name + " Row " + $row + " Col " + $col + ": " + $val)
                if ($sheet.Name -eq "Cadastro de BC - Servidores") {
                    Write-Host ("VINCULO: " + $sheet.Cells.Item($row, 9).Value2)
                    Write-Host ("PERCENTUAL: " + $sheet.Cells.Item($row, 12).Value2)
                    Write-Host ("SIPES_INSS: " + $sheet.Cells.Item($row, 18).Value2)
                    Write-Host ("INSS_DEVIDO: " + $sheet.Cells.Item($row, 20).Value2)
                    Write-Host ("IRRF_DEVIDO: " + $sheet.Cells.Item($row, 29).Value2)
                    Write-Host ("TEM_INSS: " + $sheet.Cells.Item($row, 10).Value2)
                    Write-Host ("TEM_IRRF: " + $sheet.Cells.Item($row, 11).Value2)
                }
            }
        }
    }
}

$workbook.Close($false)
$excel.Quit()
