import { useRoute } from '@react-navigation/native';
import { useEffect, useState } from 'react';
import { SafeAreaView, FlatList, StyleSheet, Text } from 'react-native';

import { api } from '../api/client';
import { enqueue } from '../offline/outbox';
import { usePicks } from '../state/PickContext';
import { colors } from '../theme/colors';
import { byAisle, type PickLine } from '../utils/group';
import { PickListRow } from './PickListRow';

export function PickListScreen() {
  const { params } = useRoute();
  const id = (params as { id: string }).id;
  const { markPicked } = usePicks();
  const [lines, setLines] = useState<PickLine[]>([]);

  useEffect(() => {
    api.get<PickLine[]>(`/pick-lists/${id}/lines`).then(({ data }) => setLines(data), () => setLines([]));
  }, [id]);

  const sections = byAisle(lines);

  return (
    <SafeAreaView style={styles.screen}>
      <FlatList
        data={sections}
        keyExtractor={(section) => section.aisle}
        renderItem={({ item }) => (
          <>
            <Text style={styles.aisle}>Aisle {item.aisle}</Text>
            {item.lines.map((line) => (
              <PickListRow
                key={line.id}
                line={line}
                onPicked={(quantity) => {
                  markPicked(line.id, quantity);
                  enqueue({ id: `${line.id}:${Date.now()}`, pickListId: id, lineId: line.id, quantity });
                }}
              />
            ))}
          </>
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.surface },
  aisle: { paddingHorizontal: 16, paddingTop: 16, fontSize: 13, fontWeight: '700', color: colors.textMuted },
});
