import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Atualizei a versão para garantir que recrie com a lista completa e ordenada
    _database = await _initDB('folha_itps_v6_completa.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      final databaseFactory = databaseFactoryFfi;
      final appDocumentsDir = await getApplicationDocumentsDirectory();
      path = join(appDocumentsDir.path, filePath);
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _onCreate,
        ),
      );
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
      return await openDatabase(path, version: 1, onCreate: _onCreate);
    }
  }

  Future _onCreate(Database db, int version) async {
    // 1. Tabela Funcionários
    await db.execute('''
      CREATE TABLE funcionarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT,
        cpf TEXT,
        rg TEXT,
        vinculo TEXT,
        banco TEXT,
        agencia TEXT,
        conta TEXT,
        cargo_nome TEXT,
        locacao TEXT,
        percentual REAL,
        valor_sipes REAL,
        pensao REAL,
        outros REAL,
        tem_inss INTEGER,
        tem_irrf INTEGER
      )
    ''');

    // 2. Tabela Cargos (Com coluna Locação)
    await db.execute('''
      CREATE TABLE cargos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT,
        locacao TEXT,
        percentual_padrao REAL
      )
    ''');
    
    // 3. Configurações e Tabelas Fiscais
    await db.execute('CREATE TABLE config_geral (chave TEXT PRIMARY KEY, valor REAL)');
    await db.execute('CREATE TABLE config_inss (id INTEGER PRIMARY KEY AUTOINCREMENT, limite REAL, aliquota REAL)');
    await db.execute('CREATE TABLE config_irrf (id INTEGER PRIMARY KEY AUTOINCREMENT, limite REAL, aliquota REAL, deducao REAL)');

    // ============================================================
    //        LISTA COMPLETA DE CARGOS (ORDEM ALFABÉTICA)
    // ============================================================
    
    // A
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Agente Administrativo', 'Doc. e Inspeção', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Agente Administrativo', 'Ger. Executiva', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Agente Administrativo', 'Metrologia Legal', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Agente Administrativo', 'Protocolo', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Agente Administrativo', 'Transportes', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor Administrativo', 'Apoio Adm', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor Executivo', 'Jurídico', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor Extraordinário II', 'RH', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor Geral', 'Gestão de Qualidade', 0.85)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor III', 'Projetos e Convênios', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor Técnico Administrativo I', 'Apoio Adm', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor Tecnico Administrativo I', 'Projetos', 0.65)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor Tecnico Administrativo I', 'SAC', 0.65)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assessor Técnico Administrativo II', 'Jurídico', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assistente Administrativo', 'Protocolo', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Assistente Administrativo', 'RH', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Asssistente Administrativo', 'Serviços Gerais', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Auxiliar de Gabinete', 'Metrologia Legal', 1.20)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Auxiliar de Gabinete', 'Metrologia Legal (Padrão)', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Auxiliar de Gabinete', 'Prod. Pré Medidos', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Auxiliar de Laboratório', 'Metrologia Legal', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Auxiliar Técnico', 'Metrologia Legal', 1.50)");

    // C
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Chefe de Gabinete', 'Presidência', 1.20)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Chefe de Procuradoria', 'Jurídico', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Coordenador', 'Documentação e Inspeção', 1.00)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Coordenador', 'Orçamento e Finanças', 0.85)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Coordenador', 'Prod. Industrializados', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Coordenador', 'Prod. Pré Medidos', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Coordenador', 'Serviços Gerais', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Coordenador', 'Serviços Gerais (Nível I)', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Coordenador', 'Transporte', 0.74)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Coordenadora', 'Adm. Pessoal', 0.65)");

    // D
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor Administrativo e Financeiro', 'Diretoria Adm/Fin', 2.30)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor de Coordenadoria', 'Comunicação', 0.65)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor de Subcoordenadoria', 'Massa e Volume', 1.45)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor I', 'Metrologia Legal', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor II', 'Apoio Administrativo', 0.60)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor II', 'Gabinete Presidência', 0.45)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor II', 'Jurídico', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor II', 'Recursos Humanos', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretora de Coordenadoria', 'Organismos Insp.', 1.50)");

    // E
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Engenheiro Químico', 'Ger. Atividades Técnicas', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Engenheiro Químico', 'Presidência', 2.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Especialista em Políticas Publicas', 'Planejamento', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Executor de Serviços Básicos', 'Metrologia Legal', 1.15)");

    // G
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Apoio Administrativo', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Gerência de Informática', 1.35)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Gerência de Metrologia', 1.60)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Projetos e Convenios', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Recursos Humanos', 1.10)");

    // M
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Motorista', 'Gabinete da Presidência', 0.80)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Motorista', 'Metrologia Legal', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Motorista', 'Metrologia Legal (Nível II)', 1.20)");

    // O
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativa', 'Ger. Contabilidade', 1.60)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Apoio Adm', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Diretoria Adm/Fin', 0.60)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Diretoria Técnica', 0.45)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Doc. e Inspeção', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Doc. e Inspeção (Nível I)', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Ger. Executiva', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Ger. Qualidade', 1.60)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Memória e Tecnologia', 0.65)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Metrologia Legal', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Metrologia Legal (Nível I)', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'Protocolo', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'SAC', 1.00)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Oficial Administrativo', 'SAC (Nível I)', 0.65)");

    // P
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Professor de Educação Básica', 'Jurídico', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Professor de Educação Básica (Nível I)', '', 0.41)");

    // Q
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Química Industrial', 'Diretoria Técnica', 2.30)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Químico Industrial', 'Ger. Exec. Metrologia', 2.15)");

    // S
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Subcoordenador', 'Centro de Memórias', 0.45)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Subcoordenador', 'Contabilidade', 0.85)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Subcoordenador', 'Protocolo', 0.45)");

    // T
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Contabilidade', 'Ger. Contabilidade', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Técnico em Contabilidade', 'Informática', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Contabilidade', 'Jurídico', 0.95)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Edificações', 'Metrologia Legal', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Edificações', 'Prod. Pré Medidos', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Quimica', 'Metrologia Legal', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Telefonista', 'Prod. Pré Medidos', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Telefonista', 'Serviços Gerais', 0.41)");


    // ============================================================
    //               CONFIGURAÇÕES E TABELAS FISCAIS 2026
    // ============================================================
    await db.execute("INSERT INTO config_geral (chave, valor) VALUES ('base_convenio', 210000.00)");
    await db.execute("INSERT INTO config_geral (chave, valor) VALUES ('aliquota_patronal', 9.02)");
    await db.execute("INSERT INTO config_geral (chave, valor) VALUES ('teto_inss', 8475.55)"); 
    await db.execute("INSERT INTO config_geral (chave, valor) VALUES ('desconto_simplificado', 564.80)");

    // TABELA INSS 2026
    await db.execute("INSERT INTO config_inss (limite, aliquota) VALUES (1518.00, 7.5)");
    await db.execute("INSERT INTO config_inss (limite, aliquota) VALUES (2793.88, 9.0)");
    await db.execute("INSERT INTO config_inss (limite, aliquota) VALUES (4190.83, 12.0)");
    await db.execute("INSERT INTO config_inss (limite, aliquota) VALUES (8475.55, 14.0)");

    // TABELA IRRF 2026
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (5000.00, 0.0, 0.0)");
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (7500.00, 7.5, 375.00)"); 
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (10000.00, 15.0, 937.50)");
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (12500.00, 22.5, 1687.50)");
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (999999999.00, 27.5, 2312.50)");
  }

  // === CRUD FUNCIONÁRIOS ===
  Future<int> createFuncionario(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('funcionarios', row);
  }

  Future<List<Map<String, dynamic>>> readFuncionarios() async {
    final db = await instance.database;
    return await db.query('funcionarios');
  }

  Future<int> updateFuncionario(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('funcionarios', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteFuncionario(int id) async {
    final db = await instance.database;
    return await db.delete('funcionarios', where: 'id = ?', whereArgs: [id]);
  }

  // === CRUD CARGOS ===
  Future<int> createCargo(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('cargos', row);
  }

  // ORDENAR POR NOME NA LEITURA
  Future<List<Map<String, dynamic>>> readCargos() async {
    final db = await instance.database;
    return await db.query('cargos', orderBy: 'nome ASC');
  }

  Future<int> deleteCargo(int id) async {
    final db = await instance.database;
    return await db.delete('cargos', where: 'id = ?', whereArgs: [id]);
  }

  // === CONFIGURAÇÕES ===
  Future<Map<String, dynamic>> loadFullConfig() async {
    final db = await instance.database;
    try {
      final geralList = await db.query('config_geral');
      Map<String, double> geralMap = {};
      for (var item in geralList) {
        geralMap[item['chave'] as String] = item['valor'] as double;
      }
      final inssList = await db.query('config_inss', orderBy: 'limite ASC');
      final irrfList = await db.query('config_irrf', orderBy: 'limite ASC');
      return {
        'geral': geralMap,
        'inss': inssList,
        'irrf': irrfList,
      };
    } catch (e) {
      return {'geral': {}, 'inss': [], 'irrf': []};
    }
  }

  Future<void> updateConfigValor(String chave, double valor) async {
    final db = await instance.database;
    await db.insert('config_geral', {'chave': chave, 'valor': valor}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTabelaInss(int id, double limite, double aliquota) async {
    final db = await instance.database;
    await db.update('config_inss', {'limite': limite, 'aliquota': aliquota}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTabelaIrrf(int id, double limite, double aliquota, double deducao) async {
    final db = await instance.database;
    await db.update('config_irrf', {'limite': limite, 'aliquota': aliquota, 'deducao': deducao}, where: 'id = ?', whereArgs: [id]);
  }
}