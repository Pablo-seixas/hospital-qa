Hospital – QA e Testes de Software

Este repositório contém os artefatos de Qualidade de Software desenvolvidos para o projeto Hospital (aplicação React Native + Node + PostgreSQL).

O foco deste repositório é demonstrar processo de QA, estratégia de testes, evidências de execução e padronização de relatórios.

Escopo

• Estratégia de testes  
• Matriz de cobertura funcional  
• Testes unitários (Jest)  
• Testes de autenticação e RBAC  
• Evidências de execução  
• Relatório de cobertura  
• Template profissional de Bug Report  
• Checklists de validação  

Estrutura do repositório

qa/
- QA_REPORT.md → Relatório técnico consolidado
- test-matrix.md → Matriz de rastreabilidade
- evidence/ → Logs de execução
- bugs/ → Template de Bug Report
- checklists/ → Checklists de validação

__tests__/
- Testes unitários de:
  - Auth service
  - Auth store
  - RBAC
  - Renderização de telas principais

Abordagem de Qualidade

A estratégia aplicada considera:

• Testes de fluxo positivo e negativo  
• Casos de falha de autenticação  
• Simulação de MFA  
• Validação de permissões por role  
• Tratamento de erros  
• Controle de estado (Zustand)  
• Mock de dependências externas  

O objetivo foi validar comportamento e não apenas cobertura numérica.

Cobertura atual

Statements: 8.85%  
Branches: 5.18%  
Functions: 7.27%  
Lines: 9.22%  

A cobertura priorizou módulos críticos (autenticação e autorização).

Como executar os testes

Pré-requisitos:
Node 20+

Executar:

npx jest

Para rodar com cobertura:

npx jest --coverage

Observação

Este repositório não contém o código-fonte completo da aplicação.
Apenas os artefatos relacionados à qualidade e testes.

Autor

Pablo Seixas  
QA / Software Quality Engineer
