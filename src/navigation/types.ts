export type RootStackParamList = {
  Auth: undefined;
  Mfa: undefined;

  // novas telas
  PatientRegister: undefined;
  ForgotPassword: undefined;

  Main: undefined;

  EmployeeDetail: { id: string };
  EmployeeForm: { id?: string } | undefined;

  PatientForm: { id?: string } | undefined;
  ServiceForm: { id?: string } | undefined;
  AppointmentForm: { id?: string } | undefined;

  PatientChart: { patientId: string };
};
