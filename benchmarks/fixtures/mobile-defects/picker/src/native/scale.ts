import { NativeModules } from 'react-native';

const { ScaleBridge } = NativeModules;

export type Reading = { grams: number; stable: boolean };

/** Reads the Bluetooth bench scale paired with this device. */
export function readWeight(): Promise<Reading> {
  return ScaleBridge.readWeight();
}

/** Zeroes the scale with the crate on it, before loose produce is weighed into the crate. */
export function tare(): Promise<void> {
  return ScaleBridge.tare();
}
