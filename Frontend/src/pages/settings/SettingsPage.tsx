import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import {
  Building2,
  Percent,
  Settings,
  Plus,
  Edit2,
  Trash2,
  X,
  Save,
} from "lucide-react"
import toast from "react-hot-toast"
import { apiGet, apiPost, apiPut, apiDelete } from "@/api/client"
import { PageLoader, Spinner } from "@/components/feedback"
import type {
  BusinessInfo,
  BusinessInfoUpdate,
  TaxRateRead,
  TaxRateCreate,
  TaxRateUpdate,
  SettingRead,
  SettingCreate,
  SettingUpdate,
} from "@/types"

const businessInfoSchema = z.object({
  business_name: z.string().min(1, "Business name is required"),
  legal_name: z.string().optional(),
  tax_id: z.string().optional(),
  email: z.string().email("Invalid email").optional().or(z.literal("")),
  phone: z.string().optional(),
  address: z.string().optional(),
  city: z.string().optional(),
  state: z.string().optional(),
  postal_code: z.string().optional(),
  country: z.string().optional(),
  currency_code: z.string().optional(),
  logo_url: z.string().url("Invalid URL").optional().or(z.literal("")),
})

type BusinessInfoForm = z.infer<typeof businessInfoSchema>

const taxRateSchema = z.object({
  tax_name: z.string().min(1, "Tax name is required"),
  tax_code: z.string().min(1, "Tax code is required"),
  rate_percent: z.coerce
    .number()
    .min(0, "Rate must be non-negative")
    .max(100, "Rate must be at most 100"),
  is_default: z.boolean().optional(),
})

type TaxRateForm = z.infer<typeof taxRateSchema>

const settingSchema = z.object({
  setting_key: z.string().min(1, "Key is required"),
  setting_value: z.string().min(1, "Value is required"),
  data_type: z.enum(["string", "number", "boolean", "json"]),
  category: z.string().min(1, "Category is required"),
  description: z.string().optional(),
})

type SettingForm = z.infer<typeof settingSchema>

type Tab = "business" | "tax" | "settings"

const CATEGORIES = ["general", "appearance", "receipt", "notifications", "integrations"]

