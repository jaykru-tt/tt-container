#!/usr/bin/env ruby

require 'pathname' # Provides a nicer way to handle file paths
require 'fileutils' # Not strictly needed here, but often useful with files
require 'optparse' # For command-line option parsing
require 'securerandom' # For potentially better random selection, though sample is fine too

# --- Configuration ---
# Base directory inside the container where files/dirs will be mapped
CONTAINER_BASE_PATH = "/home/j/".freeze

# --- Options ---
options = { attach: false }
OptionParser.new do |opts|
  opts.banner = "Usage: dock.rb"
  end
end.parse!

# --- Find Potential Items (Files or Directories, Not Symlinks) ---
home_dir = Pathname.new(Dir.home)
items = [] # Now holds files or directories
blacklist = []
dots = [/\.ssh/, /\.envrc\.template/, /api/, /hostname/, /claude/, /history/]

begin
  # Iterate over items directly in the home directory
  home_dir.children.each do |path|
    # Check conditions:
    # 1. Is it a file OR a directory? (path.file? || path.directory?)
    # 2. Is it NOT a symbolic link?   !path.symlink?
    # 3. Is its name NOT starting with '.' (not hidden)? !path.basename.to_s.start_with?('.')
    if (path.file? || path.directory?) && !path.symlink? && !path.basename.to_s.start_with?('.') && !blacklist.any? { |black| path.basename.to_s.start_with?(black) }
      items << path
    end
    if dots.any? { |dot| dot.match?(path.basename.to_s) }
      items << path
    end
  end
rescue Errno::EACCES => e
   puts "Permission Error: Cannot access items in #{home_dir}. Check permissions."
   puts "Details: #{e.message}"
   exit 1
rescue Errno::ENOENT
  puts "Error: Home directory not found at #{home_dir}"
  exit 1
rescue => e
  puts "An error occurred while listing items: #{e.message}"
  exit 1
end

# --- Handle No Items ---
if items.empty?
  puts "No non-hidden files or directories (excluding symlinks) found directly in your home directory (#{home_dir})."
  exit 0
end

puts "\nSelected items to map:"
volume_args = items.map do |host_path|
  container_path = File.join(CONTAINER_BASE_PATH, host_path.basename.to_s)
  item_type = host_path.directory? ? '[Dir]' : '[File]'
  puts "  - #{host_path.basename} #{item_type} -> #{container_path}"
  # Quote the paths properly for the shell command using single quotes
  # host_path.to_s ensures we get the string representation
  "-v '#{host_path.to_s}:#{container_path}'"
end

# --- Main Logic: Attach or Start ---
image_name = ARGV[0] || "jaykru-tt/dev"
# --- Attach Mode (-a) ---
container_name = "jtainer"
attach_cmd = "sudo docker attach #{container_name}"
inspect_running = `sudo docker ps --filter "name=^/#{container_name}$" --format "{{.Names}}"`.strip

if !inspect_running.empty?
  puts "Attaching to running container '#{container_name}'..."
  exec(attach_cmd) # exec replaces the current process
else
  puts "Container '#{container_name}' not found or not running. Starting a new one."
  puts "Starting container #{container_name}"
 
  # Build the docker run command
  command = ["sudo docker run --name #{container_name} -it"]
  command += ["--detach-keys=\"ctrl-^\""]
  command += volume_args
  command += ["-v", "/dev/hugepages-1G:/dev/hugepages-1G"]
  command += ["--device", "/dev/tenstorrent"]
  command += [image_name]
  command_str = command.join(" ")

  puts "Starting new container '#{container_name}'..."
  puts "Executing: #{command_str}"
  system(command_str)
end
