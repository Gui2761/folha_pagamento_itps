import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:excel/excel.dart' hide Border; 
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'calculadora_taxas.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema Folha ITPS',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          secondary: const Color(0xFF00695C),
          surface: const Color(0xFFF5F7FA),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(const Color(0xFF0D47A1).withValues(alpha: 0.6)),
          thickness: WidgetStateProperty.all(10), 
          radius: const Radius.circular(10),
          thumbVisibility: WidgetStateProperty.all(true), 
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
          prefixIconColor: const Color(0xFF0D47A1),
          labelStyle: TextStyle(color: Colors.grey[700]),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _configData;
  List<Map<String, dynamic>> _funcionarios = [];
  List<Map<String, dynamic>> _cargos = [];
  bool _isLoading = true;
  int? _editingId;

  // Controllers de Scroll
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _rgCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  final _agenciaCtrl = TextEditingController();
  final _contaCtrl = TextEditingController();
  final _cargoManualCtrl = TextEditingController();
  final _locacaoCtrl = TextEditingController();
  final _percentualCtrl = TextEditingController();
  
  final _sipesCtrl = TextEditingController(); 
  final _pensaoCtrl = TextEditingController();
  final _outrosCtrl = TextEditingController();
  
  String _vinculoSelecionado = 'Efetivo';
  int? _selectedCargoId;
  bool _temInss = false;
  bool _temIrrf = true;

  final _money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _refreshTudo();
  }

  Future<void> _refreshTudo() async {
    setState(() => _isLoading = true);
    final configs = await DatabaseHelper.instance.loadFullConfig();
    final funcs = await DatabaseHelper.instance.readFuncionarios();
    final cargos = await DatabaseHelper.instance.readCargos();
    setState(() {
      _configData = configs;
      _funcionarios = funcs;
      _cargos = cargos;
      _isLoading = false;
    });
  }

  Future<void> _salvarOuAtualizar() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> dados = {
        'nome': _nomeCtrl.text,
        'cpf': _cpfCtrl.text,
        'rg': _rgCtrl.text,
        'vinculo': _vinculoSelecionado,
        'banco': _bancoCtrl.text,
        'agencia': _agenciaCtrl.text,
        'conta': _contaCtrl.text,
        'cargo_nome': _cargoManualCtrl.text,
        'locacao': _locacaoCtrl.text,
        'percentual': double.tryParse(_percentualCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'valor_sipes': _parseMoeda(_sipesCtrl.text),
        'pensao': _parseMoeda(_pensaoCtrl.text),
        'outros': _parseMoeda(_outrosCtrl.text),
        'tem_inss': _temInss ? 1 : 0,
        'tem_irrf': _temIrrf ? 1 : 0,
      };

      if (_editingId == null) {
        await DatabaseHelper.instance.createFuncionario(dados);
        if (mounted) _mostrarSnack("Funcionário cadastrado!", Colors.green);
      } else {
        dados['id'] = _editingId!;
        await DatabaseHelper.instance.updateFuncionario(dados);
        if (mounted) _mostrarSnack("Dados atualizados!", Colors.blue);
      }
      _limparForm();
      _refreshTudo();
    }
  }

  double _parseMoeda(String text) {
    String limpa = text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(limpa) ?? 0.0;
  }
  
  String _formatMoeda(double valor) {
    return _money.format(valor);
  }

  void _carregarParaEdicao(Map<String, dynamic> f) {
    setState(() {
      _editingId = f['id'];
      _nomeCtrl.text = f['nome'];
      _cpfCtrl.text = f['cpf'];
      _rgCtrl.text = f['rg'] ?? '';
      _vinculoSelecionado = f['vinculo'] ?? 'Efetivo';
      _bancoCtrl.text = f['banco'] ?? '';
      _agenciaCtrl.text = f['agencia'] ?? '';
      _contaCtrl.text = f['conta'] ?? '';
      _cargoManualCtrl.text = f['cargo_nome'] ?? '';
      _locacaoCtrl.text = f['locacao'] ?? '';
      _percentualCtrl.text = f['percentual'].toString();
      _sipesCtrl.text = _formatMoeda(f['valor_sipes']);
      _pensaoCtrl.text = _formatMoeda(f['pensao'] ?? 0.0);
      _outrosCtrl.text = _formatMoeda(f['outros'] ?? 0.0);
      _temInss = f['tem_inss'] == 1;
      _temIrrf = f['tem_irrf'] == 1;
      _selectedCargoId = null; 
    });
  }

  void _limparForm() {
    _nomeCtrl.clear(); _cpfCtrl.clear(); _rgCtrl.clear(); _bancoCtrl.clear();
    _agenciaCtrl.clear(); _contaCtrl.clear(); _percentualCtrl.clear();
    _cargoManualCtrl.clear(); _locacaoCtrl.clear(); 
    _sipesCtrl.clear(); _pensaoCtrl.clear(); _outrosCtrl.clear();
    setState(() {
      _editingId = null; _selectedCargoId = null; _vinculoSelecionado = 'Efetivo';
      _temInss = false; _temIrrf = true;
    });
  }

  void _onVinculoChanged(String? novoVinculo) {
    if (novoVinculo == null) return;
    setState(() {
      _vinculoSelecionado = novoVinculo;
      if (novoVinculo == 'Efetivo') _temInss = false;
      else _temInss = true;
      _temIrrf = true;
    });
  }

  void _onCargoChanged(int? novoId) {
    setState(() {
      _selectedCargoId = novoId;
    });
    if (novoId != null) {
      final cargo = _cargos.firstWhere((c) => c['id'] == novoId);
      String nomeCompleto = cargo['nome'];
      if (nomeCompleto.contains(" - ")) {
        final partes = nomeCompleto.split(" - ");
        _cargoManualCtrl.text = partes[0].trim();
        _locacaoCtrl.text = partes.sublist(1).join(" - ").trim();
      } else {
        _cargoManualCtrl.text = nomeCompleto;
        _locacaoCtrl.text = "";
      }
      _percentualCtrl.text = cargo['percentual_padrao'].toString();
    }
  }

  void _mostrarSnack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }

  // === GERADOR DE EXCEL ===
  Future<void> _exportarExcel() async {
    if (_funcionarios.isEmpty) {
      _mostrarSnack("Não há dados para exportar.", Colors.red);
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Folha ITPS'];
    excel.delete('Sheet1'); 

    CellStyle headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    List<String> headers = [
      'Nome', 'Vínculo', 'CPF', 'RG', 'Banco', 'Agência', 'Conta', 
      'Cargo', 'Locação', 'SIPES', '%', 'Bruto', 'INSS', 'IRRF', 
      'Pensão', 'Outros', 'Líquido'
    ];

    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    double totalBruto = 0;
    double totalLiquido = 0;

    for (var f in _funcionarios) {
      final calc = CalculadoraTaxas.calcularFolha(
        percentual: f['percentual'],
        valorSipes: f['valor_sipes'],
        pensao: f['pensao'] ?? 0.0,
        outros: f['outros'] ?? 0.0,
        temInss: f['tem_inss'] == 1,
        temIrrf: f['tem_irrf'] == 1,
        configData: _configData!,
      );

      totalBruto += calc['bruto'];
      totalLiquido += calc['liquido'];

      sheetObject.appendRow([
        TextCellValue(f['nome']),
        TextCellValue(f['vinculo'] ?? ''),
        TextCellValue(f['cpf'] ?? ''),
        TextCellValue(f['rg'] ?? ''),
        TextCellValue(f['banco'] ?? ''),
        TextCellValue(f['agencia'] ?? ''),
        TextCellValue(f['conta'] ?? ''),
        TextCellValue(f['cargo_nome'] ?? ''),
        TextCellValue(f['locacao'] ?? ''),
        DoubleCellValue(f['valor_sipes']),
        DoubleCellValue(f['percentual']),
        DoubleCellValue(calc['bruto']),
        DoubleCellValue(calc['inss']),
        DoubleCellValue(calc['irrf']),
        DoubleCellValue(f['pensao'] ?? 0.0),
        DoubleCellValue(f['outros'] ?? 0.0),
        DoubleCellValue(calc['liquido']),
      ]);
    }

    sheetObject.appendRow([
      TextCellValue('TOTAIS'),
      TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''),
      TextCellValue(''), TextCellValue(''),
      DoubleCellValue(totalBruto),
      TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''),
      DoubleCellValue(totalLiquido),
    ]);

    final String fileName = "folha_itps_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.xlsx";
    final FileSaveLocation? result = await getSaveLocation(suggestedName: fileName);
    
    if (result != null) {
      final List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        final File file = File(result.path);
        await file.writeAsBytes(fileBytes);
        if (mounted) _mostrarSnack("Arquivo Excel salvo com sucesso!", Colors.green);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    double totalBrutoGeral = 0;
    double baseAtual = _configData!['geral']['base_convenio'] ?? 210000.00;
    double aliquotaPatronal = _configData!['geral']['aliquota_patronal'] ?? 0.0;

    final List<DataRow> rows = [];
    
    for (var f in _funcionarios) {
      final calc = CalculadoraTaxas.calcularFolha(
        percentual: f['percentual'],
        valorSipes: f['valor_sipes'],
        pensao: f['pensao'] ?? 0.0,
        outros: f['outros'] ?? 0.0,
        temInss: f['tem_inss'] == 1,
        temIrrf: f['tem_irrf'] == 1,
        configData: _configData!,
      );

      totalBrutoGeral += calc['bruto'];

      rows.add(DataRow(cells: [
        DataCell(Row(children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade200, 
            radius: 12, 
            child: Text(f['nome'].isNotEmpty ? f['nome'][0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
          ),
          const SizedBox(width: 8),
          Text(f['nome'], style: const TextStyle(fontWeight: FontWeight.w600)),
        ])),
        DataCell(Text(f['cpf'] ?? '-', style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
        DataCell(Text(f['rg'] ?? '-', style: const TextStyle(color: Colors.grey))),
        DataCell(Text(f['banco'] ?? '-')),
        DataCell(Text(f['agencia'] ?? '-')),
        DataCell(Text(f['conta'] ?? '-')),
        DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(f['cargo_nome'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(f['locacao'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ])),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: f['vinculo'] == 'Efetivo' ? Colors.blue[50] : (f['vinculo'] == 'Comissionado' ? Colors.green[50] : Colors.orange[50]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: f['vinculo'] == 'Efetivo' ? Colors.blue.shade200 : (f['vinculo'] == 'Comissionado' ? Colors.green.shade200 : Colors.orange.shade200))
          ),
          child: Text(f['vinculo'] ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        )),
        DataCell(Text(_money.format(f['valor_sipes']), style: const TextStyle(color: Colors.grey))),
        DataCell(Text("${f['percentual']}%", style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(_money.format(calc['bruto']), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(f['tem_inss'] == 1 ? _money.format(calc['inss']) : "-", style: TextStyle(color: Colors.red[700]))),
        DataCell(Text(f['tem_irrf'] == 1 ? _money.format(calc['irrf']) : "-", style: TextStyle(color: Colors.red[700]))),
        DataCell(Text(_money.format(f['pensao'] ?? 0), style: TextStyle(color: Colors.orange[800]))), 
        DataCell(Text(_money.format(f['outros'] ?? 0), style: TextStyle(color: Colors.orange[800]))), 
        DataCell(Text(_money.format(calc['liquido']), style: const TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.w900))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), onPressed: () => _carregarParaEdicao(f), tooltip: "Editar"),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () async {
              await DatabaseHelper.instance.deleteFuncionario(f['id']);
              _refreshTudo();
            }, tooltip: "Remover"),
          ],
        )),
      ]));
    }

    double valorPatronal = totalBrutoGeral * (aliquotaPatronal / 100);
    double totalRetirada = totalBrutoGeral + valorPatronal;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 2,
        // --- LOGO REMOVIDA, VOLTANDO AO ÍCONE PADRÃO ---
        title: const Row(children: [
          Icon(Icons.table_chart, size: 28), 
          SizedBox(width: 10), 
          Text('Sistema Folha ITPS', style: TextStyle(fontWeight: FontWeight.bold))
        ]),
        // -----------------------------------------------
        backgroundColor: const Color(0xFF0D47A1), 
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilledButton.icon(
              onPressed: _exportarExcel,
              icon: const Icon(Icons.file_download, size: 18),
              label: const Text("Exportar Excel"),
              style: FilledButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConfigScreen(data: _configData!, onSave: _refreshTudo))),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text("Config."),
              style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), foregroundColor: Colors.white),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // DASHBOARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoCard("Base de Cálculo", baseAtual, Icons.account_balance, Colors.grey),
                _buildInfoCard("Total Bruto", totalBrutoGeral, Icons.attach_money, Colors.blue),
                _buildInfoCard("Empregador + RAT", valorPatronal, Icons.business, Colors.orange),
                _buildInfoCard("Retirada Total", totalRetirada, Icons.account_balance_wallet, Colors.green, isBold: true),
              ],
            ),
          ),

          // CONTEUDO PRINCIPAL
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch, 
              children: [
                // ESQUERDA: FORM
                Container(
                  width: 380,
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(bottom: 16),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_editingId != null ? "Editar" : "Novo Cadastro", 
                                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _editingId != null ? Colors.orange[800] : const Color(0xFF0D47A1))),
                                  if (_editingId != null) 
                                    IconButton(icon: const Icon(Icons.close), onPressed: _limparForm, tooltip: "Cancelar Edição")
                                ],
                              ),
                            ),
                            
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.only(top: 16),
                                children: [
                                  TextFormField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome Completo", prefixIcon: Icon(Icons.person)), validator: (v)=>v!.isEmpty?'Obrigatório':null),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(child: TextFormField(
                                      controller: _cpfCtrl, 
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [CpfInputFormatter()],
                                      decoration: const InputDecoration(labelText: "CPF", prefixIcon: Icon(Icons.badge), hintText: "000.000.000-00")
                                    )),
                                    const SizedBox(width: 8),
                                    Expanded(child: TextFormField(controller: _rgCtrl, decoration: const InputDecoration(labelText: "RG"))),
                                  ]),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _vinculoSelecionado,
                                    decoration: const InputDecoration(labelText: "Vínculo", prefixIcon: Icon(Icons.work)),
                                    items: ['Efetivo', 'Comissionado', 'Cedido'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                    onChanged: _onVinculoChanged,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(controller: _bancoCtrl, decoration: const InputDecoration(labelText: "Banco", prefixIcon: Icon(Icons.account_balance))),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(child: TextFormField(controller: _agenciaCtrl, decoration: const InputDecoration(labelText: "Agência"))),
                                    const SizedBox(width: 8),
                                    Expanded(child: TextFormField(controller: _contaCtrl, decoration: const InputDecoration(labelText: "Conta"))),
                                  ]),
                                  
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                                  
                                  DropdownButtonFormField<int>(
                                    value: _selectedCargoId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: "Selecionar Cargo (Lista)", prefixIcon: Icon(Icons.list_alt)),
                                    items: _cargos.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text("${c['nome']}", overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: _onCargoChanged,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(controller: _cargoManualCtrl, decoration: const InputDecoration(labelText: "Nome do Cargo")),
                                  const SizedBox(height: 12),
                                  TextFormField(controller: _locacaoCtrl, decoration: const InputDecoration(labelText: "Locação / Setor")),
                                  
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                                  const Text("Valores & Descontos", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 8),

                                  Row(
                                    children: [
                                      Expanded(child: TextFormField(controller: _percentualCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "%", suffixText: "%", prefixIcon: Icon(Icons.percent)))),
                                      const SizedBox(width: 8),
                                      Expanded(child: TextFormField(
                                        controller: _sipesCtrl, 
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [CurrencyInputFormatter()],
                                        decoration: const InputDecoration(labelText: "SIPES")
                                      )),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: TextFormField(
                                        controller: _pensaoCtrl, 
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [CurrencyInputFormatter()],
                                        decoration: const InputDecoration(labelText: "Pensão")
                                      )),
                                      const SizedBox(width: 8),
                                      Expanded(child: TextFormField(
                                        controller: _outrosCtrl, 
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [CurrencyInputFormatter()],
                                        decoration: const InputDecoration(labelText: "Outros")
                                      )),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                    child: Column(
                                      children: [
                                        CheckboxListTile(title: const Text("Descontar INSS"), secondary: const Icon(Icons.account_circle), value: _temInss, onChanged: (v)=>setState(()=>_temInss=v!), activeColor: const Color(0xFF0D47A1)),
                                        const Divider(height: 1),
                                        CheckboxListTile(title: const Text("Descontar IRRF"), secondary: const Icon(Icons.request_quote), value: _temIrrf, onChanged: (v)=>setState(()=>_temIrrf=v!), activeColor: const Color(0xFF0D47A1)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _salvarOuAtualizar, 
                                icon: Icon(_editingId != null ? Icons.save : Icons.add_circle),
                                label: Text(_editingId != null ? "SALVAR ALTERAÇÕES" : "ADICIONAR FUNCIONÁRIO"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _editingId != null ? Colors.orange[800] : const Color(0xFF0D47A1), 
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                ), 
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // DIREITA: TABELA (Scrollbar Fixo Embaixo)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                    child: Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              border: Border(bottom: BorderSide(color: Colors.black12))
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people_alt, color: Colors.grey),
                                const SizedBox(width: 10),
                                Text("Lista de Funcionários (${rows.length})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          
                          // MÁGICA: O Scrollbar Horizontal envolve tudo
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Scrollbar(
                                  controller: _horizontalScroll,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScroll,
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight, 
                                        minWidth: 1500, // Largura forçada para ativar scroll
                                      ),
                                      child: Scrollbar(
                                        controller: _verticalScroll,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _verticalScroll,
                                          scrollDirection: Axis.vertical,
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                                            dataRowColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                                              if (states.contains(WidgetState.selected)) return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
                                              return null;
                                            }),
                                            columnSpacing: 24,
                                            horizontalMargin: 20,
                                            columns: const [
                                              DataColumn(label: Text("NOME", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("CPF", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("RG", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("BANCO", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("AGÊNCIA", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("CONTA", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("CARGO / LOCAÇÃO", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("VÍNCULO", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("SIPES", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("%", style: TextStyle(fontWeight: FontWeight.bold))), 
                                              DataColumn(label: Text("BRUTO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))), 
                                              DataColumn(label: Text("INSS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))), 
                                              DataColumn(label: Text("IRRF", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))), 
                                              DataColumn(label: Text("PENSÃO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))), 
                                              DataColumn(label: Text("OUTROS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))), 
                                              DataColumn(label: Text("LÍQUIDO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))), 
                                              DataColumn(label: Text("AÇÕES", style: TextStyle(fontWeight: FontWeight.bold))),
                                            ],
                                            rows: rows,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, double value, IconData icon, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                _money.format(value), 
                style: TextStyle(
                  fontSize: isBold ? 22 : 18, 
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: color
                )
              )
            ],
          ),
        ],
      ),
    );
  }
}

// CLASSES DE FORMATAÇÃO (MÁSCARAS)
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    double value = double.parse(newValue.text.replaceAll(RegExp('[^0-9]'), ''));
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    String newText = formatter.format(value / 100);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 11) text = text.substring(0, 11);
    var newText = "";
    for (var i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) newText += ".";
      if (i == 9) newText += "-";
      newText += text[i];
    }
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}

// ==========================================
// TELA DE CONFIGURAÇÕES (COM EDIÇÃO)
// ==========================================
class ConfigScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSave;
  const ConfigScreen({super.key, required this.data, required this.onSave});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _baseCtrl;
  late TextEditingController _tetoInssCtrl;
  late TextEditingController _patronalCtrl;
  List<Map<String, dynamic>> _cargosLocais = [];
  List<Map<String, dynamic>> _tabelaInss = [];
  List<Map<String, dynamic>> _tabelaIrrf = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarDados();
  }

  void _carregarDados() async {
    final configs = await DatabaseHelper.instance.loadFullConfig();
    final cargos = await DatabaseHelper.instance.readCargos();
    
    double base = configs['geral']['base_convenio'] ?? 210000.00;
    double teto = configs['geral']['teto_inss'] ?? 8475.55;
    double patronal = configs['geral']['aliquota_patronal'] ?? 9.02;

    setState(() {
      _baseCtrl = TextEditingController(text: base.toString());
      _tetoInssCtrl = TextEditingController(text: teto.toString());
      _patronalCtrl = TextEditingController(text: patronal.toString());
      _cargosLocais = List.from(cargos);
      _tabelaInss = List.from(configs['inss']);
      _tabelaIrrf = List.from(configs['irrf']);
    });
  }

  Future<void> _salvarGeral() async {
    await DatabaseHelper.instance.updateConfigValor('base_convenio', double.parse(_baseCtrl.text));
    await DatabaseHelper.instance.updateConfigValor('teto_inss', double.parse(_tetoInssCtrl.text));
    await DatabaseHelper.instance.updateConfigValor('aliquota_patronal', double.parse(_patronalCtrl.text));
    if (!mounted) return;
    widget.onSave();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configurações salvas!")));
  }

  Future<void> _editarFaixaInss(Map<String, dynamic> item) async {
    final limiteCtrl = TextEditingController(text: item['limite'].toString());
    final aliquotaCtrl = TextEditingController(text: item['aliquota'].toString());
    
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Editar Faixa INSS"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: limiteCtrl, decoration: const InputDecoration(labelText: "Limite (R\$)")),
        const SizedBox(height: 10),
        TextField(controller: aliquotaCtrl, decoration: const InputDecoration(labelText: "Alíquota (%)")),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
        TextButton(onPressed: () async {
          await DatabaseHelper.instance.updateTabelaInss(
            item['id'], 
            double.tryParse(limiteCtrl.text) ?? 0.0, 
            double.tryParse(aliquotaCtrl.text) ?? 0.0
          );
          if (mounted) Navigator.pop(ctx);
          _carregarDados();
          widget.onSave();
        }, child: const Text("Salvar"))
      ],
    ));
  }

  Future<void> _editarFaixaIrrf(Map<String, dynamic> item) async {
    final limiteCtrl = TextEditingController(text: item['limite'].toString());
    final aliquotaCtrl = TextEditingController(text: item['aliquota'].toString());
    final deducaoCtrl = TextEditingController(text: item['deducao'].toString());
    
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Editar Faixa IRRF"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: limiteCtrl, decoration: const InputDecoration(labelText: "Limite (R\$)")),
        const SizedBox(height: 10),
        TextField(controller: aliquotaCtrl, decoration: const InputDecoration(labelText: "Alíquota (%)")),
        const SizedBox(height: 10),
        TextField(controller: deducaoCtrl, decoration: const InputDecoration(labelText: "Dedução (R\$)")),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
        TextButton(onPressed: () async {
          await DatabaseHelper.instance.updateTabelaIrrf(
            item['id'], 
            double.tryParse(limiteCtrl.text) ?? 0.0, 
            double.tryParse(aliquotaCtrl.text) ?? 0.0,
            double.tryParse(deducaoCtrl.text) ?? 0.0
          );
          if (mounted) Navigator.pop(ctx);
          _carregarDados();
          widget.onSave();
        }, child: const Text("Salvar"))
      ],
    ));
  }

  Future<void> _adicionarCargo() async {
    final nomeCtrl = TextEditingController();
    final percCtrl = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Novo Cargo"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Nome")), TextField(controller: percCtrl, decoration: const InputDecoration(labelText: "%"), keyboardType: TextInputType.number)]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")), TextButton(onPressed: () async { await DatabaseHelper.instance.createCargo({'nome': nomeCtrl.text, 'percentual_padrao': double.tryParse(percCtrl.text) ?? 0.0}); if(mounted) Navigator.pop(ctx); _carregarDados(); widget.onSave(); }, child: const Text("Salvar"))],
    ));
  }

  Future<void> _deletarCargo(int id) async { await DatabaseHelper.instance.deleteCargo(id); _carregarDados(); widget.onSave(); }

  @override
  Widget build(BuildContext context) {
    if (_tabelaInss.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Configurações do Sistema"), bottom: TabBar(controller: _tabController, tabs: const [Tab(text: "Geral"), Tab(text: "Tabelas"), Tab(text: "Cargos")])),
      body: TabBarView(controller: _tabController, children: [
          ListView(padding: const EdgeInsets.all(20), children: [const Text("Valores Base", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 10), TextField(controller: _baseCtrl, decoration: const InputDecoration(labelText: "Valor Base Convênio (R\$)", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _tetoInssCtrl, decoration: const InputDecoration(labelText: "Teto Máximo INSS (R\$)", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _patronalCtrl, decoration: const InputDecoration(labelText: "Alíquota Patronal/RAT (%)", border: OutlineInputBorder())), const SizedBox(height: 20), ElevatedButton(onPressed: _salvarGeral, child: const Text("SALVAR ALTERAÇÕES"))]),
          ListView(padding: const EdgeInsets.all(20), children: [
            const Text("Tabela INSS", style: TextStyle(fontWeight: FontWeight.bold)), 
            ..._tabelaInss.map((r) => ListTile(
                title: Text("Até R\$ ${r['limite']}"), 
                subtitle: Text("${r['aliquota']}%"),
                trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editarFaixaInss(r))
            )), 
            const Divider(), 
            const Text("Tabela IRRF", style: TextStyle(fontWeight: FontWeight.bold)), 
            ..._tabelaIrrf.map((r) => ListTile(
                title: Text("Até R\$ ${r['limite']}"), 
                subtitle: Text("${r['aliquota']}% (Ded: ${r['deducao']})"),
                trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editarFaixaIrrf(r))
            ))
          ]),
          Column(children: [Padding(padding: const EdgeInsets.all(10.0), child: ElevatedButton.icon(onPressed: _adicionarCargo, icon: const Icon(Icons.add), label: const Text("Adicionar Novo Cargo"))), Expanded(child: ListView.builder(itemCount: _cargosLocais.length, itemBuilder: (ctx, i) { final c = _cargosLocais[i]; return ListTile(title: Text(c['nome']), subtitle: Text("Percentual Padrão: ${c['percentual_padrao']}%"), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deletarCargo(c['id']))); }))])
      ]),
    );
  }
}