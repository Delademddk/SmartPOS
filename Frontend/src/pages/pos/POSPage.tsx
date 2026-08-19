import { useState, useRef, useEffect, useCallback, useMemo } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  Search,
  ShoppingCart,
  Trash2,
  Plus,
  Minus,
  CreditCard,
  Banknote,
  X,
  Check,
  AlertTriangle,
} from "lucide-react"
import toast from "react-hot-toast"
import { apiGet, apiPost } from "@/api/client"
import { Spinner } from "@/components/feedback"
import { ProductImage } from "@/components/ui/ProductImage"
import { cn } from "@/utils/cn"
import { formatCurrency } from "@/utils/format"
import { useDebounce } from "@/hooks/useDebounce"
import type { Product, PaymentMethod, Customer, Category, TaxRate } from "@/types"

interface CartItem {
  product_id: number
  product_name: string
  sku: string
  quantity: number
  unit_price: number
  discount_rate: number
  line_total: number
}

interface SaleItemCreate {
  product_id: number
  quantity: number
  unit_price: number
  discount_rate: number
}

interface PaymentLineCreate {
  payment_method_id: number
  amount: number
  reference_number?: string
}

interface SaleCreate {
  sale_type: "CASH" | "CREDIT" | "CREDIT_PARTIAL"
  tax_rate_id: number | null
  customer_id: number | null
  discount_amount: number
  items: SaleItemCreate[]
  payments: PaymentLineCreate[]
  amount_received: number
  notes: string | null
  due_date: string | null
}

interface SaleRead {
  sale_id: number
  receipt_number: string
  status: string
  total_amount: number
}

const SALE_TYPES = [
  { value: "CASH", label: "Cash", icon: Banknote },
  { value: "CREDIT", label: "Credit", icon: CreditCard },
] as const

