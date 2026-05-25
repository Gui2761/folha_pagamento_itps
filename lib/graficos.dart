import 'package:flutter/material.dart';
import 'dart:math';

// --- GRÁFICO DE ROSCA (SETORES/LOTAÇÃO) ---
class GraficoSetores extends StatelessWidget {
  final Map<String, double> dadosSetores;
  final bool isDarkMode;

  const GraficoSetores({
    super.key,
    required this.dadosSetores,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (dadosSetores.isEmpty) {
      return Center(
        child: Text(
          "Sem dados disponíveis",
          style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
        ),
      );
    }

    // Cores premium para o gráfico
    final List<Color> cores = [
      const Color(0xFF0D47A1), // Azul Escuro
      const Color(0xFF1E88E5), // Azul Claro
      const Color(0xFF26A69A), // Verde Ciano
      const Color(0xFF66BB6A), // Verde
      const Color(0xFFFFB300), // Amarelo/Laranja
      const Color(0xFFEF5350), // Vermelho Suave
      const Color(0xFFAB47BC), // Roxo
      const Color(0xFF26C6DA), // Ciano
      const Color(0xFF8D6E63), // Marrom Suave
      const Color(0xFF78909C), // Slate
    ];

    double totalValores = dadosSetores.values.fold(0, (sum, val) => sum + val);

    // Filtrar e agrupar setores muito pequenos em "Outros" se passar de 8 itens
    final List<MapEntry<String, double>> listaOrdenada = dadosSetores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<MapEntry<String, double>> setoresExibidos = [];
    double totalOutros = 0.0;

    for (int i = 0; i < listaOrdenada.length; i++) {
      if (i < 7) {
        setoresExibidos.add(listaOrdenada[i]);
      } else {
        totalOutros += listaOrdenada[i].value;
      }
    }

    if (totalOutros > 0) {
      setoresExibidos.add(MapEntry("Outros", totalOutros));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double minSize = min(constraints.maxWidth * 0.45, constraints.maxHeight - 20);
        
        return Row(
          children: [
            // Círculo do Gráfico
            Container(
              width: minSize,
              height: minSize,
              margin: const EdgeInsets.all(10),
              child: CustomPaint(
                painter: _DoughnutChartPainter(
                  setoresExibidos: setoresExibidos,
                  totalValores: totalValores,
                  cores: cores,
                  isDarkMode: isDarkMode,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Legendas do Gráfico
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: setoresExibidos.length,
                itemBuilder: (context, index) {
                  final item = setoresExibidos[index];
                  final cor = cores[index % cores.length];
                  final perc = (item.value / totalValores) * 100;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: cor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "${perc.toStringAsFixed(1)}%",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DoughnutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> setoresExibidos;
  final double totalValores;
  final List<Color> cores;
  final bool isDarkMode;

  _DoughnutChartPainter({
    required this.setoresExibidos,
    required this.totalValores,
    required this.cores,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalValores == 0) return;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.26
      ..isAntiAlias = true;

    double startAngle = -pi / 2;

    for (int i = 0; i < setoresExibidos.length; i++) {
      final sweepAngle = (setoresExibidos[i].value / totalValores) * 2 * pi;
      paint.color = cores[i % cores.length];

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Desenhar sombra interna ou borda sutil no centro
    final centerPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      (size.width / 2) - (size.width * 0.26 / 2) - 1,
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- GRÁFICO DE BARRAS COMPARATIVO (BRUTO VS LÍQUIDO) ---
class GraficoBarrasComparativo extends StatelessWidget {
  final double valorBruto;
  final double valorLiquido;
  final double valorDescontos;
  final bool isDarkMode;

  const GraficoBarrasComparativo({
    super.key,
    required this.valorBruto,
    required this.valorLiquido,
    required this.valorDescontos,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    double totalMax = max(valorBruto, 1.0);
    double percLiquido = (valorLiquido / totalMax) * 100;
    double percDescontos = (valorDescontos / totalMax) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Distribuição do Bruto Geral",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Barra 1: Bruto
              _buildBarra("Bruto Total", valorBruto, 100, const Color(0xFF0D47A1), isDarkMode),
              // Barra 2: Líquido
              _buildBarra("Líquido Pago", valorLiquido, percLiquido, const Color(0xFF26A69A), isDarkMode),
              // Barra 3: Descontos
              _buildBarra("Retenções", valorDescontos, percDescontos, const Color(0xFFEF5350), isDarkMode),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarra(String rotulo, double valor, double percentual, Color cor, bool isDark) {
    // Formatar moeda compacto
    String valorFormatado = "R\$ ${valor.toStringAsFixed(2)}";
    if (valor >= 1000000) {
      valorFormatado = "R\$ ${(valor / 1000000).toStringAsFixed(2)}M";
    } else if (valor >= 1000) {
      valorFormatado = "R\$ ${(valor / 1000).toStringAsFixed(1)}k";
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          valorFormatado,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 45,
          height: max(5.0, percentual * 1.5), // Escala do gráfico de barras
          decoration: BoxDecoration(
            color: cor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: cor.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        Text(
          "${percentual.toStringAsFixed(0)}%",
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }
}
