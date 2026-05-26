import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class GeradorPdf {
  static final NumberFormat _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // --- VIA INDIVIDUAL DE HOLERITE (2 VIAS POR PÁGINA) ---
  static Future<void> gerarEImprimirHolerite(
    Map<String, dynamic> colaborador,
    Map<String, dynamic> calc,
    String mesAno,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildVia(colaborador, calc, mesAno, "VIA DO COLABORADOR"),
              pw.SizedBox(height: 15),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                child: pw.Row(
                  children: List.generate(
                    40,
                    (index) => pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                        child: pw.Divider(color: PdfColors.grey, height: 1, thickness: 1),
                      ),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 15),
              buildVia(colaborador, calc, mesAno, "VIA DO ITPS (ARQUIVO RH)"),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Holerite_${colaborador['nome']}_$mesAno.pdf',
    );
  }

  static pw.Widget buildVia(
    Map<String, dynamic> colab,
    Map<String, dynamic> calc,
    String mesAno,
    String tituloVia,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ITPS - INSTITUTO DE TECNOLOGIA E PESQUISA DE SERGIPE',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                  pw.Text(
                    'CNPJ: 13.128.798/0001-00',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'RECIBO DE PAGAMENTO - CONVÊNIO',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                  pw.Text(
                    'Mês de Referência: $mesAno',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue800),
                  ),
                ],
              ),
            ],
          pw.Divider(thickness: 1, color: PdfColors.black),
          // Informações do Colaborador
          pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: _buildInfoItem("Colaborador", colab['nome'] ?? ''),
              ),
              pw.Expanded(
                flex: 1.2,
                child: _buildInfoItem("CPF", colab['cpf'] ?? ''),
              ),
              pw.Expanded(
                flex: 1.2,
                child: _buildInfoItem("Previdência", (calc['previdencia_rpps'] == true) ? "RPPS" : "RGPS (INSS)"),
              ),
              pw.Expanded(
                flex: 1.2,
                child: _buildInfoItem("Vínculo", colab['vinculo'] ?? ''),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: _buildInfoItem("Cargo", colab['cargo_nome'] ?? ''),
              ),
              pw.Expanded(
                flex: 2,
                child: _buildInfoItem("Lotação / Setor", colab['locacao'] ?? ''),
              ),
              pw.Expanded(
                flex: 2.2,
                child: _buildInfoItem("Banco", "${colab['banco'] ?? ''} Ag: ${colab['agencia'] ?? ''} C/C: ${colab['conta'] ?? ''}"),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Tabela de Proventos e Descontos
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
            },
            children: [
              // Cabeçalho da Tabela
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Cód.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Descrição da Rubrica', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Proventos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Descontos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              // Vencimento do Convênio (Bruto)
              _buildTableRow(
                '101', 
                'Valor Bruto do Convênio (${colab['percentual'] ?? 0}%)' + 
                    ((calc['dias_trabalhados'] ?? 30) < 30 ? ' - Proporcional ${calc['dias_trabalhados']} dias' : ''),
                _moeda.format(calc['bruto'] ?? 0.0), 
                ''
              ),
              // Desconto INSS / RPPS
              if ((calc['inss'] ?? 0.0) > 0.0)
                _buildTableRow(
                  '201', 
                  (calc['previdencia_rpps'] == true) ? 'Previdência Própria (RPPS 14%)' : 'Desconto INSS (Enc. Convênio)', 
                  '', 
                  _moeda.format(calc['inss'])
                ),
              // Desconto IRRF
              if ((calc['irrf'] ?? 0.0) > 0.0)
                _buildTableRow('202', 'Desconto IRRF (Enc. Convênio)', '', _moeda.format(calc['irrf'])),
              // Desconto Pensão
              if ((calc['pensao'] ?? 0.0) > 0.0)
                _buildTableRow('203', 'Pensão Alimentícia', '', _moeda.format(calc['pensao'])),
              // Desconto Outros
              if ((calc['outros'] ?? 0.0) > 0.0)
                _buildTableRow('204', 'Outros Descontos', '', _moeda.format(calc['outros'])),
              // Acréscimos
              if ((calc['acrescimos'] ?? 0.0) > 0.0)
                _buildTableRow('102', 'Acréscimos / Adicionais', _moeda.format(calc['acrescimos']), ''),
            ],
          ),

          // Rodapé do Recibo (Totalizadores e Assinatura)
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Base Global Bruta: ${_moeda.format(calc['base_global_bruta'] ?? 0.0)}', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Base IRRF: ${_moeda.format(calc['base_irrf'] ?? 0.0)}', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Salário SIPES: ${_moeda.format(calc['sipes'] ?? 0.0)}', style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total de Proventos', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        pw.Text(_moeda.format((calc['bruto'] ?? 0.0) + (calc['acrescimos'] ?? 0.0)), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total de Descontos', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        pw.Text(
                          _moeda.format(
                            (calc['inss'] ?? 0.0) +
                            (calc['irrf'] ?? 0.0) +
                            (calc['pensao'] ?? 0.0) +
                            (calc['outros'] ?? 0.0)
                          ),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('LÍQUIDO A RECEBER', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text(_moeda.format(calc['liquido'] ?? 0.0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue900)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Declaro ter recebido a importância líquida discriminada neste recibo.',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
              pw.Column(
                children: [
                  pw.Container(width: 150, child: pw.Divider(thickness: 0.5, color: PdfColors.black, height: 1)),
                  pw.SizedBox(height: 2),
                  pw.Text('Assinatura do Colaborador', style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Gerado em: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              ),
              pw.Text(
                tituloVia,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(right: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.TableRow _buildTableRow(String cod, String desc, String prov, String descVal) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(cod, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(desc, style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(prov, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(descVal, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  // --- RELATÓRIO CONSOLIDADO DA FOLHA (PDF) ---
  static Future<void> gerarERelatorioConsolidado(
    List<Map<String, dynamic>> colaboradores,
    List<Map<String, dynamic>> calculos,
    String mesAno,
  ) async {
    final pdf = pw.Document();

    // Calcular totais
    double totalBruto = 0.0;
    double totalInss = 0.0;
    double totalIrrf = 0.0;
    double totalPensao = 0.0;
    double totalOutros = 0.0;
    double totalAcrescimos = 0.0;
    double totalLiquido = 0.0;

    for (var c in calculos) {
      totalBruto += c['bruto'] ?? 0.0;
      totalInss += c['inss'] ?? 0.0;
      totalIrrf += c['irrf'] ?? 0.0;
      totalPensao += c['pensao'] ?? 0.0;
      totalOutros += c['outros'] ?? 0.0;
      totalAcrescimos += c['acrescimos'] ?? 0.0;
      totalLiquido += c['liquido'] ?? 0.0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ITPS - INSTITUTO DE TECNOLOGIA E PESQUISA DE SERGIPE',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                      pw.Text('COORDENADORIA DE RECURSOS HUMANOS - CRH', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RESUMO DA FOLHA DO CONVÊNIO',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.Text('Referência: $mesAno', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue800)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, color: PdfColors.black),
              pw.SizedBox(height: 5),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text('ITPS Folha Automação - Gerado em: ${DateTime.now().toLocal().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5), // Seq
                1: const pw.FlexColumnWidth(2.5), // Nome
                2: const pw.FlexColumnWidth(1.2), // CPF
                3: const pw.FlexColumnWidth(1.5), // Cargo
                4: const pw.FlexColumnWidth(1), // Setor
                5: const pw.FlexColumnWidth(0.8), // Bruto
                6: const pw.FlexColumnWidth(0.8), // INSS
                7: const pw.FlexColumnWidth(0.8), // IRRF
                8: const pw.FlexColumnWidth(0.8), // Pensão
                9: const pw.FlexColumnWidth(0.8), // Outros
                10: const pw.FlexColumnWidth(0.8), // Acres
                11: const pw.FlexColumnWidth(1), // Liquido
              },
              children: [
                // Linha de Cabeçalho
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    _buildHeaderCell('#'),
                    _buildHeaderCell('Colaborador', align: pw.TextAlign.left),
                    _buildHeaderCell('CPF'),
                    _buildHeaderCell('Cargo'),
                    _buildHeaderCell('Lotação'),
                    _buildHeaderCell('Bruto'),
                    _buildHeaderCell('Prev.'),
                    _buildHeaderCell('IRRF'),
                    _buildHeaderCell('Pensão'),
                    _buildHeaderCell('Outros'),
                    _buildHeaderCell('Acrésc.'),
                    _buildHeaderCell('Líquido'),
                  ],
                ),
                // Linhas de Colaboradores
                for (int i = 0; i < colaboradores.length; i++)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      _buildCell('${i + 1}'),
                      _buildCell(colaboradores[i]['nome'] ?? '', align: pw.TextAlign.left),
                      _buildCell(colaboradores[i]['cpf'] ?? ''),
                      _buildCell(colaboradores[i]['cargo_nome'] ?? '', align: pw.TextAlign.left),
                      _buildCell(colaboradores[i]['locacao'] ?? '', align: pw.TextAlign.left),
                      _buildCell(_moeda.format(calculos[i]['bruto'] ?? 0.0), align: pw.TextAlign.right),
                      _buildCell(_moeda.format(calculos[i]['inss'] ?? 0.0), align: pw.TextAlign.right),
                      _buildCell(_moeda.format(calculos[i]['irrf'] ?? 0.0), align: pw.TextAlign.right),
                      _buildCell(_moeda.format(calculos[i]['pensao'] ?? 0.0), align: pw.TextAlign.right),
                      _buildCell(_moeda.format(calculos[i]['outros'] ?? 0.0), align: pw.TextAlign.right),
                      _buildCell(_moeda.format(calculos[i]['acrescimos'] ?? 0.0), align: pw.TextAlign.right),
                      _buildCell(_moeda.format(calculos[i]['liquido'] ?? 0.0), align: pw.TextAlign.right, bold: true),
                    ],
                  ),
                // Linha de Total Geral
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildCell('', bold: true),
                    _buildCell('TOTAL GERAL', align: pw.TextAlign.left, bold: true),
                    _buildCell('', bold: true),
                    _buildCell('', bold: true),
                    _buildCell('', bold: true),
                    _buildCell(_moeda.format(totalBruto), align: pw.TextAlign.right, bold: true),
                    _buildCell(_moeda.format(totalInss), align: pw.TextAlign.right, bold: true),
                    _buildCell(_moeda.format(totalIrrf), align: pw.TextAlign.right, bold: true),
                    _buildCell(_moeda.format(totalPensao), align: pw.TextAlign.right, bold: true),
                    _buildCell(_moeda.format(totalOutros), align: pw.TextAlign.right, bold: true),
                    _buildCell(_moeda.format(totalAcrescimos), align: pw.TextAlign.right, bold: true),
                    _buildCell(_moeda.format(totalLiquido), align: pw.TextAlign.right, bold: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 200, child: pw.Divider(thickness: 0.5, color: PdfColors.black)),
                    pw.SizedBox(height: 2),
                    pw.Text('Coordenadoria de Recursos Humanos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text('ITPS', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 200, child: pw.Divider(thickness: 0.5, color: PdfColors.black)),
                    pw.SizedBox(height: 2),
                    pw.Text('Diretoria Administrativa e Financeira', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text('ITPS', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_Folha_Convenio_$mesAno.pdf',
    );
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildCell(String text, {pw.TextAlign align = pw.TextAlign.center, bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 7.5,
          color: color,
        ),
        textAlign: align,
      ),
    );
  }
}
