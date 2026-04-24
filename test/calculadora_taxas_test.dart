import 'package:flutter_test/flutter_test.dart';
import 'package:folha_pagamento_itps/calculadora_taxas.dart';

void main() {
  group('Validação Janeiro/2026 - Conforme RH', () {
    final configData = {
      'geral': {
        'base_convenio': 208720.00,
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
        {'limite': 99999999.0, 'aliquota': 27.5, 'deducao': 908.73},
      ]
    };

    group('Comissionados sem SIPES (temInss:true, temIrrf:true)', () {
      test('Adailton (1,15%) -> B=2400.28, INSS=191.71, Líq=2208.57', () {
        final r = CalculadoraTaxas.calcularFolha(
          percentual: 1.15, valorSipes: 0.0, pensao: 0.0, outros: 0.0, acrescimos: 0.0,
          temInss: true, temIrrf: true, configData: configData,
        );
        expect(r['bruto'], 2400.28);
        expect(r['inss'], 191.71);
        expect(r['liquido'], 2208.57);
      });
    });

    group('Comissionados com SIPES - só INSS (temIrrf:false)', () {
      test('Maianne Mirelle (1,10% | SIPES=1883.40) -> INSS=244.93, Líq=2050.99', () {
        final r = CalculadoraTaxas.calcularFolha(
          percentual: 1.10, valorSipes: 1883.40, pensao: 0.0, outros: 0.0, acrescimos: 0.0,
          temInss: true, temIrrf: false, configData: configData,
        );
        expect(r['bruto'], 2295.92);
        expect(r['inss'], 244.93);
        expect(r['liquido'], 2050.99);
      });

      test('Carlos André (0,80% | sem SIPES) -> INSS=125.96, Líq=1543.80', () {
        final r = CalculadoraTaxas.calcularFolha(
          percentual: 0.80, valorSipes: 0.0, pensao: 0.0, outros: 0.0, acrescimos: 0.0,
          temInss: true, temIrrf: false, configData: configData,
        );
        expect(r['inss'], 125.96);
        expect(r['liquido'], 1543.80);
      });
    });

    group('Cedidos Estaduais (Antonio Carlos)', () {
      test('Antonio Carlos (2,5% | SIPES=22451.02) -> IRRF=1434.95, Líq=3783.05', () {
        final r = CalculadoraTaxas.calcularFolha(
          percentual: 2.5, valorSipes: 22451.02, pensao: 0.0, outros: 0.0, acrescimos: 0.0,
          temInss: false, temIrrf: true, configData: configData,
        );
        expect(r['irrf'], 1434.95);
        expect(r['liquido'], 3783.05);
      });
    });
  });
}
