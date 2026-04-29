import 'dart:math';

class CalculadoraTaxas {
  // Função de Arredondamento Padrão Excel (Half-Up)
  static double _arredondar(double valor) {
    return ((valor + 0.0000001) * 100).roundToDouble() / 100;
  }

  static Map<String, dynamic> calcularFolha({
    required double percentual,
    required double valorSipes,
    required double pensao,
    required double outros,
    required double acrescimos,
    required bool temInss,
    required bool temIrrf,
    required Map<String, dynamic> configData,
  }) {
    final Map<String, double> geral =
        Map<String, double>.from(configData['geral'] ?? {});
    final List<Map<String, dynamic>> tabelaInss = List.from(configData['inss']);
    final List<Map<String, dynamic>> tabelaIrrf = List.from(configData['irrf']);

    // ========================================================================
    // PASSO 1: CÁLCULO DO VALOR DO CONVÊNIO
    // Fórmula: Valor do Convênio = Base do Mês * Índice de Participação
    // ========================================================================
    double baseConvenioMes = geral['base_convenio'] ?? 211000.00;
    double indiceparticipacao = percentual / 100;
    double valorConvenio = _arredondar(baseConvenioMes * indiceparticipacao);

    // ========================================================================
    // PASSO 2: SOMA DA BASE GLOBAL BRUTA
    // Fórmula: Base Global Bruta = Vencimento SIPES + Valor do Convênio
    // ========================================================================
    double baseGlobalBruta = _arredondar(valorSipes + valorConvenio);

    // ========================================================================
    // PASSO 3: CÁLCULO DO INSS (COM TRAVÃO DE TETO EM R$ 8.475,55)
    // ========================================================================
    double inssTotalGlobal = 0.0;
    double inssSobreSipes = 0.0;
    double inssADescontar = 0.0;

    if (temInss) {
      // 3.1 Cálculo do INSS sobre a Base Global Bruta (com travão de teto)
      // O travão: Se a Base Global Bruta > R$ 8.475,55, o cálculo não aumenta mais
      const double TETO_INSS = 8475.55;

      if (baseGlobalBruta > TETO_INSS) {
        // Se ultrapassou o teto, aplicar a alíquota do teto sobre o teto
        inssTotalGlobal = _calcularInssProgressivo(TETO_INSS, tabelaInss);
      } else {
        inssTotalGlobal = _calcularInssProgressivo(baseGlobalBruta, tabelaInss);
      }

      // 3.2 Cálculo do INSS já pago no SIPES
      inssSobreSipes = _calcularInssProgressivo(valorSipes, tabelaInss);

      // 3.3 INSS a Descontar nesta Folha = INSS Total - INSS já pago no SIPES
      // Se já pagou o teto com o SIPES, este resultado será automaticamente zero
      inssADescontar = max(0, inssTotalGlobal - inssSobreSipes);
    }

    // ========================================================================
    // PASSO 4: PREPARAÇÃO DA BASE DO IRRF
    // Fórmula: Base do IRRF = Base Global Bruta - INSS Total - Deduções
    // Deduções incluem: Pensões alimentícias + Dependentes (aqui: pensao)
    // ========================================================================
    double baseIrrf = _arredondar(baseGlobalBruta - inssTotalGlobal - pensao);

    // ========================================================================
    // PASSO 5: CÁLCULO DO IRRF
    // ========================================================================
    double irrfTotalGlobal = 0.0;
    double irrfSobreSipes = 0.0;
    double irffADescontar = 0.0;

    if (temIrrf) {
      // 5.1 Cálculo do IRRF Total sobre a Base do IRRF
      irrfTotalGlobal =
          baseIrrf > 0 ? _calcularIrrf(baseIrrf, tabelaIrrf) : 0.0;

      // 5.2 Cálculo do IRRF já pago no SIPES
      // (Base do SIPES para IRRF = Vencimento SIPES - INSS sobre SIPES - Pensão)
      double baseSipesIrrf = _arredondar(valorSipes - inssSobreSipes - pensao);
      irrfSobreSipes =
          baseSipesIrrf > 0 ? _calcularIrrf(baseSipesIrrf, tabelaIrrf) : 0.0;

      // 5.3 IRRF a Descontar nesta Folha = IRRF Total - IRRF já pago no SIPES
      irffADescontar = max(0, irrfTotalGlobal - irrfSobreSipes);
    }

    // ========================================================================
    // CÁLCULO DO LÍQUIDO FINAL
    // ========================================================================
    double liquido = _arredondar(valorConvenio -
        inssADescontar -
        irffADescontar -
        pensao -
        outros +
        acrescimos);

    return {
      'bruto': _arredondar(valorConvenio),
      'inss': _arredondar(inssADescontar),
      'inss_total': _arredondar(inssTotalGlobal),
      'inss_sipes': _arredondar(inssSobreSipes),
      'irrf': _arredondar(irffADescontar),
      'irrf_total': _arredondar(irrfTotalGlobal),
      'irrf_sipes': _arredondar(irrfSobreSipes),
      'pensao': _arredondar(pensao),
      'outros': _arredondar(outros),
      'acrescimos': _arredondar(acrescimos),
      'liquido': _arredondar(liquido),
      'sipes': _arredondar(valorSipes),
      'base_convenio': _arredondar(valorConvenio),
      'base_global_bruta': _arredondar(baseGlobalBruta),
      'base_irrf': _arredondar(baseIrrf),
    };
  }

  static double _calcularInssProgressivo(
      double salario, List<Map<String, dynamic>> tabela) {
    tabela.sort((a, b) => (a['limite'] as num).compareTo(b['limite'] as num));
    for (var faixa in tabela) {
      if (salario <= faixa['limite']) {
        return max(0,
            (salario * (faixa['aliquota'] / 100)) - (faixa['deducao'] ?? 0.0));
      }
    }
    if (tabela.isNotEmpty) {
      var ultima = tabela.last;
      return max(
          0,
          (ultima['limite'] * (ultima['aliquota'] / 100)) -
              (ultima['deducao'] ?? 0.0));
    }
    return 0.0;
  }

  static double _calcularIrrf(double base, List<Map<String, dynamic>> tabela) {
    tabela.sort((a, b) => (a['limite'] as num).compareTo(b['limite'] as num));
    for (var faixa in tabela) {
      if (base <= faixa['limite']) {
        return max(0, (base * (faixa['aliquota'] / 100)) - faixa['deducao']);
      }
    }
    if (tabela.isNotEmpty) {
      var ultima = tabela.last;
      return max(0, (base * (ultima['aliquota'] / 100)) - ultima['deducao']);
    }
    return 0.0;
  }
}
