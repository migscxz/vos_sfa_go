# TODO: Add Orders Feature Structure

## Tasks

- [x] Create application/order_controller.dart: A controller class to handle order business logic, interacting with repository and managing order state.
- [x] Create data/models/cart_item_model.dart: A model for cart items, possibly extending or similar to OrderLineItem.
- [x] Create data/repositories/order_repository.dart: Repository for order data operations, using DatabaseManager.
- [x] Create presentation/widgets/order_item_card.dart: Widget to display individual order items in the cart.
- [x] Create presentation/widgets/modals/customer_picker_modal.dart: Modal for customer selection (extract from order_form.dart).
- [x] Create presentation/widgets/modals/supplier_picker_modal.dart: Modal for supplier selection (extract from order_form.dart).
- [x] Create presentation/widgets/modals/product_multi_picker_modal.dart: Modal for multi-product selection (extract from order_form.dart).
- [x] Update order_form.dart to use the new modal widgets instead of inline dialogs.
- [x] Test integration and ensure no breaking changes.
