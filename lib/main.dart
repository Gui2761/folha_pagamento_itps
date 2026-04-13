import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:excel/excel.dart' as excel_pkg; 
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'calculadora_taxas.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
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

  final _formKey = GlobalKey<FormState>();
  
  // Controllers
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
  final _acrescimosCtrl = TextEditingController(); 
  
  // Scrolls
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();
  
  String _vinculoSelecionado = 'Efetivo';
  int? _selectedCargoId;
  bool _temInss = false;
  bool _temIrrf = true;

  // Variável para controlar a visibilidade do formulário
  bool _mostrarFormulario = false;

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

  // === SALVAR ===
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
        'acrescimos': _parseMoeda(_acrescimosCtrl.text), 
        'tem_inss': _temInss ? 1 : 0,
        'tem_irrf': _temIrrf ? 1 : 0,
      };

      if (_editingId == null) {
        await DatabaseHelper.instance.createFuncionario(dados);
        if (mounted) _mostrarSnack("Colaborador cadastrado!", Colors.green);
      } else {
        dados['id'] = _editingId!;
        await DatabaseHelper.instance.updateFuncionario(dados);
        if (mounted) _mostrarSnack("Dados atualizados!", Colors.blue);
      }
      _limparForm();
      setState(() => _mostrarFormulario = false); // Fecha o form ao salvar
      _refreshTudo();
    }
  }

  double _parseMoeda(String text) {
    String limpa = text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(limpa) ?? 0.0;
  }
  
  String _formatMoeda(double? valor) {
    if (valor == null) return "R\$ 0,00";
    return _money.format(valor);
  }

  void _carregarParaEdicao(Map<String, dynamic> f) {
    setState(() {
      _mostrarFormulario = true; // Abre o formulário ao editar
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
      _acrescimosCtrl.text = _formatMoeda(f['acrescimos'] ?? 0.0);
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
    _acrescimosCtrl.clear();
    setState(() {
      _editingId = null; _selectedCargoId = null; _vinculoSelecionado = 'Efetivo';
      _temInss = false; _temIrrf = true;
    });
  }

  void _onVinculoChanged(String? novoVinculo) {
    if (novoVinculo == null) return;
    setState(() {
      _vinculoSelecionado = novoVinculo;
      if (novoVinculo == 'Efetivo') {
        _temInss = false;
        _temIrrf = true;
      } else if (novoVinculo == 'Estagiário') {
        _temInss = false;
        _temIrrf = false;
      } else {
        _temInss = true;
        _temIrrf = true;
      }
    });
  }

  void _onCargoChanged(int? novoId) {
    setState(() {
      _selectedCargoId = novoId;
    });
    if (novoId != null) {
      final cargo = _cargos.firstWhere((c) => c['id'] == novoId);
      _cargoManualCtrl.text = cargo['nome'];

      if (cargo['locacao'] != null && cargo['locacao'].toString().isNotEmpty) {
        _locacaoCtrl.text = cargo['locacao'];
      } else {
        _locacaoCtrl.text = "";
      }
      _percentualCtrl.text = cargo['percentual_padrao'].toString();
    }
  }

  void _mostrarSnack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }

  // === EXPORTAR EXCEL ===
  Future<void> _exportarExcel() async {
    if (_funcionarios.isEmpty) {
      _mostrarSnack("Não há dados para exportar.", Colors.red);
      return;
    }

    var excel = excel_pkg.Excel.createExcel();
    excel.delete('Sheet1'); 

    excel_pkg.CellStyle styleHeaderResumo = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.blue,
      fontColorHex: excel_pkg.ExcelColor.white,
      bold: true,
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
    );

    excel_pkg.CellStyle styleHeaderLista = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString("#EEEEEE"),
      bold: true,
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
    );

    excel_pkg.Sheet sheetResumo = excel['Resumo Gerencial'];
    List<String> headersResumo = ['CATEGORIA', 'BRUTO', 'INSS', 'IRRF', 'PENSÃO', 'OUTROS', 'TOTAL DESC.', 'ACRÉSCIMOS', 'LÍQUIDO'];
    sheetResumo.appendRow(headersResumo.map((e) => excel_pkg.TextCellValue(e)).toList());
    
    for(int i=0; i<headersResumo.length; i++) {
      sheetResumo.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = styleHeaderResumo;
    }

    List<String> categorias = ['Efetivo', 'Comissionado', 'Cedido', 'Estagiário'];
    double gBruto=0, gInss=0, gIrrf=0, gPensao=0, gOutros=0, gDesc=0, gAcres=0, gLiquido=0;

    for (var cat in categorias) {
      var lista = _funcionarios.where((f) => f['vinculo'] == cat).toList();
      double tBruto=0, tInss=0, tIrrf=0, tPensao=0, tOutros=0, tAcres=0, tLiquido=0;

      for (var f in lista) {
        final calc = CalculadoraTaxas.calcularFolha(
          percentual: f['percentual'], valorSipes: f['valor_sipes'], pensao: f['pensao'] ?? 0,
          outros: f['outros'] ?? 0, acrescimos: f['acrescimos'] ?? 0.0, temInss: f['tem_inss'] == 1, temIrrf: f['tem_irrf'] == 1,
          configData: _configData!,
        );
        tBruto += calc['bruto'] ?? 0.0; tInss += calc['inss'] ?? 0.0; tIrrf += calc['irrf'] ?? 0.0;
        tPensao += f['pensao'] ?? 0; tOutros += f['outros'] ?? 0; tAcres += f['acrescimos'] ?? 0; tLiquido += calc['liquido'] ?? 0.0;
      }
      
      double tDescontos = tInss + tIrrf + tPensao + tOutros;
      gBruto+=tBruto; gInss+=tInss; gIrrf+=tIrrf; gPensao+=tPensao; gOutros+=tOutros; gDesc+=tDescontos; gAcres+=tAcres; gLiquido+=tLiquido;

      sheetResumo.appendRow([
        excel_pkg.TextCellValue(cat.toUpperCase()),
        excel_pkg.DoubleCellValue(tBruto), excel_pkg.DoubleCellValue(tInss), excel_pkg.DoubleCellValue(tIrrf),
        excel_pkg.DoubleCellValue(tPensao), excel_pkg.DoubleCellValue(tOutros),
        excel_pkg.DoubleCellValue(tDescontos), excel_pkg.DoubleCellValue(tAcres), excel_pkg.DoubleCellValue(tLiquido)
      ]);
    }

    sheetResumo.appendRow([
      excel_pkg.TextCellValue('TOTAL GERAL'),
      excel_pkg.DoubleCellValue(gBruto), excel_pkg.DoubleCellValue(gInss), excel_pkg.DoubleCellValue(gIrrf),
      excel_pkg.DoubleCellValue(gPensao), excel_pkg.DoubleCellValue(gOutros),
      excel_pkg.DoubleCellValue(gDesc), excel_pkg.DoubleCellValue(gAcres), excel_pkg.DoubleCellValue(gLiquido)
    ]);

    for (var cat in categorias) {
      var lista = _funcionarios.where((f) => f['vinculo'] == cat).toList();
      if (lista.isNotEmpty) {
        excel_pkg.Sheet sheetCat = excel['Lista $cat'];
        List<String> headersDet = ['NOME COMPLETO', 'CPF', 'RG', 'BANCO', 'AGÊNCIA', 'CONTA', 'CARGO', 'LOCAÇÃO', 'SIPES', '%', 'BRUTO', 'INSS', 'IRRF', 'PENSÃO', 'OUTROS', 'ACRÉSCIMOS', 'LÍQUIDO'];
        sheetCat.appendRow(headersDet.map((e) => excel_pkg.TextCellValue(e)).toList());

        for(int i=0; i<headersDet.length; i++) {
          sheetCat.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = styleHeaderLista;
        }

        for (var f in lista) {
           final calc = CalculadoraTaxas.calcularFolha(
              percentual: f['percentual'], valorSipes: f['valor_sipes'], pensao: f['pensao']??0,
              outros: f['outros']??0, acrescimos: f['acrescimos'] ?? 0.0, temInss: f['tem_inss']==1, temIrrf: f['tem_irrf']==1,
              configData: _configData!,
            );
            sheetCat.appendRow([
              excel_pkg.TextCellValue(f['nome']), excel_pkg.TextCellValue(f['cpf'] ?? ''), excel_pkg.TextCellValue(f['rg'] ?? ''),
              excel_pkg.TextCellValue(f['banco'] ?? ''), excel_pkg.TextCellValue(f['agencia'] ?? ''), excel_pkg.TextCellValue(f['conta'] ?? ''),
              excel_pkg.TextCellValue(f['cargo_nome']), excel_pkg.TextCellValue(f['locacao'] ?? ''),
              excel_pkg.DoubleCellValue(f['valor_sipes']), excel_pkg.DoubleCellValue(f['percentual']),
              excel_pkg.DoubleCellValue(calc['bruto'] ?? 0.0), excel_pkg.DoubleCellValue(calc['inss'] ?? 0.0), excel_pkg.DoubleCellValue(calc['irrf'] ?? 0.0),
              excel_pkg.DoubleCellValue(f['pensao'] ?? 0), excel_pkg.DoubleCellValue(f['outros'] ?? 0), excel_pkg.DoubleCellValue(f['acrescimos'] ?? 0), excel_pkg.DoubleCellValue(calc['liquido'] ?? 0.0),
            ]);
        }
      }
    }

    final String fileName = "folha_itps_v8_sincronizada_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.xlsx";
    final FileSaveLocation? result = await getSaveLocation(suggestedName: fileName);
    
    if (result != null) {
      final List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        final File file = File(result.path);
        await file.writeAsBytes(fileBytes);
        if (mounted) _mostrarSnack("Relatório salvo com sucesso!", Colors.green);
      }
    }
  }

  // === RELATÓRIO NA TELA ===
  void _mostrarRelatorioNaTela() {
    Map<String, double> somar(List<Map<String, dynamic>> lista) {
      double tBruto=0, tInss=0, tIrrf=0, tPensao=0, tOutros=0, tAcres=0, tLiquido=0;
      for (var f in lista) {
        final calc = CalculadoraTaxas.calcularFolha(
          percentual: f['percentual'], valorSipes: f['valor_sipes'], pensao: f['pensao']??0,
          outros: f['outros']??0, acrescimos: f['acrescimos'] ?? 0.0, temInss: f['tem_inss']==1, temIrrf: f['tem_irrf']==1,
          configData: _configData!,
        );
        tBruto += calc['bruto'] ?? 0.0; 
        tInss += calc['inss'] ?? 0.0; 
        tIrrf += calc['irrf'] ?? 0.0;
        tPensao += f['pensao']??0; tOutros += f['outros']??0; tAcres += f['acrescimos']??0;
        tLiquido += calc['liquido'] ?? 0.0;
      }
      return {'bruto': tBruto, 'inss': tInss, 'irrf': tIrrf, 'pensao': tPensao, 'outros': tOutros, 'acrescimos': tAcres, 'liquido': tLiquido};
    }

    var efetivos = _funcionarios.where((f) => f['vinculo'] == 'Efetivo').toList();
    var comissionados = _funcionarios.where((f) => f['vinculo'] == 'Comissionado').toList();
    var cedidos = _funcionarios.where((f) => f['vinculo'] == 'Cedido').toList();
    var estagiarios = _funcionarios.where((f) => f['vinculo'] == 'Estagiário').toList();

    var sEfetivos = somar(efetivos);
    var sComissionados = somar(comissionados);
    var sCedidos = somar(cedidos);
    var sEstagiarios = somar(estagiarios);

    Widget linhaTabela(String titulo, Map<String, double> dados, {bool isTotal = false}) {
      double descontos = (dados['inss'] ?? 0) + (dados['irrf'] ?? 0) + (dados['pensao'] ?? 0) + (dados['outros'] ?? 0);
      TextStyle style = TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: 13);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(titulo, style: style.copyWith(color: isTotal ? Colors.black : Colors.blue[900]))),
            Expanded(child: Text(_formatMoeda(dados['bruto']), style: style)),
            Expanded(child: Text(_formatMoeda(dados['inss']), style: style.copyWith(color: Colors.red[700]))),
            Expanded(child: Text(_formatMoeda(dados['irrf']), style: style.copyWith(color: Colors.red[700]))),
            Expanded(child: Text(_formatMoeda(descontos), style: style.copyWith(fontWeight: FontWeight.bold))),
            Expanded(child: Text(_formatMoeda(dados['acrescimos']), style: style.copyWith(color: Colors.green[600]))),
            Expanded(child: Text(_formatMoeda(dados['liquido']), style: style.copyWith(color: Colors.green[800], fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Resumo da Folha por Vínculo"),
        content: SizedBox(
          width: 1000,
          height: 450,
          child: Column(
            children: [
              Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.all(10),
                child: const Row(children: [
                  Expanded(flex: 2, child: Text("CATEGORIA", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text("BRUTO", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text("INSS", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text("IRRF", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text("T. DESC.", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text("ACRÉSC.", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text("LÍQUIDO", style: TextStyle(fontWeight: FontWeight.bold))),
                ]),
              ),
              const Divider(),
              linhaTabela("Folha Efetivos (${efetivos.length})", sEfetivos),
              const Divider(),
              linhaTabela("Folha Comissionados (${comissionados.length})", sComissionados),
              const Divider(),
              linhaTabela("Folha Cedidos (${cedidos.length})", sCedidos),
              const Divider(),
              linhaTabela("Folha Estagiários (${estagiarios.length})", sEstagiarios),
              const Divider(thickness: 2),
               linhaTabela("TOTAL GERAL", {
                 'bruto': (sEfetivos['bruto']! + sComissionados['bruto']! + sCedidos['bruto']! + sEstagiarios['bruto']!),
                 'inss': (sEfetivos['inss']! + sComissionados['inss']! + sCedidos['inss']! + sEstagiarios['inss']!),
                 'irrf': (sEfetivos['irrf']! + sComissionados['irrf']! + sCedidos['irrf']! + sEstagiarios['irrf']!),
                 'pensao': (sEfetivos['pensao']! + sComissionados['pensao']! + sCedidos['pensao']! + sEstagiarios['pensao']!),
                 'outros': (sEfetivos['outros']! + sComissionados['outros']! + sCedidos['outros']! + sEstagiarios['outros']!),
                 'acrescimos': (sEfetivos['acrescimos']! + sComissionados['acrescimos']! + sCedidos['acrescimos']! + sEstagiarios['acrescimos']!),
                 'liquido': (sEfetivos['liquido']! + sComissionados['liquido']! + sCedidos['liquido']! + sEstagiarios['liquido']!),
               }, isTotal: true),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.print), 
            label: const Text("Exportar Relatório Excel"),
            style: FilledButton.styleFrom(backgroundColor: Colors.green[700]),
            onPressed: () {
              Navigator.pop(ctx);
              _exportarExcel();
            },
          ),
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Fechar"))
        ],
      ),
    );
  }

  void _mostrarDetalhesCalculo(String nome, Map<String, dynamic> calc) {
    double inssTotal = calc['inss_total'] ?? 0.0;
    double inssSipes = calc['inss_sipes'] ?? 0.0;
    double inssFinal = calc['inss'] ?? 0.0;

    double irrfTotal = calc['irrf_total'] ?? 0.0;
    double irrfSipes = calc['irrf_sipes'] ?? 0.0;
    double irrfFinal = calc['irrf'] ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Cálculo Detalhado: $nome"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("INSS (Encontro de Contas)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 5),
              Text("INSS do Convênio (Bruto): ${_formatMoeda(inssTotal)}"),
              Text("(-) INSS do Sipes (Estado): ${_formatMoeda(inssSipes)}"),
              const Divider(),
              Text("= INSS a Pagar: ${_formatMoeda(inssFinal)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 20),
              
              const Text("IRRF (Encontro de Contas)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 5),
              Text("IRRF do Convênio (Bruto): ${_formatMoeda(irrfTotal)}"),
              Text("(-) IRRF do Sipes (Estado): ${_formatMoeda(irrfSipes)}"),
              const Divider(),
              Text("= IRRF a Pagar: ${_formatMoeda(irrfFinal)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 20),
              const Text("* Sincronizado com os parâmetros do RH.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Fechar"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    double totalBrutoGeral = 0;
    double baseConvenio = _configData!['geral']['base_convenio'] ?? 210000.00;
    double aliquotaPatronal = _configData!['geral']['aliquota_patronal'] ?? 9.02;

    final List<DataRow> rows = [];
    
    for (var f in _funcionarios) {
      final calc = CalculadoraTaxas.calcularFolha(
        percentual: f['percentual'],
        valorSipes: f['valor_sipes'],
        pensao: f['pensao'] ?? 0.0,
        outros: f['outros'] ?? 0.0,
        acrescimos: f['acrescimos'] ?? 0.0,
        temInss: f['tem_inss'] == 1,
        temIrrf: f['tem_irrf'] == 1,
        configData: _configData!,
      );

      totalBrutoGeral += calc['bruto'] ?? 0.0;

      rows.add(DataRow(cells: [
        DataCell(Row(children: [
          CircleAvatar(backgroundColor: Colors.grey.shade200, radius: 12, child: Text(f['nome'].isNotEmpty ? f['nome'][0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
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
          decoration: BoxDecoration(color: f['vinculo'] == 'Efetivo' ? Colors.blue[50] : (f['vinculo'] == 'Comissionado' ? Colors.green[50] : (f['vinculo'] == 'Estagiário' ? Colors.purple[50] : Colors.orange[50])), borderRadius: BorderRadius.circular(10), border: Border.all(color: f['vinculo'] == 'Efetivo' ? Colors.blue.shade200 : (f['vinculo'] == 'Comissionado' ? Colors.green.shade200 : (f['vinculo'] == 'Estagiário' ? Colors.purple.shade200 : Colors.orange.shade200)))),
          child: Text(f['vinculo'] ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        )),
        DataCell(Text(_formatMoeda(f['valor_sipes']), style: const TextStyle(color: Colors.grey))),
        DataCell(Text("${f['percentual']}%", style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(_formatMoeda(calc['bruto']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
        DataCell(Text(f['tem_inss'] == 1 ? _formatMoeda(calc['inss']) : "-", style: TextStyle(color: Colors.red[700]))),
        DataCell(Text(f['tem_irrf'] == 1 ? _formatMoeda(calc['irrf']) : "-", style: TextStyle(color: Colors.red[700]))),
        DataCell(Text(_formatMoeda(f['pensao']), style: TextStyle(color: Colors.orange[800]))), 
        DataCell(Text(_formatMoeda(f['outros']), style: TextStyle(color: Colors.orange[800]))), 
        DataCell(Text(_formatMoeda(f['acrescimos']), style: TextStyle(color: Colors.green[600]))), 
        DataCell(Text(_formatMoeda(calc['liquido']), style: const TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.w900))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.info_outline, color: Colors.grey), tooltip: "Ver Detalhes do Cálculo", onPressed: () => _mostrarDetalhesCalculo(f['nome'], calc)),
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), onPressed: () => _carregarParaEdicao(f), tooltip: "Editar"),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () async { await DatabaseHelper.instance.deleteFuncionario(f['id']); _refreshTudo(); }, tooltip: "Remover"),
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
        title: const Row(children: [Icon(Icons.table_chart, size: 28), SizedBox(width: 10), Text('Sistema Folha ITPS', style: TextStyle(fontWeight: FontWeight.bold))]),
        backgroundColor: const Color(0xFF0D47A1), 
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilledButton.icon(
              onPressed: _mostrarRelatorioNaTela,
              icon: const Icon(Icons.analytics, size: 18),
              label: const Text("Resumo"),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilledButton.icon(
              onPressed: _exportarExcel,
              icon: const Icon(Icons.file_download, size: 18),
              label: const Text("Excel"),
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
      
      // BOTÃO FLUTUANTE PARA ABRIR O FORMULÁRIO
      floatingActionButton: !_mostrarFormulario 
        ? FloatingActionButton.extended(
            onPressed: () {
              _limparForm();
              setState(() => _mostrarFormulario = true);
            },
            icon: const Icon(Icons.person_add),
            label: const Text("Novo Colaborador"),
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
          )
        : null,
      
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoCard("Base Convênio", baseConvenio, Icons.account_balance, Colors.grey),
                _buildInfoCard("Total Bruto", totalBrutoGeral, Icons.attach_money, Colors.blue, isBold: true),
                _buildInfoCard("Patronal/RAT (${aliquotaPatronal}%)", valorPatronal, Icons.business, Colors.orange),
                _buildInfoCard("Retirada Total", totalRetirada, Icons.account_balance_wallet, Colors.green, isBold: true),
              ],
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch, 
              children: [
                // Formulário Lateral Condicional
                if (_mostrarFormulario)
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
                                    Text(_editingId != null ? "Editar" : "Novo Cadastro", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _editingId != null ? Colors.orange[800] : const Color(0xFF0D47A1))),
                                    IconButton(
                                      icon: const Icon(Icons.close), 
                                      onPressed: () {
                                        _limparForm();
                                        setState(() => _mostrarFormulario = false);
                                      }, 
                                      tooltip: "Fechar"
                                    )
                                  ],
                                ),
                              ),
                              
                              Expanded(
                                child: ListView(
                                  // CORREÇÃO: padding right 16 para a scrollbar
                                  padding: const EdgeInsets.only(top: 16, right: 16),
                                  children: [
                                    TextFormField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome Completo", prefixIcon: Icon(Icons.person)), validator: (v)=>v!.isEmpty?'Obrigatório':null),
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      Expanded(child: TextFormField(controller: _cpfCtrl, keyboardType: TextInputType.number, inputFormatters: [CpfInputFormatter()], decoration: const InputDecoration(labelText: "CPF", prefixIcon: Icon(Icons.badge), hintText: "000.000.000-00"))),
                                      const SizedBox(width: 8),
                                      Expanded(child: TextFormField(controller: _rgCtrl, decoration: const InputDecoration(labelText: "RG"))),
                                    ]),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      value: _vinculoSelecionado,
                                      decoration: const InputDecoration(labelText: "Vínculo", prefixIcon: Icon(Icons.work)),
                                      items: ['Efetivo', 'Comissionado', 'Cedido', 'Estagiário'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                                        Expanded(child: TextFormField(controller: _sipesCtrl, keyboardType: TextInputType.number, inputFormatters: [CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "SIPES"))),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: TextFormField(controller: _pensaoCtrl, keyboardType: TextInputType.number, inputFormatters: [CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "Pensão"))),
                                        const SizedBox(width: 8),
                                        Expanded(child: TextFormField(controller: _outrosCtrl, keyboardType: TextInputType.number, inputFormatters: [CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "Outros"))),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(controller: _acrescimosCtrl, keyboardType: TextInputType.number, inputFormatters: [CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "Acréscimos (Aux. Transp.)", prefixIcon: Icon(Icons.add_circle_outline, color: Colors.green))),
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
                                  label: Text(_editingId != null ? "SALVAR ALTERAÇÕES" : "ADICIONAR COLABORADOR"),
                                  style: ElevatedButton.styleFrom(backgroundColor: _editingId != null ? Colors.orange[800] : const Color(0xFF0D47A1), foregroundColor: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                    child: Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(12)), border: Border(bottom: BorderSide(color: Colors.black12))),
                            child: Row(
                              children: [
                                const Icon(Icons.people_alt, color: Colors.grey),
                                const SizedBox(width: 10),
                                Text("Lista de Colaboradores (${rows.length})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          
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
                                      constraints: BoxConstraints(minHeight: constraints.maxHeight, minWidth: 1600),
                                      child: Scrollbar(
                                        controller: _verticalScroll,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _verticalScroll,
                                          scrollDirection: Axis.vertical,
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
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
                                              DataColumn(label: Text("ACRÉSC.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))), 
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_formatMoeda(value), style: TextStyle(fontSize: isBold ? 22 : 18, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color))
            ],
          ),
        ],
      ),
    );
  }
}

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
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: limiteCtrl, decoration: const InputDecoration(labelText: "Limite (R\$)")), const SizedBox(height: 10), TextField(controller: aliquotaCtrl, decoration: const InputDecoration(labelText: "Alíquota (%)"))]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")), TextButton(onPressed: () async { await DatabaseHelper.instance.updateTabelaInss(item['id'], double.tryParse(limiteCtrl.text) ?? 0.0, double.tryParse(aliquotaCtrl.text) ?? 0.0); if (mounted) Navigator.pop(ctx); _carregarDados(); widget.onSave(); }, child: const Text("Salvar"))],
    ));
  }

  Future<void> _editarFaixaIrrf(Map<String, dynamic> item) async {
    final limiteCtrl = TextEditingController(text: item['limite'].toString());
    final aliquotaCtrl = TextEditingController(text: item['aliquota'].toString());
    final deducaoCtrl = TextEditingController(text: item['deducao'].toString());
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Editar Faixa IRRF"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: limiteCtrl, decoration: const InputDecoration(labelText: "Limite (R\$)")), const SizedBox(height: 10), TextField(controller: aliquotaCtrl, decoration: const InputDecoration(labelText: "Alíquota (%)")), const SizedBox(height: 10), TextField(controller: deducaoCtrl, decoration: const InputDecoration(labelText: "Dedução (R\$)"))]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")), TextButton(onPressed: () async { await DatabaseHelper.instance.updateTabelaIrrf(item['id'], double.tryParse(limiteCtrl.text) ?? 0.0, double.tryParse(aliquotaCtrl.text) ?? 0.0, double.tryParse(deducaoCtrl.text) ?? 0.0); if (mounted) Navigator.pop(ctx); _carregarDados(); widget.onSave(); }, child: const Text("Salvar"))],
    ));
  }

  // Função que serve tanto para CRIAR quanto para EDITAR cargos
  Future<void> _abrirDialogoCargo({Map<String, dynamic>? cargo}) async {
    final nomeCtrl = TextEditingController(text: cargo?['nome'] ?? '');
    final locacaoCtrl = TextEditingController(text: cargo?['locacao'] ?? ''); 
    final percCtrl = TextEditingController(text: cargo?['percentual_padrao']?.toString() ?? '');
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cargo == null ? "Novo Cargo" : "Editar Cargo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Nome do Cargo")),
            const SizedBox(height: 10),
            TextField(controller: locacaoCtrl, decoration: const InputDecoration(labelText: "Locação/Setor Padrão")), 
            const SizedBox(height: 10),
            TextField(controller: percCtrl, decoration: const InputDecoration(labelText: "Percentual (%)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              final dados = {
                'nome': nomeCtrl.text,
                'locacao': locacaoCtrl.text, 
                'percentual_padrao': double.tryParse(percCtrl.text) ?? 0.0
              };

              if (cargo == null) {
                await DatabaseHelper.instance.createCargo(dados);
              } else {
                dados['id'] = cargo['id'];
                await DatabaseHelper.instance.updateCargo(dados);
              }

              if(mounted) Navigator.pop(ctx);
              _carregarDados();
              widget.onSave();
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  Future<void> _deletarCargo(int id) async { await DatabaseHelper.instance.deleteCargo(id); _carregarDados(); widget.onSave(); }

  @override
  Widget build(BuildContext context) {
    if (_tabelaInss.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text("Configurações"), bottom: TabBar(controller: _tabController, tabs: const [Tab(text: "Geral"), Tab(text: "Tabelas"), Tab(text: "Cargos")])),
      body: TabBarView(controller: _tabController, children: [
          ListView(padding: const EdgeInsets.all(20), children: [const Text("Valores Base", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 10), TextField(controller: _baseCtrl, decoration: const InputDecoration(labelText: "Base Convênio (R\$)", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _tetoInssCtrl, decoration: const InputDecoration(labelText: "Teto INSS (R\$)", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _patronalCtrl, decoration: const InputDecoration(labelText: "Patronal (%)", border: OutlineInputBorder())), const SizedBox(height: 20), ElevatedButton(onPressed: _salvarGeral, child: const Text("SALVAR"))]),
          ListView(padding: const EdgeInsets.all(20), children: [const Text("Tabela INSS", style: TextStyle(fontWeight: FontWeight.bold)), ..._tabelaInss.map((r) => ListTile(title: Text("Até R\$ ${r['limite']}"), subtitle: Text("${r['aliquota']}%"), trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editarFaixaInss(r)))), const Divider(), const Text("Tabela IRRF", style: TextStyle(fontWeight: FontWeight.bold)), ..._tabelaIrrf.map((r) => ListTile(title: Text("Até R\$ ${r['limite']}"), subtitle: Text("${r['aliquota']}% (Ded: ${r['deducao']})"), trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editarFaixaIrrf(r))))]),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0), 
                child: ElevatedButton.icon(
                  onPressed: () => _abrirDialogoCargo(), 
                  icon: const Icon(Icons.add), 
                  label: const Text("Novo Cargo")
                )
              ), 
              Expanded(
                child: ListView.builder(
                  itemCount: _cargosLocais.length, 
                  itemBuilder: (ctx, i) { 
                    final c = _cargosLocais[i]; 
                    return ListTile(
                      title: Text(c['nome']), 
                      subtitle: Text("${c['locacao'] ?? 'Sem setor'} - ${c['percentual_padrao']}%"), 
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue), 
                            onPressed: () => _abrirDialogoCargo(cargo: c)
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red), 
                            onPressed: () => _deletarCargo(c['id'])
                          ),
                        ],
                      )
                    ); 
                  }
                )
              )
            ]
          )
      ]),
    );
  }
}