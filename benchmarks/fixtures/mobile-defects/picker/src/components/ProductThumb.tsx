import { StyleSheet } from 'react-native';
import FastImage from 'react-native-fast-image';

import { colors } from '../theme/colors';

/** Product photo on a pick-list row: catalogue images are 1200 px originals from the supplier feed. */
export function ProductThumb({ uri }: { uri: string }) {
  return (
    <FastImage
      source={{ uri, priority: FastImage.priority.normal }}
      resizeMode={FastImage.resizeMode.cover}
      style={styles.thumb}
    />
  );
}

const styles = StyleSheet.create({
  thumb: { width: 56, height: 56, borderRadius: 8, backgroundColor: colors.surfaceAlt },
});
