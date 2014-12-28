require 'net/http'
require 'mixlib/shellout'

Ohai.plugin(:Rackconnect) do
  provides 'rackspace/rackconnect'

  depends 'rackspace'

  def pub_cloud?
    rackspace != nil
  end

  def create_objects
    rackconnect Mash.new
    rackconnect[:enabled] = false
  end

  def rackconnect_api
    uri = URI.parse("https://#{rackspace[:region]}.api.rackconnect.rackspace.com/v1/automation_status/details")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.get(uri.request_uri)

    if response.code == '200'
      json_response = JSON.parse(response.body)

      rackconnect[:enabled] = true
      if json_response.key? 'automation_status'
        rackconnect[:automation_status] = json_response['automation_status']
      end
    end
  end

  def xenstore_api
    xenstore_cmd = '/usr/bin/xenstore-read'
    rackconnect_metadata = 'vm-data/user-metadata/rackconnect_automation_status'

    cmd = Mixlib::ShellOut.new("#{xenstore_cmd} #{rackconnect_metadata}")
    cmd.run_command
    if cmd.stderr == ''
      rackconnect[:enabled] = true

      ## Command returns "\"DEPLOYED\"\n" so lets remove the extra
      automation_status = cmd.stdout.chomp.gsub('"', '')
      rackconnect[:automation_status] = automation_status
    end
  end

  collect_data(:linux) do

    ## No support for dedicated and private clouds
    if pub_cloud?
      create_objects
      begin
        rackconnect_api
      rescue
        xenstore_api
      end
      rackspace[:rackconnect] = rackconnect
    end
  end
end
