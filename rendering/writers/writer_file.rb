class WriterFile
  def write(content, directory, filename)
    FileUtils.mkdir_p(directory) unless Dir.exist?(directory)
    file_path = File.join(directory, filename)
    File.write(file_path, content)
    puts "Written to #{file_path}"
  end
end
