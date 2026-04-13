import 'package:flutter_test/flutter_test.dart';
import 'package:folha_pagamento_itps/calculadora_taxas.dart';

void main() {
  group('CalculadoraTaxas - Lei 2026', () {
    final configData = {
      'geral': {
        'base_convenio': 210000.0,
        'desconto_simplificado': 607.20,
      },
      'inss': [
        {'limite': 1621.00, 'aliquota': 7.5},
        {'limite': 2902.84, 'aliquota': 9.0},
        {'limite': 4354.27, 'aliquota': 12.0},
        {'limite': 8475.55, 'aliquota': 14.0},
      ],
      'irrf': [
        {'limite': 2259.20, 'aliquota': 0.0, 'deducao': 0.0},
        {'limite': 2826.65, 'aliquota': 7.5, 'deducao': 169.44},
        {'limite': 3751.05, 'aliquota': 15.0, 'deducao': 381.44},
        {'limite': 4664.68, 'aliquota': 22.5, 'deducao': 662.77},
        {'limite': 99999999.0, 'aliquota': 27.5, 'deducao': 896.00},
      ]
    };

    test('Isenção total para rendimentos até R\$ 5.000,00', () {
      final resultado = CalculadoraTaxas.calcularFolha(
        percentual: 2.0, // 210000 * 0.02 = 4200
        valorSipes: 0.0,
        pensao: 0.0,
        outros: 0.0,
        acrescimos: 0.0,
        temInss: false,
        temIrrf: true,
        configData: configData,
      );
      
      expect(resultado['irrf'], 0.0);
    });

    test('Aplicação do redutor decrescente para rendimentos entre 5000 e 7350', () {
      // Exemplo: Salário R$ 6.000,00
      // 1. IRRF Normal: (6000 * 0.275) - 896.0 = 1650 - 896 = 754.0
      // 2. Redução 2026: 978.62 - (0.133145 * 6000) = 978.62 - 798.87 = 179.75
      // 3. IRRF Final: 754.0 - 179.75 = 574.25
      
      CalculadoraTaxas.calcularFolha(
        percentual: 2.85714, // Aprox 6000/210000
        valorSipes: 0.0,
        pensao: 0.0,
        outros: 0.0,
        acrescimos: 0.0,
        temInss: false,
        temIrrf: true,
        configData: configData,
      );
      
      // Ajustando percentual para dar exatamente 6000
      final resultadoExato = CalculadoraTaxas.calcularFolha(
        percentual: (6000 / 210000) * 100,
        valorSipes: 0.0,
        pensao: 0.0,
        outros: 0.0,
        acrescimos: 0.0,
        temInss: false,
        temIrrf: true,
        configData: configData,
      );

      expect(resultadoExato['bruto'], 6000.0);
      expect(resultadoExato['irrf'], 407.27);
    });

    test('Cálculo normal para rendimentos acima de R\$ 7.350,00', () {
      // Exemplo: Salário R$ 8.000,00
      // IRRF Normal: (8000 * 0.275) - 896.0 = 2200 - 896 = 1304.0
      
      final resultado = CalculadoraTaxas.calcularFolha(
        percentual: (8000 / 210000) * 100,
        valorSipes: 0.0,
        pensao: 0.0,
        outros: 0.0,
        acrescimos: 0.0,
        temInss: false,
        temIrrf: true,
        configData: configData,
      );

      expect(resultado['bruto'], 8000.0);
      expect(resultado['irrf'], 1137.02);
    });
  });
}
