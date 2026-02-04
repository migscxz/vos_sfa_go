// lib/core/database/table_schemas.dart

class TableSchemas {
  static const String userTable = '''
  CREATE TABLE IF NOT EXISTS user (
    user_id INTEGER PRIMARY KEY,

    user_email TEXT,
    user_password TEXT,
    user_fname TEXT,
    user_mname TEXT,
    user_lname TEXT,
    user_contact TEXT,
    user_province TEXT,
    user_city TEXT,
    user_brgy TEXT,
    user_department INTEGER,

    user_sss TEXT,
    user_philhealth TEXT,
    user_tin TEXT,
    user_position TEXT,

    -- Canonical column (your current schema)
    user_date_of_hire TEXT,
    -- Compatibility column (API sends this)
    user_dateOfHire TEXT,

    user_tags TEXT,
    user_bday TEXT,
    role_id INTEGER,
    user_image TEXT,

    -- Canonical
    updated_at TEXT,
    -- Compatibility (API sends these sometimes)
    updateAt TEXT,
    update_at TEXT,

    -- Canonical
    external_id TEXT,
    -- Compatibility
    externalId TEXT,

    -- Canonical
    is_deleted INTEGER,
    -- Compatibility
    isDeleted INTEGER,

    biometric_id TEXT,
    rf_id TEXT,

    -- Canonical
    is_admin INTEGER,
    -- Compatibility
    isAdmin INTEGER,

    user_pagibig TEXT,
    signature TEXT,
    emergency_contact_name TEXT,
    emergency_contact_number TEXT
  )
''';

  static const String salesmanTable = '''
    CREATE TABLE IF NOT EXISTS salesman (
      id INTEGER PRIMARY KEY,
      employee_id INTEGER,
      salesman_code TEXT,
      salesman_name TEXT,
      truck_plate TEXT,
      division_id INTEGER,
      branch_code INTEGER,
      bad_branch_code INTEGER,
      operation INTEGER,
      company_code INTEGER,
      supplier_code INTEGER,
      price_type TEXT,
      isActive INTEGER,
      isInventory INTEGER,
      canCollect INTEGER,
      inventory_day INTEGER,
      modified_date TEXT,
      encoder_id INTEGER
    )
  ''';

  // --- DEPARTMENT ---

  static const String departmentTable = '''
    CREATE TABLE IF NOT EXISTS department (
      department_id INTEGER PRIMARY KEY,
      department_name TEXT,
      parent_division INTEGER,
      department_description TEXT,
      department_head TEXT,
      tax_id INTEGER,
      date_added TEXT
    )
  ''';

  static const String unitTable = '''
    CREATE TABLE IF NOT EXISTS unit (
      unit_id INTEGER PRIMARY KEY,
      unit_name TEXT,
      unit_shortcut TEXT,
      sort_order INTEGER
    )
  ''';

  // --- CUSTOMER DB ---

  static const String customerTable = '''
    CREATE TABLE IF NOT EXISTS customer (
      id INTEGER PRIMARY KEY,
      customer_code TEXT,
      customer_name TEXT,
      customer_image TEXT,
      store_name TEXT,
      store_signage TEXT,
      brgy TEXT,
      city TEXT,
      province TEXT,
      contact_number TEXT,
      customer_email TEXT,
      tel_number TEXT,
      bank_details TEXT,
      customer_tin TEXT,
      payment_term INTEGER,
      store_type INTEGER,
      price_type TEXT,
      encoder_id INTEGER,
      credit_type TEXT,
      company_code TEXT,
      date_entered TEXT,
      isActive INTEGER,
      isVAT INTEGER,
      isEWT INTEGER,
      discount_type TEXT,
      otherDetails TEXT,
      classification TEXT,
      location TEXT
    )
  ''';

  /// Supplier table based on suppliers API
  static const String supplierTable = '''
    CREATE TABLE IF NOT EXISTS supplier (
      id INTEGER PRIMARY KEY,
      supplier_name TEXT,
      supplier_shortcut TEXT,
      supplier_type TEXT,
      supplier_image TEXT,
      address TEXT,
      brgy TEXT,
      city TEXT,
      state_province TEXT,
      country TEXT,
      postal_code TEXT,
      phone_number TEXT,
      email_address TEXT,
      contact_person TEXT,
      bank_details TEXT,
      delivery_terms TEXT,
      payment_terms TEXT,
      agreement_or_contract TEXT,
      notes_or_comments TEXT,
      preferred_communication_method TEXT,
      tin_number TEXT,
      date_added TEXT,
      isActive INTEGER,
      nonBuy INTEGER
    )
  ''';

