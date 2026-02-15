Hospital – QA e Testes de Software (TypeScript)

Este repositório reúne artefatos e evidências de Qualidade de Software aplicados ao projeto Hospital, uma aplicação em desenvolvimento construída com React Native + Node.js + PostgreSQL, com código e testes em TypeScript.

O objetivo é demonstrar prática de QA em um cenário real: estratégia, planejamento, execução, evidências e padrões de relatório.

 Contexto do Projeto

O sistema estava em desenvolvimento ativo durante a execução dos testes.
Por isso, a abordagem adotada foi baseada em priorização por risco, concentrando testes nos módulos mais sensíveis (ex.: autenticação, autorização e RBAC).

O foco foi validar comportamento e segurança funcional, não “inflar” métricas de cobertura.

 Escopo de QA

Estratégia de testes (baseada em risco)

Matriz de rastreabilidade / cobertura funcional

Testes unitários em TypeScript (Jest)

Testes de autenticação e autorização (RBAC)

Evidências de execução

Relatório de cobertura

Template profissional de Bug Report

Checklists de validação

 Estrutura do repositório
qa/
- QA_REPORT.md        → Relatório técnico consolidado
- test-matrix.md      → Matriz de rastreabilidade (casos x requisitos)
- evidence/           → Evidências e logs de execução
- bugs/               → Template de Bug Report
- checklists/         → Checklists de validação

__tests__/
- Testes unitários (TypeScript) de:
  - Auth service
  - Auth store
  - RBAC
  - Renderização de telas principais
🧪 Abordagem de Qualidade

A estratégia aplicada considera:

Fluxos positivos e negativos

Falhas de autenticação (token inválido/expirado, sessão, etc.)

Simulação de MFA (quando aplicável ao fluxo)

Validação de permissões por role (RBAC)

Tratamento de erros e retornos (ex.: API)

Controle de estado (Zustand)

Mocks de dependências externas

📊 Cobertura atual

A cobertura reflete a fase do projeto e a priorização por risco (módulos críticos primeiro):

Statements: 8.85%

Branches: 5.18%

Functions: 7.27%

Lines: 9.22%

Os testes foram concentrados em funcionalidades de autenticação e autorização, por serem áreas críticas para segurança e controle de acesso.

 Como executar os testes

Pré-requisitos:

Node.js 20+

Instalar dependências:

npm install

Rodar testes:

npx jest

Rodar com cobertura:

npx jest --coverage

Observação: o projeto utiliza testes em TypeScript (ex.: ts-jest quando aplicável na configuração).

 Observação importante

Este repositório não contém o código-fonte completo da aplicação.
Ele existe para expor o que fica “na vitrine” de QA: processo, estratégia, evidência e documentação.

 Autor

Pablo Seixas
QA / Software Quality Engineer
