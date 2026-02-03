import 'package:flutter/material.dart';
import 'dart:math';

class CalculadoraTaxas {
  
  static Map<String, dynamic> calcularFolha({
    required double percentual,
    required double valorSipes, 
    required double pensao,
    required double outros,
    required bool temInss,
    required bool temIrrf,
    required Map<String, dynamic> configData,
  }) {
    final Map<String, double> geral = Map<String, double>.from(configData['geral'] ?? {});
    final List<Map<String, dynamic>> tabelaInss = List.from(configData['inss']);
    final List<Map<String, dynamic>> tabelaIrrf = List.from(configData['irrf']);

    // 1. Definição do Bruto (Base Convênio)
    double baseConvenio = geral['base_convenio'] ?? 210000.00;
    double valorBrutoConvenio = baseConvenio * (percentual / 100);
    
    // Variáveis de Detalhe
    double inssSobreTotal = 0.0;
    double inssSobreSipes = 0.0;
    double inssDevido = 0.0;

    // 2. CÁLCULO DO INSS (CORREÇÃO: SOMA DAS BASES)
    if (temInss) {
      // Calcula o INSS como se fosse um salário único (Sipes + Convênio)
      // Isso joga o funcionário para a faixa correta (ex: 12% ou 14%)
      double baseTotal = valorSipes + valorBrutoConvenio;
      inssSobreTotal = _calcularInssProgressivo(baseTotal, tabelaInss);
      
      // Calcula quanto ele JÁ PAGOU no Estado (Sipes)
      inssSobreSipes = _calcularInssProgressivo(valorSipes, tabelaInss);
      
      // A diferença é o que ele deve pagar no Convênio
      inssDevido = max(0, inssSobreTotal - inssSobreSipes);
    }

    // 3. CÁLCULO DO IRRF
    double irrf = 0.0;
    double irrfBrutoFinal = 0.0;
    double irrfSipesFinal = 0.0;
    double descontoSimplificado = geral['desconto_simplificado'] ?? 564.80; 

    if (temIrrf) {
      // Soma para base de IRRF
      double baseTotalIR = valorBrutoConvenio + valorSipes;
      
      // A: IRRF Total (Considerando Sipes + Convenio)
      // Opção 1: Deduções Legais (INSS Total + Pensão)
      double baseLegalTotal = baseTotalIR - inssSobreTotal - pensao; 
      double impostoLegalTotal = baseLegalTotal > 0 ? _calcularIrrf(baseLegalTotal, tabelaIrrf) : 0.0;

      // Opção 2: Desconto Simplificado
      double baseSimplesTotal = baseTotalIR - descontoSimplificado;
      double impostoSimplesTotal = baseSimplesTotal > 0 ? _calcularIrrf(baseSimplesTotal, tabelaIrrf) : 0.0;

      double irrfTotal = min(impostoLegalTotal, impostoSimplesTotal);

      // B: IRRF Sipes (O que já seria retido lá)
      double baseLegalSipes = valorSipes - inssSobreSipes;
      double impostoLegalSipes = baseLegalSipes > 0 ? _calcularIrrf(baseLegalSipes, tabelaIrrf) : 0.0;

      double baseSimplesSipes = valorSipes - descontoSimplificado;
      double impostoSimplesSipes = baseSimplesSipes > 0 ? _calcularIrrf(baseSimplesSipes, tabelaIrrf) : 0.0;

      irrfSipesFinal = min(impostoLegalSipes, impostoSimplesSipes);

      // C: Diferença a pagar
      irrf = max(0, irrfTotal - irrfSipesFinal);
      irrfBrutoFinal = irrfTotal;
    }

    double liquido = valorBrutoConvenio - inssDevido - irrf - pensao - outros;

    return {
      'bruto': valorBrutoConvenio,
      'inss': inssDevido,
      'inss_total': inssSobreTotal,
      'inss_sipes': inssSobreSipes,
      'irrf': irrf,
      'irrf_total': irrfBrutoFinal,
      'irrf_sipes': irrfSipesFinal,
      'pensao': pensao,
      'outros': outros,
      'liquido': liquido,
      'sipes': valorSipes,
    };
  }

  // --- FUNÇÕES AUXILIARES ---
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
    return imposto; // Se passar do teto, retorna o acumulado
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