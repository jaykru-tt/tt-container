#!/usr/bin/env ruby

require 'pathname' # Provides a nicer way to handle file paths
require 'fileutils' # Not strictly needed here, but often useful with files
require 'optparse' # For command-line option parsing
require 'securerandom' # For potentially better random selection, though sample is fine too

# --- Configuration ---
# Base directory inside the container where files/dirs will be mapped
CONTAINER_BASE_PATH = "/home/j".freeze
# Default container name for attaching
DEFAULT_CONTAINER_NAME = "jtainer-new".freeze
# Path to dictionary file
DICTIONARY_PATH = "/usr/share/dict/words".freeze # Adjust if needed

# --- Options ---
options = { attach: false }
OptionParser.new do |opts|
  opts.banner = "Usage: dock.rb [options]"
  opts.on("-a", "--attach", "Attach to the default container (#{DEFAULT_CONTAINER_NAME}) if running") do |a|
    options[:attach] = a
  end
end.parse!

# --- Helper Functions ---
def generate_random_name(dict_path)
  unless File.exist?(dict_path)
    puts "Error: Dictionary file not found at #{dict_path}. Cannot generate random name."
    # Fallback or exit? Let's fallback for now, but this might not be ideal.
    return "#{DEFAULT_CONTAINER_NAME}-#{SecureRandom.hex(3)}"
  end
  words = File.readlines(dict_path).map(&:strip).reject { |w| w.length < 4 || w.length > 8 || w.include?("'") || /\A[A-Z]/.match?(w) }
  if words.length < 2
     puts "Warning: Dictionary file #{dict_path} has too few suitable words. Using fallback name."
     return "#{DEFAULT_CONTAINER_NAME}-#{SecureRandom.hex(3)}"
  end
  "#{words.sample}-#{words.sample}"
end

# --- Find Potential Items (Files or Directories, Not Symlinks) ---
home_dir = Pathname.new(Dir.home)
items = [] # Now holds files or directories
blacklist = []
dots = [/\.ssh/, /\.envrc\.template/, /api/, /hostname/]

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
image_name = "jaykrutt/tt-dev"
if options[:attach]
  # --- Attach Mode (-a) ---
  container_name = DEFAULT_CONTAINER_NAME
  attach_cmd = "sudo docker attach #{container_name}"
  inspect_running = `sudo docker ps --filter "name=^/#{container_name}$" --format "{{.Names}}"`.strip

  if !inspect_running.empty?
    puts "Attaching to running container '#{container_name}'..."
    exec(attach_cmd) # exec replaces the current process
  else
    puts "Error: Container '#{container_name}' not found or not running. Cannot attach."
    exit 1 # Exit if attach was requested but container isn't running
  end
else
  # --- Start New Container Mode --- 
  container_name = generate_random_name(DICTIONARY_PATH)
  puts "Generating random container name: #{container_name}"
 
  # Build the docker run command
  command = ["sudo docker run --name #{container_name} -it --rm"]
  command += volume_args
  command += ["-v", "/dev/hugepages-1G:/dev/hugepages-1G"]
  command += ["--device", "/dev/tenstorrent"]
  command += [image_name]
  command_str = command.join(" ")

  puts "Starting new container '#{container_name}'..."
  # No need to check/remove stopped containers with random names
  puts "Executing: #{command_str}"
  system(command_str)
end

# Check if the container exists and is running
# attach_cmd = "sudo docker attach #{container_name}" # Build later
# inspect_running = `sudo docker ps --filter "name=^/#{container_name}$" --format "{{.Names}}"`.strip # Check later
