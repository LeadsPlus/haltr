# Receives an email extract its attachments and determines if it is a bounced
# mail for a sent invoice, or an incoming invoice.
#
# Assuming that mail is a file with raw email message,
# you can test it from command line with:
#
#  bundle exec rails runner -e development "InvoiceReceiver.receive(File.read('/path/to/mail'))"
#
class HaltrMailHandler < MailHandler # < ActionMailer::Base
  unloadable

  require "rexml/document"
  require "tempfile"

  def receive(email)
    invoices = []
    if email.multipart?
      raw_invoices = attached_invoices(email)

      if email.to and email.to.include? "noreply@b2brouter.net"
        # bounced invoice
        if raw_invoices.size == 1 # we send only 1 invoice on each mail
          logger.info "Bounced invoice mail received (#{raw_invoices.first.filename})"
          process_bounced_file(raw_invoices.first)
        else
          logger.info "Discarding bounce mail with != 1 (#{raw_invoices.size}) invoices attached (#{raw_invoices.collect {|i| i.filename}.join(',')})"
        end
      else
        # incoming invoices (PDF/XML)
        logger.info "Incoming invoice mail with #{raw_invoices.size} attached invoices"
        company_found=false
        email['to'].to_s.scan(/[\w.]+@[\w.]+/).each do |to|
          company = Company.find_by_taxcode(to.split("@").first)
          if company
            from = email['from'].to_s.scan(/[\w.]+@[\w.]+/).first
            company_found=true
            raw_invoices.each do |raw_invoice|

              # discard invoice if md5 exists
              tmpfile = Tempfile.new("invoice.xml", :encoding => 'ascii-8bit')
              tmpfile.write(raw_invoice.read.chomp)
              tmpfile.close
              md5 = `md5sum #{tmpfile.path} | cut -d" " -f1`.chomp
              if found_invoice = Invoice.find_by_md5(md5)
                invoices << found_invoice
                logger.error "Discarding repeated invoice with md5 #{md5}. Invoice.id = #{found_invoice.id}"
              else
                if raw_invoice.content_type =~ /xml/
                  invoices << Invoice.create_from_xml(raw_invoice,company,from,md5,'email')
                  #TODO rescue and bounce?
                elsif raw_invoice.content_type =~ /pdf/
                  invoices << process_pdf_file(raw_invoice,company,from,md5,'email')
                else
                  logger.info "Discarding #{raw_invoice.filename} on incoming mail (#{raw_invoice.content_type})"
                end
              end
            end
            break #TODO: allow incoming invoice to several companies?
          end
        end
        unless company_found
          logger.info "Discarding email for #{email['to'].to_s} (Can't find company with taxcode #{email['to'].to_s.split("@").first})"
        end
      end
    else
      # we do not process emails without attachments
      logger.info "email has no attachments"
    end
    return invoices
  end

  def process_pdf_file(raw_invoice,company,from="",md5,transport)
    @company = company

    # PDF attachment has #<Encoding:ASCII-8BIT>
    # without force_encoding write halts with: "\xFE" from ASCII-8BIT to UTF-8
    attachment = raw_invoice.read.chomp
    attachment.force_encoding('UTF-8')
    tmpfile = Tempfile.new "pdf"
    tmpfile.write(attachment)
    tmpfile.close

    text_file = Tempfile.new "txt"
    cmd = "pdftotext -f 1 -l 1 -layout #{tmpfile.path} #{text_file.path}"
    out = `#{cmd} 2>&1`
    raise "Error with pdftotext <br /><pre>#{cmd}</pre><pre>#{out}</pre>" unless $?.success?
    ds = Estructura::Invoice.new(text_file.read.chomp,:tax_id=>@company.taxcode)
    text_file.close
    text_file.unlink
    ds.apply_rules
    ds.fix_amounts
    client = Client.find(:all, :conditions => ["project_id = ? AND taxcode = ?",@company.project_id,ds.tax_identification_number]).first
    ri = ReceivedInvoice.new(:number          => ds.invoice_number,
                            :client          => client,
                            :date            => ds.issue_date,
                            :import          => ds.total_amount.to_money,
#                            :currency        => ds.currency,
#                            :tax_percent     => ds.tax_rate,
#                            :subtotal        => ds.invoice_subtotal.to_money,
#                            :withholding_tax => ds.withholding_tax.to_money,
                            :due_date        => ds.due_date,
                            :project         => @company.project)

    ri.md5 = `md5sum #{tmpfile.path} | cut -d" " -f1`.chomp
    ri.transport=transport
    ri.from=from
    ri.invoice_format = "pdf"
    ri.original = raw_invoice.read.chomp
    ri.file_name = raw_invoice.filename
    ri.save!
    return ri
  end

  private

  def attached_invoices(email)
    invoices = []
    email.attachments.each do |attachment|
      invoices << attachment if attachment.content_type =~ /xml/ || attachment.content_type =~ /pdf/
    end
    email.parts.each do |part|
      attached_mail = nil
      attached_mail = TMail::Mail.parse(part.body) if email.attachment?(part) rescue nil
      next if attached_mail.nil? || attached_mail.attachments.nil?
      attached_mail.attachments.each do |attachment|
        invoices << attachment if attachment.content_type =~ /xml/ || attachment.content_type =~ /pdf/
      end
    end
    invoices
  end

end
