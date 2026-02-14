# QA Report

## Escopo
- App React Native (smoke + fluxos principais)
- Integração com API (quando aplicável)

## Estratégia
- Lint/Format
- Testes unitários (Jest) quando existirem
- Testes E2E (Detox) para smoke
- Teste manual com checklist

## Evidências
- Prints/Vídeos/Logs em `qa/evidence` (não versionar se tiver dados sensíveis)

## Resultados
- (preencher após rodar pipeline)

## Evidências geradas
- Execução: `qa/evidence/test-run.txt`
- Cobertura: `qa/evidence/coverage-summary.txt`
- Relatório HTML: `qa/coverage/lcov-report/index.html`

## Observações técnicas (mocks)
- AsyncStorage mockado para ambiente Jest
- expo-sqlite mockado para evitar dependências nativas (expo-asset) no Node

## Quality gates (local)
- Prettier check: `qa/evidence/format-check.txt`
- ESLint: `qa/evidence/lint.txt`
- Unit/UI tests: `qa/evidence/tests.txt`