  // ⬇️ LINK TABLE – which customer belongs to which salesman
  static const String customerSalesmanTable = '''
    CREATE TABLE IF NOT EXISTS customer_salesman (
      id INTEGER PRIMARY KEY,
      customer_id INTEGER,
      salesman_id INTEGER
    )
  ''';

  // --- SALES DB ---

  static const String productTable = '''
    CREATE TABLE IF NOT EXISTS product (
      product_id INTEGER PRIMARY KEY,
      product_code TEXT,
      barcode TEXT,
      product_name TEXT,
      short_description TEXT,
      description TEXT,
      product_brand INTEGER,
      product_category INTEGER,
      product_class INTEGER,
      product_section INTEGER,
      supplier_id INTEGER,
      product_segment INTEGER,
      product_type INTEGER,
      product_shelf_life TEXT,
      product_weight REAL,
      unit_of_measurement INTEGER,
      unit_of_measurement_count REAL,
      cost_per_unit REAL,
      price_per_unit REAL,
      priceA REAL,
      priceB REAL,
      priceC REAL,
      priceD REAL,
      priceE REAL,
      maintaining_quantity REAL,
      estimated_extended_cost REAL,
      estimated_unit_cost REAL,
      product_image TEXT,
      date_added TEXT,
      created_at TEXT,
      last_updated TEXT,
      external_id TEXT,
      parent_id INTEGER,
      isActive INTEGER
    )
  ''';

  static const String productPerSupplierTable = '''
    CREATE TABLE IF NOT EXISTS product_per_supplier (
      id INTEGER PRIMARY KEY,
      product_id INTEGER,
      supplier_id INTEGER,
      discount_type INTEGER
    )
  ''';

  static const String salesOrderTable = '''
    CREATE TABLE IF NOT EXISTS sales_order (
      order_id INTEGER PRIMARY KEY,
      order_no TEXT,
      po_no TEXT,
      customer_code TEXT,
      salesman_id INTEGER,
      supplier_id INTEGER,
      branch_id INTEGER,
      order_date TEXT,
      delivery_date TEXT,
      due_date TEXT,
      payment_terms TEXT,
      order_status TEXT,
      total_amount REAL,
      allocated_amount REAL,
      sales_type TEXT,
      receipt_type TEXT,
      discount_amount REAL,
      net_amount REAL,
      created_by INTEGER,
      created_date TEXT,
      modified_by INTEGER,
      modified_date TEXT,
      posted_by INTEGER,
      posted_date TEXT,
      remarks TEXT,
      isDelivered INTEGER,
      isCancelled INTEGER,
      for_approval_at TEXT,
      for_consolidation_at TEXT,
      for_picking_at TEXT,
      for_invoicing_at TEXT,
      for_loading_at TEXT,
      for_shipping_at TEXT,
      delivered_at TEXT,
      on_hold_at TEXT,
      cancelled_at TEXT,
      customer_name TEXT,
      is_synced INTEGER DEFAULT 0,
      order_type TEXT,
      supplier TEXT,
      product TEXT,
      product_id INTEGER,
      product_base_id INTEGER,
      unit_id INTEGER,
      unit_count REAL,
      price_type TEXT,
      quantity INTEGER,
      has_attachment INTEGER,
      callsheet_image_path TEXT
    )
  ''';

  static const String salesOrderDetailsTable = '''
    CREATE TABLE IF NOT EXISTS sales_order_details (
      detail_id INTEGER PRIMARY KEY,
      product_id INTEGER,
      order_id INTEGER,
      unit_price REAL,
      ordered_quantity REAL,
      allocated_quantity REAL,
      served_quantity REAL,
      discount_type REAL,
      discount_amount REAL,
      gross_amount REAL,
      net_amount REAL,
      allocated_amount REAL,
      remarks TEXT,
      created_date TEXT,
      modified_date TEXT
    )
  ''';

