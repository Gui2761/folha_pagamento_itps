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
    final Map<String, double> geral = Map<String, double>.from(configData['geral'] ?? {});
    final List<Map<String, dynamic>> tabelaInss = List.from(configData['inss']);
    final List<Map<String, dynamic>> tabelaIrrf = List.from(configData['irrf']);

    // 1. Definição do Bruto (Base Convênio)
    double baseConvenio = geral['base_convenio'] ?? 211000.00;
    double valorBrutoConvenio = baseConvenio * (percentual / 100);
    
    double inssSobreTotal = 0.0;
    double inssSobreSipes = 0.0;
    double inssDevido = 0.0;

    // 2. CÁLCULO DO INSS (Encontro de Contas Legal)
    if (temInss) {
      double baseTotalInss = valorSipes + valorBrutoConvenio;
      inssSobreTotal = _calcularInssProgressivo(baseTotalInss, tabelaInss);
      inssSobreSipes = _calcularInssProgressivo(valorSipes, tabelaInss);
      inssDevido = max(0, inssSobreTotal - inssSobreSipes);
    }

    // 3. CÁLCULO DO IRRF (DE ACORDO COM A LEI)
    double irrf = 0.0;
    double irrfBrutoFinal = 0.0;
    double irrfSipesFinal = 0.0;
    double descontoSimplificado = geral['desconto_simplificado'] ?? 564.80; 

    if (temIrrf) {
      // REGRA LEGAL: Soma-se o Convênio com o SIPES para a base de cálculo
      double baseTotalIR = valorBrutoConvenio + valorSipes;
      
      // ISENÇÃO LEGAL: Somente para quem ganha TOTAL até R$ 5.000,00
      if (baseTotalIR <= 5000.0) {
        irrf = 0.0;
      } else {
        // Cálculo do Imposto Total (Convênio + SIPES)
        // Comparando Deduções Legais vs Desconto Simplificado
        double baseLegalTotal = baseTotalIR - inssSobreTotal - pensao; 
        double impostoLegalTotal = baseLegalTotal > 0 ? _calcularIrrf(baseLegalTotal, tabelaIrrf) : 0.0;

        double baseSimplesTotal = baseTotalIR - descontoSimplificado;
        double impostoSimplesTotal = baseSimplesTotal > 0 ? _calcularIrrf(baseSimplesTotal, tabelaIrrf) : 0.0;

        double irrfTotalGlobal = min(impostoLegalTotal, impostoSimplesTotal);

        // Cálculo do Imposto que já incide sobre o SIPES (Estado)
        double baseLegalSipes = valorSipes - inssSobreSipes;
        double impostoLegalSipes = baseLegalSipes > 0 ? _calcularIrrf(baseLegalSipes, tabelaIrrf) : 0.0;

        double baseSimplesSipes = valorSipes - descontoSimplificado;
        double impostoSimplesSipes = baseSimplesSipes > 0 ? _calcularIrrf(baseSimplesSipes, tabelaIrrf) : 0.0;

        irrfSipesFinal = min(impostoLegalSipes, impostoSimplesSipes);
        
        // IRRF DEVIDO NO CONVÊNIO: É a diferença (Encontro de Contas do IR)
        irrf = max(0, irrfTotalGlobal - irrfSipesFinal);
        irrfBrutoFinal = irrfTotalGlobal;
      }
    }

    // LÍQUIDO FINAL
    double liquido = valorBrutoConvenio - inssDevido - irrf - pensao - outros + acrescimos;

    return {
      'bruto': _arredondar(valorBrutoConvenio),
      'inss': _arredondar(inssDevido),
      'inss_total': _arredondar(inssSobreTotal),
      'inss_sipes': _arredondar(inssSobreSipes),
      'irrf': _arredondar(irrf),
      'irrf_total': _arredondar(irrfBrutoFinal),
      'irrf_sipes': _arredondar(irrfSipesFinal),
      'pensao': _arredondar(pensao),
      'outros': _arredondar(outros),
      'acrescimos': _arredondar(acrescimos),
      'liquido': _arredondar(liquido),
      'sipes': _arredondar(valorSipes),
    };
  }

  static double _calcularInssProgressivo(double salario, List<Map<String, dynamic>> tabela) {
    double imposto = 0.0;
    tabela.sort((a, b) => (a['limite'] as num).compareTo(b['limite'] as num));
    double limiteAnterior = 0.0;
    for (var faixa in tabela) {
      double limite = faixa['limite'];
      double aliquota = faixa['aliquota'];
      if (salario > limite) {
        imposto += (limite - limiteAnterior) * (aliquota / 100);
      } else {
        imposto += (salario - limiteAnterior) * (aliquota / 100);
        return imposto;
      }
      limiteAnterior = limite;
    }
    return imposto;
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