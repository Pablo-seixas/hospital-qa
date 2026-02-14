import AsyncStorage from '@react-native-async-storage/async-storage';
import * as AuthService from '@/services/auth/auth.service';

const mockGetByEmail = jest.fn();
const mockGetById = jest.fn();
const mockUpdate = jest.fn();

jest.mock('@/data/repositories/employees.repo', () => ({
  EmployeesRepo: {
    getByEmail: (...args: any[]) => mockGetByEmail(...args),
    getById: (...args: any[]) => mockGetById(...args),
    update: (...args: any[]) => mockUpdate(...args),
  },
}));

const mockAuditLog = jest.fn(async () => {});
jest.mock('@/services/audit/audit.service', () => ({
  auditLog: (...args: any[]) => mockAuditLog(...args),
}));

jest.mock('@/utils/hash', () => ({
  simpleHash: (v: string) => `h:${v}`,
}));

describe('auth.service MFA negative cases', () => {
  beforeEach(async () => {
    jest.clearAllMocks();
    await AsyncStorage.clear();
  });

  async function seedPendingMfa(employeeId = 'e10') {
    mockGetByEmail.mockResolvedValueOnce({
      id: employeeId,
      name: 'User',
      role: 'EMPLOYEE',
      passwordHash: 'h:1234',
      mfaEnabled: 1,
      mfaImageToken: 'IMG',
    });
    await AuthService.login('u@x.com', '1234');

    mockGetById.mockResolvedValueOnce({
      id: employeeId,
      name: 'User',
      role: 'EMPLOYEE',
      mfaEnabled: 1,
      mfaImageToken: 'IMG',
    });
  }

  it('rejects when phone code is wrong', async () => {
    await seedPendingMfa();

    const res = await AuthService.verifyMfa({
      phoneCode: '000000',
      emailCode: '222222',
      imageToken: 'IMG',
    });

    expect(res.ok).toBe(false);
    if (!res.ok) expect(res.error).toMatch(/inválidos/i);
    expect(mockUpdate).not.toHaveBeenCalled();
    expect(mockAuditLog).not.toHaveBeenCalledWith(expect.objectContaining({ action: 'MFA_VERIFY' }));
  });

  it('rejects when email code is wrong', async () => {
    await seedPendingMfa();

    const res = await AuthService.verifyMfa({
      phoneCode: '111111',
      emailCode: '000000',
      imageToken: 'IMG',
    });

    expect(res.ok).toBe(false);
    if (!res.ok) expect(res.error).toMatch(/inválidos/i);
    expect(mockUpdate).not.toHaveBeenCalled();
  });

  it('rejects when image token is wrong', async () => {
    await seedPendingMfa();

    const res = await AuthService.verifyMfa({
      phoneCode: '111111',
      emailCode: '222222',
      imageToken: 'WRONG',
    });

    expect(res.ok).toBe(false);
    if (!res.ok) expect(res.error).toMatch(/inválidos/i);
    expect(mockUpdate).not.toHaveBeenCalled();
  });
});
