import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
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
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  final _agenciaCtrl = TextEditingController();
  final _contaCtrl = TextEditingController();
  final _cargoManualCtrl = TextEditingController();
  final _locacaoCtrl = TextEditingController();
  final _percentualCtrl = TextEditingController();
  final _sipesCtrl = TextEditingController(); 
  
  // Vínculo
  String _vinculoSelecionado = 'Efetivo'; // Valor padrão
  
  int? _selectedCargoId;
  bool _temInss = true;
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
        'vinculo': _vinculoSelecionado, // SALVA O VINCULO
        'banco': _bancoCtrl.text,
        'agencia': _agenciaCtrl.text,
        'conta': _contaCtrl.text,
        'cargo_nome': _cargoManualCtrl.text,
        'locacao': _locacaoCtrl.text,
        'percentual': double.tryParse(_percentualCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'valor_sipes': double.tryParse(_sipesCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'tem_inss': _temInss ? 1 : 0,
        'tem_irrf': _temIrrf ? 1 : 0,
      };

      if (_editingId == null) {
        await DatabaseHelper.instance.createFuncionario(dados);
      } else {
        dados['id'] = _editingId!;
        await DatabaseHelper.instance.updateFuncionario(dados);
      }
      _limparForm();
      _refreshTudo();
    }
  }

  void _carregarParaEdicao(Map<String, dynamic> f) {
    setState(() {
      _editingId = f['id'];
      _nomeCtrl.text = f['nome'];
      _cpfCtrl.text = f['cpf'];
      _vinculoSelecionado = f['vinculo'] ?? 'Efetivo'; // CARREGA VINCULO
      _bancoCtrl.text = f['banco'] ?? '';
      _agenciaCtrl.text = f['agencia'] ?? '';
      _contaCtrl.text = f['conta'] ?? '';
      _cargoManualCtrl.text = f['cargo_nome'] ?? '';
      _locacaoCtrl.text = f['locacao'] ?? '';
      _percentualCtrl.text = f['percentual'].toString();
      _sipesCtrl.text = f['valor_sipes'].toString();
      _temInss = f['tem_inss'] == 1;
      _temIrrf = f['tem_irrf'] == 1;
      _selectedCargoId = null; 
    });
  }

  void _limparForm() {
    _nomeCtrl.clear(); _cpfCtrl.clear(); _bancoCtrl.clear();
    _agenciaCtrl.clear(); _contaCtrl.clear(); _percentualCtrl.clear();
    _cargoManualCtrl.clear(); _locacaoCtrl.clear(); _sipesCtrl.clear();
    setState(() {
      _editingId = null;
      _selectedCargoId = null;
      _vinculoSelecionado = 'Efetivo';
      _temInss = true;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    double totalBruto = 0, totalLiq = 0;
    final List<DataRow> rows = [];
    double baseAtual = _configData!['geral']['base_convenio'];

    for (var f in _funcionarios) {
      final calc = CalculadoraTaxas.calcularFolha(
        percentual: f['percentual'],
        valorSipes: f['valor_sipes'],
        temInss: f['tem_inss'] == 1,
        temIrrf: f['tem_irrf'] == 1,
        configData: _configData!,
      );
      totalBruto += calc['bruto'];
      totalLiq += calc['liquido'];

      rows.add(DataRow(cells: [
        DataCell(Text(f['nome'])),
        DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(f['cargo_nome'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(f['locacao'] ?? '-', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        DataCell(Text(f['vinculo'] ?? '-')), // COLUNA VINCULO
        DataCell(Text(_money.format(f['valor_sipes']))),
        DataCell(Text("${f['percentual']}%")),
        DataCell(Text(_money.format(calc['bruto']))),
        DataCell(Text(f['tem_inss'] == 1 ? _money.format(calc['inss']) : "-", style: TextStyle(color: f['tem_inss'] == 1 ? Colors.red : Colors.grey))),
        DataCell(Text(f['tem_irrf'] == 1 ? _money.format(calc['irrf']) : "-", style: TextStyle(color: f['tem_irrf'] == 1 ? Colors.red : Colors.grey))),
        DataCell(Text(_money.format(calc['liquido']), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        DataCell(Row(
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _carregarParaEdicao(f)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
              await DatabaseHelper.instance.deleteFuncionario(f['id']);
              _refreshTudo();
            }),
          ],
        )),
      ]));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema Folha ITPS'),
        backgroundColor: _editingId != null ? Colors.orange : Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConfigScreen(data: _configData!, onSave: _refreshTudo))),
              icon: const Icon(Icons.settings),
              label: const Text("Configurações"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          // LADO ESQUERDO: FORMULÁRIO
          SizedBox(
            width: 380,
            child: Card(
              margin: const EdgeInsets.all(10),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_editingId != null ? "Editar Funcionário" : "Novo Cadastro", 
                               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _editingId != null ? Colors.orange : Colors.indigo)),
                          if (_editingId != null) 
                            TextButton.icon(icon: const Icon(Icons.close), label: const Text("Cancelar"), onPressed: _limparForm)
                        ],
                      ),
                      const SizedBox(height: 15),
                      TextFormField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome Completo", border: OutlineInputBorder()), validator: (v)=>v!.isEmpty?'Obrigatório':null),
                      const SizedBox(height: 10),
                      TextFormField(controller: _cpfCtrl, decoration: const InputDecoration(labelText: "CPF", border: OutlineInputBorder())),
                      
                      const SizedBox(height: 10),
                      // NOVO: DROPDOWN VINCULO
                      DropdownButtonFormField<String>(
                        value: _vinculoSelecionado,
                        decoration: const InputDecoration(labelText: "Vínculo", border: OutlineInputBorder()),
                        items: ['Efetivo', 'Comissionado', 'Cedido'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _vinculoSelecionado = v!),
                      ),
                      
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _bancoCtrl, decoration: const InputDecoration(labelText: "Banco", border: OutlineInputBorder()))),
                        const SizedBox(width: 5),
                        Expanded(child: TextFormField(controller: _agenciaCtrl, decoration: const InputDecoration(labelText: "Agência", border: OutlineInputBorder()))),
                      ]),
                      const SizedBox(height: 10),
                      TextFormField(controller: _contaCtrl, decoration: const InputDecoration(labelText: "Conta", border: OutlineInputBorder())),
                      
                      const Divider(height: 30),
                      
                      DropdownButtonFormField<int>(
                        value: _selectedCargoId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: "Selecionar Cargo (Lista Oficial)", border: OutlineInputBorder()),
                        items: _cargos.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text("${c['nome']}", overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: _onCargoChanged,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: _cargoManualCtrl, decoration: const InputDecoration(labelText: "Cargo", border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextFormField(controller: _locacaoCtrl, decoration: const InputDecoration(labelText: "Locação", border: OutlineInputBorder())),
                      
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _percentualCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: "Percentual (%)", suffixText: "%", border: OutlineInputBorder()),
                              validator: (v)=>v!.isEmpty?'Necessário':null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _sipesCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: "Folha SIPES", prefixText: "R\$ ", border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: CheckboxListTile(title: const Text("INSS"), value: _temInss, onChanged: (v)=>setState(()=>_temInss=v!), contentPadding: EdgeInsets.zero)),
                          Expanded(child: CheckboxListTile(title: const Text("IRRF"), value: _temIrrf, onChanged: (v)=>setState(()=>_temIrrf=v!), contentPadding: EdgeInsets.zero)),
                        ],
                      ),

                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _salvarOuAtualizar, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _editingId != null ? Colors.orange : Colors.indigo, 
                          foregroundColor: Colors.white, padding: const EdgeInsets.all(18)
                        ), 
                        child: Text(_editingId != null ? "ATUALIZAR DADOS" : "CADASTRAR")
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // LADO DIREITO: TABELA
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.indigo[50],
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("Base: ${_money.format(baseAtual)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Bruto Total: ${_money.format(totalBruto)}"),
                      Text("Líquido Total: ${_money.format(totalLiq)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(child: SingleChildScrollView(child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(label: Text("Nome")), 
                    DataColumn(label: Text("Cargo/Locação")), 
                    DataColumn(label: Text("Vínculo")), // NOVA COLUNA
                    DataColumn(label: Text("SIPES")), 
                    DataColumn(label: Text("%")), 
                    DataColumn(label: Text("Bruto")), 
                    DataColumn(label: Text("INSS")), 
                    DataColumn(label: Text("IRRF")), 
                    DataColumn(label: Text("Líquido")), 
                    DataColumn(label: Text("Ações"))
                  ],
                  rows: rows,
                )))
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// TELA DE CONFIGURAÇÕES (COMPLETA)
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

  List<Map<String, dynamic>> _cargosLocais = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final g = widget.data['geral'];
    _baseCtrl = TextEditingController(text: g['base_convenio'].toString());
    _tetoInssCtrl = TextEditingController(text: g['teto_inss'].toString());
    _carregarCargos();
  }

  Future<void> _carregarCargos() async {
    final c = await DatabaseHelper.instance.readCargos();
    setState(() {
      _cargosLocais = List.from(c);
    });
  }

  Future<void> _salvarGeral() async {
    await DatabaseHelper.instance.updateConfigValor('base_convenio', double.parse(_baseCtrl.text));
    await DatabaseHelper.instance.updateConfigValor('teto_inss', double.parse(_tetoInssCtrl.text));
    if (!mounted) return;
    widget.onSave();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configurações salvas!")));
  }

  Future<void> _adicionarCargo() async {
    final nomeCtrl = TextEditingController();
    final percCtrl = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Novo Cargo"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Nome")),
        TextField(controller: percCtrl, decoration: const InputDecoration(labelText: "%"), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
        TextButton(onPressed: () async {
          await DatabaseHelper.instance.createCargo({
            'nome': nomeCtrl.text,
            'percentual_padrao': double.tryParse(percCtrl.text) ?? 0.0
          });
          if (mounted) Navigator.pop(ctx);
          _carregarCargos();
          widget.onSave();
        }, child: const Text("Salvar"))
      ],
    ));
  }

  Future<void> _deletarCargo(int id) async {
    await DatabaseHelper.instance.deleteCargo(id);
    _carregarCargos();
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurações do Sistema"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Geral"),
            Tab(text: "Tabelas"),
            Tab(text: "Cargos"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ABA GERAL
          ListView(padding: const EdgeInsets.all(20), children: [
            const Text("Valores Base", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            TextField(controller: _baseCtrl, decoration: const InputDecoration(labelText: "Valor Base Convênio (R\$)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _tetoInssCtrl, decoration: const InputDecoration(labelText: "Teto Máximo INSS (R\$)", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _salvarGeral, child: const Text("SALVAR ALTERAÇÕES"))
          ]),

          // ABA TABELAS
          ListView(padding: const EdgeInsets.all(20), children: [
            const Text("Tabela INSS", style: TextStyle(fontWeight: FontWeight.bold)),
            ...(widget.data['inss'] as List).map((r) => ListTile(title: Text("Até R\$ ${r['limite']}"), subtitle: Text("${r['aliquota']}%"))).toList(),
            const Divider(),
            const Text("Tabela IRRF", style: TextStyle(fontWeight: FontWeight.bold)),
            ...(widget.data['irrf'] as List).map((r) => ListTile(title: Text("Até R\$ ${r['limite']}"), subtitle: Text("${r['aliquota']}% (Ded: ${r['deducao']})"))).toList(),
          ]),

          // ABA CARGOS
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: ElevatedButton.icon(onPressed: _adicionarCargo, icon: const Icon(Icons.add), label: const Text("Adicionar Novo Cargo")),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _cargosLocais.length,
                  itemBuilder: (ctx, i) {
                    final c = _cargosLocais[i];
                    return ListTile(
                      title: Text(c['nome']),
                      subtitle: Text("Percentual Padrão: ${c['percentual_padrao']}%"),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deletarCargo(c['id'])),
                    );
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}