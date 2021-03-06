# Methods added to this helper will be available to all templates in the application.
module HaltrHelper

  include Cocoon::ViewHelpers

  # Renders flash messages
  def render_flash_messages
    s = ''
    flash.each do |k,v|
      s << content_tag('div', v, :class => "flash #{k}")
    end
    s.html_safe
  end

  def money(import)
    currency = Money::Currency.new(import.currency)
    currency_symbol = currency.symbol || ""
    if currency.subunit_to_unit == 1
      number_to_currency(import, :unit => currency_symbol, :precision => 0)
    else
      number_to_currency(import, :unit => currency_symbol)
    end
  end

  def line_price(line)
    precision = line.price.to_s.split(".").last.size
    precision = 2 if precision == 1
    currency = Money::Currency.new(line.invoice.currency)
    currency_symbol = currency.symbol || ""
    if currency.subunit_to_unit == 1 and precision == 2
      precision = 0
    end
    number_to_currency(line.price, :unit => currency_symbol, :precision => precision)
  end

  def quantity(q)
    if q.floor == q
      q.to_i
    else
      number_with_delimiter q, :delimiter => ".", :separator => ","
    end
  end

  def notify_pending_requests(project)
    if project.company.companies_with_link_requests.any?
      "<span style='color: #dd6600;'>(#{l(:pending_requests,:i=>project.company.companies_with_link_requests.size)})</span>"
    end
  end

  def self.currency_options_for_select
    opts = []
    Money::Currency.table.each do |id,attributes|
      if attributes[:priority] && attributes[:priority] < 105
        opts << ["#{id.to_s.upcase} - #{attributes[:name]}",id.to_s.upcase]
      end
    end
    opts.compact.sort {|x,y|
      if x[1] == "EUR"
        -1
      elsif y[1] == "EUR"
        1
      elsif x[1] == "USD"
        -1
      elsif y[1] == "USD"
        1
      else
        x[0] <=> y[0]
      end
    }
  end

  def currency_options_for_select
    HaltrHelper.currency_options_for_select
  end

  def help(topic)
    content_tag("span",:class=>'help') do
      image_tag('help.png', :title => l(topic))
    end
  end

  def hide_to_user(action)
    return (Setting.plugin_haltr['hide_unauthorized'] and !User.current.allowed_to?(action,@project))
  end

  def selclass(controller,action)
    if params[:controller].to_s == controller.to_s and
      params[:action].to_s == action.to_s
      "sel"
    end
  end

  # overwrite redmine helper to allow url passed as string
  # (to allow use with new _path helpers)
  def link_to_if_authorized(name, options = {}, html_options = {}, *parameters_for_method_reference)
    if options.is_a?(String)
      options = Rails.application.routes.recognize_path(options, html_options)
    end
    link_to(name, options, html_options, *parameters_for_method_reference) if authorize_for(options[:controller] || params[:controller], options[:action])
  rescue ActionController::RoutingError
  end

  def n19taxcode(taxcode)
    if taxcode and taxcode.size > 9
      taxcode.last(9)
    else
      taxcode
    end
  end

  def iban_for_mandate
    if @client.iban.blank?
      #iban = "#{@client.country_alpha2}______________________"
      iban = "________________________"
    else
      iban = @client.iban
    end
    iban.gsub(/(.)/,'\1 ').gsub(/(. . . .)/,'\1 ').gsub(/ /,'&nbsp;')
  end

end
