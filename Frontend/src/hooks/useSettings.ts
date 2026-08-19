import { useCallback, useEffect, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { apiGet } from "@/api/client";
import { authService } from "@/services/auth.service";
import { formatCurrencyWithConfig, setCurrencyConfig } from "@/utils/format";
import type { CurrencyConfig } from "@/utils/format";
import type { SettingRead } from "@/types";

export interface SettingsMap {
  [key: string]: string | null;
}

export interface CurrencyConfigApi {
  currency_code: string;
  currency_symbol: string;
  currency_locale: string;
  decimal_places: number;
}

export interface UseSettingsResult {
  settings: SettingsMap;
  isLoading: boolean;
  businessName: string;
  currency: CurrencyConfig;
  currencyCode: string;
  currencySymbol: string;
  currencyLocale: string;
  receiptFooter: string;
  defaultTaxRateId: number | null;
  lowStockThresholdDefault: number;
  formatMoney: (amount: number | null | undefined) => string;
}

const DEFAULT_BUSINESS_NAME = "SmartPOS";
const DEFAULT_RECEIPT_FOOTER = "Thank you for your business!";
const DEFAULT_CURRENCY: CurrencyConfig = {
  code: "USD",
  symbol: "$",
  locale: "en-US",
  decimalPlaces: 2,
};

function toSettingsMap(rows: SettingRead[] | undefined): SettingsMap {
  const map: SettingsMap = {};
  for (const row of rows ?? []) {
    map[row.setting_key] = row.setting_value;
  }
  return map;
}

function toCurrencyConfig(value: Partial<CurrencyConfigApi> | undefined): CurrencyConfig {
  const code = normalizeConfigCode(value?.currency_code ?? "");
  return {
    code,
    symbol: value?.currency_symbol ?? DEFAULT_CURRENCY.symbol,
    locale: value?.currency_locale ?? DEFAULT_CURRENCY.locale,
    decimalPlaces: value?.decimal_places ?? DEFAULT_CURRENCY.decimalPlaces,
  };
}

function normalizeConfigCode(code: string): string {
  const trimmed = code.trim().toUpperCase();
  return trimmed ? trimmed : DEFAULT_CURRENCY.code;
}

/**
 * Provides display settings (business name, currency, receipt footer, default
 * tax rate) that are readable by every authenticated user. The currency is
 * loaded from the authoritative `/settings/currency` endpoint and also kept in
 * sync with the module-level currency config in format.ts so existing
 * formatCurrency() call sites reflect the configured currency.
 */
export function useSettings(): UseSettingsResult {
  const settingsEnabled = authService.isAuthenticated();

  const { data, isLoading } = useQuery<SettingRead[]>({
    queryKey: ["settings", "public"],
    queryFn: async () => {
      const res = await apiGet<SettingRead[]>("/settings/public");
      return res.data;
    },
    enabled: settingsEnabled,
    staleTime: 60_000,
  });

  const { data: currencyData } = useQuery<Partial<CurrencyConfigApi>>({
    queryKey: ["settings", "currency"],
    queryFn: async () => {
      const res = await apiGet<Partial<CurrencyConfigApi>>("/settings/currency");
      return res.data;
    },
    enabled: settingsEnabled,
    staleTime: 60_000,
  });

  const settings = useMemo(() => toSettingsMap(data), [data]);
  const currency = useMemo(() => toCurrencyConfig(currencyData), [currencyData]);
  const currencyCode = currency.code;
  const currencySymbol = currency.symbol;
  const currencyLocale = currency.locale;
  const businessName = settings["business_name"] ?? DEFAULT_BUSINESS_NAME;
  const receiptFooter = settings["receipt_footer"] ?? DEFAULT_RECEIPT_FOOTER;
  const defaultTaxRateId = settings["default_tax_rate_id"]
    ? Number(settings["default_tax_rate_id"])
    : null;
  const lowStockThresholdDefault =
    Number(settings["low_stock_threshold_default"]) || 10;

  useEffect(() => {
    setCurrencyConfig(currency);
  }, [currency]);

  const formatMoney = useCallback(
    (amount: number | null | undefined) => formatCurrencyWithConfig(amount, currency),
    [currency],
  );

  return {
    settings,
    isLoading,
    businessName,
    currency,
    currencyCode,
    currencySymbol,
    currencyLocale,
    receiptFooter,
    defaultTaxRateId,
    lowStockThresholdDefault,
    formatMoney,
  };
}