import { useSyncExternalStore } from "react";
import { getCurrencyConfig, subscribeCurrency } from "@/utils/format";
import type { CurrencyConfig } from "@/utils/format";

/**
 * Subscribes a component to the active application currency so that it
 * re-renders whenever the global currency configuration changes (after the
 * admin changes it in Settings and the settings layer syncs it).
 */
export function useCurrency(): CurrencyConfig {
  return useSyncExternalStore(subscribeCurrency, getCurrencyConfig);
}