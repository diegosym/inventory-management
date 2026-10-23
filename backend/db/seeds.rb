# Idempotent demo dataset (RF-15): re-running `db:seed` never duplicates it.
# Fixed, readable data (plan D-P4 — no Faker). SKUs are D-6 valid (uppercase
# letters, digits, hyphens), prices > 0 with at most two decimals, stock varied
# (0 is valid), a mix of active and inactive products, and varied names that
# exercise the `q` substring search (e.g. "keyboard", "monitor", "cable").
#
# Spec 004 (D-16(a)): idempotence is scoped to visible products. A soft-deleted
# demo product is invisible to the default-scoped `find_or_create_by!`, so a
# re-run resurrects its SKU under a NEW id while the old row stays soft-deleted.
# No code here delivers that — the model's default scope + the partial unique
# SKU index already do (plan D-P39).
products = [
  { sku: "KB-001", name: "Mechanical Keyboard", description: "RGB mechanical keyboard with brown switches", price: 89.90, stock: 25, active: true },
  { sku: "KB-002", name: "Wireless Keyboard", description: "Low-profile wireless keyboard", price: 59.50, stock: 14, active: true },
  { sku: "MSE-001", name: "Ergonomic Mouse", description: "Vertical ergonomic mouse", price: 24.99, stock: 40, active: true },
  { sku: "MSE-002", name: "Gaming Mouse", description: "RGB gaming mouse, 16000 DPI", price: 45.00, stock: 18, active: true },
  { sku: "MON-001", name: "27-inch LED Monitor", description: "27-inch 1440p IPS monitor", price: 199.99, stock: 8, active: true },
  { sku: "MON-002", name: "34-inch Ultrawide Monitor", description: "34-inch ultrawide curved monitor", price: 449.00, stock: 5, active: true },
  { sku: "CBL-001", name: "USB-C Cable 2m", description: "Braided USB-C cable, 100W", price: 12.49, stock: 100, active: true },
  { sku: "CBL-002", name: "HDMI Cable 3m", description: "Ultra-high-speed HDMI cable", price: 15.90, stock: 60, active: true },
  { sku: "HUB-001", name: "USB-C Hub 7-in-1", description: "Hub with HDMI, USB 3.0 and SD card reader", price: 39.95, stock: 22, active: true },
  { sku: "CHG-001", name: "65W GaN Charger", description: "Compact 65W USB-C charger", price: 34.99, stock: 30, active: true },
  { sku: "CHG-002", name: "Wireless Charging Pad", description: "15W Qi wireless charging pad", price: 29.90, stock: 0, active: true },
  { sku: "STN-001", name: "Laptop Stand Aluminum", description: "Adjustable aluminum laptop stand", price: 42.50, stock: 17, active: true },
  { sku: "CAM-001", name: "Full HD Webcam", description: "1080p webcam with privacy cover", price: 79.00, stock: 11, active: false },
  { sku: "MIC-001", name: "USB Studio Microphone", description: "USB condenser microphone for streaming", price: 119.00, stock: 6, active: false }
]

products.each do |attributes|
  Product.find_or_create_by!(sku: attributes[:sku]) do |product|
    product.assign_attributes(attributes)
  end
end
