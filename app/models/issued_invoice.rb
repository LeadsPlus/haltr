class IssuedInvoice < InvoiceDocument

  unloadable

  belongs_to :invoice_template
  validates_presence_of :number, :due_date
  validate :number_must_be_unique_in_project
  validate :invoice_must_have_lines

  before_validation :set_due_date
  before_save :update_import
  before_save :update_status, :unless => Proc.new {|invoicedoc| invoicedoc.state_changed? }
  after_create :create_event

  # new sending sent error discarded closed
  state_machine :state, :initial => :new do
    before_transition do |invoice,transition|
      unless Event.automatic.include?(transition.event.to_s)
        Event.create(:name=>transition.event.to_s,:invoice=>invoice,:user=>User.current)
      end
    end
    event :manual_send do
      transition [:new,:sending,:error,:discarded] => :sent
    end
    event :queue do
      transition :new => :sending
    end
    event :requeue do
      transition [:closed,:sending,:sent,:error,:discarded] => :sending
    end
    event :success_sending do
      transition [:sending,:error] => :sent
    end
    event :mark_unsent do
      transition [:sent,:closed,:error,:discarded] => :new
    end
    event :error_sending do
      transition :sending => :error
    end
    event :close do
      transition [:sent] => :closed
    end
    event :discard_sending do
      transition [:error,:sending] => :discarded
    end
    event :paid do
      transition [:sent] => :closed
    end
    event :unpaid do
      transition [:closed] => :sent
    end
    event :bounced do
      transition [:sent] => :discarded
    end
  end

  def sent?
    state?(:sent) or state?(:closed)
  end

  def self.find_due_dates(project)
    find_by_sql "SELECT due_date, invoices.id, count(*) AS invoice_count FROM invoices, clients WHERE type='IssuedInvoice' AND client_id = clients.id AND clients.project_id = #{project.id} AND state = 'sent' AND bank_account AND payment_method=#{Invoice::PAYMENT_DEBIT} GROUP BY due_date ORDER BY due_date DESC"
  end

  def label
    if self.draft
      l :label_draft
    else
      l :label_invoice
    end
  end

  def to_label
    "#{number}"
  end

  def self.find_not_sent(project)
    find :all, :include => [:client], :conditions => ["clients.project_id = ? and state = 'new' and draft != ?", project.id, 1 ]
  end

  def total_paid
    paid_amount=0
    self.payments.each do |payment|
      paid_amount += payment.amount.cents
    end
    Money.new(paid_amount,currency)
  end

  def unpaid
    total - total_paid
  end

  def paid?
    unpaid.cents <= 0
  end

  def self.candidates_for_payment(payment)
    # order => older invoices to get paid first
    #TODO: add withholding_tax
    find :all, :conditions => ["round(import_in_cents*(1+tax_percent/100)) = ? and date <= ? and state != 'closed'", payment.amount_in_cents, payment.date], :order => "due_date ASC"
  end

  def past_due?
    !state?(:closed) && due_date && due_date < Date.today
  end

  def md5
    #TODO: check #2451 to store md5 on invoice.
    self.events.collect {|e| e unless e.final_md5.blank? }.compact.sort.last.final_md5 rescue nil
  end

  def can_be_exported?
    ExportChannels.channel(client.invoice_format) != nil
  end

  def past_due?
    #TODO
    false
  end

  def self.last_number(project)
    i = IssuedInvoice.last(:order => "number", :include => [:client], :conditions => ["clients.project_id=? AND draft=?",project.id,false])
    i.number if i
  end

  def self.next_number(project)
    number = self.last_number(project)
    if number.nil?
      a = []
      num = 0
    else
      a = number.split('/')
      num = number.to_i
    end
    if a.size > 1
      a[1] =  sprintf('%03d', a[1].to_i + 1)
      return a.join("/")
    else
      return num + 1
    end
  end

  protected

  def update_status
    if paid?
      paid
    else
      unpaid
    end
    return true # always continue saving
  end

  def create_event
    Event.create(:name=>'new',:invoice=>self,:user=>User.current)
  end

  def number_must_be_unique_in_project
    return if self.client.nil?
    return if !self.new_record? && !self.number_changed?
    if self.client.project.clients.collect {|c| c.issued_invoices }.flatten.compact.collect {|i| i.number unless i.id == self.id}.include? self.number
      errors.add(:base, ("#{l(:field_number)} #{l(:taken,:scope=>'activerecord.errors.messages')}"))
    end
  end

  def invoice_must_have_lines
    if invoice_lines.empty? or invoice_lines.all? {|i| i.marked_for_destruction?}
      errors.add(:base, "#{l(:label_invoice)} #{l(:must_have_lines)}")
    end
  end

end