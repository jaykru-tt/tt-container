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
end.parse!

image_name = ARGV[0] || "jaykrutt/tt-dev"
container_name = "jtainer"
inspect_running = `docker ps --filter "name=#{container_name}" --format "{{.Names}}"`.strip

# touch .zsh_history, needs to exist for this container
`touch #{Dir.home}/.zsh_history`

if !inspect_running.empty?
  puts "Attaching to running container '#{container_name}'..."
  exec("docker exec -it --detach-keys=\"ctrl-^\" #{container_name} bash")
else
  puts "Container '#{container_name}' not found or not running. Starting a new one."
  command = ["docker run -d --name #{container_name}"]
  command += ["--detach-keys=\"ctrl-^\""]
  command += ["-v", "#{Dir.home}/dotfiles:/#{CONTAINER_BASE_PATH}/dotfiles"]
  command += ["-v", "#{Dir.home}:#{CONTAINER_BASE_PATH}/host"]
  command += ["--device", "/dev/tenstorrent"]
  command += [image_name, "tail", "-f", "/dev/null"] # to keep the container running after shell exit
  command_str = command.join(" ")
  success = system(command_str)
  abort("Failed to start container '#{container_name}'.") unless success
  puts "Container '#{container_name}' started. Opening shell..."
  exec("docker exec -it --detach-keys=\"ctrl-^\" #{container_name} bash")
end
