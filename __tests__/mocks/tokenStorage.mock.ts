export const tokenStorageMock = {
  setAccessToken: jest.fn(async (_v: string) => {}),
  setRefreshToken: jest.fn(async (_v: string) => {}),
  getAccessToken: jest.fn(async () => null),
  getRefreshToken: jest.fn(async () => null),
  clear: jest.fn(async () => {}),
};
