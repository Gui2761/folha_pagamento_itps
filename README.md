ITPS Folha Automação 📱💰
Um aplicativo móvel desenvolvido para facilitar o setor de Recursos Humanos e Financeiro do ITPS. O objetivo é automatizar o cálculo e a gestão da folha de pagamento dos funcionários e estagiários, eliminando o trabalho manual em planilhas.

✨ Funcionalidades

Calculadora Dinâmica: Algoritmo dedicado para calcular pagamentos, descontos (como meia-passagem de ônibus) e dias proporcionais.

Gestão de Cadastros: Inserção e manutenção de dados de estagiários e funcionários.

Persistência Local: Banco de dados integrado ao app para salvar históricos e informações de forma rápida e offline.

Interface Intuitiva: Telas limpas desenvolvidas em Flutter para facilitar o uso diário pela equipe administrativa.

🚀 Tecnologias Utilizadas

Frontend (Mobile)

Framework: Flutter (Dart)

Armazenamento Local: SQLite (database_helper.dart) para persistência relacional off-line.

Lógica de Negócio: Módulos independentes em Dart (calculadora_folha.dart).

📦 Estrutura do Projeto

lib/main.dart: Ponto de entrada da aplicação Flutter e interface de usuário.

lib/calculadora_folha.dart: Classe com a inteligência e regras de negócio para cálculos de salário/descontos.

lib/database_helper.dart: Gerenciador de conexão e tabelas do banco de dados local.

⚙️ Configuração e Instalação
Pré-requisitos

Flutter SDK instalado.

Android Studio ou Xcode (para emuladores).
