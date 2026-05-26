import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_selector/file_selector.dart';
import 'database_helper.dart';
import 'calculadora_taxas.dart';
import 'gerador_pdf.dart';
import 'graficos.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
          thumbColor: WidgetStateProperty.all(
              const Color(0xFF0D47A1).withValues(alpha: 0.6)),
          thickness: WidgetStateProperty.all(10),
          radius: const Radius.circular(10),
          thumbVisibility: WidgetStateProperty.all(true),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
          prefixIconColor: const Color(0xFF0D47A1),
          labelStyle: TextStyle(color: Colors.grey[700]),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HomeScreen({super.key, required this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _configData;
  List<Map<String, dynamic>> _funcionarios = [];
  List<Map<String, dynamic>> _cargos = [];
  List<Map<String, dynamic>> _folhasSalvas = [];
  List<Map<String, dynamic>> _logsAuditoria = [];
  bool _isLoading = true;
  int? _editingId;
  Timer? _refreshTimer;
  int _activeTab = 0; // 0: Dashboard, 1: Colaboradores, 2: Fechamento, 3: Auditoria
  bool _isDarkMode = false;
  bool _previdenciaRpps = false;

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
  final _irrfManualCtrl = TextEditingController();
  final _diasTrabalhadosCtrl = TextEditingController(text: '30');
  final _rppsValCtrl = TextEditingController();

  // Scroll Controllers
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  String _vinculoSelecionado = 'Efetivo';
  int? _selectedCargoId;
  bool _temInss = false;
  bool _temIrrf = true;
  bool _mostrarFormulario = false;

  // Filtro de auditoria
  String _filtroAuditoria = '';

  // Parâmetros de Fechamento
  String _mesFechamento = 'Janeiro';
  String _anoFechamento = '2026';

  @override
  void initState() {
    super.initState();
    _refreshTudo();
    // Configura o timer para atualizar automaticamente a cada 15 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _refreshTudo(silencioso: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTudo({bool silencioso = false}) async {
    if (!silencioso) setState(() => _isLoading = true);
    try {
      final configs = await DatabaseHelper.instance.loadFullConfig();
      final funcs = await DatabaseHelper.instance.readFuncionarios();
      final cargos = await DatabaseHelper.instance.readCargos();
      final folhas = await DatabaseHelper.instance.readFolhasSalvas();
      final logs = await DatabaseHelper.instance.readLogs();
      if (!mounted) return;
      setState(() {
        _configData = configs;
        _funcionarios = funcs;
        _cargos = cargos;
        _folhasSalvas = folhas;
        _logsAuditoria = logs;
        _isLoading = false;
      });
      if (silencioso) {
        debugPrint("Folha RH: Sincronização automática realizada.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _mostrarSnack("Erro ao carregar dados: $e", Colors.red);
    }
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
        'irrf_manual': _parseMoeda(_irrfManualCtrl.text),
        'dias_trabalhados': int.tryParse(_diasTrabalhadosCtrl.text) ?? 30,
        'previdencia_rpps': _previdenciaRpps ? _parseMoeda(_rppsValCtrl.text) : 0.0,
      };

      if (_editingId == null) {
        await DatabaseHelper.instance.createFuncionario(dados, usuario: widget.userData['usuario']);
        _mostrarSnackPremium("Colaborador cadastrado!", Icons.check_circle, Colors.green);
      } else {
        dados['id'] = _editingId!;
        await DatabaseHelper.instance.updateFuncionario(dados, usuario: widget.userData['usuario']);
        _mostrarSnackPremium("Dados do colaborador atualizados!", Icons.edit, Colors.blue);
      }
      _limparForm();
      setState(() => _mostrarFormulario = false);
      _refreshTudo();
    }
  }

  void _carregarParaEdicao(Map<String, dynamic> f) {
    setState(() {
      _mostrarFormulario = true;
      _editingId = f['id'];
      _nomeCtrl.text = f['nome'];
      _cpfCtrl.text = f['cpf'] ?? '';
      _rgCtrl.text = f['rg'] ?? '';
      _vinculoSelecionado = f['vinculo'] ?? 'Efetivo';
      _bancoCtrl.text = f['banco'] ?? '';
      _agenciaCtrl.text = f['agencia'] ?? '';
      _contaCtrl.text = f['conta'] ?? '';
      _cargoManualCtrl.text = f['cargo_nome'] ?? '';
      _locacaoCtrl.text = f['locacao'] ?? '';
      final brFormat = NumberFormat.currency(locale: 'pt_BR', symbol: '');
      _percentualCtrl.text = brFormat.format(f['percentual']).trim();
      _sipesCtrl.text = _formatMoeda(f['valor_sipes']);
      _pensaoCtrl.text = _formatMoeda(f['pensao'] ?? 0.0);
      _outrosCtrl.text = _formatMoeda(f['outros'] ?? 0.0);
      _acrescimosCtrl.text = _formatMoeda(f['acrescimos'] ?? 0.0);
      _irrfManualCtrl.text = _formatMoeda(f['irrf_manual'] ?? 0.0);
      _diasTrabalhadosCtrl.text = (f['dias_trabalhados'] ?? 30).toString();
      _temInss = f['tem_inss'] == 1;
      _temIrrf = f['tem_irrf'] == 1;
      double valRpps = f['previdencia_rpps'] is num ? (f['previdencia_rpps'] as num).toDouble() : 0.0;
      _previdenciaRpps = valRpps > 0.0;
      _rppsValCtrl.text = valRpps > 0.0 ? _formatMoeda(valRpps) : '';
      _selectedCargoId = null;
    });
  }

  void _limparForm() {
    _nomeCtrl.clear();
    _cpfCtrl.clear();
    _rgCtrl.clear();
    _bancoCtrl.clear();
    _agenciaCtrl.clear();
    _contaCtrl.clear();
    _percentualCtrl.clear();
    _cargoManualCtrl.clear();
    _locacaoCtrl.clear();
    _sipesCtrl.clear();
    _pensaoCtrl.clear();
    _outrosCtrl.clear();
    _acrescimosCtrl.clear();
    _irrfManualCtrl.clear();
    _rppsValCtrl.clear();
    _diasTrabalhadosCtrl.text = '30';
    setState(() {
      _editingId = null;
      _selectedCargoId = null;
      _vinculoSelecionado = 'Efetivo';
      _temInss = false;
      _temIrrf = true;
      _previdenciaRpps = false;
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
      final brFormat = NumberFormat.currency(locale: 'pt_BR', symbol: '');
      _percentualCtrl.text = brFormat.format(cargo['percentual_padrao']).trim();
    }
  }

  void _mostrarSnack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarSnackPremium(String msg, IconData icone, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(icone, color: cor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    List<String> headersResumo = [
      'CATEGORIA',
      'BRUTO',
      'INSS',
      'IRRF',
      'PENSÃO',
      'OUTROS',
      'TOTAL DESC.',
      'ACRÉSCIMOS',
      'LÍQUIDO'
    ];
    sheetResumo.appendRow(headersResumo.map((e) => excel_pkg.TextCellValue(e)).toList());

    for (int i = 0; i < headersResumo.length; i++) {
      sheetResumo
          .cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = styleHeaderResumo;
    }

    List<String> categorias = ['Efetivo', 'Comissionado', 'Cedido', 'Estagiário'];
    double gBruto = 0, gInss = 0, gIrrf = 0, gPensao = 0, gOutros = 0, gDesc = 0, gAcres = 0, gLiquido = 0;

    for (var cat in categorias) {
      var lista = _funcionarios.where((f) => f['vinculo'] == cat).toList();
      double tBruto = 0, tInss = 0, tIrrf = 0, tPensao = 0, tOutros = 0, tAcres = 0, tLiquido = 0;

      for (var f in lista) {
        final calc = CalculadoraTaxas.calcularFolha(
          percentual: f['percentual'],
          valorSipes: f['valor_sipes'],
          pensao: f['pensao'] ?? 0,
          outros: f['outros'] ?? 0,
          acrescimos: f['acrescimos'] ?? 0.0,
          temInss: f['tem_inss'] == 1,
          temIrrf: f['tem_irrf'] == 1,
          configData: _configData!,
          irrfManual: f['irrf_manual'] ?? 0.0,
          irrfSipesReal: f['irrf_sipes_real'] ?? 0.0,
          diasTrabalhados: f['dias_trabalhados'] ?? 30,
          previdenciaRpps: f['previdencia_rpps'] is num ? (f['previdencia_rpps'] as num).toDouble() : 0.0,
        );
        tBruto += calc['bruto'] ?? 0.0;
        tInss += calc['inss'] ?? 0.0;
        tIrrf += calc['irrf'] ?? 0.0;
        tPensao += f['pensao'] ?? 0;
        tOutros += f['outros'] ?? 0;
        tAcres += f['acrescimos'] ?? 0;
        tLiquido += calc['liquido'] ?? 0.0;
      }

      double tDescontos = tInss + tIrrf + tPensao + tOutros;
      gBruto += tBruto;
      gInss += tInss;
      gIrrf += tIrrf;
      gPensao += tPensao;
      gOutros += tOutros;
      gDesc += tDescontos;
      gAcres += tAcres;
      gLiquido += tLiquido;

      sheetResumo.appendRow([
        excel_pkg.TextCellValue(cat.toUpperCase()),
        excel_pkg.DoubleCellValue(tBruto),
        excel_pkg.DoubleCellValue(tInss),
        excel_pkg.DoubleCellValue(tIrrf),
        excel_pkg.DoubleCellValue(tPensao),
        excel_pkg.DoubleCellValue(tOutros),
        excel_pkg.DoubleCellValue(tDescontos),
        excel_pkg.DoubleCellValue(tAcres),
        excel_pkg.DoubleCellValue(tLiquido)
      ]);
    }

    sheetResumo.appendRow([
      excel_pkg.TextCellValue('TOTAL GERAL'),
      excel_pkg.DoubleCellValue(gBruto),
      excel_pkg.DoubleCellValue(gInss),
      excel_pkg.DoubleCellValue(gIrrf),
      excel_pkg.DoubleCellValue(gPensao),
      excel_pkg.DoubleCellValue(gOutros),
      excel_pkg.DoubleCellValue(gDesc),
      excel_pkg.DoubleCellValue(gAcres),
      excel_pkg.DoubleCellValue(gLiquido)
    ]);

    for (var cat in categorias) {
      var lista = _funcionarios.where((f) => f['vinculo'] == cat).toList();
      if (lista.isNotEmpty) {
        excel_pkg.Sheet sheetCat = excel['Lista $cat'];
        List<String> headersDet = [
          'NOME COMPLETO', 'CPF', 'RG', 'BANCO', 'AGÊNCIA', 'CONTA', 'CARGO', 'LOCAÇÃO',
          'SIPES', '%', 'BRUTO', 'INSS', 'IRRF', 'PENSÃO', 'OUTROS', 'ACRÉSCIMOS', 'LÍQUIDO'
        ];
        sheetCat.appendRow(headersDet.map((e) => excel_pkg.TextCellValue(e)).toList());

        for (int i = 0; i < headersDet.length; i++) {
          sheetCat
              .cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
              .cellStyle = styleHeaderLista;
        }

        for (var f in lista) {
          final calc = CalculadoraTaxas.calcularFolha(
            percentual: f['percentual'],
            valorSipes: f['valor_sipes'],
            pensao: f['pensao'] ?? 0,
            outros: f['outros'] ?? 0,
            acrescimos: f['acrescimos'] ?? 0.0,
            temInss: f['tem_inss'] == 1,
            temIrrf: f['tem_irrf'] == 1,
            configData: _configData!,
            irrfManual: f['irrf_manual'] ?? 0.0,
            irrfSipesReal: f['irrf_sipes_real'] ?? 0.0,
            diasTrabalhados: f['dias_trabalhados'] ?? 30,
            previdenciaRpps: f['previdencia_rpps'] is num ? (f['previdencia_rpps'] as num).toDouble() : 0.0,
          );
          sheetCat.appendRow([
            excel_pkg.TextCellValue(f['nome']),
            excel_pkg.TextCellValue(f['cpf'] ?? ''),
            excel_pkg.TextCellValue(f['rg'] ?? ''),
            excel_pkg.TextCellValue(f['banco'] ?? ''),
            excel_pkg.TextCellValue(f['agencia'] ?? ''),
            excel_pkg.TextCellValue(f['conta'] ?? ''),
            excel_pkg.TextCellValue(f['cargo_nome']),
            excel_pkg.TextCellValue(f['locacao'] ?? ''),
            excel_pkg.DoubleCellValue(f['valor_sipes']),
            excel_pkg.DoubleCellValue(f['percentual']),
            excel_pkg.DoubleCellValue(calc['bruto'] ?? 0.0),
            excel_pkg.DoubleCellValue(calc['inss'] ?? 0.0),
            excel_pkg.DoubleCellValue(calc['irrf'] ?? 0.0),
            excel_pkg.DoubleCellValue(f['pensao'] ?? 0),
            excel_pkg.DoubleCellValue(f['outros'] ?? 0),
            excel_pkg.DoubleCellValue(f['acrescimos'] ?? 0),
            excel_pkg.DoubleCellValue(calc['liquido'] ?? 0.0),
          ]);
        }
      }
    }

    final String fileName = "folha_itps_sincronizada_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.xlsx";
    final FileSaveLocation? result = await getSaveLocation(suggestedName: fileName);

    if (result != null) {
      final List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        final File file = File(result.path);
        await file.writeAsBytes(fileBytes);
        await DatabaseHelper.instance.registrarLog(widget.userData['usuario'], 'EXPORTAR_EXCEL', 'Exportou planilha geral da folha para Excel');
        _mostrarSnackPremium("Relatório salvo com sucesso!", Icons.check_circle, Colors.green);
      }
    }
  }

  // === RELATÓRIO NA TELA ===
  void _mostrarRelatorioNaTela() {
    Map<String, double> somar(List<Map<String, dynamic>> lista) {
      double tBruto = 0, tInss = 0, tIrrf = 0, tPensao = 0, tOutros = 0, tAcres = 0, tLiquido = 0;
      for (var f in lista) {
        final calc = CalculadoraTaxas.calcularFolha(
          percentual: f['percentual'],
          valorSipes: f['valor_sipes'],
          pensao: f['pensao'] ?? 0,
          outros: f['outros'] ?? 0,
          acrescimos: f['acrescimos'] ?? 0.0,
          temInss: f['tem_inss'] == 1,
          temIrrf: f['tem_irrf'] == 1,
          configData: _configData!,
          irrfManual: f['irrf_manual'] ?? 0.0,
          irrfSipesReal: f['irrf_sipes_real'] ?? 0.0,
          diasTrabalhados: f['dias_trabalhados'] ?? 30,
          previdenciaRpps: f['previdencia_rpps'] is num ? (f['previdencia_rpps'] as num).toDouble() : 0.0,
        );
        tBruto += calc['bruto'] ?? 0.0;
        tInss += calc['inss'] ?? 0.0;
        tIrrf += calc['irrf'] ?? 0.0;
        tPensao += f['pensao'] ?? 0;
        tOutros += f['outros'] ?? 0;
        tAcres += f['acrescimos'] ?? 0;
        tLiquido += calc['liquido'] ?? 0.0;
      }
      return {
        'bruto': tBruto, 'inss': tInss, 'irrf': tIrrf, 'pensao': tPensao,
        'outros': tOutros, 'acrescimos': tAcres, 'liquido': tLiquido
      };
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
      TextStyle style = TextStyle(
        fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
        color: _isDarkMode ? Colors.white : Colors.black87,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                titulo,
                style: style.copyWith(color: isTotal ? (_isDarkMode ? Colors.cyan : Colors.black) : (_isDarkMode ? Colors.blue[300] : Colors.blue[900])),
              ),
            ),
            Expanded(child: Text(_formatMoeda(dados['bruto']), style: style)),
            Expanded(child: Text(_formatMoeda(dados['inss']), style: style.copyWith(color: Colors.red[300]))),
            Expanded(child: Text(_formatMoeda(dados['irrf']), style: style.copyWith(color: Colors.red[300]))),
            Expanded(child: Text(_formatMoeda(descontos), style: style.copyWith(fontWeight: FontWeight.bold))),
            Expanded(child: Text(_formatMoeda(dados['acrescimos']), style: style.copyWith(color: Colors.green[300]))),
            Expanded(child: Text(_formatMoeda(dados['liquido']), style: style.copyWith(color: Colors.green[400], fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          "Resumo da Folha por Vínculo",
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
        ),
        content: SizedBox(
          width: 1000,
          height: 450,
          child: Column(
            children: [
              Container(
                color: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text("CATEGORIA", style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87))),
                    Expanded(child: Text("BRUTO", style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87))),
                    Expanded(child: Text("INSS", style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87))),
                    Expanded(child: Text("IRRF", style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87))),
                    Expanded(child: Text("T. DESC.", style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87))),
                    Expanded(child: Text("ACRÉSC.", style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87))),
                    Expanded(child: Text("LÍQUIDO", style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87))),
                  ],
                ),
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
              linhaTabela(
                "TOTAL GERAL",
                {
                  'bruto': (sEfetivos['bruto']! + sComissionados['bruto']! + sCedidos['bruto']! + sEstagiarios['bruto']!),
                  'inss': (sEfetivos['inss']! + sComissionados['inss']! + sCedidos['inss']! + sEstagiarios['inss']!),
                  'irrf': (sEfetivos['irrf']! + sComissionados['irrf']! + sCedidos['irrf']! + sEstagiarios['irrf']!),
                  'pensao': (sEfetivos['pensao']! + sComissionados['pensao']! + sCedidos['pensao']! + sEstagiarios['pensao']!),
                  'outros': (sEfetivos['outros']! + sComissionados['outros']! + sCedidos['outros']! + sEstagiarios['outros']!),
                  'acrescimos': (sEfetivos['acrescimos']! + sComissionados['acrescimos']! + sCedidos['acrescimos']! + sEstagiarios['acrescimos']!),
                  'liquido': (sEfetivos['liquido']! + sComissionados['liquido']! + sCedidos['liquido']! + sEstagiarios['liquido']!),
                },
                isTotal: true,
              ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fechar"),
          )
        ],
      ),
    );
  }

  void _mostrarDetalhesCalculo(String nome, Map<String, dynamic> calc) {
    double sipes = calc['sipes'] ?? 0.0;
    double convenio = calc['base_convenio'] ?? 0.0;
    double global = calc['base_global_bruta'] ?? 0.0;
    double inssTotal = calc['inss_total'] ?? 0.0;
    double inssSipes = calc['inss_sipes'] ?? 0.0;
    double inssFinal = calc['inss'] ?? 0.0;
    double baseIrrf = calc['base_irrf'] ?? 0.0;
    double irrfTotal = calc['irrf_total'] ?? 0.0;
    double irrfSipes = calc['irrf_sipes'] ?? 0.0;
    double irrfFinal = calc['irrf'] ?? 0.0;
    bool irrfManualInformado = calc['irrf_manual_informado'] ?? false;
    double redutorIrrf = calc['redutor_irrf'] ?? 0.0;
    bool isentoIrrf2026 = calc['isento_irrf_2026'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF1E88E5)),
            const SizedBox(width: 10),
            Expanded(child: Text("Memória de Cálculo: $nome", style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87))),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDestaqueValores("Base Bruta Global", global,
                    "Soma: ${_formatMoeda(sipes)} (SIPES) + ${_formatMoeda(convenio)} (Convênio)"),
                const SizedBox(height: 20),
                _buildHeaderSecao("INSS - Previdência", Icons.security, Colors.blue),
                _buildItemCalculo("INSS Total (sobre Global)", inssTotal),
                _buildItemCalculo("(-) INSS já pago no SIPES", inssSipes, isDeducao: true),
                const Divider(),
                _buildItemResultado("INSS a descontar nesta folha", inssFinal, Colors.blue),
                const SizedBox(height: 24),
                _buildHeaderSecao("IRRF - Imposto de Renda", Icons.request_quote, Colors.red),
                _buildItemCalculo("Base de Cálculo IRRF", baseIrrf, info: "Bruto - INSS Total - Pensão"),
                if (isentoIrrf2026)
                  _buildItemCalculo("IRRF Total (Regra 2026)", 0.0, info: "Isento (Salário Bruto Total <= R\$ 5.000,00)")
                else ...[
                  _buildItemCalculo("IRRF (Tabela Tradicional)", irrfTotal + redutorIrrf),
                  if (redutorIrrf > 0)
                    _buildItemCalculo("(-) Redutor IRRF 2026", redutorIrrf, isDeducao: true, info: "Atenuação para salários até R\$ 7.350,00"),
                  if (redutorIrrf > 0)
                    _buildItemCalculo("IRRF Total Global", irrfTotal, info: "Imposto após aplicação do redutor"),
                ],
                _buildItemCalculo("(-) IRRF já pago no SIPES", irrfSipes, isDeducao: true, info: irrfManualInformado ? "Diferença do valor manual" : "Valor calculado"),
                const Divider(),
                _buildItemResultado("IRRF a descontar nesta folha", irrfFinal, irrfManualInformado ? Colors.orange : Colors.red, info: irrfManualInformado ? "Valor digitado manualmente" : null),
                const SizedBox(height: 24),
                _buildHeaderSecao("Líquido do Convênio", Icons.wallet, Colors.green),
                _buildItemCalculo("Valor Bruto do Convênio", convenio),
                _buildItemCalculo("(-) INSS a descontar", inssFinal, isDeducao: true),
                _buildItemCalculo("(-) IRRF a descontar", irrfFinal, isDeducao: true),
                _buildItemCalculo("(-) Pensão/Outros", (calc['pensao'] ?? 0) + (calc['outros'] ?? 0), isDeducao: true),
                _buildItemCalculo("(+) Acréscimos", calc['acrescimos'] ?? 0),
                const Divider(thickness: 2),
                _buildItemResultado("VALOR LÍQUIDO A RECEBER", calc['liquido'] ?? 0.0, Colors.green[400]!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("FECHAR", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDestaqueValores(String label, double valor, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_formatMoeda(valor), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 11, color: _isDarkMode ? Colors.grey : Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildHeaderSecao(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildItemCalculo(String label, double valor, {bool isDeducao = false, String? info}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: _isDarkMode ? Colors.white.withValues(alpha: 0.87) : Colors.black87)),
              Text(
                "${isDeducao ? '-' : ''} ${_formatMoeda(valor)}",
                style: TextStyle(
                  fontSize: 13,
                  color: isDeducao ? Colors.red[300] : (_isDarkMode ? Colors.white : Colors.black),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (info != null)
            Text(info, style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildItemResultado(String label, double valor, Color color, {String? info}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
            Text(_formatMoeda(valor), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        if (info != null)
          Text(info, style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  // --- CONTROLES DE COR COM BASE NO TEMA ---
  Color get _corFundo => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  Color get _corCard => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _corTexto => _isDarkMode ? Colors.white : Colors.black87;
  Color get _corSubTexto => _isDarkMode ? Colors.white60 : Colors.grey[700]!;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _corFundo,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _corFundo,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. LEFT SIDEBAR MENU
          _buildLeftSidebar(),
          // 2. MAIN BODY WRAPPER
          Expanded(
            child: Column(
              children: [
                // TOP BAR (Premium actions)
                _buildTopBar(),
                // ACTIVE TAB VIEW
                Expanded(
                  child: _buildSelectedTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- CONSTRUÇÃO DO MENU LATERAL COMPACTO E PREMIUM ---
  Widget _buildLeftSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF0D47A1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(2, 0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Título
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calculate, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Folha ITPS",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5),
                      ),
                      Text(
                        "RH & Financeiro",
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          // Itens de Menu
          _buildMenuItem(0, "Dashboard", Icons.dashboard_outlined),
          _buildMenuItem(1, "Colaboradores", Icons.people_outline),
          _buildMenuItem(2, "Histórico & Fechamento", Icons.history_edu),
          _buildMenuItem(3, "Trilha de Auditoria", Icons.security),
          const Spacer(),
          // Logout / User Info
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 16,
                      child: Text(
                        widget.userData['usuario'].toString().isNotEmpty ? widget.userData['usuario'][0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userData['usuario'].toString().toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.userData['permissao'].toString().toUpperCase(),
                            style: const TextStyle(color: Colors.white54, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.logout, size: 14),
                  label: const Text("Sair do Sistema"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int tabIndex, String label, IconData icone) {
    final bool isSelected = _activeTab == tabIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = tabIndex;
            _mostrarFormulario = false; // fecha o form ao trocar de aba
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icone, color: isSelected ? Colors.white : Colors.white70, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CONSTRUÇÃO DA TOP BAR ---
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: _corCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activeTab == 0
                    ? "Dashboard Geral"
                    : (_activeTab == 1
                        ? "Painel de Colaboradores"
                        : (_activeTab == 2 ? "Histórico & Fechamento Mensal" : "Auditoria de Ações")),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _corTexto),
              ),
              Text(
                "Sincronização de Rede: Sincronizado silenciosamente a cada 15 segundos",
                style: TextStyle(color: _corSubTexto.withValues(alpha: 0.7), fontSize: 11),
              ),
            ],
          ),
          Row(
            children: [
              // Botões originais adaptados
              FilledButton.icon(
                onPressed: _mostrarRelatorioNaTela,
                icon: const Icon(Icons.analytics, size: 16),
                label: const Text("Resumo Geral"),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _exportarExcel,
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text("Exportar Excel"),
                style: FilledButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfigScreen(data: _configData!, onSave: _refreshTudo, userData: widget.userData),
                  ),
                ),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text("Ajustar Parâmetros"),
                style: FilledButton.styleFrom(
                  backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.blueGrey[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SELECIONA O CONTEÚDO DO TAMPÃO ATIVO ---
  Widget _buildSelectedTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildColaboradoresTab();
      case 2:
        return _buildFechamentoTab();
      case 3:
        return _buildAuditoriaTab();
      default:
        return _buildDashboardTab();
    }
  }

  // ==========================================
  // 📊 TAB 1: DASHBOARD VISUAL PREMIUM
  // ==========================================
  Widget _buildDashboardTab() {
    double totalBrutoGeral = 0;
    double totalInss = 0;
    double totalIrrf = 0;
    double totalLiquido = 0;
    double totalDescontos = 0;

    Map<String, double> dadosSetores = {};

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
        irrfManual: f['irrf_manual'] ?? 0.0,
        irrfSipesReal: f['irrf_sipes_real'] ?? 0.0,
        diasTrabalhados: f['dias_trabalhados'] ?? 30,
        previdenciaRpps: f['previdencia_rpps'] is num ? (f['previdencia_rpps'] as num).toDouble() : 0.0,
      );

      double bruto = calc['bruto'] ?? 0.0;
      double inss = calc['inss'] ?? 0.0;
      double irrf = calc['irrf'] ?? 0.0;
      double liq = calc['liquido'] ?? 0.0;
      double desc = inss + irrf + (f['pensao'] ?? 0.0) + (f['outros'] ?? 0.0);

      totalBrutoGeral += bruto;
      totalInss += inss;
      totalIrrf += irrf;
      totalDescontos += desc;
      totalLiquido += liq;

      // Gastos por setor
      String setor = f['locacao'] ?? 'Sem Setor';
      dadosSetores[setor] = (dadosSetores[setor] ?? 0.0) + bruto;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CARDS DE MÉTRICAS COM GRADIENTES MODERNOS
          Row(
            children: [
              Expanded(
                child: _buildMetricCardPremium(
                  "Total Bruto Convênio",
                  totalBrutoGeral,
                  Icons.monetization_on,
                  [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCardPremium(
                  "Retenções Previdenciárias",
                  totalInss,
                  Icons.security,
                  [const Color(0xFF7F1D1D), const Color(0xFFEF4444)],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCardPremium(
                  "Imposto de Renda",
                  totalIrrf,
                  Icons.request_quote,
                  [const Color(0xFFB45309), const Color(0xFFF59E0B)],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCardPremium(
                  "Desembolso Líquido",
                  totalLiquido,
                  Icons.payments,
                  [const Color(0xFF065F46), const Color(0xFF10B981)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 2. GRÁFICOS LADO A LADO
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doughnut Chart (Setores)
              Expanded(
                flex: 5,
                child: Card(
                  color: _corCard,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Despesas por Lotação / Setor",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _corTexto),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 230,
                          child: GraficoSetores(dadosSetores: dadosSetores, isDarkMode: _isDarkMode),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Bar Chart (Bruto vs Liquido)
              Expanded(
                flex: 4,
                child: Card(
                  color: _corCard,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      height: 270,
                      child: GraficoBarrasComparativo(
                        valorBruto: totalBrutoGeral,
                        valorLiquido: totalLiquido,
                        valorDescontos: totalDescontos,
                        isDarkMode: _isDarkMode,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCardPremium(String rotulo, double valor, IconData icone, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rotulo.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatMoeda(valor),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 👥 TAB 2: ORIGINAL COLABORADORES TABLE VIEW
  // ==========================================
  Widget _buildColaboradoresTab() {
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
        irrfManual: f['irrf_manual'] ?? 0.0,
        irrfSipesReal: f['irrf_sipes_real'] ?? 0.0,
        diasTrabalhados: f['dias_trabalhados'] ?? 30,
        previdenciaRpps: f['previdencia_rpps'] is num ? (f['previdencia_rpps'] as num).toDouble() : 0.0,
      );

      totalBrutoGeral += calc['bruto'] ?? 0.0;

      rows.add(DataRow(
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (_isDarkMode) {
            return rows.length % 2 == 0 ? const Color(0xFF242424) : const Color(0xFF1E1E1E);
          }
          return rows.length % 2 == 0 ? Colors.grey[50] : Colors.white;
        }),
        cells: [
          DataCell(Row(children: [
            CircleAvatar(
              backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
              radius: 12,
              child: Text(
                f['nome'].isNotEmpty ? f['nome'][0].toUpperCase() : '?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _corTexto),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(f['nome'], style: TextStyle(fontWeight: FontWeight.w600, color: _corTexto)),
                if (f['previdencia_rpps'] is num && (f['previdencia_rpps'] as num) > 0.0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "RPPS",
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 9),
                    ),
                  ),
                ],
              ],
            ),
          ])),
          DataCell(Text(f['cpf'] ?? '-', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: _corTexto))),
          DataCell(Text(f['rg'] ?? '-', style: TextStyle(color: _corSubTexto))),
          DataCell(Text(f['banco'] ?? '-', style: TextStyle(color: _corTexto))),
          DataCell(Text(f['agencia'] ?? '-', style: TextStyle(color: _corTexto))),
          DataCell(Text(f['conta'] ?? '-', style: TextStyle(color: _corTexto))),
          DataCell(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(f['cargo_nome'] ?? '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _corTexto)),
              Text(f['locacao'] ?? '-', style: TextStyle(fontSize: 11, color: _corSubTexto)),
            ],
          )),
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: f['vinculo'] == 'Efetivo'
                  ? Colors.blue.withValues(alpha: 0.1)
                  : (f['vinculo'] == 'Comissionado'
                      ? Colors.green.withValues(alpha: 0.1)
                      : (f['vinculo'] == 'Estagiário'
                          ? Colors.purple.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1))),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: f['vinculo'] == 'Efetivo'
                    ? Colors.blue.shade300
                    : (f['vinculo'] == 'Comissionado'
                        ? Colors.green.shade300
                        : (f['vinculo'] == 'Estagiário'
                            ? Colors.purple.shade300
                            : Colors.orange.shade300)),
              ),
            ),
            child: Text(
              f['vinculo'] ?? '-',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: f['vinculo'] == 'Efetivo'
                    ? Colors.blue[300]
                    : (f['vinculo'] == 'Comissionado'
                        ? Colors.green[300]
                        : (f['vinculo'] == 'Estagiário'
                            ? Colors.purple[300]
                            : Colors.orange[300])),
              ),
            ),
          )),
          DataCell(Text(_formatMoeda(f['valor_sipes']), style: TextStyle(color: _corSubTexto))),
          DataCell(Text("${f['percentual']}%", style: TextStyle(fontWeight: FontWeight.bold, color: _corTexto))),
          DataCell(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_formatMoeda(calc['bruto']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              if ((f['dias_trabalhados'] ?? 30) < 30)
                Text(
                  "${f['dias_trabalhados']} dias",
                  style: TextStyle(fontSize: 10, color: Colors.orange[800], fontWeight: FontWeight.bold),
                ),
            ],
          )),
          DataCell(Text(f['tem_inss'] == 1 ? _formatMoeda(calc['inss']) : "-", style: TextStyle(color: Colors.red[300]))),
          DataCell(Text(f['tem_irrf'] == 1 ? _formatMoeda(calc['irrf']) : "-", style: TextStyle(color: Colors.red[300]))),
          DataCell(Text(_formatMoeda(f['pensao']), style: TextStyle(color: Colors.orange[300]))),
          DataCell(Text(_formatMoeda(f['outros']), style: TextStyle(color: Colors.orange[300]))),
          DataCell(Text(_formatMoeda(f['acrescimos']), style: TextStyle(color: Colors.green[300]))),
          DataCell(Text(_formatMoeda(calc['liquido']), style: const TextStyle(color: Color(0xFF26A69A), fontWeight: FontWeight.w900))),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.grey),
                tooltip: "Ver Detalhes do Cálculo",
                onPressed: () => _mostrarDetalhesCalculo(f['nome'], calc),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.amber),
                tooltip: "Imprimir Holerite (PDF)",
                onPressed: () async {
                  await DatabaseHelper.instance.registrarLog(widget.userData['usuario'], 'IMPRIMIR_HOLERITE', 'Gerou PDF do holerite para: ${f['nome']}');
                  await GeradorPdf.gerarEImprimirHolerite(f, calc, DateFormat('MM/yyyy').format(DateTime.now()));
                },
              ),
              if (widget.userData['permissao'] != 'leitura') ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  onPressed: () => _carregarParaEdicao(f),
                  tooltip: "Editar",
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () async {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: _corCard,
                        title: Text("Remover Colaborador?", style: TextStyle(color: _corTexto)),
                        content: Text("Tem certeza que deseja remover ${f['nome']}?", style: TextStyle(color: _corTexto)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await DatabaseHelper.instance.deleteFuncionario(f['id'], usuario: widget.userData['usuario']);
                              _mostrarSnackPremium("Colaborador removido!", Icons.delete, Colors.red);
                              _refreshTudo();
                            },
                            child: const Text("Sim, Remover", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: "Remover",
                ),
              ],
            ],
          )),
        ],
      ));
    }

    double valorPatronal = totalBrutoGeral * (aliquotaPatronal / 100);
    double totalRetirada = totalBrutoGeral + valorPatronal;

    return Column(
      children: [
        // Mini Info Panel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _corCard,
            border: Border(bottom: BorderSide(color: _isDarkMode ? Colors.grey[800]! : Colors.grey[200]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniInfoBox("Total Bruto Geral", totalBrutoGeral, Colors.blue),
              _buildMiniInfoBox("Base do Mês", baseConvenio, Colors.grey),
              _buildMiniInfoBox("RAT / Patronal ($aliquotaPatronal%)", valorPatronal, Colors.orange),
              _buildMiniInfoBox("Retirada Total", totalRetirada, Colors.green),
            ],
          ),
        ),
        // Sheet & Grid Layout
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lateral Form (Conditional)
              if (_mostrarFormulario)
                Container(
                  width: 420,
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: _corCard,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _isDarkMode ? Colors.grey[800]! : Colors.black12))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _editingId != null ? "Editar" : "Novo Cadastro",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _editingId != null ? Colors.orange[800] : const Color(0xFF0D47A1),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: _corTexto),
                                    onPressed: () {
                                      _limparForm();
                                      setState(() => _mostrarFormulario = false);
                                    },
                                    tooltip: "Fechar",
                                  )
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.only(top: 16, right: 16),
                                children: [
                                  _buildFormSectionHeader("Dados Pessoais", Icons.person_outline),
                                  TextFormField(
                                    controller: _nomeCtrl,
                                    style: TextStyle(color: _corTexto),
                                    decoration: const InputDecoration(labelText: "Nome Completo", prefixIcon: Icon(Icons.person)),
                                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _cpfCtrl,
                                          style: TextStyle(color: _corTexto),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [CpfInputFormatter()],
                                          decoration: const InputDecoration(labelText: "CPF", prefixIcon: Icon(Icons.badge), hintText: "000.000.000-00"),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _rgCtrl,
                                          style: TextStyle(color: _corTexto),
                                          decoration: const InputDecoration(labelText: "RG"),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _vinculoSelecionado,
                                    dropdownColor: _corCard,
                                    style: TextStyle(color: _corTexto),
                                    decoration: const InputDecoration(labelText: "Vínculo", prefixIcon: Icon(Icons.work)),
                                    items: ['Efetivo', 'Comissionado', 'Cedido', 'Estagiário']
                                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: _corTexto))))
                                        .toList(),
                                    onChanged: _onVinculoChanged,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFormSectionHeader("Dados Bancários", Icons.account_balance),
                                  TextFormField(
                                    controller: _bancoCtrl,
                                    style: TextStyle(color: _corTexto),
                                    decoration: const InputDecoration(labelText: "Banco", prefixIcon: Icon(Icons.account_balance)),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _agenciaCtrl,
                                          style: TextStyle(color: _corTexto),
                                          decoration: const InputDecoration(labelText: "Agência"),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _contaCtrl,
                                          style: TextStyle(color: _corTexto),
                                          decoration: const InputDecoration(labelText: "Conta"),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFormSectionHeader("Cargo & Atribuição", Icons.assignment_ind_outlined),
                                  DropdownButtonFormField<int>(
                                    value: _selectedCargoId,
                                    isExpanded: true,
                                    dropdownColor: _corCard,
                                    decoration: const InputDecoration(labelText: "Selecionar Cargo", prefixIcon: Icon(Icons.list_alt)),
                                    items: _cargos
                                        .map((c) => DropdownMenuItem<int>(
                                              value: c['id'],
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    "${c['nome']}",
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _corTexto),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    "${c['locacao'] ?? 'Sem Setor'} • ${c['percentual_padrao']}%",
                                                    style: TextStyle(fontSize: 11, color: _corSubTexto),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: _onCargoChanged,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _cargoManualCtrl,
                                    style: TextStyle(color: _corTexto),
                                    decoration: const InputDecoration(labelText: "Nome do Cargo"),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _locacaoCtrl,
                                    style: TextStyle(color: _corTexto),
                                    decoration: const InputDecoration(labelText: "Locação / Setor"),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFormSectionHeader("Valores & Descontos", Icons.monetization_on_outlined),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _percentualCtrl,
                                          style: TextStyle(color: _corTexto),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [DecimalInputFormatter()],
                                          decoration: const InputDecoration(labelText: "% Participação", suffixText: "%", prefixIcon: Icon(Icons.percent)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _sipesCtrl,
                                          style: TextStyle(color: _corTexto),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [CurrencyInputFormatter()],
                                          decoration: const InputDecoration(labelText: "SIPES Venc.", prefixIcon: Icon(Icons.money_off)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _irrfManualCtrl,
                                    style: TextStyle(color: _corTexto),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [CurrencyInputFormatter()],
                                    decoration: const InputDecoration(
                                      labelText: "IRRF Desconto Manual",
                                      helperText: "Vazio para cálculo automático",
                                      prefixIcon: Icon(Icons.request_quote, color: Colors.orange),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _pensaoCtrl,
                                          style: TextStyle(color: _corTexto),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [CurrencyInputFormatter()],
                                          decoration: const InputDecoration(labelText: "Pensão"),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _outrosCtrl,
                                          style: TextStyle(color: _corTexto),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [CurrencyInputFormatter()],
                                          decoration: const InputDecoration(labelText: "Outros Desc."),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _acrescimosCtrl,
                                          style: TextStyle(color: _corTexto),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [CurrencyInputFormatter()],
                                          decoration: const InputDecoration(
                                            labelText: "Acréscimos",
                                            prefixIcon: Icon(Icons.add_circle_outline, color: Colors.green),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _diasTrabalhadosCtrl,
                                          style: TextStyle(color: _corTexto),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: "Dias Trab.",
                                            prefixIcon: Icon(Icons.calendar_today, color: Colors.blue),
                                          ),
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return 'Obrigatório';
                                            final val = int.tryParse(v);
                                            if (val == null || val < 1 || val > 30) return '1 a 30 dias';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _isDarkMode ? Colors.grey[850]! : Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        CheckboxListTile(
                                          title: Text("Descontar Previdência", style: TextStyle(color: _corTexto)),
                                          secondary: Icon(Icons.account_circle, color: _isDarkMode ? Colors.white70 : Colors.black54),
                                          value: _temInss,
                                          onChanged: (v) => setState(() => _temInss = v!),
                                          activeColor: const Color(0xFF0D47A1),
                                        ),
                                        const Divider(height: 1),
                                        CheckboxListTile(
                                          title: Text("Previdência Própria (RPPS)", style: TextStyle(color: _corTexto)),
                                          secondary: const Icon(Icons.shield_outlined, color: Colors.blue),
                                          value: _previdenciaRpps,
                                          onChanged: (v) {
                                            setState(() {
                                              _previdenciaRpps = v!;
                                              if (!_previdenciaRpps) {
                                                _rppsValCtrl.clear();
                                              }
                                            });
                                          },
                                          activeColor: const Color(0xFF0D47A1),
                                        ),
                                        if (_previdenciaRpps)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                                            child: TextFormField(
                                              controller: _rppsValCtrl,
                                              decoration: InputDecoration(
                                                labelText: r"Valor RPPS (R$)",
                                                prefixText: r"R$ ",
                                                labelStyle: TextStyle(color: _corTexto),
                                                border: const OutlineInputBorder(),
                                              ),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(RegExp(r'^\d*,?\d*')),
                                              ],
                                              validator: (v) {
                                                if (_previdenciaRpps && (v == null || v.isEmpty)) {
                                                  return "Informe o valor do RPPS";
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        const Divider(height: 1),
                                        CheckboxListTile(
                                          title: Text("Descontar IRRF", style: TextStyle(color: _corTexto)),
                                          secondary: Icon(Icons.request_quote, color: _isDarkMode ? Colors.white70 : Colors.black54),
                                          value: _temIrrf,
                                          onChanged: (v) => setState(() => _temIrrf = v!),
                                          activeColor: const Color(0xFF0D47A1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _salvarOuAtualizar,
                                icon: Icon(_editingId != null ? Icons.save : Icons.add_circle),
                                label: Text(_editingId != null ? "SALVAR ALTERAÇÕES" : "ADICIONAR COLABORADOR"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _editingId != null ? Colors.orange[800] : const Color(0xFF0D47A1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Main data grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                  child: Card(
                    color: _corCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            border: Border(bottom: BorderSide(color: _isDarkMode ? Colors.grey[850]! : Colors.black12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people_alt, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Lista de Colaboradores (${rows.length})",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _corTexto),
                                  ),
                                ],
                              ),
                              if (!_mostrarFormulario && widget.userData['permissao'] != 'leitura')
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _limparForm();
                                    setState(() => _mostrarFormulario = true);
                                  },
                                  icon: const Icon(Icons.person_add, size: 16),
                                  label: const Text("Adicionar Novo Colaborador"),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(builder: (context, constraints) {
                            return Scrollbar(
                              controller: _horizontalScroll,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                controller: _horizontalScroll,
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight, minWidth: 1750),
                                  child: Scrollbar(
                                    controller: _verticalScroll,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _verticalScroll,
                                      scrollDirection: Axis.vertical,
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(_isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100]),
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
                          }),
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
    );
  }

  Widget _buildMiniInfoBox(String rotulo, double valor, Color cor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rotulo.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatMoeda(valor),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cor,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Colors.black12, height: 1),
        ],
      ),
    );
  }

  // ==========================================
  // 📅 TAB 3: FECHAMENTO & HISTÓRICO MENSAL
  // ==========================================
  Widget _buildFechamentoTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Painel de Fechamento (Esquerda)
          Expanded(
            flex: 3,
            child: Card(
              color: _corCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.archive_outlined, color: Colors.blue, size: 24),
                        const SizedBox(width: 8),
                        Text("Novo Fechamento", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _corTexto)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Realize a consolidação definitiva dos cálculos deste mês. O fechamento cria um registro histórico imutável para futuras consultas e auditorias.",
                      style: TextStyle(color: _corSubTexto, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: _mesFechamento,
                      dropdownColor: _corCard,
                      decoration: const InputDecoration(labelText: "Mês de Referência", prefixIcon: Icon(Icons.calendar_month)),
                      items: ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(color: _corTexto))))
                          .toList(),
                      onChanged: (v) => setState(() => _mesFechamento = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _anoFechamento,
                      dropdownColor: _corCard,
                      decoration: const InputDecoration(labelText: "Ano de Referência", prefixIcon: Icon(Icons.date_range)),
                      items: ['2025', '2026', '2027', '2028', '2029', '2030']
                          .map((y) => DropdownMenuItem(value: y, child: Text(y, style: TextStyle(color: _corTexto))))
                          .toList(),
                      onChanged: (v) => setState(() => _anoFechamento = v!),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_funcionarios.isEmpty) {
                          _mostrarSnack("Não há colaboradores para fechar a folha.", Colors.red);
                          return;
                        }
                        final mesAno = "$_mesFechamento/$_anoFechamento";

                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: _corCard,
                            title: Text("Confirmar Fechamento?", style: TextStyle(color: _corTexto)),
                            content: Text("Tem certeza que deseja consolidar a folha de $mesAno? Isso substituirá qualquer fechamento anterior deste mesmo período.", style: TextStyle(color: _corTexto)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  setState(() => _isLoading = true);

                                  // Coletar detalhes
                                  List<Map<String, dynamic>> historico = [];
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
                                      irrfManual: f['irrf_manual'] ?? 0.0,
                                      irrfSipesReal: f['irrf_sipes_real'] ?? 0.0,
                                      diasTrabalhados: f['dias_trabalhados'] ?? 30,
                                      previdenciaRpps: f['previdencia_rpps'] is num ? (f['previdencia_rpps'] as num).toDouble() : 0.0,
                                    );

                                    historico.add({
                                      'funcionario_id': f['id'],
                                      'nome': f['nome'],
                                      'cpf': f['cpf'],
                                      'cargo_nome': f['cargo_nome'],
                                      'locacao': f['locacao'],
                                      'vinculo': f['vinculo'],
                                      'percentual': f['percentual'],
                                      'valor_sipes': f['valor_sipes'],
                                      'pensao': f['pensao'],
                                      'outros': f['outros'],
                                      'acrescimos': f['acrescimos'],
                                      'bruto': calc['bruto'],
                                      'inss': calc['inss'],
                                      'irrf': calc['irrf'],
                                      'liquido': calc['liquido'],
                                      'dias_trabalhados': f['dias_trabalhados'] ?? 30,
                                      'previdencia_rpps': f['previdencia_rpps'] ?? 0.0,
                                    });
                                  }

                                  await DatabaseHelper.instance.fecharFolha(mesAno, widget.userData['usuario'], historico);
                                  await DatabaseHelper.instance.registrarLog(widget.userData['usuario'], 'FECHAMENTO_FOLHA', 'Realizou o fechamento da folha para o período: $mesAno');
                                  
                                  _mostrarSnackPremium("Folha de $mesAno consolidada com sucesso!", Icons.verified, Colors.green);
                                  _refreshTudo();
                                },
                                child: const Text("Confirmar Fechamento", style: TextStyle(color: Colors.green)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.task_alt, color: Colors.white),
                      label: const Text("SALVAR & FECHAR FOLHA"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Lista de Fechamentos (Direita)
          Expanded(
            flex: 5,
            child: Card(
              color: _corCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: Colors.blue, size: 24),
                        const SizedBox(width: 8),
                        Text("Histórico de Fechamentos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _corTexto)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _folhasSalvas.isEmpty
                          ? Center(
                              child: Text(
                                "Nenhuma folha fechada encontrada.",
                                style: TextStyle(color: _corSubTexto, fontStyle: FontStyle.italic),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _folhasSalvas.length,
                              itemBuilder: (context, index) {
                                final f = _folhasSalvas[index];
                                return Card(
                                  color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    title: Text(
                                      f['mes_ano'] ?? '',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: _corTexto),
                                    ),
                                    subtitle: Text(
                                      "Fechada em: ${f['data_fechamento']} por ${f['criado_por']}",
                                      style: TextStyle(fontSize: 11, color: _corSubTexto),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Visualizar
                                        IconButton(
                                          icon: const Icon(Icons.visibility, color: Colors.blue),
                                          tooltip: "Visualizar Memória Histórica",
                                          onPressed: () => _visualizarFolhaFechada(f['id'], f['mes_ano']),
                                        ),
                                        // Imprimir holerites consolidado
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, color: Colors.amber),
                                          tooltip: "Imprimir Holerites Históricos",
                                          onPressed: () => _imprimirTodosHoleritesFechados(f['id'], f['mes_ano']),
                                        ),
                                        // Imprimir Relatório consolidado
                                        IconButton(
                                          icon: const Icon(Icons.analytics_outlined, color: Colors.green),
                                          tooltip: "Imprimir Relatório de Repasse",
                                          onPressed: () => _imprimirRelatorioFechado(f['id'], f['mes_ano']),
                                        ),
                                        // Excluir
                                        if (widget.userData['permissao'] == 'admin')
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            tooltip: "Excluir Registro",
                                            onPressed: () async {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  backgroundColor: _corCard,
                                                  title: Text("Excluir Histórico?", style: TextStyle(color: _corTexto)),
                                                  content: Text("Tem certeza que deseja apagar permanentemente o fechamento de ${f['mes_ano']}?", style: TextStyle(color: _corTexto)),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                                                    TextButton(
                                                      onPressed: () async {
                                                        Navigator.pop(ctx);
                                                        await DatabaseHelper.instance.deleteFolhaSalva(f['id']);
                                                        await DatabaseHelper.instance.registrarLog(widget.userData['usuario'], 'EXCLUIR_HISTORICO', 'Excluiu o registro da folha de: ${f['mes_ano']}');
                                                        _mostrarSnackPremium("Histórico excluído!", Icons.delete, Colors.red);
                                                        _refreshTudo();
                                                      },
                                                      child: const Text("Sim, Excluir", style: TextStyle(color: Colors.red)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _visualizarFolhaFechada(int folhaId, String mesAno) async {
    final list = await DatabaseHelper.instance.readFolhaDetalhes(folhaId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _corCard,
        title: Text("Visualização Histórica: Folha de $mesAno", style: TextStyle(color: _corTexto)),
        content: SizedBox(
          width: 800,
          height: 450,
          child: list.isEmpty
              ? const Center(child: Text("Nenhum detalhe encontrado para este período."))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Card(
                      color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(item['nome'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: _corTexto)),
                        subtitle: Text(
                          "Cargo: ${item['cargo_nome']} • Vínculo: ${item['vinculo']}",
                          style: TextStyle(fontSize: 11, color: _corSubTexto),
                        ),
                        trailing: Text(
                          "Líquido: ${_formatMoeda(item['liquido'])}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar")),
        ],
      ),
    );
  }

  Future<void> _imprimirTodosHoleritesFechados(int folhaId, String mesAno) async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.readFolhaDetalhes(folhaId);
    setState(() => _isLoading = false);

    if (list.isEmpty) {
      _mostrarSnack("Nenhum colaborador nesta folha.", Colors.red);
      return;
    }

    // Criamos um PDF multi-páginas para os holerites históricos
    final pdf = pw.Document();

    for (var item in list) {
      final colabMap = {
        'nome': item['nome'],
        'cpf': item['cpf'],
        'cargo_nome': item['cargo_nome'],
        'locacao': item['locacao'],
        'banco': '-', 'agencia': '-', 'conta': '-', // Valores estáticos no histórico
        'vinculo': item['vinculo'],
        'percentual': item['percentual'] ?? 0.0,
      };

      final calcMap = {
        'bruto': item['bruto'],
        'inss': item['inss'],
        'irrf': item['irrf'],
        'pensao': item['pensao'],
        'outros': item['outros'],
        'acrescimos': item['acrescimos'],
        'liquido': item['liquido'],
        'base_global_bruta': item['bruto'] + item['valor_sipes'],
        'base_irrf': item['bruto'] + item['valor_sipes'] - item['inss'],
        'sipes': item['valor_sipes'] ?? 0.0,
        'dias_trabalhados': item['dias_trabalhados'] ?? 30,
        'previdencia_rpps': (item['previdencia_rpps'] ?? 0) == 1,
      };

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                GeradorPdf.buildVia(colabMap, calcMap, mesAno, "VIA DO COLABORADOR"),
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
                GeradorPdf.buildVia(colabMap, calcMap, mesAno, "VIA DO ITPS (ARQUIVO RH)"),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Holerites_Todos_$mesAno.pdf',
    );
  }

  Future<void> _imprimirRelatorioFechado(int folhaId, String mesAno) async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.readFolhaDetalhes(folhaId);
    setState(() => _isLoading = false);

    if (list.isEmpty) {
      _mostrarSnack("Nenhum colaborador nesta folha.", Colors.red);
      return;
    }

    // Adaptar para as chamadas do gerador de PDF
    List<Map<String, dynamic>> colaboradores = [];
    List<Map<String, dynamic>> calculos = [];

    for (var item in list) {
      colaboradores.add({
        'nome': item['nome'],
        'cpf': item['cpf'],
        'cargo_nome': item['cargo_nome'],
        'locacao': item['locacao'],
      });

      calculos.add({
        'bruto': item['bruto'],
        'inss': item['inss'],
        'irrf': item['irrf'],
        'pensao': item['pensao'],
        'outros': item['outros'],
        'acrescimos': item['acrescimos'],
        'liquido': item['liquido'],
      });
    }

    await GeradorPdf.gerarERelatorioConsolidado(colaboradores, calculos, mesAno);
  }

  // ==========================================
  // 🔍 TAB 4: AUDITORIA DE AÇÕES (LOGS)
  // ==========================================
  Widget _buildAuditoriaTab() {
    // Filtragem dos logs
    final logsExibidos = _filtroAuditoria.isEmpty
        ? _logsAuditoria
        : _logsAuditoria
            .where((l) =>
                l['usuario'].toString().toLowerCase().contains(_filtroAuditoria.toLowerCase()) ||
                l['acao'].toString().toLowerCase().contains(_filtroAuditoria.toLowerCase()) ||
                l['detalhes'].toString().toLowerCase().contains(_filtroAuditoria.toLowerCase()))
            .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        color: _corCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: Colors.blue, size: 24),
                      const SizedBox(width: 8),
                      Text("Logs de Auditoria", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _corTexto)),
                    ],
                  ),
                  Row(
                    children: [
                      // Barra de busca
                      SizedBox(
                        width: 250,
                        height: 40,
                        child: TextField(
                          style: TextStyle(color: _corTexto, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "Buscar logs...",
                            hintStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                          ),
                          onChanged: (v) => setState(() => _filtroAuditoria = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.userData['permissao'] == 'admin')
                        ElevatedButton.icon(
                          onPressed: () async {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: _corCard,
                                title: Text("Limpar Trilha?", style: TextStyle(color: _corTexto)),
                                content: Text("Tem certeza que deseja apagar permanentemente todos os registros de auditoria?", style: TextStyle(color: _corTexto)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await DatabaseHelper.instance.limparLogs();
                                      await DatabaseHelper.instance.registrarLog(widget.userData['usuario'], 'LIMPAR_AUDITORIA', 'Apagou todo o histórico de logs de auditoria do sistema.');
                                      _mostrarSnackPremium("Logs apagados!", Icons.delete_forever, Colors.red);
                                      _refreshTudo();
                                    },
                                    child: const Text("Confirmar Limpeza", style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_forever, size: 16),
                          label: const Text("Limpar logs"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: logsExibidos.isEmpty
                    ? Center(
                        child: Text(
                          "Nenhum log encontrado.",
                          style: TextStyle(color: _corSubTexto, fontStyle: FontStyle.italic),
                        ),
                      )
                    : ListView.separated(
                        itemCount: logsExibidos.length,
                        separatorBuilder: (context, index) => Divider(color: _isDarkMode ? Colors.grey[850]! : Colors.grey[200]!),
                        itemBuilder: (context, index) {
                          final log = logsExibidos[index];
                          Color badgeColor = Colors.grey;
                          if (log['acao'].toString().contains('CADAS')) {
                            badgeColor = Colors.green;
                          } else if (log['acao'].toString().contains('REMOV') || log['acao'].toString().contains('EXCLU')) {
                            badgeColor = Colors.red;
                          } else if (log['acao'].toString().contains('EDIT')) {
                            badgeColor = Colors.blue;
                          } else if (log['acao'].toString().contains('FECHA')) {
                            badgeColor = Colors.purple;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Data / Hora
                                Container(
                                  width: 140,
                                  child: Text(
                                    log['data_hora'] ?? '',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Badge Ação
                                Container(
                                  width: 160,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    log['acao'] ?? '',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Usuário
                                Container(
                                  width: 90,
                                  child: Text(
                                    log['usuario'].toString().toUpperCase(),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _corTexto, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Detalhes
                                Expanded(
                                  child: Text(
                                    log['detalhes'] ?? '',
                                    style: TextStyle(color: _corTexto, fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FORMATAÇÃO AUXILIAR ---
  String _formatMoeda(dynamic val) {
    if (val == null) return "R\$ 0,00";
    double numVal = 0.0;
    if (val is double) numVal = val;
    if (val is int) numVal = val.toDouble();
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return formatter.format(numVal);
  }

  double _parseMoeda(String text) {
    if (text.isEmpty) return 0.0;
    String clean = text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}

class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    // Permite números, pontos e vírgulas em qualquer ordem.
    // O _parseMoeda cuida de limpar e converter depois.
    // Isso permite apagar caracteres um por um mesmo com a máscara ativada.
    final regExp = RegExp(r'^[0-9.,]*$');
    if (regExp.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Se o usuário apagar tudo, deixa apagar
    if (newValue.text.isEmpty) return newValue;

    if (newValue.selection.baseOffset == 0) return newValue;
    String text = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    if (text.isEmpty) return const TextEditingValue(text: "");

    double value = double.parse(text);
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    String newText = formatter.format(value / 100);
    return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length));
  }
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 11) text = text.substring(0, 11);
    var newText = "";
    for (var i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) newText += ".";
      if (i == 9) newText += "-";
      newText += text[i];
    }
    return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length));
  }
}

class ConfigScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic> userData;
  final VoidCallback onSave;
  const ConfigScreen({super.key, required this.data, required this.onSave, required this.userData});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _baseCtrl = TextEditingController();
  final TextEditingController _patronalCtrl = TextEditingController();
  List<Map<String, dynamic>> _cargosLocais = [];
  List<Map<String, dynamic>> _tabelaInss = [];
  List<Map<String, dynamic>> _tabelaIrrf = [];
  bool _isLoadingConfig = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: widget.userData['permissao'] == 'admin' ? 4 : 3, vsync: this);
    _carregarDados();
    if (widget.userData['permissao'] == 'admin') _carregarUsuarios();
  }

  List<Map<String, dynamic>> _usuarios = [];
  void _carregarUsuarios() async {
    final users = await DatabaseHelper.instance.readUsuarios();
    setState(() => _usuarios = users);
  }

  void _abrirDialogoUsuario() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String permissao = 'leitura';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Novo Usuário"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: "Usuário")),
              const SizedBox(height: 12),
              TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: "Senha")),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: permissao,
                decoration: const InputDecoration(labelText: "Permissão"),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text("Admin (Tudo)")),
                  DropdownMenuItem(
                      value: 'editor', child: Text("Editor (Edita Dados)")),
                  DropdownMenuItem(
                      value: 'leitura', child: Text("Leitura (Só vê)")),
                ],
                onChanged: (v) => setDialogState(() => permissao = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () async {
                  if (userCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                    await DatabaseHelper.instance.createUsuario({
                      'usuario': userCtrl.text,
                      'senha': passCtrl.text,
                      'permissao': permissao,
                    });
                    _carregarUsuarios();
                    if (mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("Salvar")),
          ],
        ),
      ),
    );
  }

  void _carregarDados() async {
    setState(() {
      _isLoadingConfig = true;
      _loadError = false;
    });

    try {
      final configs = await DatabaseHelper.instance.loadFullConfig();
      final cargos = await DatabaseHelper.instance.readCargos();
      double base = configs['geral']['base_convenio'] ??
          widget.data['geral']['base_convenio'] ??
          210000.00;
      double patronal = configs['geral']['aliquota_patronal'] ??
          widget.data['geral']['aliquota_patronal'] ??
          9.02;

      final brFormat = NumberFormat.currency(locale: 'pt_BR', symbol: '');
      setState(() {
        String novaBase = brFormat.format(base).trim();
        if (_baseCtrl.text.isEmpty) _baseCtrl.text = novaBase;

        String novoPatr = brFormat.format(patronal).trim();
        if (_patronalCtrl.text.isEmpty) _patronalCtrl.text = novoPatr;

        _cargosLocais = List.from(cargos);
        _tabelaInss = configs['inss'].isNotEmpty
            ? List.from(configs['inss'])
            : List.from(widget.data['inss'] ?? []);
        _tabelaIrrf = configs['irrf'].isNotEmpty
            ? List.from(configs['irrf'])
            : List.from(widget.data['irrf'] ?? []);
        _isLoadingConfig = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = true;
        _isLoadingConfig = false;
        _tabelaInss = List.from(widget.data['inss'] ?? []);
        _tabelaIrrf = List.from(widget.data['irrf'] ?? []);
        _cargosLocais = [];
      });
    }
  }

  Future<void> _salvarGeral() async {
    await DatabaseHelper.instance
        .updateConfigValor('base_convenio', _parseMoeda(_baseCtrl.text));
    await DatabaseHelper.instance.updateConfigValor(
        'aliquota_patronal', _parseMoeda(_patronalCtrl.text));
    if (!mounted) return;
    widget.onSave();
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Configurações salvas!")));
  }

  Future<void> _editarFaixaInss(Map<String, dynamic> item) async {
    final brFormat = NumberFormat.currency(locale: 'pt_BR', symbol: '');
    final limiteCtrl =
        TextEditingController(text: brFormat.format(item['limite']).trim());
    final aliquotaCtrl =
        TextEditingController(text: brFormat.format(item['aliquota']).trim());
    final deducaoCtrl = TextEditingController(
        text: brFormat.format(item['deducao'] ?? 0.0).trim());
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Editar Faixa INSS"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: limiteCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter()],
                    decoration:
                        const InputDecoration(labelText: "Limite (R\$)")),
                const SizedBox(height: 10),
                TextField(
                    controller: aliquotaCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter()],
                    decoration:
                        const InputDecoration(labelText: "Alíquota (%)")),
                const SizedBox(height: 10),
                TextField(
                    controller: deducaoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter()],
                    decoration:
                        const InputDecoration(labelText: "Dedução (R\$)")),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar")),
                TextButton(
                    onPressed: () async {
                      await DatabaseHelper.instance.updateTabelaInss(
                        item['id'],
                        double.tryParse(limiteCtrl.text.replaceAll(',', '.')) ??
                            0.0,
                        double.tryParse(
                                aliquotaCtrl.text.replaceAll(',', '.')) ??
                            0.0,
                        double.tryParse(
                                deducaoCtrl.text.replaceAll(',', '.')) ??
                            0.0,
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        _carregarDados();
                        widget.onSave();
                      }
                    },
                    child: const Text("Salvar"))
              ],
            ));
  }

  Future<void> _editarFaixaIrrf(Map<String, dynamic> item) async {
    final brFormat = NumberFormat.currency(locale: 'pt_BR', symbol: '');
    final limiteCtrl =
        TextEditingController(text: brFormat.format(item['limite']).trim());
    final aliquotaCtrl =
        TextEditingController(text: brFormat.format(item['aliquota']).trim());
    final deducaoCtrl =
        TextEditingController(text: brFormat.format(item['deducao']).trim());
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Editar Faixa IRRF"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: limiteCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter()],
                    decoration:
                        const InputDecoration(labelText: "Limite (R\$)")),
                const SizedBox(height: 10),
                TextField(
                    controller: aliquotaCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter()],
                    decoration:
                        const InputDecoration(labelText: "Alíquota (%)")),
                const SizedBox(height: 10),
                TextField(
                    controller: deducaoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter()],
                    decoration:
                        const InputDecoration(labelText: "Dedução (R\$)"))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar")),
                TextButton(
                    onPressed: () async {
                      await DatabaseHelper.instance.updateTabelaIrrf(
                          item['id'],
                          double.tryParse(
                                  limiteCtrl.text.replaceAll(',', '.')) ??
                              0.0,
                          double.tryParse(
                                  aliquotaCtrl.text.replaceAll(',', '.')) ??
                              0.0,
                          double.tryParse(
                                  deducaoCtrl.text.replaceAll(',', '.')) ??
                              0.0);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        _carregarDados();
                        widget.onSave();
                      }
                    },
                    child: const Text("Salvar"))
              ],
            ));
  }

  // Função que serve tanto para CRIAR quanto para EDITAR cargos
  Future<void> _abrirDialogoCargo({Map<String, dynamic>? cargo}) async {
    final brFormat = NumberFormat.currency(locale: 'pt_BR', symbol: '');
    final nomeCtrl = TextEditingController(text: cargo?['nome'] ?? '');
    final locacaoCtrl = TextEditingController(text: cargo?['locacao'] ?? '');
    final percCtrl = TextEditingController(
        text: cargo != null
            ? brFormat.format(cargo['percentual_padrao']).trim()
            : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cargo == null ? "Novo Cargo" : "Editar Cargo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: "Nome do Cargo")),
            const SizedBox(height: 10),
            TextField(
                controller: locacaoCtrl,
                decoration:
                    const InputDecoration(labelText: "Locação/Setor Padrão")),
            const SizedBox(height: 10),
            TextField(
                controller: percCtrl,
                decoration: const InputDecoration(labelText: "Percentual (%)"),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter()]),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              final dados = {
                'nome': nomeCtrl.text,
                'locacao': locacaoCtrl.text,
                'percentual_padrao':
                    double.tryParse(percCtrl.text.replaceAll(',', '.')) ?? 0.0
              };

              if (cargo == null) {
                await DatabaseHelper.instance.createCargo(dados);
              } else {
                dados['id'] = cargo['id'];
                await DatabaseHelper.instance.updateCargo(dados);
              }

              if (!context.mounted) return;
              Navigator.pop(ctx);
              _carregarDados();
              widget.onSave();
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  Future<void> _deletarCargo(int id) async {
    await DatabaseHelper.instance.deleteCargo(id);
    _carregarDados();
    widget.onSave();
  }

  Future<void> _resetarTabelas() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Resetar Tabelas?"),
        content: const Text(
            "Isso irá substituir todas as faixas de INSS e IRRF pelos valores oficiais de 2026. Deseja continuar?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Resetar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar == true) {
      await DatabaseHelper.instance.resetTabelasFiscais();
      _carregarDados();
      widget.onSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tabelas resetadas com sucesso!")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfig) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError) {
      return Scaffold(
        appBar: AppBar(title: const Text("Configurações")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: Colors.redAccent),
                const SizedBox(height: 20),
                const Text(
                  'Erro ao carregar as configurações.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tente novamente ou reinicie o aplicativo. Os valores padrão serão carregados caso a leitura do banco falhe.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _carregarDados,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Configurações",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0D47A1),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: const Color(0xFF0D47A1),
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            const Tab(text: "Geral", icon: Icon(Icons.settings_outlined)),
            const Tab(text: "Tabelas", icon: Icon(Icons.table_chart_outlined)),
            const Tab(text: "Cargos", icon: Icon(Icons.badge_outlined)),
            if (widget.userData['permissao'] == 'admin')
              const Tab(text: "Usuários", icon: Icon(Icons.people_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeralTab(),
          _buildTabelasTab(),
          _buildCargosTab(),
          if (widget.userData['permissao'] == 'admin') _buildUsuariosTab(),
        ],
      ),
    );
  }

  Widget _buildGeralTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        color: Colors.blue[800]),
                    const SizedBox(width: 12),
                    const Text("Valores Base do Sistema",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Configure os parâmetros globais para o cálculo da folha.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                TextField(
                  controller: _baseCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Base Convênio (R\$)",
                    prefixIcon: Icon(Icons.money),
                    hintText: "0,00",
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _patronalCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Patronal (%)",
                    prefixIcon: Icon(Icons.percent),
                    hintText: "0,00",
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _salvarGeral,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("SALVAR CONFIGURAÇÕES",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabelasTab() {
    return LayoutBuilder(builder: (context, constraints) {
      bool isWide = constraints.maxWidth > 900;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Parâmetros Fiscais",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      Text("Valores sincronizados com a tabela oficial de 2026.",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _resetarTabelas,
                  icon: const Icon(Icons.refresh),
                  label: const Text("RESETAR PARA 2026"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _buildTableCard("Tabela INSS", _tabelaInss, true)),
                      const SizedBox(width: 24),
                      Expanded(
                          child: _buildTableCard("Tabela IRRF", _tabelaIrrf, false)),
                    ],
                  )
                : Column(
                    children: [
                      _buildTableCard("Tabela INSS", _tabelaInss, true),
                      const SizedBox(height: 16),
                      _buildTableCard("Tabela IRRF", _tabelaIrrf, false),
                    ],
                  ),
          ],
        ),
      );
    });
  }

  Widget _buildTableCard(
      String title, List<Map<String, dynamic>> data, bool isInss) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(isInss ? Icons.security : Icons.request_quote,
                    color: isInss ? Colors.green[700] : Colors.red[700],
                    size: 20),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text("${data.length} faixas",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const Divider(height: 1),
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: Text("Nenhuma faixa cadastrada",
                      style: TextStyle(color: Colors.grey))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = data[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(
                    "Até ${_formatMoeda(r['limite'])}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${r['aliquota']}%",
                            style: TextStyle(
                                color: Colors.blue[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Dedução: ${_formatMoeda(r['deducao'] ?? 0.0)}",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_note, size: 22),
                      color: const Color(0xFF0D47A1),
                      onPressed: () =>
                          isInss ? _editarFaixaInss(r) : _editarFaixaIrrf(r),
                      tooltip: "Editar Faixa",
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCargosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Gestão de Cargos",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("Gerencie os cargos e seus percentuais padrão.",
                        style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _abrirDialogoCargo(),
                icon: const Icon(Icons.add),
                label: const Text("NOVO CARGO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _cargosLocais.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text("Nenhum cargo cadastrado",
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _cargosLocais.length,
                  itemBuilder: (ctx, i) {
                    final c = _cargosLocais[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[50],
                          child: Icon(Icons.work_outline,
                              color: Colors.blue[800], size: 20),
                        ),
                        title: Text(c['nome'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "${c['locacao'] ?? 'Sem setor'} • ${c['percentual_padrao']}%",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon:
                                    const Icon(Icons.edit_note, size: 24),
                                color: Colors.blue[700],
                                onPressed: () => _abrirDialogoCargo(cargo: c),
                                tooltip: "Editar"),
                            IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 24),
                                color: Colors.red[400],
                                onPressed: () => _deletarCargo(c['id']),
                                tooltip: "Excluir"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUsuariosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Usuários do Sistema",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("Gerencie quem pode acessar e editar a folha.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _abrirDialogoUsuario,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text("NOVO USUÁRIO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _usuarios.length,
            itemBuilder: (ctx, idx) {
              final u = _usuarios[idx];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        const Color(0xFF0D47A1).withValues(alpha: 0.1),
                    child: const Icon(Icons.person_outline,
                        color: Color(0xFF0D47A1)),
                  ),
                  title: Text(u['usuario'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "Nível: ${u['permissao'].toString().toUpperCase()}"),
                  trailing: u['usuario'] == 'admin'
                      ? const Chip(label: Text("Sistema"))
                      : IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () async {
                            await DatabaseHelper.instance
                                .deleteUsuario(u['id']);
                            _carregarUsuarios();
                          },
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  void _tentarLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await DatabaseHelper.instance.login(
        _userCtrl.text.trim(),
        _passCtrl.text.trim(),
      );

      if (user != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(userData: user),
          ),
        );
      } else {
        setState(() => _error = "Usuário ou senha inválidos");
      }
    } catch (e) {
      setState(() => _error = "Erro ao conectar ao banco: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person, size: 64, color: Color(0xFF0D47A1)),
              const SizedBox(height: 24),
              const Text(
                "Sistema Folha ITPS",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text("Faça login para continuar", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: "Usuário",
                  prefixIcon: Icon(Icons.person),
                ),
                onSubmitted: (_) => _tentarLogin(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Senha",
                  prefixIcon: Icon(Icons.key),
                ),
                onSubmitted: (_) => _tentarLogin(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _tentarLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === UTILITÁRIOS GLOBAIS DE FORMATAÇÃO ===

final _moneyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

double _parseMoeda(String text) {
  if (text.isEmpty) return 0.0;
  String clean = text.replaceAll('R\$', '').trim();
  if (clean.contains(',') && clean.contains('.')) {
    clean = clean.replaceAll('.', '');
    clean = clean.replaceAll(',', '.');
  } else {
    clean = clean.replaceAll(',', '.');
  }
  return double.tryParse(clean) ?? 0.0;
}

String _formatMoeda(double? valor) {
  if (valor == null) return "R\$ 0,00";
  return _moneyFormatter.format(valor);
}
