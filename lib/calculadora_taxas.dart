import 'dart:math';

class CalculadoraTaxas {
  
  static Map<String, dynamic> calcularFolha({
    required double percentual,
    required bool temInss,
    required bool temIrrf,
    required double valorSipes, // Novo parâmetro (para futuro uso ou exibição)
    required Map<String, dynamic> configData,
  }) {
    final Map<String, double> geral = configData['geral'];
    final List<Map<String, dynamic>> tabelaInss = configData['inss'];
    final List<Map<String, dynamic>> tabelaIrrf = configData['irrf'];

    double baseConvenio = geral['base_convenio'] ?? 210000.00;
    double tetoInss = geral['teto_inss'] ?? 8475.55;
    double descSimplificado = geral['desconto_simplificado'] ?? 607.20;

    // 1. Bruto do Convênio (Baseado no Percentual, não no SIPES)
    double valorBruto = baseConvenio * (percentual / 100);
    
    // 2. INSS
    double inss = 0.0;
    if (temInss) {
      inss = _calcularInssDinamico(valorBruto, tabelaInss, tetoInss);
    }

    // 3. IRRF
    // Nota: Se futuramente precisar somar o SIPES para achar a faixa de IRRF, altera-se aqui.
    // Por enquanto, calcula IRRF apenas sobre o valor do convênio, conforme padrão.
    double irrf = 0.0;
    if (temIrrf) {
      irrf = _calcularIrrfDinamico(valorBruto, inss, tabelaIrrf, descSimplificado, geral);
    }

    return {
      'bruto': valorBruto,
      'inss': inss,
      'irrf': irrf,
      'liquido': valorBruto - inss - irrf,
      'sipes': valorSipes, // Retorna para exibição
    };
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

  static double _calcularIrrfDinamico(double bruto, double inss, List<Map<String, dynamic>> tabela, double simplificado, Map<String, double> geral) {
    double baseLegal = bruto - inss;
    double baseSimplificada = bruto - simplificado;
    double baseCalculo = min(baseLegal, baseSimplificada);
    double imposto = 0.0;
    for (var faixa in tabela) {
      if (baseCalculo <= faixa['limite']) {
        imposto = (baseCalculo * (faixa['aliquota'] / 100)) - faixa['deducao'];
        break;
      }
    }
    if (imposto < 0) imposto = 0;
    double limiteRedutor = geral['ir_limite_redutor'] ?? 0;
    if (bruto <= limiteRedutor && limiteRedutor > 0) {
      double a = geral['ir_redutor_a'] ?? 0;
      double b = geral['ir_redutor_b'] ?? 0;
      double redutor = a - (b * bruto);
      if (redutor < 0) redutor = 0;
      imposto = imposto - redutor;
    }
    return imposto < 0 ? 0.0 : imposto;
  }
}