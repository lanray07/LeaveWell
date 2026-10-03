# Only selects a processed build and adds the app to an EXISTING unsubmitted draft.
# Never sets submitted, creates a submission, removes items, or prints credentials.
require 'openssl'
require 'base64'
require 'json'
require 'net/http'
require 'uri'

abort 'Run this script only in GitHub Actions.' unless ENV['GITHUB_ACTIONS'] == 'true'
app_id = '6818834817'
build_id = ENV.fetch('LEAVEWELL_BUILD_ID')
build_number = ENV.fetch('LEAVEWELL_BUILD_NUMBER')
abort 'Invalid build ID.' unless build_id.match?(/\A[0-9a-f-]{36}\z/)
abort 'Invalid build number.' unless build_number.match?(/\A\d+\z/)
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
abort 'Unexpected app identity.' unless app.dig('attributes', 'bundleId') == 'com.LeaveWell.app'
build = api.call(:get, "/v1/builds/#{build_id}?include=app,preReleaseVersion")
abort 'Unexpected build owner/number/state.' unless build.dig('data', 'relationships', 'app', 'data', 'id') == app_id &&
  build.dig('data', 'attributes', 'version') == build_number && build.dig('data', 'attributes', 'processingState') == 'VALID' &&
  build.dig('data', 'attributes', 'expired') == false
prerelease = build.fetch('included', []).find { |resource| resource['type'] == 'preReleaseVersions' }
abort 'Expected iOS version 1.0.' unless prerelease&.dig('attributes', 'version') == '1.0' && prerelease&.dig('attributes', 'platform') == 'IOS'
versions = api.call(:get, "/v1/apps/#{app_id}/appStoreVersions?limit=50").fetch('data')
matches = versions.select { |version| version.dig('attributes', 'versionString') == '1.0' && version.dig('attributes', 'platform') == 'IOS' }
abort 'Expected one iOS 1.0 version.' unless matches.length == 1
version = matches.first
state = version.dig('attributes', 'appVersionState') || version.dig('attributes', 'appStoreState')
abort "Version is not an editable draft: #{state}." unless %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW].include?(state)
drafts = api.call(:get, "/v1/apps/#{app_id}/reviewSubmissions?limit=50").fetch('data').select do |draft|
  draft.dig('attributes', 'state') == 'READY_FOR_REVIEW' && draft.dig('attributes', 'submittedDate').nil?
end
abort 'Expected exactly one existing unsubmitted draft.' unless drafts.length == 1
draft_id = drafts.first.fetch('id')
items = api.call(:get, "/v1/reviewSubmissions/#{draft_id}/items?include=appStoreVersion&limit=50").fetch('data')
linked_app = items.find { |item| item.dig('relationships', 'appStoreVersion', 'data', 'id') == version.fetch('id') }
selected = api.call(:get, "/v1/appStoreVersions/#{version.fetch('id')}/relationships/build").dig('data', 'id')
if selected != build_id
  abort 'Remove the app from its review draft before changing its build.' if linked_app || state != 'PREPARE_FOR_SUBMISSION'
  api.call(:patch, "/v1/appStoreVersions/#{version.fetch('id')}/relationships/build", data: { type: 'builds', id: build_id })
end
verified = api.call(:get, "/v1/appStoreVersions/#{version.fetch('id')}/build").fetch('data')
abort 'Build selection read-back did not match.' unless verified.fetch('id') == build_id
puts "Selected and verified LeaveWell 1.0 (#{build_number})."
unless linked_app
  api.call(:post, '/v1/reviewSubmissionItems', data: { type: 'reviewSubmissionItems', relationships: {
    reviewSubmission: { data: { type: 'reviewSubmissions', id: draft_id } },
    appStoreVersion: { data: { type: 'appStoreVersions', id: version.fetch('id') } }
  } })
end
items = api.call(:get, "/v1/reviewSubmissions/#{draft_id}/items?include=appStoreVersion&limit=50").fetch('data')
draft = api.call(:get, "/v1/reviewSubmissions/#{draft_id}").fetch('data')
abort 'Draft unexpectedly submitted.' unless draft.dig('attributes', 'submittedDate').nil? && draft.dig('attributes', 'state') == 'READY_FOR_REVIEW'
abort 'App missing from draft.' unless items.any? { |item| item.dig('relationships', 'appStoreVersion', 'data', 'id') == version.fetch('id') }
puts "Existing draft #{draft_id}: #{items.length} items; #{items.map { |item| item.dig('attributes', 'state') }.join(', ')}."
puts 'Final App Review submission was not performed.'
