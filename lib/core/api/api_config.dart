class ApiConfig {
  static const String baseUrl = "http://goatedcodoer:8056/items";

  static const String user = "/user";
  static const String salesman = "/salesman";
  static const String customer = "/customer";
  static const String salesOrder = "/sales_order";
  static const String salesOrderDetails = "/sales_order_details";
  static const String salesInvoice = "/sales_invoice";
  static const String salesInvoiceDetails = "/sales_invoice_details";
  static const String salesReturn = "/sales_return";
  static const String salesReturnDetails = "/sales_return_details";
  static const String task = "/task";
  static const String dap = "/daily_action_plan";
  static const String mcp = "/monthly_coverage_plan";
  static const String department = "/department";
  static const String products = "/products";
  static const String suppliers = "/suppliers";
  static const String dailyActionPlanAttachment =
      "/daily_action_plan_attachment";

  // ✅ new
  static const String customerSalesmen = "/customer_salesmen";
  static const String productPerSupplier = "/product_per_supplier";
  static const String units = "/units";
  static const String salesOrderAttachment = "/sales_order_attachment";

  // Discount Endpoints
  static const String discountTypes = "/discount_type";
  static const String linePerDiscountType = "/line_per_discount_type";
  static const String lineDiscount = "/line_discount";
  static const String productPerCustomer = "/product_per_customer";
  static const String supplierCategoryDiscountPerCustomer =
      "/supplier_category_discount_per_customer";
}
