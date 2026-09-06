require 'yaml'

def fix_schema(data)
  case data
  when Hash
    if data['type'] == 'array' && !data.key?('items')
      data['items'] = {}
    end
    data.each { |k, v| data[k] = fix_schema(v) }
    data
  when Array
    data.map { |item| fix_schema(item) }
  else
    data
  end
end

input = ARGV[0] || 'yaml_examples/openapi.yaml'

data = YAML.load_file(input)
fixed = fix_schema(data)
File.write(input, fixed.to_yaml)

puts "Fixed schema saved to #{input} (in-place)"
