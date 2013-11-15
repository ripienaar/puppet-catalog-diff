require 'erb'
require 'json'
desc "Build final report"
task :build do
  @nodes = load_json("lastrun.json")
  build_file("Report.md")
end

def load_json(filename)
  cputs "Loading json file #{filename}"
  JSON.parse( IO.read(filename) )
end

def build_file(filename)
  template_path = "./templates/report.erb"
  target_dir = "."
  target_path = "#{target_dir}/#{filename}"
  FileUtils.mkdir(target_dir) unless File.directory?(target_dir)
  if File.file?(template_path)
    cputs "Building #{target_path}..."
    File.open(target_path,'w') do |f|
      template_content = ERB.new(File.read(template_path)).result
      f.write(template_content)
    end
  else
    cputs "No source template found: #{template_path}"
  end
end

def cputs(string)
  puts "\033[1m#{string}\033[0m"
end

