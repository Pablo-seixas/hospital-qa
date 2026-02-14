import React, { useEffect, useState } from "react";
import { FlatList, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Card } from "@/ui/components/Card";
import { AuditRepo } from "@/data/repositories/audit.repo";
import { formatDateTime } from "@/utils/dates";

export function AuditScreen() {
  const [items, setItems] = useState<any[]>([]);
  useEffect(() => {
    AuditRepo.listLatest(200).then(setItems);
  }, []);

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Auditoria (últimos 200)</Text>
      <FlatList
        data={items}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={`${item.action} ${item.entity} (${formatDateTime(item.createdAt)})`}
            subtitle={`Por: ${item.actorName} | ID: ${item.entityId}`}
          />
        )}
      />
    </Screen>
  );
}
