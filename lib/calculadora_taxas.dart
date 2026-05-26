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
    double irrfSipesReal = 0.0,
    double irrfManual = 0.0,
    int diasTrabalhados = 30,
    double previdenciaRpps = 0.0,
  }) {
    final Map<String, double> geral =
        Map<String, double>.from(configData['geral'] ?? {});
    final List<Map<String, dynamic>> tabelaInss = List.from(configData['inss']);
    final List<Map<String, dynamic>> tabelaIrrf = List.from(configData['irrf']);

    // ========================================================================
    // PASSO 1: CÁLCULO DO VALOR DO CONVÊNIO
    // Fórmula: Valor do Convênio = Base do Mês * Índice de Participação
    // Com dedução de faltas se o colaborador não trabalhou os 30 dias completos
    // ========================================================================
    double baseConvenioMes = geral['base_convenio'] ?? 211000.00;
    double indiceparticipacao = percentual / 100;
    double valorConvenioIntegral = baseConvenioMes * indiceparticipacao;
    double valorConvenio = _arredondar(valorConvenioIntegral * (diasTrabalhados / 30.0));

    // ========================================================================
    // PASSO 2: SOMA DA BASE GLOBAL BRUTA
    // Fórmula: Base Global Bruta = Vencimento SIPES + Valor do Convênio
    // ========================================================================
    double baseGlobalBruta = _arredondar(valorSipes + valorConvenio);

    // ========================================================================
    // PASSO 3: CÁLCULO DA PREVIDÊNCIA (INSS PROGRESSIVO OU RPPS DE VALOR INFORMADO)
    // ========================================================================
    double inssTotalGlobal = 0.0;
    double inssSobreSipes = 0.0;
    double inssADescontar = 0.0;

    if (temInss) {
      if (previdenciaRpps > 0.0) {
        // Regime Próprio de Previdência Social - Valor Informado Manualmente
        inssTotalGlobal = previdenciaRpps;
        inssSobreSipes = 0.0;
        inssADescontar = previdenciaRpps;
      } else {
        // 3.1 Calculation of INSS on the Global Gross Base
        const double TETO_INSS = 8475.55;

        if (baseGlobalBruta > TETO_INSS) {
          inssTotalGlobal = _calcularInssProgressivo(TETO_INSS, tabelaInss);
        } else {
          inssTotalGlobal = _calcularInssProgressivo(baseGlobalBruta, tabelaInss);
        }

        // 3.2 Calculation of INSS already paid in SIPES
        inssSobreSipes = _calcularInssProgressivo(valorSipes, tabelaInss);

        // 3.3 INSS to discount in this sheet
        inssADescontar = max(0.0, inssTotalGlobal - inssSobreSipes);
      }
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
    
    double redutorIrrf = 0.0;
    bool isentoIrrf2026 = false;

    if (temIrrf) {
      // 5.1 Cálculo do IRRF Total (Regra 2026)
      if (baseGlobalBruta <= 5000.00) {
        irrfTotalGlobal = 0.0;
        isentoIrrf2026 = true;
      } else {
        double baseCalculoExcel = baseGlobalBruta - inssSobreSipes - pensao;
        double irrfTradicional = (baseCalculoExcel * 0.275) - 908.73;
        
        if (baseGlobalBruta <= 7350.00) {
          redutorIrrf = max(0.0, 978.62 - (0.133145 * baseGlobalBruta));
          irrfTotalGlobal = _arredondar(max(0.0, irrfTradicional - redutorIrrf));
        } else {
          irrfTotalGlobal = _arredondar(irrfTradicional);
        }
      }

      // 5.2 Cálculo do IRRF e Encontro de Contas
      if (irrfManual > 0) {
        irffADescontar = irrfManual;
        irrfSobreSipes = max(0, irrfTotalGlobal - irffADescontar); 
      } else if (irrfSipesReal > 0) {
        irrfSobreSipes = irrfSipesReal;
        irffADescontar = max(0, irrfTotalGlobal - irrfSobreSipes);
      } else {
        if (valorSipes <= 5000.00) {
          irrfSobreSipes = 0.0;
        } else {
          double baseSipesIrrf = valorSipes - inssSobreSipes - pensao;
          double irrfTradicionalSipes = (baseSipesIrrf * 0.275) - 908.73;
          
          if (valorSipes <= 7350.00) {
            double redutorSipes = max(0.0, 978.62 - (0.133145 * valorSipes));
            irrfSobreSipes = _arredondar(max(0.0, irrfTradicionalSipes - redutorSipes));
          } else {
            irrfSobreSipes = _arredondar(irrfTradicionalSipes);
          }
        }
        
        irffADescontar = max(0, irrfTotalGlobal - irrfSobreSipes);
      }
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
      'irrf_manual_informado': irrfManual > 0,
      'redutor_irrf': _arredondar(redutorIrrf),
      'isento_irrf_2026': isentoIrrf2026,
      'pensao': _arredondar(pensao),
      'outros': _arredondar(outros),
      'acrescimos': _arredondar(acrescimos),
      'liquido': _arredondar(liquido),
      'sipes': _arredondar(valorSipes),
      'base_convenio': _arredondar(valorConvenio),
      'base_global_bruta': _arredondar(baseGlobalBruta),
      'base_irrf': _arredondar(baseIrrf),
      'dias_trabalhados': diasTrabalhados,
      'previdencia_rpps': previdenciaRpps > 0.0,
      'valor_previdencia_rpps': previdenciaRpps,
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
