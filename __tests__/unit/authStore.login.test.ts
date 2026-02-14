import { useAuthStore } from '@/state/authStore';

const mockEmployeeLogin = jest.fn();
const mockEmployeeMe = jest.fn();
const mockEmployeeLogout = jest.fn();

jest.mock('@/api/authApi', () => ({
  employeeLogin: (...args: any[]) => mockEmployeeLogin(...args),
  employeeMe: (...args: any[]) => mockEmployeeMe(...args),
  employeeLogout: (...args: any[]) => mockEmployeeLogout(...args),
}));

describe('authStore', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // NÃO usar replace=true aqui (isso apaga as funções do store)
    useAuthStore.setState({ loading: false, employee: null, error: undefined } as any);
  });

  it('bootstrap sets employee when employeeMe resolves', async () => {
    mockEmployeeMe.mockResolvedValueOnce({ id: 'e1', name: 'Root', role: 'ROOT_ADMIN' });

    await useAuthStore.getState().bootstrap();

    const s = useAuthStore.getState();
    expect(s.loading).toBe(false);
    expect(s.employee).toEqual({ id: 'e1', name: 'Root', role: 'ROOT_ADMIN' });
    expect(s.error).toBeUndefined();
  });

  it('bootstrap clears employee when employeeMe rejects', async () => {
    mockEmployeeMe.mockRejectedValueOnce(new Error('no_session'));

    await useAuthStore.getState().bootstrap();

    const s = useAuthStore.getState();
    expect(s.loading).toBe(false);
    expect(s.employee).toBeNull();
  });

  it('login sets employee on success', async () => {
    mockEmployeeLogin.mockResolvedValueOnce({
      employee: { id: 'e2', name: 'Doctor', role: 'DOCTOR' },
    });

    await useAuthStore.getState().login('doc@hospital.com', '1234');

    const s = useAuthStore.getState();
    expect(s.loading).toBe(false);
    expect(s.employee).toEqual({ id: 'e2', name: 'Doctor', role: 'DOCTOR' });
    expect(s.error).toBeUndefined();
    expect(mockEmployeeLogin).toHaveBeenCalledWith('doc@hospital.com', '1234');
  });

  it('login sets error and rethrows on failure', async () => {
    mockEmployeeLogin.mockRejectedValueOnce(new Error('invalid_credentials'));

    await expect(useAuthStore.getState().login('x@y.com', 'bad')).rejects.toThrow('invalid_credentials');

    const s = useAuthStore.getState();
    expect(s.loading).toBe(false);
    expect(s.error).toBe('invalid_credentials');
  });

  it('logout clears employee and calls employeeLogout', async () => {
    useAuthStore.setState({ employee: { id: 'e9', name: 'Any', role: 'EMPLOYEE' } } as any);
    mockEmployeeLogout.mockResolvedValueOnce(undefined);

    await useAuthStore.getState().logout();

    const s = useAuthStore.getState();
    expect(s.loading).toBe(false);
    expect(s.employee).toBeNull();
    expect(mockEmployeeLogout).toHaveBeenCalled();
  });
});
