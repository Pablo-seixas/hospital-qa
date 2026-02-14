import React from "react";
import { View, Text, StyleSheet } from "react-native";

export function Card(props: { title: string; subtitle?: string; right?: React.ReactNode }) {
  return (
    <View style={styles.card}>
      <View style={styles.head}>
        <View style={{ flex: 1 }}>
          <Text style={styles.title}>{props.title}</Text>
          {!!props.subtitle && <Text style={styles.sub}>{props.subtitle}</Text>}
        </View>
        {props.right}
      </View>
    </View>
  );
}
const styles = StyleSheet.create({
  card: { borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" },
  head: { flexDirection: "row", gap: 12, alignItems: "center" },
  title: { fontWeight: "800" },
  sub: { color: "#666", marginTop: 2 },
});
