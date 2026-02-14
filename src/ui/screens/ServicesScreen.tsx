import React, { useEffect, useState } from "react";
import { FlatList, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { Card } from "@/ui/components/Card";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { ServiceType } from "@/domain/entities/serviceType";
import { centsToBRL } from "@/utils/money";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, any>;

export function ServicesScreen({ navigation }: Props) {
  const [items, setItems] = useState<ServiceType[]>([]);

  async function load() {
    setItems(await ServicesRepo.list());
  }
  React.useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation]);

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Serviços / Tratamentos / Preços</Text>
      <Button title="Novo serviço" onPress={() => navigation.navigate("ServiceForm")} />

      <FlatList
        data={items}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={item.name}
            subtitle={`${item.treatment} | ${centsToBRL(item.priceCents)}`}
            right={<Button title="Editar" variant="ghost" onPress={() => navigation.navigate("ServiceForm", { id: item.id })} />}
          />
        )}
      />
    </Screen>
  );
}
