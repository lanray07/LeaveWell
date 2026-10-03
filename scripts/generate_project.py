"""Generate the checked-in Xcode project using only the Python standard library."""
from pathlib import Path
import hashlib
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
def uid(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()
def quote(value):
    return json.dumps(str(value))

def generate():
    app_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'LeaveWell').rglob('*.swift'))
    test_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'Tests/iOS').rglob('*.swift'))
    resources = ['LeaveWell/Resources/Assets.xcassets', 'LeaveWell/Resources/Localizable.xcstrings', 'LeaveWell/Resources/PrivacyInfo.xcprivacy']
    files = app_sources + test_sources + resources
    objects = []
    def obj(key, body):
        objects.append(f'{uid(key)} = {{ {body} }};')
    for path in files:
        kind = 'sourcecode.swift' if path.endswith('.swift') else ('folder.assetcatalog' if path.endswith('.xcassets') else 'text.json' if path.endswith('.xcstrings') else 'text.xml')
        obj('file:' + path, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = SOURCE_ROOT;')
        obj('build:' + path, f'isa = PBXBuildFile; fileRef = {uid("file:" + path)};')
    for name, ext, kind in [('LeaveWell', 'app', 'wrapper.application'), ('LeaveWellTests', 'xctest', 'wrapper.cfbundle')]:
        obj('product:' + name, f'isa = PBXFileReference; explicitFileType = {kind}; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;')
    obj('products', 'isa = PBXGroup; children = (' + ','.join(uid('product:' + n) for n in ['LeaveWell', 'LeaveWellTests']) + '); name = Products; sourceTree = "<group>";')
    obj('main', 'isa = PBXGroup; children = (' + ','.join([uid('file:' + p) for p in files] + [uid('products')]) + '); sourceTree = "<group>";')
    obj('proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target:LeaveWell")}; remoteInfo = LeaveWell;')
    obj('dependency', f'isa = PBXTargetDependency; target = {uid("target:LeaveWell")}; targetProxy = {uid("proxy")};')
    for name, sources in [('LeaveWell', app_sources), ('LeaveWellTests', test_sources)]:
        obj('sources:' + name, 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(uid('build:' + p) for p in sources) + '); runOnlyForDeploymentPostprocessing = 0;')
        obj('resources:' + name, 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (' + (','.join(uid('build:' + p) for p in resources) if name == 'LeaveWell' else '') + '); runOnlyForDeploymentPostprocessing = 0;')
        obj('frameworks:' + name, 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
        settings = {
            'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '18.0', 'SWIFT_VERSION': '5.0',
            'TARGETED_DEVICE_FAMILY': '"1,2"', 'CODE_SIGN_STYLE': 'Automatic',
            'SWIFT_EMIT_LOC_STRINGS': 'YES', 'SWIFT_STRICT_CONCURRENCY': 'targeted',
            'PRODUCT_NAME': '"$(TARGET_NAME)"', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.leavewell.' + ('app' if name == 'LeaveWell' else 'tests'),
            'MARKETING_VERSION': '0.1.0', 'CURRENT_PROJECT_VERSION': '1',
        }
        if name == 'LeaveWell':
            settings.update(INFOPLIST_FILE='LeaveWell/Resources/Info.plist', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME='AccentColor', ENABLE_PREVIEWS='YES', LD_RUNPATH_SEARCH_PATHS='"$(inherited) @executable_path/Frameworks"')
        else:
            settings.update(GENERATE_INFOPLIST_FILE='YES', TEST_HOST='"$(BUILT_PRODUCTS_DIR)/LeaveWell.app/LeaveWell"', BUNDLE_LOADER='"$(TEST_HOST)"')
        for config in ['Debug', 'Release']:
            current = dict(settings)
            if config == 'Debug':
                current.update(SWIFT_OPTIMIZATION_LEVEL='"-Onone"', ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
            else:
                current.update(SWIFT_COMPILATION_MODE='wholemodule', SWIFT_OPTIMIZATION_LEVEL='"-O"', DEBUG_INFORMATION_FORMAT='"dwarf-with-dsym"')
            obj('config:' + name + config, 'isa = XCBuildConfiguration; buildSettings = {' + ''.join(f'{k} = {v};' for k,v in current.items()) + f'}}; name = {config};')
        obj('configlist:' + name, 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(uid('config:' + name + c) for c in ['Debug', 'Release']) + '); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
        obj('target:' + name, f'isa = PBXNativeTarget; buildConfigurationList = {uid("configlist:" + name)}; buildPhases = (' + ','.join(uid(p + ':' + name) for p in ['sources', 'frameworks', 'resources']) + '); buildRules = (); dependencies = (' + (uid('dependency') if name != 'LeaveWell' else '') + f'); name = {name}; productName = {name}; productReference = {uid("product:" + name)}; productType = "com.apple.product-type.' + ('application' if name == 'LeaveWell' else 'bundle.unit-test') + '";')
    for config in ['Debug', 'Release']:
        obj('global:' + config, f'isa = XCBuildConfiguration; buildSettings = {{ CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; }}; name = {config};')
    obj('globalconfigs', 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(uid('global:' + c) for c in ['Debug', 'Release']) + '); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; BuildIndependentTargetsInParallel = YES; }}; buildConfigurationList = {uid("globalconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "en-GB"; hasScannedForEncodings = 0; knownRegions = ("en-GB", en, Base); mainGroup = {uid("main")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target:LeaveWell")},{uid("target:LeaveWellTests")});')
    project = ROOT / 'LeaveWell.xcodeproj'
    project.mkdir(exist_ok=True)
    (project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {uid("project")}; }}\n', encoding='utf-8')
    schemes = project / 'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
    reference = lambda name: f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:" + name)}" BuildableName="{name}.{"app" if name == "LeaveWell" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:LeaveWell.xcodeproj"/>'
    (schemes / 'LeaveWell.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference('LeaveWell')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference('LeaveWellTests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('LeaveWell')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('LeaveWell')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''', encoding='utf-8')
    print(f'Generated Xcode project: {len(app_sources)} app sources, {len(test_sources)} test sources.')

if __name__ == '__main__':
    generate()
