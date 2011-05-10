class ExportChannels 

  unloadable

  # TODO: move this settings to activerecord
  def self.available
    {
      'paper'         => { :format=>nil,          :channel=>nil} ,
      'ublinvoice_20' => { :format=>'ubl21', :channel=>'free_ubl'},
      'facturae_30'   => { :format=>'facturae30', :channel=>'free_xml'},
      'facturae_31'   => { :format=>'facturae31', :channel=>'free_xml'},
      'facturae_32'   => { :format=>'facturae32', :channel=>'free_xml'},
      'signed_pdf'    => { :format=>'facturae32', :channel=>'free_pdf'},
      'aoc'           => { :format=>'facturae30', :channel=>'free_aoc', :private=>true},
      'aoc31'         => { :format=>'facturae31', :channel=>'free_aoc', :private=>true},
      'aoc32'         => { :format=>'facturae32', :channel=>'free_aoc', :private=>true}
    }
  end

  def self.default
    'signed_pdf'
  end

  def self.available?(id)
    available.include? id
  end

  def self.format(id)
    available[id][:format] if available? id
  end

  def self.channel(id)
    available[id][:channel] if available? id
  end

  def self.for_select
    available.collect {|k,v|
      unless User.current.admin? or User.current.allowed_to?(:use_restricted_channels, User.current.project)
        next if v[:private]
      end
      [ I18n.t(k), k ]
    }.compact.sort {|a,b| a[1] <=> b[1] }
  end

  def self.path(id)
    part1 = "#{Setting.plugin_haltr['export_channels_path']}/#{self.channel(id)}"
  end
end

