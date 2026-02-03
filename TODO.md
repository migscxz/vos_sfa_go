# Cart-Style Ordering Refactoring TODO

## Phase 1: UI Cleanup & Customer Selection

- [x] Remove Order Type: Delete the \_orderType variable and the \_buildOrderTypeSelector widget. Default the logic to "Manual" internally if needed.
- [x] Load Customers: Create a function \_loadCustomersFromDb() similar to \_loadSuppliersFromDb() to populate a list for the search.
- [x] Customer Search Widget: Replace the "Customer Name" TextFormField with a Searchable Dropdown (or a read-only text field that opens a search dialog when tapped).
- [x] Auto-Fill Logic: When a customer is selected from the search, automatically set the text for \_customerCodeCtrl.

## Phase 2: Supplier & Product Logic

- [x] Supplier Search: Convert the existing Supplier dropdown into a Searchable Dropdown.
- [x] Filter Products: Ensure \_getProductsForSupplier(supplierId) returns only products linked to that supplier in the product_per_supplier table.
- [x] Multi-Select Dialog: Create a new widget \_showMultiSelectProductDialog.
  - It should accept a list of products.
  - It should display a CheckboxListTile for each product.
  - It should return a List<Product> of selected items.

## Phase 3: The "Cart" (Order Details)

- [x] State Management: Replace the single variables (\_selectedProduct, \_quantityCtrl) with a list: List<OrderLineItem> \_cartItems = [];.
- [x] Dynamic List View: In the "Order Details" container, remove the old product dropdown. Replace it with:
  - An "Add Products" button.
  - A ListView.builder that renders a card for each item in \_cartItems.
- [x] Row Logic: Inside each row of the list:
  - Show Product Name.
  - Show a Dropdown for Unit/Packaging (populated from that product's available units).
  - Show a Quantity input field.
  - Add a "Remove" (Trash) icon.
- [x] Real-Time Totals: Create a getter double get \_grandTotal that loops through \_cartItems and sums up (price \* quantity). Display this at the bottom.

## Phase 4: Saving Data

- [x] Update Save Function: Refactor \_saveOrder to:
  - Insert into sales_order table (get the new ID).
  - Loop through \_cartItems and insert each into sales_order_detail using that ID.
  - Clear the form.
