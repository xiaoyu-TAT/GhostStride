#!/usr/bin/env python3
"""Deterministic dependency-free .xcodeproj generator; XcodeGen is also supported."""
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parents[1]
objects = {}
def uid(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def add(key, isa, **kwargs):
    objects[uid(key)] = dict(isa=isa, **kwargs)
    return uid(key)
def config_list(name, settings):
    configs=[]
    for mode in ('Debug','Release'):
        values=dict(settings)
        values.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode=='Debug' else '-O')
        if mode=='Debug': values.update(ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
        configs.append(add(name+mode,'XCBuildConfiguration',name=mode,buildSettings=values))
    return add(name+'configs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
app_files=sorted(root.glob('GhostStride/**/*.swift'))
test_files=sorted(root.glob('GhostStrideTests/*.swift'))
resources=sorted(root.glob('GhostStride/Resources/*.gpx'))+[root/'GhostStride/Resources/Assets.xcassets']
groups={}
for group,files in [('Sources',app_files),('Tests',test_files),('Resources',resources+[root/'GhostStride/Resources/Info.plist'])]:
    refs=[]
    for path in files:
        rel=path.relative_to(root).as_posix()
        typ={'swift':'sourcecode.swift','plist':'text.plist.xml','gpx':'text.xml','xcassets':'folder.assetcatalog'}[path.suffix[1:]]
        refs.append(add('ref'+rel,'PBXFileReference',lastKnownFileType=typ,path=rel,sourceTree='<group>'))
    groups[group]=add(group,'PBXGroup',children=refs,name=group,sourceTree='<group>')
products=[]
for name,ext,typ in [('GhostStride','app','wrapper.application'),('GhostStrideTests','xctest','wrapper.cfbundle')]:
    products.append(add(name+'product','PBXFileReference',explicitFileType=typ,includeInIndex='0',path=name+'.'+ext,sourceTree='BUILT_PRODUCTS_DIR'))
groups['Products']=add('Products','PBXGroup',children=products,name='Products',sourceTree='<group>')
main=add('main','PBXGroup',children=list(groups.values()),sourceTree='<group>')
common=dict(SWIFT_VERSION='6.0',SWIFT_STRICT_CONCURRENCY='complete',IPHONEOS_DEPLOYMENT_TARGET='17.0',SDKROOT='iphoneos',TARGETED_DEVICE_FAMILY='1',CODE_SIGN_STYLE='Automatic',CLANG_ENABLE_MODULES='YES',ENABLE_USER_SCRIPT_SANDBOXING='YES')
pc=config_list('project',common)
proxy=add('proxy','PBXContainerItemProxy',containerPortal=uid('project'),proxyType='1',remoteGlobalIDString=uid('GhostStride'),remoteInfo='GhostStride')
dep=add('dependency','PBXTargetDependency',target=uid('GhostStride'),targetProxy=proxy)
for name,files,res,product in [('GhostStride',app_files,resources,products[0]),('GhostStrideTests',test_files,[],products[1])]:
    phases=[]
    for phase,items,isa in [('Sources',files,'PBXSourcesBuildPhase'),('Resources',res,'PBXResourcesBuildPhase'),('Frameworks',[],'PBXFrameworksBuildPhase')]:
        buildfiles=[add('build'+p.relative_to(root).as_posix(),'PBXBuildFile',fileRef=uid('ref'+p.relative_to(root).as_posix())) for p in items]
        phases.append(add(name+phase,isa,buildActionMask='2147483647',files=buildfiles,runOnlyForDeploymentPostprocessing='0'))
    settings=dict(PRODUCT_NAME='$(TARGET_NAME)',PRODUCT_BUNDLE_IDENTIFIER='com.example.'+name,GENERATE_INFOPLIST_FILE='YES',SUPPORTED_PLATFORMS='iphoneos iphonesimulator',LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/Frameworks','@loader_path/Frameworks'])
    if name=='GhostStride': settings.update(INFOPLIST_FILE='GhostStride/Resources/Info.plist',GENERATE_INFOPLIST_FILE='NO',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon')
    else: settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/GhostStride.app/GhostStride',BUNDLE_LOADER='$(TEST_HOST)')
    add(name,'PBXNativeTarget',buildConfigurationList=config_list(name,settings),buildPhases=phases,buildRules=[],dependencies=[] if name=='GhostStride' else [dep],name=name,productName=name,productReference=product,productType='com.apple.product-type.application' if name=='GhostStride' else 'com.apple.product-type.bundle.unit-test')
add('project','PBXProject',attributes={'LastUpgradeCheck':'1600','BuildIndependentTargetsInParallel':'YES','TargetAttributes':{uid('GhostStride'):{'CreatedOnToolsVersion':'16.0'},uid('GhostStrideTests'):{'CreatedOnToolsVersion':'16.0','TestTargetID':uid('GhostStride')}}},buildConfigurationList=pc,compatibilityVersion='Xcode 15.0',developmentRegion='zh_CN',hasScannedForEncodings='0',knownRegions=['zh_CN','en','Base'],mainGroup=main,productRefGroup=groups['Products'],projectDirPath='',projectRoot='',targets=[uid('GhostStride'),uid('GhostStrideTests')])
def encode(value,level=0):
    if isinstance(value,dict): return '{\n'+''.join('  '*(level+1)+json.dumps(k)+' = '+encode(v,level+1)+';\n' for k,v in value.items())+'  '*level+'}'
    if isinstance(value,list): return '('+', '.join(encode(v,level) for v in value)+')'
    return json.dumps(value,ensure_ascii=False)
project=root/'GhostStride.xcodeproj';project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode(dict(archiveVersion='1',classes={},objectVersion='60',objects=objects,rootObject=uid('project')))+'\n')
schemes=project/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(name,ext): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name)}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:GhostStride.xcodeproj"/>'
(schemes/'GhostStride.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('GhostStride','app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('GhostStrideTests','xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('GhostStride','app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('GhostStride','app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated project: {len(app_files)} app sources, {len(test_files)} test sources, {len(resources)} resources')
