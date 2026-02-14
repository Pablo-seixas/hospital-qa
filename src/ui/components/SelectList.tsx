import React, { useMemo, useState } from "react";
import { Modal, Pressable, ScrollView, Text, TextInput, View } from "react-native";

export type SelectOption = { id: string; label: string; subtitle?: string };

export function SelectList(props: {
  label: string;
  valueId: string | null;
  onChange: (id: string) => void;
  options: SelectOption[];
  placeholder?: string;
}) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");

  const selected = useMemo(
    () => props.options.find((o) => o.id === props.valueId) ?? null,
    [props.options, props.valueId]
  );

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    if (!s) return props.options;
    return props.options.filter((o) => (o.label + " " + (o.subtitle ?? "")).toLowerCase().includes(s));
  }, [q, props.options]);

  return (
    <View style={{ gap: 6 }}>
      <Text style={{ fontWeight: "800" }}>{props.label}</Text>

      <Pressable
        onPress={() => setOpen(true)}
        style={{ borderWidth: 1, borderColor: "#ddd", borderRadius: 12, padding: 12, backgroundColor: "#fff" }}
      >
        <Text style={{ fontWeight: "700" }}>{selected?.label ?? (props.placeholder ?? "Selecionar...")}</Text>
        {!!selected?.subtitle && <Text style={{ color: "#666", marginTop: 2 }}>{selected.subtitle}</Text>}
      </Pressable>

      <Modal visible={open} animationType="slide" onRequestClose={() => setOpen(false)}>
        <View style={{ flex: 1, padding: 16, gap: 10 }}>
          <Text style={{ fontSize: 18, fontWeight: "900" }}>{props.label}</Text>

          <TextInput
            placeholder="Buscar..."
            value={q}
            onChangeText={setQ}
            style={{ borderWidth: 1, borderColor: "#ddd", borderRadius: 12, padding: 12 }}
          />

          <ScrollView contentContainerStyle={{ gap: 10, paddingBottom: 40 }}>
            {filtered.map((o) => (
              <Pressable
                key={o.id}
                onPress={() => {
                  props.onChange(o.id);
                  setOpen(false);
                }}
                style={{
                  borderWidth: 1,
                  borderColor: "#eee",
                  borderRadius: 14,
                  padding: 12,
                  backgroundColor: o.id === props.valueId ? "#111" : "#fff",
                }}
              >
                <Text style={{ fontWeight: "900", color: o.id === props.valueId ? "#fff" : "#111" }}>{o.label}</Text>
                {!!o.subtitle && (
                  <Text style={{ color: o.id === props.valueId ? "#ddd" : "#666", marginTop: 2 }}>{o.subtitle}</Text>
                )}
              </Pressable>
            ))}
          </ScrollView>

          <Pressable
            onPress={() => setOpen(false)}
            style={{ borderWidth: 1, borderColor: "#111", borderRadius: 12, padding: 12, alignItems: "center" }}
          >
            <Text style={{ fontWeight: "900" }}>Fechar</Text>
          </Pressable>
        </View>
      </Modal>
    </View>
  );
}
