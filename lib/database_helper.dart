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
    _database = await _initDB('folha_itps_v8_rh_sync.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      final databaseFactory = databaseFactoryFfi;
      
      // Caminho de Rede compartilhado pelo usuário
      const String networkPath = r'\\172.23.6.7\gerh\1- COAPE\FolhaITPS_Dados';
      
      // Verifica se a pasta de rede existe, se não, tenta criar (ou usa local como fallback se falhar)
      final dir = Directory(networkPath);
      String finalDir;
      
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        finalDir = networkPath;
      } catch (e) {
        // Se der erro de rede (offline), salva nos documentos locais como fallback
        final appDocumentsDir = await getApplicationDocumentsDirectory();
        finalDir = appDocumentsDir.path;
        print("Aviso: Caminho de rede não encontrado ou sem permissão. Usando local: $e");
      }

      path = join(finalDir, filePath);
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
      return await openDatabase(path, version: 6, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }
  }

  Future _onCreate(Database db, int version) async {
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
        acrescimos REAL,
        tem_inss INTEGER,
        tem_irrf INTEGER,
        irrf_sipes_real REAL DEFAULT 0.0,
        irrf_manual REAL DEFAULT 0.0,
        dias_trabalhados INTEGER DEFAULT 30,
        previdencia_rpps INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario TEXT UNIQUE,
        senha TEXT,
        permissao TEXT DEFAULT 'leitura' -- admin, editor, leitura
      )
    ''');

    // Inserir usuário administrador padrão
    await db.insert('usuarios', {
      'usuario': 'admin',
      'senha': 'itps2026',
      'permissao': 'admin'
    });

    await db.execute('''
      CREATE TABLE cargos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT,
        locacao TEXT,
        percentual_padrao REAL
      )
    ''');
    
    await db.execute('CREATE TABLE config_geral (chave TEXT PRIMARY KEY, valor REAL)');
    await db.execute('CREATE TABLE config_inss (id INTEGER PRIMARY KEY AUTOINCREMENT, limite REAL, aliquota REAL, deducao REAL)');
    await db.execute('CREATE TABLE config_irrf (id INTEGER PRIMARY KEY AUTOINCREMENT, limite REAL, aliquota REAL, deducao REAL)');

    await db.execute('''
      CREATE TABLE folhas_salvas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mes_ano TEXT UNIQUE,
        data_fechamento TEXT,
        criado_por TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE folha_historico_detalhe (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folha_salva_id INTEGER,
        funcionario_id INTEGER,
        nome TEXT,
        cpf TEXT,
        cargo_nome TEXT,
        locacao TEXT,
        vinculo TEXT,
        percentual REAL,
        valor_sipes REAL,
        pensao REAL,
        outros REAL,
        acrescimos REAL,
        bruto REAL,
        inss REAL,
        irrf REAL,
        liquido REAL,
        dias_trabalhados INTEGER DEFAULT 30,
        previdencia_rpps INTEGER DEFAULT 0,
        FOREIGN KEY (folha_salva_id) REFERENCES folhas_salvas (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE auditoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario TEXT,
        acao TEXT,
        data_hora TEXT,
        detalhes TEXT
      )
    ''');

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
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor Administrativo e Financeiro', 'Diretoria Adm/Fin', 2.30)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor de Coordenadoria', 'Comunicação', 0.65)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor de Subcoordenadoria', 'Massa e Volume', 1.45)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor I', 'Metrologia Legal', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor II', 'Apoio Administrativo', 0.60)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor II', 'Gabinete Presidência', 0.45)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor II', 'Jurídico', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretor II', 'Recursos Humanos', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Diretora de Coordenadoria', 'Organismos Insp.', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Engenheiro Químico', 'Ger. Atividades Técnicas', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Engenheiro Químico', 'Presidência', 2.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Especialista em Políticas Publicas', 'Planejamento', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Executor de Serviços Básicos', 'Metrologia Legal', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Apoio Administrativo', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Gerência de Informática', 1.35)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Gerência de Metrologia', 1.60)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Projetos e Convenios', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Gerente', 'Recursos Humanos', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Motorista', 'Gabinete da Presidência', 0.80)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Motorista', 'Metrologia Legal', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Motorista', 'Metrologia Legal (Nível II)', 1.20)");
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
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Professor de Educação Básica', 'Jurídico', 1.10)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Professor de Educação Básica (Nível I)', '', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Química Industrial', 'Diretoria Técnica', 2.30)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Químico Industrial', 'Ger. Exec. Metrologia', 2.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Subcoordenador', 'Centro de Memórias', 0.45)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Subcoordenador', 'Contabilidade', 0.85)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Subcoordenador', 'Protocolo', 0.45)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Contabilidade', 'Ger. Contabilidade', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Técnico em Contabilidade', 'Informática', 0.41)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Contabilidade', 'Jurídico', 0.95)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Edificações', 'Metrologia Legal', 1.15)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Edificações', 'Prod. Pré Medidos', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Tecnico em Quimica', 'Metrologia Legal', 1.50)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Telefonista', 'Prod. Pré Medidos', 0.75)");
    await db.execute("INSERT INTO cargos (nome, locacao, percentual_padrao) VALUES ('Telefonista', 'Serviços Gerais', 0.41)");

    await db.execute("INSERT INTO config_geral (chave, valor) VALUES ('base_convenio', 230680.00)");
    await db.execute("INSERT INTO config_geral (chave, valor) VALUES ('aliquota_patronal', 9.02)");
    await db.execute("INSERT INTO config_geral (chave, valor) VALUES ('teto_inss', 8475.55)"); 
    await db.execute("INSERT INTO config_geral (chave, valor) VALUES ('desconto_simplificado', 607.20)");

    await db.execute("INSERT INTO config_inss (limite, aliquota, deducao) VALUES (1621.00, 7.5, 0.0)");
    await db.execute("INSERT INTO config_inss (limite, aliquota, deducao) VALUES (2902.84, 9.0, 24.32)");
    await db.execute("INSERT INTO config_inss (limite, aliquota, deducao) VALUES (4354.27, 12.0, 111.40)");
    await db.execute("INSERT INTO config_inss (limite, aliquota, deducao) VALUES (8475.55, 14.0, 198.49)");

    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (2428.80, 0.0, 0.0)");
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (2826.65, 7.5, 182.16)"); 
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (3751.05, 15.0, 394.16)");
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (4664.68, 22.5, 675.49)");
    await db.execute("INSERT INTO config_irrf (limite, aliquota, deducao) VALUES (999999999.00, 27.5, 908.73)");
  }

  Future<int> createFuncionario(Map<String, dynamic> row, {String? usuario}) async {
    final db = await instance.database;
    final id = await db.insert('funcionarios', row);
    if (usuario != null) {
      await registrarLog(usuario, 'CADASTRAR_COLABORADOR', 'Cadastrou o colaborador ${row['nome']} (CPF: ${row['cpf']}, Vínculo: ${row['vinculo']})');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> readFuncionarios() async {
    final db = await instance.database;
    return await db.query('funcionarios', orderBy: 'nome ASC');
  }

  Future<int> updateFuncionario(Map<String, dynamic> row, {String? usuario}) async {
    final db = await instance.database;
    int id = row['id'];
    if (usuario != null) {
      final antigas = await db.query('funcionarios', where: 'id = ?', whereArgs: [id]);
      String anterior = antigas.isNotEmpty ? " (anterior: ${antigas.first['nome']})" : "";
      await registrarLog(usuario, 'EDITAR_COLABORADOR', 'Editou o colaborador ${row['nome']}$anterior (CPF: ${row['cpf']})');
    }
    return await db.update('funcionarios', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteFuncionario(int id, {String? usuario}) async {
    final db = await instance.database;
    String details = "ID: $id";
    if (usuario != null) {
      final res = await db.query('funcionarios', where: 'id = ?', whereArgs: [id]);
      if (res.isNotEmpty) {
        details = "${res.first['nome']} (CPF: ${res.first['cpf']})";
      }
    }
    final result = await db.delete('funcionarios', where: 'id = ?', whereArgs: [id]);
    if (usuario != null) {
      await registrarLog(usuario, 'REMOVER_COLABORADOR', 'Removeu o colaborador $details');
    }
    return result;
  }

  Future<int> createCargo(Map<String, dynamic> row, {String? usuario}) async {
    final db = await instance.database;
    final id = await db.insert('cargos', row);
    if (usuario != null) {
      await registrarLog(usuario, 'CADASTRAR_CARGO', 'Cadastrou o cargo ${row['nome']} - Lotação: ${row['locacao']}');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> readCargos() async {
    final db = await instance.database;
    return await db.query('cargos', orderBy: 'nome ASC');
  }

  Future<int> updateCargo(Map<String, dynamic> row, {String? usuario}) async {
    final db = await instance.database;
    int id = row['id'];
    if (usuario != null) {
      await registrarLog(usuario, 'EDITAR_CARGO', 'Editou o cargo ${row['nome']} - Lotação: ${row['locacao']}');
    }
    return await db.update('cargos', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCargo(int id, {String? usuario}) async {
    final db = await instance.database;
    String details = "ID: $id";
    if (usuario != null) {
      final res = await db.query('cargos', where: 'id = ?', whereArgs: [id]);
      if (res.isNotEmpty) {
        details = "${res.first['nome']} - Lotação: ${res.first['locacao']}";
      }
    }
    final result = await db.delete('cargos', where: 'id = ?', whereArgs: [id]);
    if (usuario != null) {
      await registrarLog(usuario, 'REMOVER_CARGO', 'Removeu o cargo $details');
    }
    return result;
  }

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

  Future<void> updateConfigValor(String chave, double valor, {String? usuario}) async {
    final db = await instance.database;
    if (usuario != null) {
      final antigas = await db.query('config_geral', where: 'chave = ?', whereArgs: [chave]);
      String anterior = antigas.isNotEmpty ? " (de ${antigas.first['valor']} para $valor)" : " (para $valor)";
      await registrarLog(usuario, 'EDITAR_CONFIG', 'Alterou configuração $chave$anterior');
    }
    await db.insert('config_geral', {'chave': chave, 'valor': valor}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTabelaInss(int id, double limite, double aliquota, double deducao, {String? usuario}) async {
    final db = await instance.database;
    if (usuario != null) {
      await registrarLog(usuario, 'EDITAR_TABELA_INSS', 'Editou faixa de INSS ID: $id (Limite: $limite, Alíquota: $aliquota%, Dedução: $deducao)');
    }
    await db.update('config_inss', {'limite': limite, 'aliquota': aliquota, 'deducao': deducao}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTabelaIrrf(int id, double limite, double aliquota, double deducao, {String? usuario}) async {
    final db = await instance.database;
    if (usuario != null) {
      await registrarLog(usuario, 'EDITAR_TABELA_IRRF', 'Editou faixa de IRRF ID: $id (Limite: $limite, Alíquota: $aliquota%, Dedução: $deducao)');
    }
    await db.update('config_irrf', {'limite': limite, 'aliquota': aliquota, 'deducao': deducao}, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> login(String usuario, String senha) async {
    final db = await instance.database;
    final res = await db.query(
      'usuarios',
      where: 'usuario = ? AND senha = ?',
      whereArgs: [usuario, senha],
    );
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> readUsuarios() async {
    final db = await instance.database;
    return await db.query('usuarios', orderBy: 'usuario ASC');
  }

  Future<int> createUsuario(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('usuarios', row);
  }

  Future<int> deleteUsuario(int id) async {
    final db = await instance.database;
    return await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adicionar coluna irrf_sipes_real para bancos existentes
      try {
        await db.execute('ALTER TABLE funcionarios ADD COLUMN irrf_sipes_real REAL DEFAULT 0.0');
      } catch (_) {
        // Coluna já existe, ignorar
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE funcionarios ADD COLUMN irrf_manual REAL DEFAULT 0.0');
      } catch (_) {
        // Coluna já existe, ignorar
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario TEXT UNIQUE,
            senha TEXT,
            permissao TEXT DEFAULT 'leitura'
          )
        ''');
        await db.insert('usuarios', {
          'usuario': 'admin',
          'senha': 'itps2026',
          'permissao': 'admin'
        });
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE folhas_salvas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mes_ano TEXT UNIQUE,
            data_fechamento TEXT,
            criado_por TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE folha_historico_detalhe (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folha_salva_id INTEGER,
            funcionario_id INTEGER,
            nome TEXT,
            cpf TEXT,
            cargo_nome TEXT,
            locacao TEXT,
            vinculo TEXT,
            percentual REAL,
            valor_sipes REAL,
            pensao REAL,
            outros REAL,
            acrescimos REAL,
            bruto REAL,
            inss REAL,
            irrf REAL,
            liquido REAL,
            FOREIGN KEY (folha_salva_id) REFERENCES folhas_salvas (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE auditoria (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario TEXT,
            acao TEXT,
            data_hora TEXT,
            detalhes TEXT
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE funcionarios ADD COLUMN dias_trabalhados INTEGER DEFAULT 30');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE funcionarios ADD COLUMN previdencia_rpps INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE folha_historico_detalhe ADD COLUMN dias_trabalhados INTEGER DEFAULT 30');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE folha_historico_detalhe ADD COLUMN previdencia_rpps INTEGER DEFAULT 0');
      } catch (_) {}
    }
  }

  Future<void> resetTabelasFiscais() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('config_inss');
      await txn.delete('config_irrf');

      await txn.insert('config_inss', {'limite': 1621.00, 'aliquota': 7.5, 'deducao': 0.0});
      await txn.insert('config_inss', {'limite': 2902.84, 'aliquota': 9.0, 'deducao': 24.32});
      await txn.insert('config_inss', {'limite': 4354.27, 'aliquota': 12.0, 'deducao': 111.40});
      await txn.insert('config_inss', {'limite': 8475.55, 'aliquota': 14.0, 'deducao': 198.49});

      await txn.insert('config_irrf', {'limite': 2428.80, 'aliquota': 0.0, 'deducao': 0.0});
      await txn.insert('config_irrf', {'limite': 2826.65, 'aliquota': 7.5, 'deducao': 182.16});
      await txn.insert('config_irrf', {'limite': 3751.05, 'aliquota': 15.0, 'deducao': 394.16});
      await txn.insert('config_irrf', {'limite': 4664.68, 'aliquota': 22.5, 'deducao': 675.49});
      await txn.insert('config_irrf', {'limite': 999999999.00, 'aliquota': 27.5, 'deducao': 908.73});
    });
  }

  // --- TRILHA DE AUDITORIA ---
  Future<void> registrarLog(String usuario, String acao, String detalhes) async {
    try {
      final db = await instance.database;
      await db.insert('auditoria', {
        'usuario': usuario,
        'acao': acao,
        'data_hora': DateTime.now().toLocal().toString().substring(0, 19),
        'detalhes': detalhes,
      });
    } catch (e) {
      print("Erro ao registrar log: $e");
    }
  }

  Future<List<Map<String, dynamic>>> readLogs() async {
    try {
      final db = await instance.database;
      return await db.query('auditoria', orderBy: 'id DESC', limit: 1000);
    } catch (_) {
      return [];
    }
  }

  Future<void> limparLogs() async {
    try {
      final db = await instance.database;
      await db.delete('auditoria');
    } catch (_) {}
  }

  // --- FECHAMENTO E HISTÓRICO MENSAL ---
  Future<int> fecharFolha(String mesAno, String usuario, List<Map<String, dynamic>> detalhes) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final antigas = await txn.query('folhas_salvas', where: 'mes_ano = ?', whereArgs: [mesAno]);
      if (antigas.isNotEmpty) {
        int antigaId = antigas.first['id'] as int;
        await txn.delete('folha_historico_detalhe', where: 'folha_salva_id = ?', whereArgs: [antigaId]);
        await txn.delete('folhas_salvas', where: 'id = ?', whereArgs: [antigaId]);
      }

      int folhaId = await txn.insert('folhas_salvas', {
        'mes_ano': mesAno,
        'data_fechamento': DateTime.now().toLocal().toString().substring(0, 19),
        'criado_por': usuario,
      });

      for (var item in detalhes) {
        await txn.insert('folha_historico_detalhe', {
          'folha_salva_id': folhaId,
          'funcionario_id': item['funcionario_id'],
          'nome': item['nome'],
          'cpf': item['cpf'],
          'cargo_nome': item['cargo_nome'],
          'locacao': item['locacao'],
          'vinculo': item['vinculo'],
          'percentual': item['percentual'],
          'valor_sipes': item['valor_sipes'],
          'pensao': item['pensao'],
          'outros': item['outros'],
          'acrescimos': item['acrescimos'],
          'bruto': item['bruto'],
          'inss': item['inss'],
          'irrf': item['irrf'],
          'liquido': item['liquido'],
          'dias_trabalhados': item['dias_trabalhados'] ?? 30,
          'previdencia_rpps': item['previdencia_rpps'] ?? 0,
        });
      }
      return folhaId;
    });
  }

  Future<List<Map<String, dynamic>>> readFolhasSalvas() async {
    try {
      final db = await instance.database;
      return await db.query('folhas_salvas', orderBy: 'mes_ano DESC');
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> readFolhaDetalhes(int folhaSalvaId) async {
    try {
      final db = await instance.database;
      return await db.query('folha_historico_detalhe', where: 'folha_salva_id = ?', whereArgs: [folhaSalvaId], orderBy: 'nome ASC');
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteFolhaSalva(int folhaSalvaId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('folha_historico_detalhe', where: 'folha_salva_id = ?', whereArgs: [folhaSalvaId]);
      await txn.delete('folhas_salvas', where: 'id = ?', whereArgs: [folhaSalvaId]);
    });
  }
}