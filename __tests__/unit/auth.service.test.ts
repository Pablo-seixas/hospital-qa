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

describe('auth.service', () => {
  beforeEach(async () => {
    jest.clearAllMocks();
    await AsyncStorage.clear();
  });

  it('login returns not found when employee does not exist', async () => {
    mockGetByEmail.mockResolvedValueOnce(null);

    const res = await AuthService.login('x@x.com', '1234');

    expect(res.ok).toBe(false);
    if (!res.ok) expect(res.error).toMatch(/Usuário não encontrado/);
    expect(mockAuditLog).not.toHaveBeenCalled();
  });

  it('login returns invalid password when hash does not match', async () => {
    mockGetByEmail.mockResolvedValueOnce({
      id: 'e1',
      name: 'Root',
      role: 'ROOT_ADMIN',
      passwordHash: 'h:other',
      mfaEnabled: 0,
    });

    const res = await AuthService.login('root@hospital.com', '1234');

    expect(res.ok).toBe(false);
    if (!res.ok) expect(res.error).toMatch(/Senha incorreta/);
    expect(mockAuditLog).not.toHaveBeenCalled();
  });

  it('login stores session when MFA is disabled and writes audit log', async () => {
    mockGetByEmail.mockResolvedValueOnce({
      id: 'e1',
      name: 'Root',
      role: 'ROOT_ADMIN',
      passwordHash: 'h:1234',
      mfaEnabled: 0,
    });

    const res = await AuthService.login('root@hospital.com', '1234');

    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.mfaRequired).toBe(false);
      expect(res.employeeId).toBe('e1');
    }

    expect(mockAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        actorEmployeeId: 'e1',
        action: 'LOGIN',
        entity: 'EMPLOYEE',
        entityId: 'e1',
        meta: expect.objectContaining({ email: 'root@hospital.com' }),
      })
    );

    expect(await AuthService.getSessionEmployeeId()).toBe('e1');
    expect(await AuthService.getMfaPendingEmployeeId()).toBeNull();
  });

  it('login sets MFA pending when MFA is enabled', async () => {
    mockGetByEmail.mockResolvedValueOnce({
      id: 'e2',
      name: 'Doctor',
      role: 'DOCTOR',
      passwordHash: 'h:1234',
      mfaEnabled: 1,
      mfaImageToken: 'IMG',
    });

    const res = await AuthService.login('doc@hospital.com', '1234');

    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.mfaRequired).toBe(true);
      expect(res.employeeId).toBe('e2');
    }

    expect(await AuthService.getSessionEmployeeId()).toBeNull();
    expect(await AuthService.getMfaPendingEmployeeId()).toBe('e2');
  });

  it('verifyMfa fails when there is no pending MFA', async () => {
    const res = await AuthService.verifyMfa({ phoneCode: '111111', emailCode: '222222', imageToken: 'IMG' });

    expect(res.ok).toBe(false);
    if (!res.ok) expect(res.error).toMatch(/Sem MFA pendente/);
  });

  it('verifyMfa succeeds with correct demo codes, stores session and clears pending', async () => {
    mockGetByEmail.mockResolvedValueOnce({
      id: 'e3',
      name: 'Nurse',
      role: 'NURSE',
      passwordHash: 'h:1234',
      mfaEnabled: 1,
      mfaImageToken: 'IMG',
    });

    await AuthService.login('nurse@hospital.com', '1234');

    mockGetById.mockResolvedValueOnce({
      id: 'e3',
      name: 'Nurse',
      role: 'NURSE',
      mfaEnabled: 1,
      mfaImageToken: 'IMG',
    });

    mockUpdate.mockResolvedValueOnce(undefined);

    const res = await AuthService.verifyMfa({
      phoneCode: '111111',
      emailCode: '222222',
      imageToken: 'IMG',
    });

    expect(res.ok).toBe(true);
    if (res.ok) expect(res.employeeId).toBe('e3');

    expect(mockUpdate).toHaveBeenCalledWith('e3', expect.objectContaining({ mfaPhoneVerified: 1, mfaEmailVerified: 1 }));
    expect(mockAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        actorEmployeeId: 'e3',
        action: 'MFA_VERIFY',
        entity: 'EMPLOYEE',
        entityId: 'e3',
      })
    );

    expect(await AuthService.getSessionEmployeeId()).toBe('e3');
    expect(await AuthService.getMfaPendingEmployeeId()).toBeNull();
  });

  it('logout clears session and MFA pending', async () => {
    await AsyncStorage.setItem('SESSION_EMPLOYEE_ID', 'e9');
    await AsyncStorage.setItem('MFA_PENDING_EMPLOYEE_ID', 'e9');

    await AuthService.logout();

    expect(await AuthService.getSessionEmployeeId()).toBeNull();
    expect(await AuthService.getMfaPendingEmployeeId()).toBeNull();
  });
});
