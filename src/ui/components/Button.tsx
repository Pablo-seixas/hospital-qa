import React from "react";
import { Pressable, Text, StyleSheet } from "react-native";

export function Button(props: { title: string; onPress: () => void; variant?: "primary"|"danger"|"ghost"; disabled?: boolean; }) {
  const v = props.variant ?? "primary";
  return (
    <Pressable
      onPress={props.onPress}
      disabled={props.disabled}
      style={({ pressed }) => [
        styles.base,
        v === "primary" && styles.primary,
        v === "danger" && styles.danger,
        v === "ghost" && styles.ghost,
        (pressed || props.disabled) && styles.pressed,
      ]}
    >
      <Text style={[styles.text, v === "ghost" && styles.ghostText]}>{props.title}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: { paddingVertical: 12, paddingHorizontal: 14, borderRadius: 12, alignItems: "center" },
  primary: { backgroundColor: "#111" },
  danger: { backgroundColor: "#8b0000" },
  ghost: { backgroundColor: "transparent", borderWidth: 1, borderColor: "#111" },
  pressed: { opacity: 0.8 },
  text: { color: "#fff", fontWeight: "700" },
  ghostText: { color: "#111" },
});
