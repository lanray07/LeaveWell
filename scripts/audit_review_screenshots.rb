require 'openssl'
require 'base64'
require 'json'
require 'net/http'
require 'uri'

abort 'Run this script only in GitHub Actions.' unless ENV['GITHUB_ACTIONS'] == 'true'
app_id = '6818834817'
raw = ENV.fetch('APP_STORE_CONNECT_API_PRIVATE_KEY').strip.gsub('\\n', "\n")
raw = Base64.strict_decode64(raw) unless raw.include?('-----BEGIN PRIVATE KEY-----')
key = OpenSSL::PKey.read(raw)
b64 = ->(value) { Base64.urlsafe_encode64(value, padding: false) }
header = b64.call(JSON.generate(alg: 'ES256', kid: ENV.fetch('APP_STORE_CONNECT_API_KEY_ID'), typ: 'JWT'))
now = Time.now.to_i
claims = b64.call(JSON.generate(iss: ENV.fetch('APP_STORE_CONNECT_API_ISSUER_ID'), iat: now - 5, exp: now + 600, aud: 'appstoreconnect-v1'))
input = header + '.' + claims
der = key.sign(OpenSSL::Digest::SHA256.new, input)
signature = OpenSSL::ASN1.decode(der).value.map { |number| number.value.to_s(16).rjust(64, '0') }.join
token = input + '.' + b64.call([signature].pack('H*'))
api = lambda do |method, path, body = nil|
  uri = URI('https://api.appstoreconnect.apple.com' + path)
  request = { get: Net::HTTP::Get, patch: Net::HTTP::Patch, post: Net::HTTP::Post }.fetch(method).new(uri)
  request['Authorization'] = 'Bearer ' + token
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 30) { |http| http.request(request) }
  unless response.is_a?(Net::HTTPSuccess)
    errors = JSON.parse(response.body).fetch('errors', []).map { |error| error['code'] }.compact rescue []
    abort "Apple draft operation failed: HTTP #{response.code}; #{errors.join(', ')}"
  end
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end
app = api.call(:get, "/v1/apps/#{app_id}").fetch('data')
abort 'Unexpected app' unless app.dig('attributes','bundleId') == 'com.LeaveWell.app'
versions = api.call(:get, "/v1/apps/#{app_id}/appStoreVersions?limit=50").fetch('data')
version = versions.find { |v| v.dig('attributes','platform') == 'IOS' && v.dig('attributes','versionString') == '1.0' }
abort 'Expected iOS 1.0' unless version
locales = api.call(:get, "/v1/appStoreVersions/#{version.fetch('id')}/appStoreVersionLocalizations?limit=200").fetch('data')
counts = Hash.new(0)
locales.each do |locale|
  name = locale.dig('attributes','locale')
  assets = api.call(:get, "/v1/appStoreVersionLocalizations/#{locale.fetch('id')}/appScreenshotSets?include=appScreenshots&limit=50&limit%5BappScreenshots%5D=10")
  screenshots = assets.fetch('included', []).to_h { |item| [item.fetch('id'),item] }
  assets.fetch('data').each do |set|
    display = set.dig('attributes','screenshotDisplayType')
    set.dig('relationships','appScreenshots','data').to_a.each do |item|
      row = screenshots.fetch(item.fetch('id'))
      state = row.dig('attributes','assetDeliveryState','state') || 'MISSING'
      counts[[display,state]] += 1
      puts "#{name} #{display} #{row.dig('attributes','fileName')} #{state}" unless state == 'COMPLETE'
    end
  end
end
counts.sort.each { |(display,state),count| puts "#{display} #{state}: #{count}" }
