# Runs only inside GitHub Actions. Never prints the key, JWT or private API errors.
require 'openssl'
require 'base64'
require 'json'
require 'net/http'
require 'uri'
require 'cgi'

%w[APP_STORE_CONNECT_API_ISSUER_ID APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_API_PRIVATE_KEY APPLE_TEAM_ID].each do |name|
  abort "Missing GitHub secret: #{name}" if ENV.fetch(name, '').strip.empty?
end
raw = ENV.fetch('APP_STORE_CONNECT_API_PRIVATE_KEY').strip.gsub('\\n', "\n")
raw = Base64.strict_decode64(raw) unless raw.include?('-----BEGIN PRIVATE KEY-----')
key = OpenSSL::PKey.read(raw)
abort 'Apple API key must be an EC private key.' unless key.is_a?(OpenSSL::PKey::EC) && key.private?
path = File.join(ENV.fetch('RUNNER_TEMP'), 'LeaveWellSigning.p8')
File.write(path, raw + "\n", mode: 'w', perm: 0600)
b64 = ->(value) { Base64.urlsafe_encode64(value, padding: false) }
header = b64.call(JSON.generate(alg: 'ES256', kid: ENV.fetch('APP_STORE_CONNECT_API_KEY_ID'), typ: 'JWT'))
now = Time.now.to_i
claims = b64.call(JSON.generate(iss: ENV.fetch('APP_STORE_CONNECT_API_ISSUER_ID'), iat: now - 5, exp: now + 600, aud: 'appstoreconnect-v1'))
signing_input = header + '.' + claims
der = key.sign(OpenSSL::Digest::SHA256.new, signing_input)
signature = OpenSSL::ASN1.decode(der).value.map { |number| number.value.to_s(16).rjust(64, '0') }.join
token = signing_input + '.' + b64.call([signature].pack('H*'))
uri = URI('https://api.appstoreconnect.apple.com/v1/apps?filter%5Bname%5D=LeaveWell&limit=100')
request = Net::HTTP::Get.new(uri); request['Authorization'] = 'Bearer ' + token
response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 30) { |http| http.request(request) }
abort "App Store Connect app lookup failed (HTTP #{response.code}). Check the API key permissions." unless response.is_a?(Net::HTTPSuccess)
apps = JSON.parse(response.body).fetch('data').select { |app| app.fetch('attributes').fetch('name').downcase == 'leavewell' }
abort 'Expected exactly one existing App Store Connect app named LeaveWell.' unless apps.length == 1
app = apps.first; bundle = app.fetch('attributes').fetch('bundleId')
abort 'Invalid bundle identifier from Apple.' unless bundle.match?(/\A[A-Za-z0-9.-]+\z/)
File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') { |file| file.puts "bundle_id=#{bundle}"; file.puts "app_id=#{app.fetch('id')}" }
puts "Resolved existing LeaveWell app #{app.fetch('id')} with bundle ID #{bundle}."
team = CGI.escapeHTML(ENV.fetch('APPLE_TEAM_ID'))
File.write(File.join(ENV.fetch('RUNNER_TEMP'), 'LeaveWellExportOptions.plist'), <<~XML)
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>export</string>
    <key>signingStyle</key><string>automatic</string>
    <key>teamID</key><string>#{team}</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
  </dict></plist>
XML
