class Client < ActiveRecord::Base

  unloadable

  has_many :invoices ##, :dependent => :nullify ## NO ESBORRAR CLIENTS
  has_many :people

  # TODO: only in Redmine
  belongs_to :project, :include => true

  validates_presence_of :project_id, :name, :taxcode, :currency, :language, :invoice_format
#  validates_uniqueness_of :name, :scope => :project_id
  validates_uniqueness_of :taxcode, :scope => :project_id
  validates_numericality_of :bank_account, :unless => Proc.new { |c| c.bank_account.blank? }
  validates_length_of :bank_account, :within => 16..40, :unless => Proc.new { |c| c.bank_account.blank? }
#  validates_length_of :name, :maximum => 30
#  validates_format_of :identifier, :with => /^[a-z0-9\-]*$/
  validates_inclusion_of :currency, :in  => Money::Currency::TABLE.collect {|k,v| v[:iso_code] }
  validates_length_of :taxcode, :maximum => 20

  def initialize(attributes=nil)
    super
    self.currency ||= Money.default_currency.iso_code
    self.invoice_format ||= ExportChannels.default
    self.language ||= "es"
  end

  # Masks db value with default if db value is deprecated
  def invoice_format
    format = read_attribute(:invoice_format)
    format = ExportChannels.default unless ExportChannels.available? format
    return format
  end

  def currency=(v)
    write_attribute(:currency,v.upcase)
  end

  def bank_invoices(due_date)
    IssuedInvoice.find :all, :conditions => ["client_id = ? and state = 'sent' and draft != ? and payment_method=#{Invoice::PAYMENT_DEBIT} and due_date = ?", self, 1, due_date ]
  end

  def bank_invoices_total(due_date)
    a = Money.new 0
    bank_invoices(due_date).each { |i| a = i.total + a }
    a
  end

  def to_label
    name
  end

  alias :to_s :to_label

  def invoice_templates
    self.invoices.find(:all,:conditions=>["type=?","InvoiceTemplate"])
  end

  def invoice_documents
    self.invoices.find(:all,:conditions=>["type=?","IssuedInvoice"])
  end

  def issued_invoices
    self.invoices.find(:all,:conditions=>["type=?","IssuedInvoice"])
  end

  def address
    "#{address1}\n#{address2}"
  end

end
