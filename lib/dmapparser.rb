require './lib/tagdefinitions'
require './lib/dmapconverter'
require 'stringio'

class DMAPParser
  
  def self.generate name, values
    name = name.to_s
    pairingstring = ""
    values.each do |key, value|
      pairingstring += "%s%s%s" % [key.to_s, [value.length].pack('N'), value]
    end
    header = name + [pairingstring.length].pack('N')
    header + pairingstring
  end
  
  def self.parse response 
    return nil if response.nil? or response.length < 8
    response = StringIO.new response
    ret = TagContainer.new 
    key = response.read(4).to_sym
    ret.type = Types.find {|a| a.tag == key}
    response.read 4 # ignore length for now
    ret.value = parse_container response
    p ret
    ret
  end
  
  private
  
  def self.parse_container response 
    values = []
    
    while !response.eof?
      key = response.read(4).to_sym
      length = parseint response.read 4
      data = response.read length
      tag = Types.find {|a| a.tag == key}
      #puts "#{key} (#{length}): #{data.inspect}"
      p data if !tag.nil? and tag.tag == :msas
      values << if !tag.nil?
         case tag.type
        when :container
          TagContainer.new tag, parse_container(StringIO.new(data))
        when :byte
          Tag.new tag, DMAPConverter.bin_to_byte(data)
        when :uint16, :short
          Tag.new tag, DMAPConverter.bin_to_short(data)
        when :uint32
          Tag.new tag, DMAPConverter.bin_to_int(data)
        when :uint64                 
          Tag.new tag, DMAPConverter.bin_to_long(data)
        when :bool                   
          Tag.new tag, DMAPConverter.bin_to_bool(data)
        when :hex
          Tag.new tag, DMAPConverter.bin_to_hex(data)
        when :string
          Tag.new tag, data
        when :date 
          Tag.new tag, Time.at(DMAPConverter.bin_to_int(data))
        when :version
          Tag.new tag, DMAPConverter.bin_to_version(data)
        else
          puts "Unknown type #{tag.type}"
          Tag.new tag, parseunknown(data)
        end
      else
        #puts "Unknown key #{key}"
        Tag.new TagDefinition.new(key,:unknown,'unknown'), parseunknown(data)
      end

    end
    
    values
  

  end
   
  def self.parseunknown data 
    if data =~ /[^\x20-\x7e]/    
      if data.length == 1 
        DMAPConverter.bin_to_byte(data)
      elsif data.length == 4 
        DMAPConverter.bin_to_int(data)
      elsif data.length == 8
        DMAPConverter.bin_to_long(data)
      else
        data
      end
    else 
      data
    end
  end
  
  def self.parseversion data
    data.unpack('nCC').join '.'
  end
  
  def self.parseshort data
    data.unpack('n').first
  end
  
  def self.parseint data
    data.unpack('N').first
  end
  
  def self.parsehex data
    data.bytes.inject("") {|ret, b| ret += "%02x" % b}
  end
  
  def self.parsebyte data 
    #TODO
  end
end