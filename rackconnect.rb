require 'net/http'
require 'json'

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
    url = "https://#{rackspace[:region]}.api.rackconnect.rackspace.com"
    urn = '/v1/automation_status/details'
    uri = URI.parse(URI.join(url, urn))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.get(uri.request_uri)

    ## Raise an exception to be caught if the server returns a 500 error
    fail 'server error' if response.code.to_i >= 500

    return unless response.code == '200'
    json_response = JSON.parse(response.body)

    rackconnect[:enabled] = true

    return unless json_response.key? 'automation_status'
    rackconnect[:automation_status] = json_response['automation_status']
  end

  def xenstore_api
    xenstore_cmd = '/usr/bin/xenstore-read'
    rackconnect_metadata = 'vm-data/user-metadata/rackconnect_automation_status'

    res = shell_out("#{xenstore_cmd} #{rackconnect_metadata}")

    return unless res.stderr.empty?
    rackconnect[:enabled] = true

    ## Command returns "\"DEPLOYED\"\n" so lets remove the extra
    automation_status = res.stdout.chomp.gsub('"', '')
    rackconnect[:automation_status] = automation_status
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