export function POSPage() {
  const queryClient = useQueryClient()
  const searchInputRef = useRef<HTMLInputElement>(null)

  const [search, setSearch] = useState("")
  const debouncedSearch = useDebounce(search, 250)
  const [selectedCategory, setSelectedCategory] = useState<number | null>(null)
  const [cart, setCart] = useState<CartItem[]>([])
  const [saleType, setSaleType] = useState<"CASH" | "CREDIT">("CASH")
  const [customerId, setCustomerId] = useState<number | null>(null)
  const [dueDate, setDueDate] = useState("")
  const [amountReceived, setAmountReceived] = useState("")
  const [discountAmount, setDiscountAmount] = useState("")
  const [taxRateId, setTaxRateId] = useState<number | null>(null)
  const [notes, setNotes] = useState("")
  const [paymentMethodId, setPaymentMethodId] = useState<number | null>(null)
  const [referenceNumber, setReferenceNumber] = useState("")

  const productsQuery = useQuery({
    queryKey: ["pos-products", debouncedSearch, selectedCategory],
    queryFn: async () => {
      const params = new URLSearchParams({ page: "1", page_size: "200" })
      if (debouncedSearch) params.set("search", debouncedSearch)
      if (selectedCategory) params.set("category_id", String(selectedCategory))
      const res = await apiGet<Product[]>(`/products?${params}`)
      return res.data
    },
    staleTime: 15_000,
  })

  const categoriesQuery = useQuery({
    queryKey: ["pos-categories"],
    queryFn: async () => {
      const res = await apiGet<Category[]>("/categories?page=1&page_size=200")
      return res.data
    },
    staleTime: 60_000,
  })

  const paymentMethodsQuery = useQuery({
    queryKey: ["pos-payment-methods"],
    queryFn: async () => {
      const res = await apiGet<PaymentMethod[]>("/payments/methods")
      return res.data
    },
    staleTime: 60_000,
  })

  const customersQuery = useQuery({
    queryKey: ["pos-customers"],
    queryFn: async () => {
      const res = await apiGet<Customer[]>("/credits/customers")
      return res.data
    },
    enabled: saleType === "CREDIT",
    staleTime: 30_000,
  })

  const taxRatesQuery = useQuery({
    queryKey: ["pos-tax-rates"],
    queryFn: async () => {
      const res = await apiGet<TaxRate[]>("/tax-rates?page=1&page_size=200")
      return res.data
    },
    staleTime: 60_000,
  })

  const cartTotal = useMemo(() => {
    const subtotal = cart.reduce((sum, item) => sum + item.line_total, 0)
    const discount = parseFloat(discountAmount) || 0
    const taxRate = taxRatesQuery.data?.find((tr) => tr.tax_rate_id === taxRateId)
    const taxableAmount = Math.max(0, subtotal - discount)
    const tax = taxRate ? taxableAmount * (taxRate.rate_percent / 100) : 0
    const total = taxableAmount + tax
    return { subtotal, discount, tax, total }
  }, [cart, discountAmount, taxRateId, taxRatesQuery.data])

  const change = useMemo(() => {
    const received = parseFloat(amountReceived) || 0
    return Math.max(0, received - cartTotal.total)
  }, [amountReceived, cartTotal.total])

  const canCompleteSale = useMemo(() => {
    if (cart.length === 0) return false
    if (cartTotal.total <= 0) return false
    if (!paymentMethodId) return false
    if (saleType === "CASH") {
      const received = parseFloat(amountReceived) || 0
      if (received < cartTotal.total) return false
    }
    if (saleType === "CREDIT") {
      if (!customerId) return false
      if (!dueDate) return false
    }
    return true
  }, [cart, cartTotal.total, paymentMethodId, saleType, amountReceived, customerId, dueDate])

  const saleMutation = useMutation({
    mutationFn: async (payload: SaleCreate) => {
      const res = await apiPost<SaleRead>("/sales", payload)
      return res.data
    },
    onSuccess: (sale) => {
      toast.success(`Sale completed! Receipt: ${sale.receipt_number}`)
      resetCart()
      queryClient.invalidateQueries({ queryKey: ["products"] })
      queryClient.invalidateQueries({ queryKey: ["pos-products"] })
      queryClient.invalidateQueries({ queryKey: ["dashboard"] })
    },
    onError: (error: Error & { response?: { data?: { error?: { details?: Array<{ message: string }> } } } }) => {
      const msg = error.response?.data?.error?.details?.[0]?.message
      toast.error(msg || "Failed to complete sale")
    },
  })

  const resetCart = useCallback(() => {
    setCart([])
    setAmountReceived("")
    setDiscountAmount("")
    setPaymentMethodId(null)
    setReferenceNumber("")
    setCustomerId(null)
    setDueDate("")
    setNotes("")
    setTaxRateId(null)
    setSaleType("CASH")
  }, [])

  const addToCart = useCallback((product: Product) => {
    if (product.stock_status === "OUT_OF_STOCK") return
    setCart((prev) => {
      const existing = prev.find((item) => item.product_id === product.product_id)
      if (existing) {
        if (existing.quantity >= product.quantity_on_hand) {
          toast.error("Insufficient stock")
          return prev
        }
        return prev.map((item) =>
          item.product_id === product.product_id
            ? {
                ...item,
                quantity: item.quantity + 1,
                line_total: (item.quantity + 1) * item.unit_price * (1 - item.discount_rate / 100),
              }
            : item
        )
      }
      return [
        ...prev,
        {
          product_id: product.product_id,
          product_name: product.product_name,
          sku: product.sku,
          quantity: 1,
          unit_price: product.unit_price,
          discount_rate: 0,
          line_total: product.unit_price,
        },
      ]
    })
  }, [])

  const updateQuantity = useCallback((productId: number, delta: number) => {
    setCart((prev) => {
      return prev
        .map((item) => {
          if (item.product_id !== productId) return item
          const newQty = item.quantity + delta
          if (newQty <= 0) return null
          return {
            ...item,
            quantity: newQty,
            line_total: newQty * item.unit_price * (1 - item.discount_rate / 100),
          }
        })
        .filter(Boolean) as CartItem[]
    })
  }, [])

  const removeItem = useCallback((productId: number) => {
    setCart((prev) => prev.filter((item) => item.product_id !== productId))
  }, [])

  const clearCart = useCallback(() => {
    resetCart()
  }, [resetCart])

  const handleCompleteSale = useCallback(() => {
    if (!canCompleteSale || saleMutation.isPending) return

    const payments: PaymentLineCreate[] = []

    if (saleType === "CASH") {
      payments.push({
        payment_method_id: paymentMethodId!,
        amount: cartTotal.total,
        ...(referenceNumber ? { reference_number: referenceNumber } : {}),
      })
    } else {
      payments.push({
        payment_method_id: paymentMethodId!,
        amount: cartTotal.total,
        ...(referenceNumber ? { reference_number: referenceNumber } : {}),
      })
    }

    const payload: SaleCreate = {
      sale_type: saleType,
      tax_rate_id: taxRateId,
      customer_id: saleType === "CREDIT" ? customerId : null,
      discount_amount: parseFloat(discountAmount) || 0,
      items: cart.map((item) => ({
        product_id: item.product_id,
        quantity: item.quantity,
        unit_price: item.unit_price,
        discount_rate: item.discount_rate,
      })),
      payments,
      amount_received: parseFloat(amountReceived) || cartTotal.total,
      notes: notes || null,
      due_date: saleType === "CREDIT" ? dueDate || null : null,
    }

    saleMutation.mutate(payload)
  }, [
    canCompleteSale,
    saleMutation,
    saleType,
    paymentMethodId,
    cartTotal.total,
    cart,
    taxRateId,
    customerId,
    discountAmount,
    amountReceived,
    notes,
    dueDate,
    referenceNumber,
  ])

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement
      const isInput = target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.tagName === "SELECT"

      if (e.key === "/" && !isInput) {
        e.preventDefault()
        searchInputRef.current?.focus()
      }
      if (e.key === "Escape" && isInput) {
        ;(target as HTMLInputElement).blur()
        setSearch("")
      }
      if (e.key === "Enter" && e.ctrlKey) {
        e.preventDefault()
        handleCompleteSale()
      }
    }

    window.addEventListener("keydown", handleKeyDown)
    return () => window.removeEventListener("keydown", handleKeyDown)
  }, [handleCompleteSale])

  useEffect(() => {
    if (!paymentMethodsQuery.data) return
    const cashMethod = paymentMethodsQuery.data.find((m) => m.is_cash && m.is_active)
    if (cashMethod && !paymentMethodId) {
      setPaymentMethodId(cashMethod.payment_method_id)
    }
  }, [paymentMethodsQuery.data, paymentMethodId])

  const defaultTaxRate = taxRatesQuery.data?.find((tr) => tr.is_default)

  useEffect(() => {
    if (defaultTaxRate && taxRateId === null) {
      setTaxRateId(defaultTaxRate.tax_rate_id)
    }
  }, [defaultTaxRate, taxRateId])

  const products = productsQuery.data || []
  const categories = categoriesQuery.data || []
  const paymentMethods = paymentMethodsQuery.data?.filter((m) => m.is_active) || []
  const customers = customersQuery.data || []
  const taxRates = taxRatesQuery.data || []

  return (
    <div className="flex h-[calc(100vh-4rem)] overflow-hidden">
      <div className="flex flex-1 overflow-hidden">
        <div className="flex w-[60%] flex-col border-r border-gray-200">
          <div className="border-b border-gray-200 bg-white p-4">
            <div className="relative mb-3">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
              <input
                ref={searchInputRef}
                type="text"
                placeholder='Search products... (press "/" to focus)'
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="input w-full pl-10 pr-10"
                autoFocus
              />
              {search && (
                <button
                  onClick={() => setSearch("")}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  <X className="h-4 w-4" />
                </button>
              )}
            </div>

            <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
              <button
                onClick={() => setSelectedCategory(null)}
                className={cn(
                  "whitespace-nowrap rounded-full px-3 py-1.5 text-sm font-medium transition-colors",
                  selectedCategory === null
                    ? "bg-primary-600 text-white"
                    : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                )}
              >
                All
              </button>
              {categories.map((cat) => (
                <button
                  key={cat.category_id}
                  onClick={() =>
                    setSelectedCategory(selectedCategory === cat.category_id ? null : cat.category_id)
                  }
                  className={cn(
                    "whitespace-nowrap rounded-full px-3 py-1.5 text-sm font-medium transition-colors",
                    selectedCategory === cat.category_id
                      ? "bg-primary-600 text-white"
                      : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                  )}
                >
                  {cat.category_name}
                </button>
              ))}
            </div>
          </div>

          <div className="flex-1 overflow-y-auto p-4">
            {productsQuery.isLoading ? (
              <div className="flex items-center justify-center py-20">
                <Spinner size="lg" />
              </div>
            ) : products.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-20 text-center">
                <ShoppingCart className="mb-3 h-12 w-12 text-gray-300" />
                <p className="text-sm font-medium text-gray-500">No products found</p>
                <p className="mt-1 text-xs text-gray-400">
                  {search ? "Try a different search term" : "No products available"}
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
                {products.map((product) => {
                  const outOfStock = product.stock_status === "OUT_OF_STOCK"
                  const lowStock = product.stock_status === "LOW_STOCK"
                  const inCart = cart.some((item) => item.product_id === product.product_id)

                  return (
                    <button
                      key={product.product_id}
                      onClick={() => addToCart(product)}
                      disabled={outOfStock}
                      className={cn(
                        "group relative rounded-lg border p-3 text-left transition-all",
                        outOfStock
                          ? "cursor-not-allowed border-gray-200 bg-gray-50 opacity-50"
                          : "border-gray-200 bg-white hover:border-primary-300 hover:shadow-md",
                        inCart && !outOfStock && "border-primary-400 ring-1 ring-primary-200"
                      )}
                    >
                      {inCart && !outOfStock && (
                        <span className="absolute -right-1 -top-1 flex h-5 w-5 items-center justify-center rounded-full bg-primary-600 text-[10px] font-bold text-white">
                          {cart.find((i) => i.product_id === product.product_id)?.quantity}
                        </span>
                      )}

                      <ProductImage
                        imageUrl={product.image_url}
                        alt={product.product_name}
                        className="mb-2 h-16 w-full rounded-lg"
                        iconClassName="h-8 w-8"
                      />

                      <p className="line-clamp-2 text-sm font-medium text-gray-900">{product.product_name}</p>
                      <p className="mt-0.5 text-xs text-gray-400">{product.sku}</p>

                      <div className="mt-2 flex items-center justify-between">
                        <span className="text-sm font-bold text-primary-700">
                          {formatCurrency(product.unit_price)}
                        </span>
                      </div>

                      <div className="mt-1.5 flex items-center justify-between">
                        <span
                          className={cn(
                            "text-xs",
                            outOfStock ? "font-medium text-red-600" : lowStock ? "text-amber-600" : "text-gray-400"
                          )}
                        >
                          {outOfStock ? "Out of stock" : `${product.quantity_on_hand} in stock`}
                        </span>
                        {outOfStock && (
                          <AlertTriangle className="h-3.5 w-3.5 text-red-400" />
                        )}
                      </div>
                    </button>
                  )
                })}
              </div>
            )}
          </div>
        </div>

        <div className="flex w-[40%] flex-col bg-gray-50">
          <div className="flex items-center justify-between border-b border-gray-200 bg-white px-4 py-3">
            <div className="flex items-center gap-2">
              <ShoppingCart className="h-5 w-5 text-gray-500" />
              <h2 className="text-sm font-semibold text-gray-900">
                Cart ({cart.reduce((sum, item) => sum + item.quantity, 0)} items)
              </h2>
            </div>
            {cart.length > 0 && (
              <button onClick={clearCart} className="text-xs text-red-500 hover:text-red-700">
                Clear all
              </button>
            )}
          </div>

          <div className="flex-1 overflow-y-auto">
            <div className="p-4">
              {cart.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 text-center">
                  <ShoppingCart className="mb-3 h-10 w-10 text-gray-300" />
                  <p className="text-sm font-medium text-gray-500">Cart is empty</p>
                  <p className="mt-1 text-xs text-gray-400">Click products to add them</p>
                </div>
              ) : (
                <div className="space-y-2">
                  {cart.map((item) => (
                    <div
                      key={item.product_id}
                      className="rounded-lg border border-gray-200 bg-white p-3"
                    >
                      <div className="flex items-start justify-between">
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-medium text-gray-900">{item.product_name}</p>
                          <p className="text-xs text-gray-400">{item.sku}</p>
                          <p className="mt-1 text-xs text-gray-500">
                            {formatCurrency(item.unit_price)} each
                          </p>
                        </div>
                        <button
                          onClick={() => removeItem(item.product_id)}
                          className="ml-2 p-1 text-gray-400 hover:text-red-500"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>

                      <div className="mt-2 flex items-center justify-between">
                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => updateQuantity(item.product_id, -1)}
                            className="flex h-7 w-7 items-center justify-center rounded-md border border-gray-300 bg-white text-gray-600 hover:bg-gray-50"
                          >
                            <Minus className="h-3.5 w-3.5" />
                          </button>
                          <span className="w-8 text-center text-sm font-medium">{item.quantity}</span>
                          <button
                            onClick={() => updateQuantity(item.product_id, 1)}
                            className="flex h-7 w-7 items-center justify-center rounded-md border border-gray-300 bg-white text-gray-600 hover:bg-gray-50"
                          >
                            <Plus className="h-3.5 w-3.5" />
                          </button>
                        </div>
                        <span className="text-sm font-semibold text-gray-900">
                          {formatCurrency(item.line_total)}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {cart.length > 0 && (
              <div className="border-t border-gray-200 bg-white px-4 py-4">
                <h3 className="mb-3 text-sm font-semibold text-gray-900">Sale Settings</h3>

                <div className="mb-3">
                  <label className="mb-1 block text-xs font-medium text-gray-700">Sale Type</label>
                  <div className="flex gap-2">
                    {SALE_TYPES.map((st) => {
                      const Icon = st.icon
                      return (
                        <button
                          key={st.value}
                          onClick={() => {
                            setSaleType(st.value)
                            if (st.value === "CASH") {
                              setCustomerId(null)
                              setDueDate("")
                            }
                          }}
                          className={cn(
                            "flex flex-1 items-center justify-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium transition-colors",
                            saleType === st.value
                              ? "border-primary-400 bg-primary-50 text-primary-700"
                              : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
                          )}
                        >
                          <Icon className="h-4 w-4" />
                          {st.label}
                        </button>
                      )
                    })}
                  </div>
                </div>

                {saleType === "CREDIT" && (
                  <>
                    <div className="mb-3">
                      <label className="mb-1 block text-xs font-medium text-gray-700">Customer</label>
                      <select
                        value={customerId || ""}
                        onChange={(e) => setCustomerId(e.target.value ? Number(e.target.value) : null)}
                        className="input w-full text-sm"
                      >
                        <option value="">Select customer</option>
                        {customers.map((c) => (
                          <option key={c.customer_id} value={c.customer_id}>
                            {c.customer_name}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="mb-3">
                      <label className="mb-1 block text-xs font-medium text-gray-700">Due Date</label>
                      <input
                        type="date"
                        value={dueDate}
                        onChange={(e) => setDueDate(e.target.value)}
                        className="input w-full text-sm"
                        min={new Date().toISOString().split("T")[0]}
                      />
                    </div>
                  </>
                )}

                <div className="mb-3">
                  <label className="mb-1 block text-xs font-medium text-gray-700">Payment Method</label>
                  <div className="grid grid-cols-2 gap-2">
                    {paymentMethods.map((pm) => (
                      <button
                        key={pm.payment_method_id}
                        onClick={() => setPaymentMethodId(pm.payment_method_id)}
                        className={cn(
                          "rounded-lg border px-3 py-2 text-sm font-medium transition-colors",
                          paymentMethodId === pm.payment_method_id
                            ? "border-primary-400 bg-primary-50 text-primary-700"
                            : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
                        )}
                      >
                        {pm.method_name}
                      </button>
                    ))}
                  </div>
                </div>

                {saleType === "CASH" && (
                  <div className="mb-3">
                    <label className="mb-1 block text-xs font-medium text-gray-700">
                      Amount Received
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={amountReceived}
                      onChange={(e) => setAmountReceived(e.target.value)}
                      placeholder={formatCurrency(cartTotal.total)}
                      className="input w-full text-sm"
                    />
                    {parseFloat(amountReceived) > 0 && (
                      <p className="mt-1 text-xs text-green-600">
                        Change: {formatCurrency(change)}
                      </p>
                    )}
                  </div>
                )}

                <div className="mb-3">
                  <label className="mb-1 block text-xs font-medium text-gray-700">
                    Reference Number (optional)
                  </label>
                  <input
                    type="text"
                    value={referenceNumber}
                    onChange={(e) => setReferenceNumber(e.target.value)}
                    placeholder="e.g. Receipt #"
                    className="input w-full text-sm"
                  />
                </div>

                <div className="mb-3">
                  <label className="mb-1 block text-xs font-medium text-gray-700">Discount</label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    value={discountAmount}
                    onChange={(e) => setDiscountAmount(e.target.value)}
                    placeholder="0.00"
                    className="input w-full text-sm"
                  />
                </div>

                <div className="mb-3">
                  <label className="mb-1 block text-xs font-medium text-gray-700">Tax Rate</label>
                  <select
                    value={taxRateId || ""}
                    onChange={(e) => setTaxRateId(e.target.value ? Number(e.target.value) : null)}
                    className="input w-full text-sm"
                  >
                    <option value="">No tax</option>
                    {taxRates.map((tr) => (
                      <option key={tr.tax_rate_id} value={tr.tax_rate_id}>
                        {tr.tax_name} ({tr.rate_percent}%)
                      </option>
                    ))}
                  </select>
                </div>

                <div className="mb-3">
                  <label className="mb-1 block text-xs font-medium text-gray-700">Notes (optional)</label>
                  <textarea
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    placeholder="Optional sale notes..."
                    rows={2}
                    className="input w-full resize-none text-sm"
                  />
                </div>
              </div>
            )}
          </div>

          {cart.length > 0 && (
            <div className="border-t border-gray-200 bg-white px-4 py-4">
              <div className="mb-3 space-y-1.5">
                <div className="flex justify-between text-sm text-gray-600">
                  <span>Subtotal</span>
                  <span>{formatCurrency(cartTotal.subtotal)}</span>
                </div>
                {cartTotal.discount > 0 && (
                  <div className="flex justify-between text-sm text-green-600">
                    <span>Discount</span>
                    <span>-{formatCurrency(cartTotal.discount)}</span>
                  </div>
                )}
                {cartTotal.tax > 0 && (
                  <div className="flex justify-between text-sm text-gray-600">
                    <span>Tax</span>
                    <span>{formatCurrency(cartTotal.tax)}</span>
                  </div>
                )}
                <div className="flex justify-between border-t border-gray-200 pt-1.5 text-base font-bold text-gray-900">
                  <span>Total</span>
                  <span>{formatCurrency(cartTotal.total)}</span>
                </div>
              </div>

              <button
                onClick={handleCompleteSale}
                disabled={!canCompleteSale || saleMutation.isPending}
                className={cn(
                  "flex w-full items-center justify-center gap-2 rounded-lg px-4 py-3 text-sm font-semibold text-white transition-colors",
                  canCompleteSale && !saleMutation.isPending
                    ? "bg-green-600 hover:bg-green-700"
                    : "cursor-not-allowed bg-gray-300"
                )}
              >
                {saleMutation.isPending ? (
                  <Spinner size="sm" />
                ) : (
                  <>
                    <Check className="h-4 w-4" />
                    Complete Sale — {formatCurrency(cartTotal.total)}
                  </>
                )}
              </button>

              <p className="mt-2 text-center text-[10px] text-gray-400">
                Ctrl+Enter to complete sale
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
