Relatório de Gate de Segurança

Este diretório contém os resultados da análise estática de segurança realizada na aplicação Hospital durante fase ativa de desenvolvimento.

O objetivo desta avaliação foi validar a postura de segurança do código-fonte por meio de técnicas automatizadas de SAST (Static Application Security Testing) antes da publicação das evidências no repositório.

Ferramenta Utilizada
Semgrep (regras da comunidade)

Configuração Aplicada
Conjunto de regras security-audit
Conjunto de regras OWASP Top 10

Escopo da Análise
A varredura foi executada sobre 444 arquivos versionados, incluindo código TypeScript e JavaScript.

Resumo dos Resultados
Foram executadas 30 regras com foco em segurança.
Nenhum achado foi identificado.
Nenhum problema bloqueante foi detectado.

De acordo com as regras aplicadas, o código analisado não apresentou padrões associados a vulnerabilidades comuns como falhas de injeção, uso inseguro de APIs, exposição de segredos ou problemas relacionados às categorias do OWASP Top 10.

Considerações Técnicas
A análise estática representa uma verificação automatizada baseada em padrões conhecidos.
Resultados refletem o estado do projeto no momento da execução.
Recomenda-se complementar com análise dinâmica e verificação de dependências para cobertura ampliada.

Finalidade da Publicação
As evidências armazenadas neste diretório demonstram a aplicação de gate de segurança como parte do processo de Qualidade de Software.
O objetivo é documentar a execução de validação automatizada de segurança em ambiente real de desenvolvimento.

Autor
Pablo Seixas
Quality Assurance
