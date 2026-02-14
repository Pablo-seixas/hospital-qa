import AsyncStorage from "@react-native-async-storage/async-storage";

const ACCESS_KEY = "@auth/accessToken";
const REFRESH_KEY = "@auth/refreshToken";

export async function getAccessToken() {
  return AsyncStorage.getItem(ACCESS_KEY);
}

export async function getRefreshToken() {
  return AsyncStorage.getItem(REFRESH_KEY);
}

export async function setTokens(tokens: { accessToken: string; refreshToken: string }) {
  await AsyncStorage.multiSet([
    [ACCESS_KEY, tokens.accessToken],
    [REFRESH_KEY, tokens.refreshToken],
  ]);
}

export async function clearTokens() {
  await AsyncStorage.multiRemove([ACCESS_KEY, REFRESH_KEY]);
}
