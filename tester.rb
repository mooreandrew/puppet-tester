Dir.chdir("puppet-test-env")

# Function to start a vagrant server
def vagrant_command(command)

  output = []

  r, io = IO.pipe # For system command
  r2, io2 = IO.pipe # For exitcode

  fork do
    system("#{command}", out: io, err: :out)
    io2.puts($?.exitstatus.to_s)
  end
  io.close
  io2.close

  r.each_line{|l| puts l; output << l.chomp}
  exitcode = r2.read.gsub("\n", '').gsub('"', '').to_i

  return {"output" => output.join("\n"), "exitcode" => exitcode }
end


servers = []
# Generate YAML Files for all Hiera Profiles
File.open('servers.yaml', 'w') { |file| file.write("servers:") }
ip = 50;
Dir.foreach('../puppet-control/hiera/roles') do |item|
  next if item == '.' or item == '..'
  ip = ip + 1
  File.open('servers.yaml', 'a') { |file| file.write("\n  - #{item.sub('.yaml', '')}.home.net:\n      environment: development\n      clone: false\n      ip: 172.16.42.#{ip.to_s}") }
  servers << item.sub('.yaml', '')
end

# start the puppet-master server
vagrant_command('vagrant up puppet-master.home.net');

#TODO: The server could already be up, so we need to SSH in and update r10k

test_results = []

# Test the servers
servers.each do |profile_name|
  result = vagrant_command("vagrant up #{profile_name}.home.net")
  puts "#{profile_name} returned: #{result['exitcode']}";
  result = vagrant_command("vagrant destroy #{profile_name}.home.net --force")
  test_results << {"profile" => profile_name, "result" => result }
end

File.open('results.json', 'w') { |file| file.write(test_results.to_json) }
