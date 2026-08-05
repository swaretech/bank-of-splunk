#!/usr/bin/env python3
"""Generate BankOfSplunk.xcodeproj/project.pbxproj"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = "BankOfSplunk"
BUNDLE_ID = "com.splunk.bankofsplunk"

SOURCES = [
    "App/AppDelegate.swift",
    "App/BankOfSplunkApp.swift",
    "Core/Config/AppConfig.swift",
    "Core/Auth/KeychainStore.swift",
    "Core/Auth/AuthStore.swift",
    "Core/Networking/APIClient.swift",
    "Core/Models/Models.swift",
    "Core/UI/KeyboardToolbar.swift",
    "Core/UI/DXAViewModifiers.swift",
    "Core/UI/Theme/AppColors.swift",
    "Core/UI/Theme/AppTypography.swift",
    "Core/UI/Theme/AppShape.swift",
    "Core/UI/Theme/AppMotion.swift",
    "Core/UI/Components/M3Button.swift",
    "Core/UI/Components/M3TextField.swift",
    "Core/UI/Components/M3Card.swift",
    "Core/UI/Components/M3Banner.swift",
    "Core/UI/Components/M3TransactionRow.swift",
    "Features/Login/LoginView.swift",
    "Features/Signup/SignupView.swift",
    "Features/Home/HomeView.swift",
    "Features/Deposit/DepositView.swift",
    "Features/Payment/PaymentView.swift",
    "Features/Transactions/TransactionListView.swift",
    "Observability/DXAIdentifiers.swift",
    "Observability/BankRum.swift",
    "Observability/SplunkRUMConfiguration.swift",
    "Observability/RumIngestProbe.swift",
]

# Stable 24-char hex IDs (Xcode requirement)
def hid(n):
    return f"{n:024X}"

ID = {
    "project": hid(1),
    "target": hid(2),
    "sources": hid(3),
    "resources": hid(4),
    "frameworks": hid(5),
    "product": hid(6),
    "main_group": hid(7),
    "products": hid(8),
    "app_group": hid(9),
    "cfg_proj_list": hid(10),
    "cfg_tgt_list": hid(11),
    "cfg_dbg_proj": hid(12),
    "cfg_rel_proj": hid(13),
    "cfg_dbg_tgt": hid(14),
    "cfg_rel_tgt": hid(15),
    "info_plist": hid(16),
    "assets": hid(17),
    "pkg_ref": hid(18),
    "pkg_prod_agent": hid(19),
    "pkg_build_agent": hid(20),
    "xcconfig_dbg": hid(21),
    "xcconfig_rel": hid(22),
}

source_refs = {}
source_builds = {}
for i, rel in enumerate(SOURCES, start=100):
    source_refs[rel] = hid(i)
    source_builds[rel] = hid(i + 200)

assets_build = hid(400)

lines = []

def emit(text=""):
    lines.append(text)

emit("// !$*UTF8*$!")
emit("{")
emit("\tarchiveVersion = 1;")
emit("\tclasses = {};")
emit("\tobjectVersion = 60;")
emit("\tobjects = {")

emit("\n/* Begin PBXBuildFile section */")
for rel, bid in source_builds.items():
    emit(f"\t\t{bid} /* {Path(rel).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {source_refs[rel]} /* {Path(rel).name} */; }};")
emit(f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ID['assets']} /* Assets.xcassets */; }};")
emit(f"\t\t{ID['pkg_build_agent']} /* SplunkAgent in Frameworks */ = {{isa = PBXBuildFile; productRef = {ID['pkg_prod_agent']} /* SplunkAgent */; }};")
emit("/* End PBXBuildFile section */")

emit("\n/* Begin PBXFileReference section */")
emit(f"\t\t{ID['product']} /* {PROJECT}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
emit(f"\t\t{ID['xcconfig_dbg']} /* Debug.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Debug.xcconfig; sourceTree = \"<group>\"; }};")
emit(f"\t\t{ID['xcconfig_rel']} /* Release.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Release.xcconfig; sourceTree = \"<group>\"; }};")
for rel, fid in source_refs.items():
    emit(f"\t\t{fid} /* {Path(rel).name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {Path(rel).name}; sourceTree = \"<group>\"; }};")
emit(f"\t\t{ID['info_plist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
emit(f"\t\t{ID['assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
emit("/* End PBXFileReference section */")

emit("\n/* Begin PBXFrameworksBuildPhase section */")
emit(f"\t\t{ID['frameworks']} /* Frameworks */ = {{")
emit("\t\t\tisa = PBXFrameworksBuildPhase;")
emit("\t\t\tbuildActionMask = 2147483647;")
emit("\t\t\tfiles = (")
emit(f"\t\t\t\t{ID['pkg_build_agent']} /* SplunkAgent in Frameworks */,")
emit("\t\t\t);")
emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
emit("\t\t};")
emit("/* End PBXFrameworksBuildPhase section */")

# Groups
group_ids = {}
def group_id(path):
    if path not in group_ids:
        group_ids[path] = hid(500 + len(group_ids))
    return group_ids[path]

for rel in SOURCES:
    parts = Path(rel).parts[:-1]
    acc = []
    for part in parts:
        acc.append(part)
        group_id("/".join(acc))

config_group = hid(499)
resources_group = group_id("Resources")

emit("\n/* Begin PBXGroup section */")
emit(f"\t\t{ID['main_group']} = {{")
emit("\t\t\tisa = PBXGroup;")
emit("\t\t\tchildren = (")
emit(f"\t\t\t\t{config_group} /* Config */,")
emit(f"\t\t\t\t{ID['app_group']} /* {PROJECT} */,")
emit(f"\t\t\t\t{ID['products']} /* Products */,")
emit("\t\t\t);")
emit("\t\t\tsourceTree = \"<group>\";")
emit("\t\t};")

emit(f"\t\t{config_group} /* Config */ = {{")
emit("\t\t\tisa = PBXGroup;")
emit("\t\t\tchildren = (")
emit(f"\t\t\t\t{ID['xcconfig_dbg']} /* Debug.xcconfig */,")
emit(f"\t\t\t\t{ID['xcconfig_rel']} /* Release.xcconfig */,")
emit("\t\t\t);")
emit("\t\t\tpath = Config;")
emit("\t\t\tsourceTree = \"<group>\";")
emit("\t\t};")

emit(f"\t\t{ID['products']} /* Products */ = {{")
emit("\t\t\tisa = PBXGroup;")
emit("\t\t\tchildren = (")
emit(f"\t\t\t\t{ID['product']} /* {PROJECT}.app */,")
emit("\t\t\t);")
emit("\t\t\tname = Products;")
emit("\t\t\tsourceTree = \"<group>\";")
emit("\t\t};")

# app root group children = top-level folders + Info.plist
top_level = sorted({Path(s).parts[0] for s in SOURCES} | {"Resources"})
emit(f"\t\t{ID['app_group']} /* {PROJECT} */ = {{")
emit("\t\t\tisa = PBXGroup;")
emit("\t\t\tchildren = (")
for name in top_level:
    emit(f"\t\t\t\t{group_id(name)} /* {name} */,")
emit(f"\t\t\t\t{ID['info_plist']} /* Info.plist */,")
emit("\t\t\t);")
emit(f"\t\t\tpath = {PROJECT};")
emit("\t\t\tsourceTree = \"<group>\";")
emit("\t\t};")

for path, gid in sorted(group_ids.items(), key=lambda x: x[0].count('/')):
    children_dirs = sorted(
        p for p in group_ids if p.startswith(path + "/") and p.count("/") == path.count("/") + 1
    )
    file_children = [source_refs[s] for s in SOURCES if Path(s).parent.as_posix() == path]
    if path == "Resources":
        file_children = [ID['assets']]
    emit(f"\t\t{gid} /* {Path(path).name} */ = {{")
    emit("\t\t\tisa = PBXGroup;")
    emit("\t\t\tchildren = (")
    for child in children_dirs:
        emit(f"\t\t\t\t{group_ids[child]} /* {Path(child).name} */,")
    for fid in file_children:
        name = next(Path(s).name for s in SOURCES if source_refs[s] == fid) if fid in source_refs.values() else "Assets.xcassets"
        emit(f"\t\t\t\t{fid} /* {name} */,")
    emit("\t\t\t);")
    emit(f"\t\t\tpath = {Path(path).name};")
    emit("\t\t\tsourceTree = \"<group>\";")
    emit("\t\t};")

emit("/* End PBXGroup section */")

emit("\n/* Begin PBXNativeTarget section */")
emit(f"\t\t{ID['target']} /* {PROJECT} */ = {{")
emit("\t\t\tisa = PBXNativeTarget;")
emit(f"\t\t\tbuildConfigurationList = {ID['cfg_tgt_list']} /* Build configuration list for PBXNativeTarget \"{PROJECT}\" */;")
emit("\t\t\tbuildPhases = (")
emit(f"\t\t\t\t{ID['sources']} /* Sources */,")
emit(f"\t\t\t\t{ID['frameworks']} /* Frameworks */,")
emit(f"\t\t\t\t{ID['resources']} /* Resources */,")
emit("\t\t\t);")
emit("\t\t\tbuildRules = ();")
emit("\t\t\tdependencies = ();")
emit(f"\t\t\tname = {PROJECT};")
emit(f"\t\t\tpackageProductDependencies = ({ID['pkg_prod_agent']} /* SplunkAgent */,);")
emit(f"\t\t\tproductName = {PROJECT};")
emit(f"\t\t\tproductReference = {ID['product']} /* {PROJECT}.app */;")
emit("\t\t\tproductType = \"com.apple.product-type.application\";")
emit("\t\t};")
emit("/* End PBXNativeTarget section */")

emit("\n/* Begin PBXProject section */")
emit(f"\t\t{ID['project']} /* Project object */ = {{")
emit("\t\t\tisa = PBXProject;")
emit("\t\t\tattributes = {")
emit("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
emit("\t\t\t\tLastSwiftUpdateCheck = 1500;")
emit("\t\t\t\tLastUpgradeCheck = 1500;")
emit("\t\t\t};")
emit(f"\t\t\tbuildConfigurationList = {ID['cfg_proj_list']} /* Build configuration list for PBXProject \"{PROJECT}\" */;")
emit("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
emit("\t\t\tdevelopmentRegion = en;")
emit("\t\t\thasScannedForEncodings = 0;")
emit("\t\t\tknownRegions = (en, Base);")
emit(f"\t\t\tmainGroup = {ID['main_group']};")
emit(f"\t\t\tpackageReferences = ({ID['pkg_ref']} /* XCRemoteSwiftPackageReference \"splunk-otel-ios\" */,);")
emit(f"\t\t\tproductRefGroup = {ID['products']} /* Products */;")
emit("\t\t\tprojectDirPath = \"\";")
emit("\t\t\tprojectRoot = \"\";")
emit("\t\t\ttargets = (")
emit(f"\t\t\t\t{ID['target']} /* {PROJECT} */,")
emit("\t\t\t);")
emit("\t\t};")
emit("/* End PBXProject section */")

emit("\n/* Begin PBXResourcesBuildPhase section */")
emit(f"\t\t{ID['resources']} /* Resources */ = {{")
emit("\t\t\tisa = PBXResourcesBuildPhase;")
emit("\t\t\tbuildActionMask = 2147483647;")
emit("\t\t\tfiles = (")
emit(f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,")
emit("\t\t\t);")
emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
emit("\t\t};")
emit("/* End PBXResourcesBuildPhase section */")

emit("\n/* Begin PBXSourcesBuildPhase section */")
emit(f"\t\t{ID['sources']} /* Sources */ = {{")
emit("\t\t\tisa = PBXSourcesBuildPhase;")
emit("\t\t\tbuildActionMask = 2147483647;")
emit("\t\t\tfiles = (")
for rel, bid in source_builds.items():
    emit(f"\t\t\t\t{bid} /* {Path(rel).name} in Sources */,")
emit("\t\t\t);")
emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
emit("\t\t};")
emit("/* End PBXSourcesBuildPhase section */")

emit("\n/* Begin XCBuildConfiguration section */")
for cid, name, kind in [
    (ID['cfg_dbg_proj'], 'Debug', 'project'),
    (ID['cfg_rel_proj'], 'Release', 'project'),
    (ID['cfg_dbg_tgt'], 'Debug', 'target'),
    (ID['cfg_rel_tgt'], 'Release', 'target'),
]:
    emit(f"\t\t{cid} /* {name} */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit(f"\t\t\tname = {name};")
    if kind == 'project':
        xc = ID['xcconfig_dbg'] if name == 'Debug' else ID['xcconfig_rel']
        emit(f"\t\t\tbaseConfigurationReference = {xc} /* {name}.xcconfig */;")
        emit("\t\t\tbuildSettings = {")
        emit("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        emit("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        emit("\t\t\t\tCOPY_PHASE_STRIP = NO;")
        if name == "Release":
            emit("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
        else:
            emit("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
        emit(f"\t\t\t\tENABLE_TESTABILITY = {'YES' if name == 'Debug' else 'NO'};")
        emit("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;")
        emit(f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = {'INCLUDE_SOURCE' if name == 'Debug' else 'NO'};")
        emit(f"\t\t\t\tONLY_ACTIVE_ARCH = {'YES' if name == 'Debug' else 'NO'};")
        emit("\t\t\t\tSDKROOT = iphoneos;")
        if name == 'Debug':
            emit("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
            emit("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
        else:
            emit("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
            emit("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
        emit("\t\t\t};")
    else:
        xc = ID['xcconfig_dbg'] if name == 'Debug' else ID['xcconfig_rel']
        emit(f"\t\t\tbaseConfigurationReference = {xc} /* {name}.xcconfig */;")
        emit("\t\t\tbuildSettings = {")
        emit("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        emit("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        emit("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        emit("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
        emit(f"\t\t\t\tINFOPLIST_FILE = {PROJECT}/Info.plist;")
        emit("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/Frameworks\");")
        emit("\t\t\t\t// MARKETING_VERSION comes from Secrets.xcconfig via Debug/Release.xcconfig")
        emit(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};")
        emit("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        emit("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        emit("\t\t\t\tSWIFT_VERSION = 5.0;")
        emit("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        emit("\t\t\t};")
    emit("\t\t};")
emit("/* End XCBuildConfiguration section */")

emit("\n/* Begin XCConfigurationList section */")
emit(f"\t\t{ID['cfg_proj_list']} /* Build configuration list for PBXProject \"{PROJECT}\" */ = {{")
emit("\t\t\tisa = XCConfigurationList;")
emit("\t\t\tbuildConfigurations = (")
emit(f"\t\t\t\t{ID['cfg_dbg_proj']} /* Debug */,")
emit(f"\t\t\t\t{ID['cfg_rel_proj']} /* Release */,")
emit("\t\t\t);")
emit("\t\t\tdefaultConfigurationIsVisible = 0;")
emit("\t\t\tdefaultConfigurationName = Release;")
emit("\t\t};")
emit(f"\t\t{ID['cfg_tgt_list']} /* Build configuration list for PBXNativeTarget \"{PROJECT}\" */ = {{")
emit("\t\t\tisa = XCConfigurationList;")
emit("\t\t\tbuildConfigurations = (")
emit(f"\t\t\t\t{ID['cfg_dbg_tgt']} /* Debug */,")
emit(f"\t\t\t\t{ID['cfg_rel_tgt']} /* Release */,")
emit("\t\t\t);")
emit("\t\t\tdefaultConfigurationIsVisible = 0;")
emit("\t\t\tdefaultConfigurationName = Release;")
emit("\t\t};")
emit("/* End XCConfigurationList section */")

emit("\n/* Begin XCRemoteSwiftPackageReference section */")
emit(f"\t\t{ID['pkg_ref']} /* XCRemoteSwiftPackageReference \"splunk-otel-ios\" */ = {{")
emit("\t\t\tisa = XCRemoteSwiftPackageReference;")
emit("\t\t\trepositoryURL = \"https://github.com/signalfx/splunk-otel-ios\";")
emit("\t\t\trequirement = {")
emit("\t\t\t\tkind = exactVersion;")
emit("\t\t\t\tversion = 2.2.3;")
emit("\t\t\t};")
emit("\t\t};")
emit("/* End XCRemoteSwiftPackageReference section */")

emit("\n/* Begin XCSwiftPackageProductDependency section */")
emit(f"\t\t{ID['pkg_prod_agent']} /* SplunkAgent */ = {{")
emit("\t\t\tisa = XCSwiftPackageProductDependency;")
emit(f"\t\t\tpackage = {ID['pkg_ref']} /* XCRemoteSwiftPackageReference \"splunk-otel-ios\" */;")
emit("\t\t\tproductName = SplunkAgent;")
emit("\t\t};")
emit("/* End XCSwiftPackageProductDependency section */")

emit("\t};")
emit(f"\trootObject = {ID['project']} /* Project object */;")
emit("}")

out = ROOT / f"{PROJECT}.xcodeproj" / "project.pbxproj"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines) + "\n")
print(f"Generated {out}")
