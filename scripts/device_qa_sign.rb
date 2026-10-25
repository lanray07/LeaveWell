# Dedicated test helper. No API credentials, private keys or device identifiers are logged.
require 'openssl'
require 'base64'
require 'json'
require 'net/http'
require 'uri'
require 'open3'
require 'fileutils'
require 'securerandom'
require 'shellwords'
RUNNER_ID = 'com.LeaveWell.DeviceQA.WebDriverAgentRunner.xctrunner'
raw = ENV.fetch('APP_STORE_CONNECT_API_PRIVATE_KEY').strip.gsub('\\n', "\n")
raw = Base64.strict_decode64(raw) unless raw.include?('-----BEGIN PRIVATE KEY-----')
api_key = OpenSSL::PKey.read(raw)
b64 = ->(v) { Base64.urlsafe_encode64(v, padding: false) }
now = Time.now.to_i
head = b64.call(JSON.generate(alg: 'ES256', kid: ENV.fetch('APP_STORE_CONNECT_API_KEY_ID'), typ: 'JWT'))
claims = b64.call(JSON.generate(iss: ENV.fetch('APP_STORE_CONNECT_API_ISSUER_ID'), iat: now - 5, exp: now + 1100, aud: 'appstoreconnect-v1'))
signed = head + '.' + claims
sig = OpenSSL::ASN1.decode(api_key.sign(OpenSSL::Digest::SHA256.new, signed)).value.map { |n| n.value.to_s(16).rjust(64, '0') }.join
$token = signed + '.' + b64.call([sig].pack('H*'))
def api(method, path, body = nil)
  uri = URI('https://api.appstoreconnect.apple.com/v1/' + path)
  klass = {'GET'=>Net::HTTP::Get, 'POST'=>Net::HTTP::Post, 'DELETE'=>Net::HTTP::Delete}.fetch(method)
  request = klass.new(uri); request['Authorization'] = 'Bearer ' + $token
  request['Content-Type'] = 'application/json'; request.body = JSON.generate(body) if body
  r = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 45) { |h| h.request(request) }
  raise "Apple API #{method} failed (HTTP #{r.code}); private response omitted" unless r.is_a?(Net::HTTPSuccess)
  r.body.nil? || r.body.empty? ? {} : JSON.parse(r.body)
end
def create(type, attributes, relationships = nil)
  data = {type: type, attributes: attributes}; data[:relationships] = relationships if relationships
  api('POST', type, data: data).fetch('data')
end
def command(*args)
  out, err, status = Open3.capture3(*args)
  unless status.success?
    ['QA_P12_PASSWORD','QA_DEVICE_UDID','APP_STORE_CONNECT_API_PRIVATE_KEY'].each { |n| err=err.gsub(ENV[n],'<redacted>') if ENV[n] && !ENV[n].empty? }
    raise "Signing operation failed: #{File.basename(args[0])}: #{err.lines.first(3).join[0,500]}"
  end
  out
end
def linked(type, id); {data: {type: type, id: id}}; end
if ENV['QA_OPERATION'] == 'cleanup'
  pid = ENV.fetch('QA_PROFILE_ID'); cid = ENV.fetch('QA_CERTIFICATE_ID')
  raise 'Invalid id' unless [pid,cid].all? { |s| s.match?(/\A[A-Za-z0-9-]+\z/) }
  profile = api('GET', "profiles/#{pid}").fetch('data')
  bundle = api('GET', "profiles/#{pid}/bundleId").fetch('data')
  certs = api('GET', "profiles/#{pid}/certificates").fetch('data')
  raise 'Refusing cleanup outside QA helper' unless profile.dig('attributes','name').start_with?('LeaveWell Device QA ') && bundle.dig('attributes','identifier') == RUNNER_ID && certs.map { |c| c['id'] } == [cid]
  api('DELETE', "profiles/#{pid}"); api('DELETE', "certificates/#{cid}")
  puts 'Dedicated QA signing resources removed.'
  exit
end
udid = ENV.fetch('QA_DEVICE_UDID'); raise 'Invalid device id' unless udid.match?(/\A[A-Fa-f0-9-]{20,45}\z/)
recipient = OpenSSL::PKey.read(Base64.strict_decode64(ENV.fetch('QA_PUBLIC_KEY')))
raise 'RSA public key required' unless recipient.is_a?(OpenSSL::PKey::RSA) && !recipient.private? && recipient.n.num_bits >= 3072
device = api('GET', 'devices?' + URI.encode_www_form('filter[udid]'=>udid, 'limit'=>200)).fetch('data').find { |d| d.dig('attributes','udid').casecmp?(udid) }
if device.nil?
  abort 'Target iPad is not registered. Unsigned runner is ready; explicit device-registration authorization is required.' unless ENV['QA_REGISTER_DEVICE'] == 'true'
  device = create('devices', name: 'LeaveWell Owner iPad QA', platform: 'IOS', udid: udid)
