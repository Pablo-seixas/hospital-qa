# Test Matrix

| Área | Caso | Tipo | Arquivo | Status | Evidência |
|------|------|------|---------|--------|----------|
| App | App abre sem crash | Unit/UI | __tests__/App.smoke.test.tsx |  | qa/evidence/test-run.txt |
| Auth | AuthScreen renderiza | Unit/UI | __tests__/AuthScreen.render.test.tsx |  | qa/evidence/test-run.txt |
| Infra | AsyncStorage mock | Test infra | jest.setup.ts |  | qa/evidence/test-run.txt |
| Infra | Expo SQLite mock | Test infra | jest.setup.ts |  | qa/evidence/test-run.txt |
| RBAC | ROOT_ADMIN possui todas permissões | Unit | __tests__/unit/rbac.can.test.ts |  | qa/evidence/test-run.txt |
| RBAC | RECEPTION permissões corretas | Unit | __tests__/unit/rbac.can.test.ts |  | qa/evidence/test-run.txt |
| RBAC | EMPLOYEE permissões limitadas | Unit | __tests__/unit/rbac.can.test.ts |  | qa/evidence/test-run.txt |
| Auth/MFA | Rejeita phoneCode inválido | Unit | __tests__/unit/auth.mfa.negative.test.ts | pass | qa/evidence/test-run.txt |
| Auth/MFA | Rejeita emailCode inválido | Unit | __tests__/unit/auth.mfa.negative.test.ts | pass | qa/evidence/test-run.txt |
| Auth/MFA | Rejeita imageToken inválido | Unit | __tests__/unit/auth.mfa.negative.test.ts | pass | qa/evidence/test-run.txt |