export default function SettingsPage() {
  const [activeTab, setActiveTab] = useState<Tab>("business")
  const queryClient = useQueryClient()

  const tabs: { id: Tab; label: string; icon: React.ReactNode }[] = [
    { id: "business", label: "Business Info", icon: <Building2 size={18} /> },
    { id: "tax", label: "Tax Rates", icon: <Percent size={18} /> },
    { id: "settings", label: "App Settings", icon: <Settings size={18} /> },
  ]

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <h1 className="text-2xl font-bold mb-6">Settings</h1>

      <div className="flex gap-1 border-b border-gray-200 mb-6">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
              activeTab === tab.id
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
            }`}
          >
            {tab.icon}
            {tab.label}
          </button>
        ))}
      </div>

      {activeTab === "business" && <BusinessInfoTab />}
      {activeTab === "tax" && <TaxRatesTab />}
      {activeTab === "settings" && <AppSettingsTab />}
    </div>
  )
}

function BusinessInfoTab() {
  const queryClient = useQueryClient()
  const [isEditing, setIsEditing] = useState(false)

  const { data: businessInfo, isLoading } = useQuery<BusinessInfo>({
    queryKey: ["business-info"],
    queryFn: () => apiGet("/business/info"),
  })

  const updateMutation = useMutation({
    mutationFn: (data: BusinessInfoUpdate) => apiPut("/business/info", data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["business-info"] })
      toast.success("Business info updated")
      setIsEditing(false)
    },
    onError: () => toast.error("Failed to update business info"),
  })

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<BusinessInfoForm>({
    resolver: zodResolver(businessInfoSchema),
  })

  if (isLoading) return <PageLoader />

  const handleEdit = () => {
    if (businessInfo) {
      reset({
        business_name: businessInfo.business_name,
        legal_name: businessInfo.legal_name ?? "",
        tax_id: businessInfo.tax_id ?? "",
        email: businessInfo.email ?? "",
        phone: businessInfo.phone ?? "",
        address: businessInfo.address ?? "",
        city: businessInfo.city ?? "",
        state: businessInfo.state ?? "",
        postal_code: businessInfo.postal_code ?? "",
        country: businessInfo.country ?? "",
        currency_code: businessInfo.currency_code ?? "",
        logo_url: businessInfo.logo_url ?? "",
      })
      setIsEditing(true)
    }
  }

  const onSubmit = (data: BusinessInfoForm) => {
    const payload: BusinessInfoUpdate = {
      ...data,
      email: data.email || undefined,
      logo_url: data.logo_url || undefined,
    }
    updateMutation.mutate(payload)
  }

  const fields: { label: string; name: keyof BusinessInfoForm; type?: string }[] = [
    { label: "Business Name", name: "business_name" },
    { label: "Legal Name", name: "legal_name" },
    { label: "Tax ID", name: "tax_id" },
    { label: "Email", name: "email", type: "email" },
    { label: "Phone", name: "phone" },
    { label: "Address", name: "address" },
    { label: "City", name: "city" },
    { label: "State", name: "state" },
    { label: "Postal Code", name: "postal_code" },
    { label: "Country", name: "country" },
    { label: "Currency Code", name: "currency_code" },
    { label: "Logo URL", name: "logo_url" },
  ]

  if (isEditing) {
    return (
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {fields.map((field) => (
            <div key={field.name}>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {field.label}
              </label>
              <input
                type={field.type ?? "text"}
                {...register(field.name)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              {errors[field.name] && (
                <p className="mt-1 text-sm text-red-600">
                  {errors[field.name]!.message}
                </p>
              )}
            </div>
          ))}
        </div>
        <div className="flex gap-3">
          <button
            type="submit"
            disabled={isSubmitting}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {isSubmitting ? <Spinner size="sm" /> : <Save size={16} />}
            Save
          </button>
          <button
            type="button"
            onClick={() => setIsEditing(false)}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            <X size={16} />
            Cancel
          </button>
        </div>
      </form>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <button
          onClick={handleEdit}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          <Edit2 size={16} />
          Edit
        </button>
      </div>
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        {businessInfo?.logo_url && (
          <img
            src={businessInfo.logo_url}
            alt="Business Logo"
            className="h-16 mb-4 object-contain"
          />
        )}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {[
            { label: "Business Name", value: businessInfo?.business_name },
            { label: "Legal Name", value: businessInfo?.legal_name },
            { label: "Tax ID", value: businessInfo?.tax_id },
            { label: "Email", value: businessInfo?.email },
            { label: "Phone", value: businessInfo?.phone },
            { label: "Address", value: businessInfo?.address },
            { label: "City", value: businessInfo?.city },
            { label: "State", value: businessInfo?.state },
            { label: "Postal Code", value: businessInfo?.postal_code },
            { label: "Country", value: businessInfo?.country },
            { label: "Currency", value: businessInfo?.currency_code },
            {
              label: "Last Updated",
              value: businessInfo?.updated_at
                ? new Date(businessInfo.updated_at).toLocaleString()
                : null,
            },
          ].map((item) => (
            <div key={item.label}>
              <dt className="text-sm text-gray-500">{item.label}</dt>
              <dd className="mt-1 text-sm font-medium text-gray-900">
                {item.value || "-"}
              </dd>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function TaxRatesTab() {
  const queryClient = useQueryClient()
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState<number | null>(null)

  const { data: taxRates = [], isLoading } = useQuery<TaxRateRead[]>({
    queryKey: ["tax-rates"],
    queryFn: () => apiGet("/business/tax-rates"),
  })

  const createMutation = useMutation({
    mutationFn: (data: TaxRateCreate) => apiPost("/business/tax-rates", data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tax-rates"] })
      toast.success("Tax rate created")
      setShowForm(false)
    },
    onError: () => toast.error("Failed to create tax rate"),
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: number; data: TaxRateUpdate }) =>
      apiPut(`/business/tax-rates/${id}`, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tax-rates"] })
      toast.success("Tax rate updated")
      setShowForm(false)
      setEditingId(null)
    },
    onError: () => toast.error("Failed to update tax rate"),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => apiDelete(`/business/tax-rates/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tax-rates"] })
      toast.success("Tax rate deleted")
    },
    onError: () => toast.error("Failed to delete tax rate"),
  })

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<TaxRateForm>({
    resolver: zodResolver(taxRateSchema),
    defaultValues: { is_default: false },
  })

  const handleEdit = (rate: TaxRateRead) => {
    setEditingId(rate.tax_rate_id)
    reset({
      tax_name: rate.tax_name,
      tax_code: rate.tax_code,
      rate_percent: rate.rate_percent,
      is_default: rate.is_default,
    })
    setShowForm(true)
  }

  const onSubmit = (data: TaxRateForm) => {
    if (editingId) {
      updateMutation.mutate({ id: editingId, data })
    } else {
      createMutation.mutate(data)
    }
  }

  const handleClose = () => {
    setShowForm(false)
    setEditingId(null)
    reset({ tax_name: "", tax_code: "", rate_percent: 0, is_default: false })
  }

  const handleDelete = (id: number) => {
    if (window.confirm("Delete this tax rate?")) {
      deleteMutation.mutate(id)
    }
  }

  if (isLoading) return <PageLoader />

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <button
          onClick={() => {
            handleClose()
            setShowForm(true)
          }}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          <Plus size={16} />
          Add Tax Rate
        </button>
      </div>

      {showForm && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <h3 className="text-lg font-semibold mb-4">
            {editingId ? "Edit Tax Rate" : "Create Tax Rate"}
          </h3>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tax Name
                </label>
                <input
                  {...register("tax_name")}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                {errors.tax_name && (
                  <p className="mt-1 text-sm text-red-600">{errors.tax_name.message}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tax Code
                </label>
                <input
                  {...register("tax_code")}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                {errors.tax_code && (
                  <p className="mt-1 text-sm text-red-600">{errors.tax_code.message}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Rate (%)
                </label>
                <input
                  type="number"
                  step="0.01"
                  {...register("rate_percent")}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                {errors.rate_percent && (
                  <p className="mt-1 text-sm text-red-600">
                    {errors.rate_percent.message}
                  </p>
                )}
              </div>
            </div>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="is_default"
                {...register("is_default")}
                className="h-4 w-4 text-blue-600 rounded"
              />
              <label htmlFor="is_default" className="text-sm text-gray-700">
                Set as default tax rate
              </label>
            </div>
            <div className="flex gap-3">
              <button
                type="submit"
                disabled={isSubmitting}
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
              >
                {isSubmitting ? <Spinner size="sm" /> : <Save size={16} />}
                {editingId ? "Update" : "Create"}
              </button>
              <button
                type="button"
                onClick={handleClose}
                className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                <X size={16} />
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Name
              </th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Code
              </th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Rate
              </th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Default
              </th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Active
              </th>
              <th className="px-4 py-3 text-right text-sm font-medium text-gray-500">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {taxRates.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-gray-500">
                  No tax rates configured
                </td>
              </tr>
            ) : (
              taxRates.map((rate) => (
                <tr key={rate.tax_rate_id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">
                    {rate.tax_name}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">{rate.tax_code}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {rate.rate_percent}%
                  </td>
                  <td className="px-4 py-3 text-sm">
                    {rate.is_default ? (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        Default
                      </span>
                    ) : (
                      <span className="text-gray-400">-</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm">
                    {rate.is_active ? (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        Active
                      </span>
                    ) : (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        Inactive
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => handleEdit(rate)}
                        className="p-1 text-gray-500 hover:text-blue-600"
                      >
                        <Edit2 size={16} />
                      </button>
                      <button
                        onClick={() => handleDelete(rate.tax_rate_id)}
                        className="p-1 text-gray-500 hover:text-red-600"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function AppSettingsTab() {
  const queryClient = useQueryClient()
  const [selectedCategory, setSelectedCategory] = useState("general")
  const [showForm, setShowForm] = useState(false)
  const [editingKey, setEditingKey] = useState<string | null>(null)

  const { data: settings = [], isLoading } = useQuery<SettingRead[]>({
    queryKey: ["settings", selectedCategory],
    queryFn: () => apiGet(`/settings?category=${selectedCategory}`),
  })

  const createMutation = useMutation({
    mutationFn: (data: SettingCreate) => apiPost("/settings", data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["settings", selectedCategory] })
      toast.success("Setting created")
      setShowForm(false)
    },
    onError: () => toast.error("Failed to create setting"),
  })

  const updateMutation = useMutation({
    mutationFn: ({ key, data }: { key: string; data: SettingUpdate }) =>
      apiPut(`/settings/${key}`, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["settings", selectedCategory] })
      toast.success("Setting updated")
      setShowForm(false)
      setEditingKey(null)
    },
    onError: () => toast.error("Failed to update setting"),
  })

  const deleteMutation = useMutation({
    mutationFn: (key: string) => apiDelete(`/settings/${key}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["settings", selectedCategory] })
      toast.success("Setting deleted")
    },
    onError: () => toast.error("Failed to delete setting"),
  })

  const {
    register,
    handleSubmit,
    reset,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<SettingForm>({
    resolver: zodResolver(settingSchema),
  })

  const dataTypeValue = watch("data_type")

  const handleEdit = (setting: SettingRead) => {
    setEditingKey(setting.setting_key)
    reset({
      setting_key: setting.setting_key,
      setting_value: setting.setting_value,
      data_type: setting.data_type as "string" | "number" | "boolean" | "json",
      category: setting.category,
      description: setting.description ?? "",
    })
    setShowForm(true)
  }

  const onSubmit = (data: SettingForm) => {
    const payload = {
      ...data,
      description: data.description || undefined,
    }
    if (editingKey) {
      updateMutation.mutate({ key: editingKey, data: payload })
    } else {
      createMutation.mutate(payload)
    }
  }

  const handleClose = () => {
    setShowForm(false)
    setEditingKey(null)
    reset({
      setting_key: "",
      setting_value: "",
      data_type: "string",
      category: selectedCategory,
      description: "",
    })
  }

  const handleDelete = (key: string) => {
    if (window.confirm(`Delete setting "${key}"?`)) {
      deleteMutation.mutate(key)
    }
  }

  if (isLoading) return <PageLoader />

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex gap-2 flex-wrap">
          {CATEGORIES.map((cat) => (
            <button
              key={cat}
              onClick={() => {
                setSelectedCategory(cat)
                setShowForm(false)
                setEditingKey(null)
              }}
              className={`px-3 py-1.5 text-sm rounded-full capitalize transition-colors ${
                selectedCategory === cat
                  ? "bg-blue-600 text-white"
                  : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
        <button
          onClick={() => {
            handleClose()
            reset({ category: selectedCategory })
            setShowForm(true)
          }}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          <Plus size={16} />
          Add Setting
        </button>
      </div>

      {showForm && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <h3 className="text-lg font-semibold mb-4">
            {editingKey ? "Edit Setting" : "Create Setting"}
          </h3>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Key
                </label>
                <input
                  {...register("setting_key")}
                  disabled={!!editingKey}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:bg-gray-100"
                />
                {errors.setting_key && (
                  <p className="mt-1 text-sm text-red-600">
                    {errors.setting_key.message}
                  </p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Category
                </label>
                <select
                  {...register("category")}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  {CATEGORIES.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat.charAt(0).toUpperCase() + cat.slice(1)}
                    </option>
                  ))}
                </select>
                {errors.category && (
                  <p className="mt-1 text-sm text-red-600">
                    {errors.category.message}
                  </p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Data Type
                </label>
                <select
                  {...register("data_type")}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <option value="string">String</option>
                  <option value="number">Number</option>
                  <option value="boolean">Boolean</option>
                  <option value="json">JSON</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Value
                </label>
                {dataTypeValue === "boolean" ? (
                  <select
                    {...register("setting_value")}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="true">True</option>
                    <option value="false">False</option>
                  </select>
                ) : dataTypeValue === "json" ? (
                  <textarea
                    {...register("setting_value")}
                    rows={3}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg font-mono text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                ) : (
                  <input
                    type={dataTypeValue === "number" ? "number" : "text"}
                    {...register("setting_value")}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                )}
                {errors.setting_value && (
                  <p className="mt-1 text-sm text-red-600">
                    {errors.setting_value.message}
                  </p>
                )}
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Description
              </label>
              <input
                {...register("description")}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
            <div className="flex gap-3">
              <button
                type="submit"
                disabled={isSubmitting}
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
              >
                {isSubmitting ? <Spinner size="sm" /> : <Save size={16} />}
                {editingKey ? "Update" : "Create"}
              </button>
              <button
                type="button"
                onClick={handleClose}
                className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                <X size={16} />
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Key
              </th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Value
              </th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Type
              </th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Description
              </th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-500">
                Active
              </th>
              <th className="px-4 py-3 text-right text-sm font-medium text-gray-500">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {settings.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-gray-500">
                  No settings in this category
                </td>
              </tr>
            ) : (
              settings.map((setting) => (
                <tr key={setting.setting_id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm font-medium text-gray-900 font-mono">
                    {setting.setting_key}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">
                    {setting.data_type === "boolean" ? (
                      <span
                        className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                          setting.setting_value === "true"
                            ? "bg-green-100 text-green-800"
                            : "bg-gray-100 text-gray-800"
                        }`}
                      >
                        {setting.setting_value}
                      </span>
                    ) : (
                      setting.setting_value
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                      {setting.data_type}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">
                    {setting.description || "-"}
                  </td>
                  <td className="px-4 py-3 text-sm">
                    {setting.is_active ? (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        Active
                      </span>
                    ) : (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        Inactive
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => handleEdit(setting)}
                        className="p-1 text-gray-500 hover:text-blue-600"
                      >
                        <Edit2 size={16} />
                      </button>
                      <button
                        onClick={() => handleDelete(setting.setting_key)}
                        className="p-1 text-gray-500 hover:text-red-600"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
