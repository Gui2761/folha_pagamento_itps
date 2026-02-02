import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('folha_itps_v9_completo.db'); // Versão 9
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. Cargos
    await db.execute('''
      CREATE TABLE cargos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        percentual_padrao REAL NOT NULL
      )
    ''');

    // 2. Funcionários (COM NOVOS CAMPOS DE DESCONTOS)
    await db.execute('''
      CREATE TABLE funcionarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        cpf TEXT NOT NULL,
        rg TEXT,             -- NOVO: RG
        vinculo TEXT NOT NULL,
        banco TEXT,
        agencia TEXT,
        conta TEXT,
        cargo_nome TEXT,
        locacao TEXT,
        percentual REAL NOT NULL,
        valor_sipes REAL DEFAULT 0.0,
        pensao REAL DEFAULT 0.0,  -- NOVO: Pensão Alimentícia
        outros REAL DEFAULT 0.0,  -- NOVO: Outros Descontos
        tem_inss INTEGER NOT NULL,
        tem_irrf INTEGER NOT NULL
      )
    ''');

    // 3. Configs e Tabelas
    await db.execute('CREATE TABLE configs (chave TEXT PRIMARY KEY, valor REAL NOT NULL)');
    await db.execute('CREATE TABLE tabela_inss (id INTEGER PRIMARY KEY AUTOINCREMENT, limite REAL NOT NULL, aliquota REAL NOT NULL)');
    await db.execute('CREATE TABLE tabela_irrf (id INTEGER PRIMARY KEY AUTOINCREMENT, limite REAL NOT NULL, aliquota REAL NOT NULL, deducao REAL NOT NULL)');

    // === INSERIR DADOS INICIAIS ===
    final List<Map<String, dynamic>> cargosReais = [
      {'nome': 'Engenheiro Químico - Presidência', 'p': 2.50},
      {'nome': 'Diretor Administrativo e Financeiro - Diretoria Adm/Fin', 'p': 2.30},
      {'nome': 'Química Industrial - Diretoria Técnica', 'p': 2.30},
      {'nome': 'Químico Industrial - Ger. Exec. Metrologia', 'p': 2.15},
      {'nome': 'Gerente - Gerência de Metrologia', 'p': 1.60},
      {'nome': 'Oficial Administrativa - Ger. Contabilidade', 'p': 1.60},
      {'nome': 'Oficial Administrativo - Ger. Qualidade', 'p': 1.60},
      {'nome': 'Diretora de Coordenadoria - Organismos Insp.', 'p': 1.50},
      {'nome': 'Auxiliar de Gabinete - Prod. Pré Medidos', 'p': 1.50},
      {'nome': 'Coordenador - Prod. Industrializados', 'p': 1.50},
      {'nome': 'Especialista em Políticas Publicas - Planejamento', 'p': 1.50},
      {'nome': 'Oficial Administrativo - Doc. e Inspeção', 'p': 1.50},
      {'nome': 'Coordenador - Prod. Pré Medidos', 'p': 1.50},
      {'nome': 'Oficial Administrativo - Metrologia Legal', 'p': 1.50},
      {'nome': 'Auxiliar Técnico - Metrologia Legal', 'p': 1.50},
      {'nome': 'Tecnico em Quimica - Metrologia Legal', 'p': 1.50},
      {'nome': 'Auxiliar de Laboratório - Metrologia Legal', 'p': 1.50},
      {'nome': 'Tecnico em Edificações - Prod. Pré Medidos', 'p': 1.50},
      {'nome': 'Diretor de Subcoordenadoria - Massa e Volume', 'p': 1.45},
      {'nome': 'Gerente - Gerência de Informática', 'p': 1.35},
      {'nome': 'Auxiliar de Gabinete - Metrologia Legal', 'p': 1.20},
      {'nome': 'Chefe de Gabinete - Presidência', 'p': 1.20},
      {'nome': 'Motorista - Metrologia Legal (Nível II)', 'p': 1.20},
      {'nome': 'Auxiliar de Gabinete - Metrologia Legal (Padrão)', 'p': 1.15},
      {'nome': 'Agente Administrativo - Metrologia Legal', 'p': 1.15},
      {'nome': 'Oficial Administrativo - Metrologia Legal (Nível I)', 'p': 1.15},
      {'nome': 'Executor de Serviços Básicos - Metrologia Legal', 'p': 1.15},
      {'nome': 'Motorista - Metrologia Legal', 'p': 1.15},
      {'nome': 'Tecnico em Edificações - Metrologia Legal', 'p': 1.15},
      {'nome': 'Diretor I - Metrologia Legal', 'p': 1.15},
      {'nome': 'Coordenador - Serviços Gerais', 'p': 1.15},
      {'nome': 'Gerente - Recursos Humanos', 'p': 1.10},
      {'nome': 'Gerente - Apoio Administrativo', 'p': 1.10},
      {'nome': 'Assessor Técnico Administrativo II - Jurídico', 'p': 1.10},
      {'nome': 'Professor de Educação Básica - Jurídico', 'p': 1.10},
      {'nome': 'Engenheiro Químico - Ger. Atividades Técnicas', 'p': 1.10},
      {'nome': 'Chefe de Procuradoria - Jurídico', 'p': 1.10},
      {'nome': 'Assessor III - Projetos e Convênios', 'p': 1.10},
      {'nome': 'Gerente - Projetos e Convenios', 'p': 1.10},
      {'nome': 'Coordenador - Documentação e Inspeção', 'p': 1.00},
      {'nome': 'Oficial Administrativo - SAC', 'p': 1.00},
      {'nome': 'Tecnico em Contabilidade - Jurídico', 'p': 0.95},
      {'nome': 'Coordenador - Orçamento e Finanças', 'p': 0.85},
      {'nome': 'Assessor Geral - Gestão de Qualidade', 'p': 0.85},
      {'nome': 'Subcoordenador - Contabilidade', 'p': 0.85},
      {'nome': 'Motorista - Gabinete da Presidência', 'p': 0.80},
      {'nome': 'Coordenador - Serviços Gerais (Nível I)', 'p': 0.75},
      {'nome': 'Assessor Técnico Administrativo I - Apoio Adm', 'p': 0.75},
      {'nome': 'Diretor II - Recursos Humanos', 'p': 0.75},
      {'nome': 'Diretor II - Jurídico', 'p': 0.75},
      {'nome': 'Oficial Administrativo - Ger. Executiva', 'p': 0.75},
      {'nome': 'Telefonista - Prod. Pré Medidos', 'p': 0.75},
      {'nome': 'Agente Administrativo - Doc. e Inspeção', 'p': 0.75},
      {'nome': 'Oficial Administrativo - Doc. e Inspeção (Nível I)', 'p': 0.75},
      {'nome': 'Assessor Executivo - Jurídico', 'p': 0.75},
      {'nome': 'Coordenador - Transporte', 'p': 0.74},
      {'nome': 'Assessor Tecnico Administrativo I - SAC', 'p': 0.65},
      {'nome': 'Oficial Administrativo - SAC (Nível I)', 'p': 0.65},
      {'nome': 'Diretor de Coordenadoria - Comunicação', 'p': 0.65},
      {'nome': 'Oficial Administrativo - Memória e Tecnologia', 'p': 0.65},
      {'nome': 'Assessor Tecnico Administrativo I - Projetos', 'p': 0.65},
      {'nome': 'Coordenadora - Adm. Pessoal', 'p': 0.65},
      {'nome': 'Diretor II - Apoio Administrativo', 'p': 0.60},
      {'nome': 'Oficial Administrativo - Diretoria Adm/Fin', 'p': 0.60},
      {'nome': 'Subcoordenador - Protocolo', 'p': 0.45},
      {'nome': 'Subcoordenador - Centro de Memórias', 'p': 0.45},
      {'nome': 'Oficial Administrativo - Diretoria Técnica', 'p': 0.45},
      {'nome': 'Diretor II - Gabinete Presidência', 'p': 0.45},
      {'nome': 'Oficial Administrativo - Protocolo', 'p': 0.41},
      {'nome': 'Técnico em Contabilidade - Informática', 'p': 0.41},
      {'nome': 'Agente Administrativo - Transportes', 'p': 0.41},
      {'nome': 'Agente Administrativo - Ger. Executiva', 'p': 0.41},
      {'nome': 'Oficial Administrativo - Apoio Adm', 'p': 0.41},
      {'nome': 'Assistente Administrativo - Protocolo', 'p': 0.41},
      {'nome': 'Assessor Extraordinário II - RH', 'p': 0.41},
      {'nome': 'Agente Administrativo - Protocolo', 'p': 0.41},
      {'nome': 'Assistente Administrativo - RH', 'p': 0.41},
      {'nome': 'Tecnico em Contabilidade - Ger. Contabilidade', 'p': 0.41},
      {'nome': 'Assessor Administrativo - Apoio Adm', 'p': 0.41},
      {'nome': 'Professor de Educação Básica (Nível I)', 'p': 0.41},
      {'nome': 'Asssistente Administrativo - Serviços Gerais', 'p': 0.41},
      {'nome': 'Telefonista - Serviços Gerais', 'p': 0.41},
    ];

    final batch = db.batch();
    for (var c in cargosReais) {
      batch.insert('cargos', {'nome': c['nome'], 'percentual_padrao': c['p']});
    }

    batch.insert('configs', {'chave': 'base_convenio', 'valor': 210000.00});
    batch.insert('configs', {'chave': 'teto_inss', 'valor': 8475.55});
    batch.insert('configs', {'chave': 'desconto_simplificado', 'valor': 607.20});
    batch.insert('configs', {'chave': 'ir_redutor_a', 'valor': 978.62});
    batch.insert('configs', {'chave': 'ir_redutor_b', 'valor': 0.133145});
    batch.insert('configs', {'chave': 'ir_limite_redutor', 'valor': 7350.00});
    batch.insert('configs', {'chave': 'aliquota_patronal', 'valor': 9.02});

    batch.insert('tabela_inss', {'limite': 1621.00, 'aliquota': 7.5});
    batch.insert('tabela_inss', {'limite': 2902.84, 'aliquota': 9.0});
    batch.insert('tabela_inss', {'limite': 4354.27, 'aliquota': 12.0});
    batch.insert('tabela_inss', {'limite': 999999999.00, 'aliquota': 14.0});

    batch.insert('tabela_irrf', {'limite': 2428.80, 'aliquota': 0.0, 'deducao': 0.0});
    batch.insert('tabela_irrf', {'limite': 2826.65, 'aliquota': 7.5, 'deducao': 182.16});
    batch.insert('tabela_irrf', {'limite': 3751.05, 'aliquota': 15.0, 'deducao': 394.16});
    batch.insert('tabela_irrf', {'limite': 4664.68, 'aliquota': 22.5, 'deducao': 675.49});
    batch.insert('tabela_irrf', {'limite': 999999999.00, 'aliquota': 27.5, 'deducao': 908.73});

    await batch.commit();
  }

  Future<int> createFuncionario(Map<String, dynamic> row) async => await (await instance.database).insert('funcionarios', row);
  Future<List<Map<String, dynamic>>> readFuncionarios() async => await (await instance.database).query('funcionarios', orderBy: 'nome ASC');
  Future<int> updateFuncionario(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update('funcionarios', row, where: 'id = ?', whereArgs: [row['id']]);
  }
  Future<int> deleteFuncionario(int id) async => await (await instance.database).delete('funcionarios', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> readCargos() async => await (await instance.database).query('cargos', orderBy: 'nome ASC');
  Future<int> createCargo(Map<String, dynamic> row) async => await (await instance.database).insert('cargos', row);
  Future<int> deleteCargo(int id) async => await (await instance.database).delete('cargos', where: 'id = ?', whereArgs: [id]);

  Future<Map<String, dynamic>> loadFullConfig() async {
    final db = await instance.database;
    final configsMap = {for (var e in await db.query('configs')) e['chave'] as String: e['valor'] as double};
    return {'geral': configsMap, 'inss': await db.query('tabela_inss', orderBy: 'limite ASC'), 'irrf': await db.query('tabela_irrf', orderBy: 'limite ASC')};
  }
  Future<void> updateConfigValor(String chave, double valor) async => await (await instance.database).update('configs', {'valor': valor}, where: 'chave = ?', whereArgs: [chave]);
  Future<void> updateTabelaInss(int id, double limite, double aliquota) async => await (await instance.database).update('tabela_inss', {'limite': limite, 'aliquota': aliquota}, where: 'id = ?', whereArgs: [id]);
  Future<void> updateTabelaIrrf(int id, double limite, double aliquota, double deducao) async => await (await instance.database).update('tabela_irrf', {'limite': limite, 'aliquota': aliquota, 'deducao': deducao}, where: 'id = ?', whereArgs: [id]);
}