import 'package:flutter_test/flutter_test.dart';
import 'package:folha_pagamento_itps/calculadora_taxas.dart';

void main() {
  group('Testes de Cálculo - 3 Cenários', () {
    // Configuração com dados reais de 2026
    final Map<String, dynamic> configData = {
      'geral': {
        'base_convenio': 210000.00,
        'aliquota_patronal': 9.02,
        'teto_inss': 8475.55,
        'desconto_simplificado': 607.20,
      },
      'inss': [
        {'limite': 1621.00, 'aliquota': 7.5, 'deducao': 0.0},
        {'limite': 2902.84, 'aliquota': 9.0, 'deducao': 24.32},
        {'limite': 4354.27, 'aliquota': 12.0, 'deducao': 111.40},
        {'limite': 8475.55, 'aliquota': 14.0, 'deducao': 198.49},
      ],
      'irrf': [
        {'limite': 2428.80, 'aliquota': 0.0, 'deducao': 0.0},
        {'limite': 2826.65, 'aliquota': 7.5, 'deducao': 182.16},
        {'limite': 3751.05, 'aliquota': 15.0, 'deducao': 394.16},
        {'limite': 4664.68, 'aliquota': 22.5, 'deducao': 675.49},
        {'limite': 999999999.00, 'aliquota': 27.5, 'deducao': 908.73},
      ],
    };

    test('CENÁRIO 1: Paga Tudo (INSS + IRRF)', () {
      // Pessoa com baixo salário SIPES - vai pagar ambos os impostos no convênio
      print(
          '\n╔════════════════════════════════════════════════════════════════╗');
      print(
          '║  CENÁRIO 1: PAGA TUDO (INSS + IRRF)                           ║');
      print(
          '╚════════════════════════════════════════════════════════════════╝');

      final resultado = CalculadoraTaxas.calcularFolha(
        percentual: 0.75, // 0.75% de participação
        valorSipes: 2500.00, // Salário SIPES base
        pensao: 0.0, // Sem pensão
        outros: 0.0, // Sem outros descontos
        acrescimos: 0.0, // Sem acréscimos
        temInss: true,
        temIrrf: true,
        configData: configData,
      );

      print('\n📊 DADOS DE ENTRADA:');
      print('  • SIPES: R\$ ${resultado['sipes']?.toStringAsFixed(2)}');
      print('  • Percentual: 0.75%');
      print('  • Pensão: R\$ 0,00');

      print('\n📈 CÁLCULOS INTERMEDIÁRIOS:');
      print(
          '  • Valor Convênio: R\$ ${resultado['base_convenio']?.toStringAsFixed(2)}');
      print(
          '  • Base Global Bruta: R\$ ${resultado['base_global_bruta']?.toStringAsFixed(2)}');
      print(
          '  • INSS Total Global: R\$ ${resultado['inss_total']?.toStringAsFixed(2)}');
      print(
          '  • INSS no SIPES: R\$ ${resultado['inss_sipes']?.toStringAsFixed(2)}');
      print('  • Base IRRF: R\$ ${resultado['base_irrf']?.toStringAsFixed(2)}');
      print(
          '  • IRRF Total Global: R\$ ${resultado['irrf_total']?.toStringAsFixed(2)}');
      print(
          '  • IRRF no SIPES: R\$ ${resultado['irrf_sipes']?.toStringAsFixed(2)}');

      print('\n💰 DESCONTOS NA FOLHA DO CONVÊNIO:');
      print(
          '  • INSS a Descontar: R\$ ${resultado['inss']?.toStringAsFixed(2)}');
      print(
          '  • IRRF a Descontar: R\$ ${resultado['irrf']?.toStringAsFixed(2)}');
      print('  • Pensão: R\$ ${resultado['pensao']?.toStringAsFixed(2)}');

      print('\n✅ RESULTADO FINAL:');
      print(
          '  • Bruto Convênio: R\$ ${resultado['bruto']?.toStringAsFixed(2)}');
      print('  • (-) INSS: R\$ ${resultado['inss']?.toStringAsFixed(2)}');
      print('  • (-) IRRF: R\$ ${resultado['irrf']?.toStringAsFixed(2)}');
      print('  • LÍQUIDO: R\$ ${resultado['liquido']?.toStringAsFixed(2)}');

      // Validações básicas
      expect(resultado['inss'], greaterThan(0),
          reason: 'Deve ter INSS a descontar');
      expect(resultado['irrf'], greaterThan(0),
          reason: 'Deve ter IRRF a descontar');
      expect(resultado['liquido'], greaterThan(0),
          reason: 'Líquido deve ser positivo');
    });

    test('CENÁRIO 2: Só INSS (IRRF zero por isenção)', () {
      // Pessoa com salário SIPES bem baixo - IRRF fica zerado por ficar abaixo da isenção
      print(
          '\n╔════════════════════════════════════════════════════════════════╗');
      print(
          '║  CENÁRIO 2: SÓ INSS (IRRF ZERADO)                             ║');
      print(
          '╚════════════════════════════════════════════════════════════════╝');

      final resultado = CalculadoraTaxas.calcularFolha(
        percentual: 0.41, // 0.41% de participação
        valorSipes: 1800.00, // Salário SIPES baixo
        pensao: 0.0,
        outros: 0.0,
        acrescimos: 0.0,
        temInss: true,
        temIrrf: true,
        configData: configData,
      );

      print('\n📊 DADOS DE ENTRADA:');
      print('  • SIPES: R\$ ${resultado['sipes']?.toStringAsFixed(2)}');
      print('  • Percentual: 0.41%');

      print('\n📈 CÁLCULOS INTERMEDIÁRIOS:');
      print(
          '  • Valor Convênio: R\$ ${resultado['base_convenio']?.toStringAsFixed(2)}');
      print(
          '  • Base Global Bruta: R\$ ${resultado['base_global_bruta']?.toStringAsFixed(2)}');
      print(
          '  • INSS Total Global: R\$ ${resultado['inss_total']?.toStringAsFixed(2)}');
      print('  • Base IRRF: R\$ ${resultado['base_irrf']?.toStringAsFixed(2)}');
      print(
          '  • IRRF Total Global: R\$ ${resultado['irrf_total']?.toStringAsFixed(2)}');

      print('\n💰 DESCONTOS NA FOLHA DO CONVÊNIO:');
      print(
          '  • INSS a Descontar: R\$ ${resultado['inss']?.toStringAsFixed(2)}');
      print(
          '  • IRRF a Descontar: R\$ ${resultado['irrf']?.toStringAsFixed(2)}');

      print('\n✅ RESULTADO FINAL:');
      print(
          '  • Bruto Convênio: R\$ ${resultado['bruto']?.toStringAsFixed(2)}');
      print('  • (-) INSS: R\$ ${resultado['inss']?.toStringAsFixed(2)}');
      print('  • (-) IRRF: R\$ ${resultado['irrf']?.toStringAsFixed(2)}');
      print('  • LÍQUIDO: R\$ ${resultado['liquido']?.toStringAsFixed(2)}');

      expect(resultado['inss'], greaterThan(0),
          reason: 'Deve ter INSS a descontar');
      expect(resultado['irrf'], equals(0),
          reason: 'IRRF deve ser zero (isenção)');
    });

    test('CENÁRIO 3: Só IRRF (INSS já pago no teto)', () {
      // Pessoa com alto salário SIPES - já atingiu o teto do INSS, IRRF terá valor
      print(
          '\n╔════════════════════════════════════════════════════════════════╗');
      print(
          '║  CENÁRIO 3: SÓ IRRF (INSS NO TETO)                            ║');
      print(
          '╚════════════════════════════════════════════════════════════════╝');

      final resultado = CalculadoraTaxas.calcularFolha(
        percentual: 1.50, // 1.50% de participação
        valorSipes: 8500.00, // Salário SIPES alto (já pagou teto INSS)
        pensao: 0.0,
        outros: 0.0,
        acrescimos: 0.0,
        temInss: true,
        temIrrf: true,
        configData: configData,
      );

      print('\n📊 DADOS DE ENTRADA:');
      print('  • SIPES: R\$ ${resultado['sipes']?.toStringAsFixed(2)}');
      print('  • Percentual: 1.50%');

      print('\n📈 CÁLCULOS INTERMEDIÁRIOS:');
      print(
          '  • Valor Convênio: R\$ ${resultado['base_convenio']?.toStringAsFixed(2)}');
      print(
          '  • Base Global Bruta: R\$ ${resultado['base_global_bruta']?.toStringAsFixed(2)}');
      print(
          '  • INSS Total Global (TRAVÃO): R\$ ${resultado['inss_total']?.toStringAsFixed(2)}');
      print(
          '  • INSS no SIPES: R\$ ${resultado['inss_sipes']?.toStringAsFixed(2)}');
      print('  • Base IRRF: R\$ ${resultado['base_irrf']?.toStringAsFixed(2)}');
      print(
          '  • IRRF Total Global: R\$ ${resultado['irrf_total']?.toStringAsFixed(2)}');
      print(
          '  • IRRF no SIPES: R\$ ${resultado['irrf_sipes']?.toStringAsFixed(2)}');

      print('\n💰 DESCONTOS NA FOLHA DO CONVÊNIO:');
      print(
          '  • INSS a Descontar: R\$ ${resultado['inss']?.toStringAsFixed(2)}');
      print(
          '  • IRRF a Descontar: R\$ ${resultado['irrf']?.toStringAsFixed(2)}');

      print('\n✅ RESULTADO FINAL:');
      print(
          '  • Bruto Convênio: R\$ ${resultado['bruto']?.toStringAsFixed(2)}');
      print('  • (-) INSS: R\$ ${resultado['inss']?.toStringAsFixed(2)}');
      print('  • (-) IRRF: R\$ ${resultado['irrf']?.toStringAsFixed(2)}');
      print('  • LÍQUIDO: R\$ ${resultado['liquido']?.toStringAsFixed(2)}');

      expect(resultado['inss'], equals(0),
          reason: 'INSS deve ser zero (já pagou teto no SIPES)');
      expect(resultado['irrf'], greaterThan(0),
          reason: 'Deve ter IRRF a descontar');
    });

    test('CENÁRIO EXTRA: Com Pensão Alimentícia', () {
      // Testa a dedução de pensão alimentícia na base do IRRF
      print(
          '\n╔════════════════════════════════════════════════════════════════╗');
      print(
          '║  CENÁRIO EXTRA: COM PENSÃO ALIMENTÍCIA                        ║');
      print(
          '╚════════════════════════════════════════════════════════════════╝');

      final resultado = CalculadoraTaxas.calcularFolha(
        percentual: 0.75,
        valorSipes: 3000.00,
        pensao: 500.00, // Pensão alimentícia
        outros: 50.00, // Outro desconto
        acrescimos: 100.00, // Acréscimo
        temInss: true,
        temIrrf: true,
        configData: configData,
      );

      print('\n📊 DADOS DE ENTRADA:');
      print('  • SIPES: R\$ ${resultado['sipes']?.toStringAsFixed(2)}');
      print('  • Percentual: 0.75%');
      print('  • Pensão: R\$ ${resultado['pensao']?.toStringAsFixed(2)}');
      print('  • Outros: R\$ ${resultado['outros']?.toStringAsFixed(2)}');
      print(
          '  • Acréscimos: R\$ ${resultado['acrescimos']?.toStringAsFixed(2)}');

      print('\n📈 CÁLCULOS INTERMEDIÁRIOS:');
      print(
          '  • Valor Convênio: R\$ ${resultado['base_convenio']?.toStringAsFixed(2)}');
      print(
          '  • Base Global Bruta: R\$ ${resultado['base_global_bruta']?.toStringAsFixed(2)}');
      print(
          '  • Base IRRF (após pensão): R\$ ${resultado['base_irrf']?.toStringAsFixed(2)}');

      print('\n💰 DESCONTOS NA FOLHA DO CONVÊNIO:');
      print('  • INSS: R\$ ${resultado['inss']?.toStringAsFixed(2)}');
      print('  • IRRF: R\$ ${resultado['irrf']?.toStringAsFixed(2)}');
      print('  • Pensão: R\$ ${resultado['pensao']?.toStringAsFixed(2)}');
      print('  • Outros: R\$ ${resultado['outros']?.toStringAsFixed(2)}');
      print(
          '  • Acréscimos: R\$ ${resultado['acrescimos']?.toStringAsFixed(2)}');

      print('\n✅ RESULTADO FINAL:');
      print(
          '  • Bruto Convênio: R\$ ${resultado['bruto']?.toStringAsFixed(2)}');
      print(
          '  • Total Descontos: R\$ ${(resultado['inss']! + resultado['irrf']! + resultado['pensao']! + resultado['outros']! - resultado['acrescimos']!).toStringAsFixed(2)}');
      print('  • LÍQUIDO: R\$ ${resultado['liquido']?.toStringAsFixed(2)}');

      // Validação: a base do IRRF deve ser menor pela pensão
      expect(resultado['base_irrf'],
          lessThan(resultado['base_global_bruta']! - resultado['inss_total']!),
          reason: 'Base IRRF deve ser reduzida pela pensão');
    });
  });
}