end
raise 'Device is not enabled' unless device.dig('attributes','status') == 'ENABLED'
puts 'Target device is registered and enabled.'
bundle = api('GET', 'bundleIds?' + URI.encode_www_form('filter[identifier]'=>RUNNER_ID, 'limit'=>200)).fetch('data').find { |b| b.dig('attributes','identifier') == RUNNER_ID }
bundle ||= create('bundleIds', name: 'LeaveWell Device QA Runner', platform: 'IOS', identifier: RUNNER_ID)
temp = ENV.fetch('RUNNER_TEMP'); runid = ENV.fetch('GITHUB_RUN_ID')
FileUtils.mkdir_p('build/runner')
command('ditto', '-x', '-k', 'build/unsigned-runner.zip', 'build/runner')
app = Dir.glob('build/runner/*.app').first or raise 'Missing runner'
raise 'Unexpected runner id' unless command('/usr/libexec/PlistBuddy','-c','Print :CFBundleIdentifier', app+'/Info.plist').strip == RUNNER_ID
# Only the helper exposes its own generated QA fixtures in Files, not LeaveWell's records.
command('python3','-c', 'import plistlib,sys; f=sys.argv[1]; p=plistlib.load(open(f,"rb")); p.update(UIFileSharingEnabled=True,LSSupportsOpeningDocumentsInPlace=True,CFBundleDisplayName="LeaveWell Device QA"); plistlib.dump(p,open(f,"wb"))', app+'/Info.plist')
# Preinstalled WDA must use the device DDI's XCTest libraries on iOS 17+.
Dir.glob(app+'/Frameworks/XC*.framework').each { |path| FileUtils.remove_entry(path) }
['Testing.framework','libXCTestSwiftSupport.dylib'].each do |name|
  path=app+'/Frameworks/'+name
  FileUtils.remove_entry(path) if File.exist?(path)
end
key = OpenSSL::PKey::RSA.new(2048)
csr = OpenSSL::X509::Request.new; csr.version = 0; csr.subject = OpenSSL::X509::Name.parse('/CN=LeaveWell Temporary Device QA'); csr.public_key = key.public_key; csr.sign(key,OpenSSL::Digest::SHA256.new)
cert = nil; profile = nil
begin
  cert = create('certificates', certificateType: 'DEVELOPMENT', csrContent: csr.to_pem)
  profile = create('profiles', {name: 'LeaveWell Device QA '+runid, profileType: 'IOS_APP_DEVELOPMENT'}, {bundleId: linked('bundleIds',bundle['id']), certificates: {data:[{type:'certificates',id:cert['id']}]}, devices:{data:[{type:'devices',id:device['id']}]}})
  signing_cert = OpenSSL::X509::Certificate.new(Base64.strict_decode64(cert.dig('attributes','certificateContent')))
  pass = SecureRandom.hex(24); puts "::add-mask::#{pass}"
  p12 = File.join(temp,'LeaveWellDeviceQA.p12'); kc = File.join(temp,'LeaveWellDeviceQA.keychain-db')
  keyfile=File.join(temp,'LeaveWellDeviceQA.key'); certfile=File.join(temp,'LeaveWellDeviceQA.cer')
  File.write(keyfile,key.to_pem,mode:'w',perm:0600); File.write(certfile,signing_cert.to_pem)
  ENV['QA_P12_PASSWORD']=pass
  command('/usr/bin/openssl','pkcs12','-export','-inkey',keyfile,'-in',certfile,'-out',p12,'-passout','env:QA_P12_PASSWORD','-keypbe','PBE-SHA1-3DES','-certpbe','PBE-SHA1-3DES','-macalg','sha1')
  File.delete(keyfile)
  command('security','create-keychain','-p',pass,kc); command('security','unlock-keychain','-p',pass,kc)
  search = command('security','list-keychains','-d','user').shellsplit
  command('security','list-keychains','-d','user','-s',kc,*search)
  command('security','import',p12,'-k',kc,'-P',pass,'-T','/usr/bin/codesign')
  command('security','set-key-partition-list','-S','apple-tool:,apple:,codesign:','-s','-k',pass,kc)
  File.binwrite(app+'/embedded.mobileprovision',Base64.strict_decode64(profile.dig('attributes','profileContent')))
  decoded = File.join(temp,'qa-profile.plist'); File.write(decoded,command('security','cms','-D','-i',app+'/embedded.mobileprovision'))
  ent = File.join(temp,'qa-entitlements.plist')
  command('python3','-c', 'import plistlib,sys; p=plistlib.load(open(sys.argv[1],"rb")); plistlib.dump(p["Entitlements"],open(sys.argv[2],"wb"))', decoded, ent)
  identity = OpenSSL::Digest::SHA1.hexdigest(signing_cert.to_der).upcase
  Dir.glob(app+'/**/*',File::FNM_DOTMATCH).select { |p| p.end_with?('.framework','.dylib','.xctest') }.sort_by { |p| -p.length }.each { |p| command('codesign','--force','--sign',identity,'--timestamp=none',p) }
  command('codesign','--force','--sign',identity,'--timestamp=none','--entitlements',ent,app)
  command('codesign','--verify','--deep','--strict',app)
  File.write('build/runner/signing-resources.json',JSON.generate(certificate_id:cert['id'],profile_id:profile['id'],bundle_id:RUNNER_ID,source:'appium/WebDriverAgent@02cb92f0e93c8b021443bcbb8eeb80932c113220'))
  command('ditto','-c','-k','build/runner','build/device-runner.zip')
  cipher = OpenSSL::Cipher.new('aes-256-gcm'); cipher.encrypt; session_key=cipher.random_key; iv=cipher.random_iv; cipher.auth_data='LeaveWell Device QA'
  data=cipher.update(File.binread('build/device-runner.zip'))+cipher.final
  wrapped=recipient.encrypt(session_key,{'rsa_padding_mode'=>'oaep','rsa_oaep_md'=>'sha256','rsa_mgf1_md'=>'sha256'})
  File.write('build/runner.encrypted.json',JSON.generate(wrapped_key:Base64.strict_encode64(wrapped),iv:Base64.strict_encode64(iv),tag:Base64.strict_encode64(cipher.auth_tag),data:Base64.strict_encode64(data)))
  puts 'Signed runner verified and encrypted to local test host. Private signing key not exported.'
rescue
  api('DELETE',"profiles/#{profile['id']}") if profile
  api('DELETE',"certificates/#{cert['id']}") if cert
  raise
end
