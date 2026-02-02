import 'dart:math';

class CalculadoraTaxas {
  
  static Map<String, dynamic> calcularFolha({
    required double percentual,
    required double valorSipes, // Base de Cálculo do SIPES (Bruto - INSS de lá)
    required double pensao,
    required double outros,
    required bool temInss,
    required bool temIrrf,
    required Map<String, dynamic> configData,
  }) {
    final Map<String, double> geral = configData['geral'];
    final List<Map<String, dynamic>> tabelaInss = configData['inss'];
    final List<Map<String, dynamic>> tabelaIrrf = configData['irrf'];

    double baseConvenio = geral['base_convenio'] ?? 210000.00;
    double tetoInss = geral['teto_inss'] ?? 8475.55;
    
    // 1. Bruto do Convênio
    double valorBrutoConvenio = baseConvenio * (percentual / 100);
    
    // 2. INSS (Calculado sobre o Convênio)
    double inss = 0.0;
    if (temInss) {
      inss = _calcularInssDinamico(valorBrutoConvenio, tabelaInss, tetoInss);
    }

    // 3. IRRF (Lógica de Soma de Bases / Marginal)
    double irrf = 0.0;
    if (temIrrf) {
      // Base 1: O que ele ganha no Estado (SIPES)
      // Assumimos que o valor digitado no campo SIPES já é a base tributável de lá
      double baseSipes = valorSipes; 
      
      // Base 2: O que ele ganha no Convênio (menos o INSS daqui e a Pensão)
      double baseConvenioLiquida = valorBrutoConvenio - inss - pensao;
      if (baseConvenioLiquida < 0) baseConvenioLiquida = 0;

      // Cálculo A: Imposto que ele pagaria somando TUDO
      double baseTotal = baseSipes + baseConvenioLiquida;
      double impostoTotal = _calcularImpostoPuro(baseTotal, tabelaIrrf);

      // Cálculo B: Imposto que ele já paga só no SIPES
      double impostoSipes = _calcularImpostoPuro(baseSipes, tabelaIrrf);

      // O IRRF desta folha é a diferença (o acréscimo de imposto gerado pelo convênio)
      irrf = impostoTotal - impostoSipes;
      
      if (irrf < 0) irrf = 0;
    }

    // 4. Líquido
    double liquido = valorBrutoConvenio - inss - irrf - pensao - outros;

    return {
      'bruto': valorBrutoConvenio,
      'inss': inss,
      'irrf': irrf,
      'pensao': pensao,
      'outros': outros,
      'liquido': liquido,
      'sipes': valorSipes,
    };
  }

  // Função auxiliar para calcular imposto sobre uma base qualquer
  static double _calcularImpostoPuro(double base, List<Map<String, dynamic>> tabela) {
    double imposto = 0.0;
    for (var faixa in tabela) {
      if (base <= faixa['limite']) {
        imposto = (base * (faixa['aliquota'] / 100)) - faixa['deducao'];
        break;
      }
    }
    return max(0, imposto);
  }

  static double _calcularInssDinamico(double salario, List<Map<String, dynamic>> tabela, double tetoMaximo) {
    double desconto = 0.0;
    double salarioCalculo = min(salario, tetoMaximo);
    double faixaAnterior = 0.0;

    for (var faixa in tabela) {
      double limite = faixa['limite'];
      double aliquota = faixa['aliquota'] / 100;

      if (salarioCalculo > limite) {
        desconto += (limite - faixaAnterior) * aliquota;
        faixaAnterior = limite;
      } else {
        desconto += (salarioCalculo - faixaAnterior) * aliquota;
        break;
      }
    }
    return desconto;
  }
}