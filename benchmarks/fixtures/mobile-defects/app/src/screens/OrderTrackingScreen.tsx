import { useQuery } from '@tanstack/react-query';
import { useLocalSearchParams } from 'expo-router';
import { useEffect, useRef } from 'react';
import { FlatList, InteractionManager, StyleSheet, Text, View } from 'react-native';

import { apiFetch } from '../api/http';
import { colors, type } from '../theme/colors';

type TrackingEvent = { id: string; at: string; label: string };

export default function OrderTrackingScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const timeline = useRef<FlatList<TrackingEvent>>(null);
  const events = useQuery({
    queryKey: ['orders', id, 'events'],
    queryFn: () => apiFetch<TrackingEvent[]>(`/me/orders/${id}/events`),
    refetchInterval: 20_000,
  });

  // Scroll to the newest event once the push transition has finished.
  useEffect(() => {
    const task = InteractionManager.runAfterInteractions(() => timeline.current?.scrollToEnd({ animated: true }));
    return () => task.cancel();
  }, [events.data?.length]);

  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Your order</Text>
      <FlatList
        ref={timeline}
        data={events.data ?? []}
        keyExtractor={(event) => event.id}
        renderItem={({ item }) => (
          <View style={styles.event}>
            <Text style={styles.at}>{new Date(item.at).toLocaleTimeString()}</Text>
            <Text style={styles.label}>{item.label}</Text>
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 16, backgroundColor: colors.surface },
  title: { fontSize: type.title, fontWeight: '700', color: colors.text, marginBottom: 12 },
  event: { flexDirection: 'row', gap: 12, paddingVertical: 8 },
  at: { fontSize: type.caption, color: colors.textMuted },
  label: { fontSize: type.body, color: colors.text },
});