  static const String salesInvoiceTable = '''
    CREATE TABLE IF NOT EXISTS sales_invoice (
      invoice_id INTEGER PRIMARY KEY,
      order_id TEXT,
      customer_code TEXT,
      invoice_no TEXT,
      salesman_id INTEGER,
      branch_id INTEGER,
      invoice_date TEXT,
      dispatch_date TEXT,
      due_date TEXT,
      payment_terms TEXT,
      transaction_status TEXT,
      payment_status TEXT,
      total_amount REAL,
      sales_type TEXT,
      invoice_type TEXT,
      price_type TEXT,
      vat_amount REAL,
      gross_amount REAL,
      discount_amount REAL,
      net_amount REAL,
      created_by INTEGER,
      created_date TEXT,
      modified_by INTEGER,
      modified_date TEXT,
      posted_by INTEGER,
      posted_date TEXT,
      remarks TEXT,
      isReceipt INTEGER,
      isPosted INTEGER,
      isDispatched INTEGER,
      isRemitted INTEGER
    )
  ''';

  static const String salesInvoiceDetailsTable = '''
    CREATE TABLE IF NOT EXISTS sales_invoice_details (
      detail_id INTEGER PRIMARY KEY,
      order_id TEXT,
      invoice_no INTEGER,
      serial_no TEXT,
      discount_type TEXT,
      product_id INTEGER,
      unit INTEGER,
      unit_price REAL,
      quantity REAL,
      discount_amount REAL,
      gross_amount REAL,
      total_amount REAL,
      created_date TEXT,
      modified_date TEXT
    )
  ''';

  static const String salesReturnTable = '''
    CREATE TABLE IF NOT EXISTS sales_return (
      return_id INTEGER PRIMARY KEY,
      return_number TEXT,
      customer_code TEXT,
      salesman_id INTEGER,
      branch_id INTEGER,
      return_date TEXT,
      total_amount REAL,
      discount_amount REAL,
      gross_amount REAL,
      remarks TEXT,
      created_by INTEGER,
      order_id TEXT,
      invoice_no TEXT,
      created_at TEXT,
      updated_at TEXT,
      received_at TEXT,
      isThirdParty INTEGER,
      price_type TEXT,
      status TEXT,
      isPosted INTEGER,
      isApplied INTEGER,
      isReceived INTEGER,
      UNIQUE(return_number)
    )
  ''';

  static const String salesReturnDetailsTable = '''
    CREATE TABLE IF NOT EXISTS sales_return_details (
      detail_id INTEGER PRIMARY KEY,
      return_no TEXT,
      product_id INTEGER,
      unit_price REAL,
      returned_quantity INTEGER,
      gross_amount REAL,
      net_amount REAL,
      remarks TEXT,
      created_date TEXT,
      modified_date TEXT,
      FOREIGN KEY(return_no) REFERENCES sales_return(return_number) ON DELETE CASCADE
    )
  ''';

  static const String salesOrderAttachmentTable = '''
    CREATE TABLE IF NOT EXISTS sales_order_attachment (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sales_order_id INTEGER,
      attachment TEXT,
      created_by INTEGER,
      created_date TEXT,
      updated_by INTEGER,
      updated_date TEXT,
      is_synced INTEGER DEFAULT 0
    )
  ''';

  // --- TASKS DB ---

  static const String taskTable = '''
    CREATE TABLE IF NOT EXISTS task (
      id INTEGER PRIMARY KEY,
      name TEXT,
      description TEXT,
      created_by INTEGER,
      created_at TEXT,
      isSalesman INTEGER,
      task_type_id INTEGER
    )
  ''';

  static const String dailyActionPlanTable = '''
    CREATE TABLE IF NOT EXISTS daily_action_plan (
      id INTEGER PRIMARY KEY,
      mcp_id INTEGER,
      task_id INTEGER,
      priority_level TEXT,
      date TEXT,
      is_completed INTEGER,
      additional_description TEXT,
      customer_id INTEGER,
      created_by INTEGER,
      created_at TEXT
    )
  ''';

  static const String monthlyCoveragePlanTable = '''
    CREATE TABLE IF NOT EXISTS monthly_coverage_plan (
      id INTEGER PRIMARY KEY,
      month INTEGER,
      year INTEGER,
      user_id INTEGER,
      created_by INTEGER,
      created_at TEXT
    )
  ''';

  static const String dapAttachmentTable = '''
    CREATE TABLE IF NOT EXISTS daily_action_plan_attachment (
      id INTEGER PRIMARY KEY,
      dap_id INTEGER,
      attachment_address TEXT,
      latitude REAL,
      longitude REAL,
      created_by INTEGER,
      created_at TEXT
    )
  ''';
}
