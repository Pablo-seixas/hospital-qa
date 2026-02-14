import React from 'react';
import { render } from '@testing-library/react-native';
import { AuthScreen } from '../src/ui/screens/AuthScreen';

jest.mock('@/state/authStore', () => ({
  useAuthStore: (selector: any) =>
    selector({
      login: jest.fn(async () => {}),
      loading: false,
    }),
}));

jest.mock('@react-navigation/native', () => ({
  useNavigation: () => ({ navigate: jest.fn() }),
}));

describe('AuthScreen', () => {
  it('renders without crashing', () => {
    const { getByText } = render(<AuthScreen />);
    expect(getByText('Hospital')).toBeTruthy();
  });
});
