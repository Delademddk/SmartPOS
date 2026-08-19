import { useCallback, useEffect, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { apiGet } from "@/api/client";
import { formatCurrency, setCurrencySymbol } from "@/utils/format";
import type { SettingRead } from "@/types";

export interface SettingsMap {
  [key: string]: string | null;
}

export interface UseSettingsResult {
  settings: SettingsMap;
  isLoading: boolean;
  businessName: string;
  currencySymbol: string;
  receiptFooter: string;
  defaultTaxRateId: number | null;
  lowStockThresholdDefault: number;
  formatMoney: (amount: number | null | undefined) => string;
}

const DEFAULT_BUSINESS_NAME = "SmartPOS";
const DEFAULT_RECEIPT_FOOTER = "Thank you for your business!";

function toSettingsMap(rows: SettingRead[] | undefined): SettingsMap {
  const map: SettingsMap = {};
  for (const row of rows ?? []) {
    map[row.setting_key] = row.setting_value;
  }
  return map;
}

/**
 * Provides display settings (business name, currency symbol, receipt footer,
 * default tax rate) that are readable by every authenticated user. Also keeps
 * the module-level currency symbol in format.ts in sync so existing
 * formatCurrency() call sites reflect the configured currency.
 */
export function useSettings(): UseSettingsResult {
  const { data, isLoading } = useQuery<SettingRead[]>({
    queryKey: ["settings", "public"],
    queryFn: async () => {
      const res = await apiGet<SettingRead[]>("/settings/public");
      return res.data;
    },
    staleTime: 60_000,
  });

  const settings = useMemo(() => toSettingsMap(data), [data]);
  const currencySymbol = settings["currency_symbol"] ?? "$";
  const businessName = settings["business_name"] ?? DEFAULT_BUSINESS_NAME;
  const receiptFooter = settings["receipt_footer"] ?? DEFAULT_RECEIPT_FOOTER;
  const defaultTaxRateId = settings["default_tax_rate_id"]
    ? Number(settings["default_tax_rate_id"])
    : null;
  const lowStockThresholdDefault =
    Number(settings["low_stock_threshold_default"]) || 10;

  useEffect(() => {
    setCurrencySymbol(currencySymbol);
  }, [currencySymbol]);

  const formatMoney = useCallback(
    (amount: number | null | undefined) => formatCurrency(amount, currencySymbol),
    [currencySymbol],
  );

  return {
    settings,
    isLoading,
    businessName,
    currencySymbol,
    receiptFooter,
    defaultTaxRateId,
    lowStockThresholdDefault,
    formatMoney,
  };
}
