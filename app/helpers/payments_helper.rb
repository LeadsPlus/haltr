module PaymentsHelper

  def invoices_for_select
    if @payment.invoice
      conditions = ["(clients.project_id = ? and state != 'closed') OR invoices.id=?", @project, @payment.invoice]
    else
      conditions = ["clients.project_id = ? and state != 'closed'", @project]
    end
    IssuedInvoice.find(:all, :order => 'number DESC', :include => 'client', :conditions => conditions).collect {|c| [ "#{c.number} #{c.total.to_s.rjust(10).gsub(' ','_')}€ #{c.client}", c.id ] }
  end


end
