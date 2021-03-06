module Haltr
  module Utils

    require "rexml/document"
    class << self

      def compress(string)
        return nil if string.nil?
        buf = ActiveSupport::Gzip.compress(string)
        Base64::encode64(buf).chomp
      end

      def decompress(string)
        return nil if string.nil?
        begin
          buf = Base64::decode64(string)
          ActiveSupport::Gzip.decompress(buf)
        rescue
          string
        end
      end

      # retrieve xpath from document
      # if xpath is an array, concatenates its values
      def get_xpath(doc,xpath)
        val = doc.xpath(*xpath)
        val.blank? ? nil : val.collect {|v| v.text }.join(" ")
      end

      def xpaths_for(format)
        xpaths = {}.with_indifferent_access
        if format =~ /facturae/
          xpaths[:invoice_number]     = [ "//Invoices/Invoice/InvoiceHeader/InvoiceNumber",
                                          "//Invoices/Invoice/InvoiceHeader/InvoiceSeriesCode" ]
          xpaths[:invoice_date]       = "//Invoices/Invoice/InvoiceIssueData/IssueDate"
          xpaths[:invoice_total]      = "//Invoices/Invoice/InvoiceTotals/InvoiceTotal"
          xpaths[:invoice_import]     = "//Invoices/Invoice/InvoiceTotals/TotalGrossAmountBeforeTaxes"
          xpaths[:discount_percent]   = "//Invoices/Invoice/InvoiceTotals/GeneralDiscounts/Discount/DiscountRate"
          xpaths[:discount_text]      = "//Invoices/Invoice/InvoiceTotals/GeneralDiscounts/Discount/DiscountReason"
          xpaths[:invoice_due_date]   = "//Invoices/Invoice/PaymentDetails/Installment/InstallmentDueDate"
          xpaths[:seller_taxcode]     = "//Parties/SellerParty/TaxIdentification/TaxIdentificationNumber"
          xpaths[:seller_name]        = "//Parties/SellerParty/LegalEntity/CorporateName"
          xpaths[:seller_name2]       = [ "//Parties/SellerParty/Individual/Name",
                                          "//Parties/SellerParty/Individual/FirstSurname",
                                          "//Parties/SellerParty/Individual/SecondSurname" ]
          xpaths[:seller_address]     = "//Parties/SellerParty/*/*/Address"
          xpaths[:seller_province]    = "//Parties/SellerParty/*/*/Province"
          xpaths[:seller_countrycode] = "//Parties/SellerParty/*/*/CountryCode"
          xpaths[:seller_website]     = "//Parties/SellerParty/*/ContactDetails/WebAddress"
          xpaths[:seller_email]       = "//Parties/SellerParty/*/ContactDetails/ElectronicMail"
          xpaths[:seller_cp_city]     = [ "//Parties/SellerParty/*/*/PostCode",
                                          "//Parties/SellerParty/*/*/Town" ]
          xpaths[:seller_cp_city2]    = "//Parties/SellerParty/*/*/PostCodeAndTown"
          xpaths[:seller_cp]          = "//Parties/SellerParty/*/*/PostCode"
          xpaths[:buyer_taxcode]      = "//Parties/BuyerParty/TaxIdentification/TaxIdentificationNumber"
          xpaths[:buyer_name]         = "//Parties/BuyerParty/LegalEntity/CorporateName"
          xpaths[:buyer_name2]        = [ "//Parties/BuyerParty/Individual/Name",
                                          "//Parties/BuyerParty/Individual/FirstSurname",
                                          "//Parties/BuyerParty/Individual/SecondSurname" ]
          xpaths[:buyer_address]      = "//Parties/BuyerParty/*/*/Address"
          xpaths[:buyer_province]     = "//Parties/BuyerParty/*/*/Province"
          xpaths[:buyer_countrycode]  = "//Parties/BuyerParty/*/*/CountryCode"
          xpaths[:buyer_website]      = "//Parties/BuyerParty/*/ContactDetails/WebAddress"
          xpaths[:buyer_email]        = "//Parties/BuyerParty/*/ContactDetails/ElectronicMail"
          xpaths[:buyer_cp_city]      = [ "//Parties/BuyerParty/*/*/PostCode",
                                          "//Parties/BuyerParty/*/*/Town" ]
          xpaths[:buyer_cp_city2]     = "//Parties/BuyerParty/*/*/PostCodeAndTown"
          xpaths[:buyer_cp]           = "//Parties/BuyerParty/*/*/PostCode"
          xpaths[:currency]           = "//FileHeader/Batch/InvoiceCurrencyCode"
          xpaths[:extra_info]         = "//Invoices/Invoice/AdditionalData/InvoiceAdditionalInformation"
          xpaths[:charge]             = "//Invoices/Invoice/InvoiceTotals/GeneralSurcharges/Charge/ChargeAmount"
          xpaths[:charge_reason]      = "//Invoices/Invoice/InvoiceTotals/GeneralSurcharges/Charge/ChargeReason"
          xpaths[:accounting_cost]    = "//Parties/BuyerParty/LegalEntity/ContactDetails/ContactPersons"
          xpaths[:to_be_debited]      = "//Invoices/Invoice/PaymentDetails/Installment/AccountToBeDebited"
          xpaths[:to_be_credited]     = "//Invoices/Invoice/PaymentDetails/Installment/AccountToBeCredited"
          # relative to AccountToBe*
          xpaths[:bank_account]       = "*/AccountNumber"
          xpaths[:iban]               = "*/IBAN"
          xpaths[:bic]                = "*/BankCode"

          xpaths[:invoice_lines]      = "//Invoices/Invoice/Items/InvoiceLine"
          # relative to invoice_lines
          xpaths[:line_quantity]      = "Quantity"
          xpaths[:line_description]   = "ItemDescription"
          xpaths[:line_price]         = "UnitPriceWithoutTax"
          xpaths[:line_unit]          = "UnitOfMeasure"
          xpaths[:line_taxes]         = ["TaxesOutputs/Tax","TaxesWithheld/Tax"]
          # relative to invoice_lines/taxes
          xpaths[:tax_id]             = "TaxTypeCode"
          xpaths[:tax_percent]        = "TaxRate"
        elsif format =~ /ubl/
          xpaths[:invoice_number]     = "/Invoice/cbc:ID"
          xpaths[:invoice_date]       = "/Invoice/cbc:IssueDate"
          xpaths[:invoice_total]      = "/Invoice/cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount"
          xpaths[:invoice_import]     = "/Invoice/cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount"
          xpaths[:invoice_due_date]   = "/Invoice/cac:PaymentMeans/cbc:PaymentDueDate"
          xpaths[:seller_taxcode]     = "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:PartyTaxScheme/cbc:CompanyID"
          xpaths[:seller_name]        = "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:PartyName/cbc:Name"
          xpaths[:seller_name2]       = nil
          xpaths[:seller_address]     = [ "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:PostalAddress/cbc:StreetName",
                                          "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:PostalAddress/cbc:BuildingNumber" ] 
          xpaths[:seller_province]    = "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:PostalAddress/cbc:CountrySubentity"
          xpaths[:seller_countrycode] = "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:PostalAddress/cac:Country/cbc:IdentificationCode"
          xpaths[:seller_website]     = "/Invoice/cac:AccountingSupplierParty/cac:Party/cbc:WebsiteURI"
          xpaths[:seller_email]       = "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:Contact/cbc:ElectronicMail"
          xpaths[:seller_cp_city]     = [ "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:PostalAddress/cbc:PostalZone",
                                          "/Invoice/cac:AccountingSupplierParty/cac:Party/cac:PostalAddress/cbc:CityName" ]
          xpaths[:seller_cp_city2]    = nil
          xpaths[:buyer_taxcode]      = "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:PartyTaxScheme/cbc:CompanyID"
          xpaths[:buyer_name]         = "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:PartyName/cbc:Name"
          xpaths[:buyer_name2]        = nil
          xpaths[:buyer_address]      = [ "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:PostalAddress/cbc:StreetName",
                                          "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:PostalAddress/cbc:BuildingNumber" ] 
          xpaths[:buyer_province]     = "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:PostalAddress/cbc:CountrySubentity"
          xpaths[:buyer_countrycode]  = "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:PostalAddress/cac:Country/cbc:IdentificationCode"
          xpaths[:buyer_website]      = "/Invoice/cac:AccountingCustomerParty/cac:Party/cbc:WebsiteURI"
          xpaths[:buyer_email]        = "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:Contact/cbc:ElectronicMail"
          xpaths[:buyer_cp_city]      = [ "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:PostalAddress/cbc:PostalZone",
                                          "/Invoice/cac:AccountingCustomerParty/cac:Party/cac:PostalAddress/cbc:CityName" ]
          xpaths[:buyer_cp_city2]     = nil
          xpaths[:currency]           = "/Invoice/cbc:DocumentCurrencyCode"
        end
        xpaths
      end

    end
  end
end
