import React from "react";
import { View, Text, TextInput, StyleSheet } from "react-native";

export function Input(props: { label: string; value: string; onChangeText: (t: string) => void; placeholder?: string; secureTextEntry?: boolean; }) {
  return (
    <View style={styles.wrap}>
      <Text style={styles.label}>{props.label}</Text>
      <TextInput
        value={props.value}
        onChangeText={props.onChangeText}
        placeholder={props.placeholder}
        secureTextEntry={props.secureTextEntry}
        style={styles.input}
        autoCapitalize="none"
      />
    </View>
  );
}
const styles = StyleSheet.create({
  wrap: { gap: 6 },
  label: { fontWeight: "700" },
  input: { borderWidth: 1, borderColor: "#ddd", borderRadius: 12, padding: 12 },
});
