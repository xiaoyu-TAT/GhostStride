#!/usr/bin/env python3
"""Structural checks only; does not substitute for xcodebuild or XCTest.
Dependencies: pip install tree-sitter==0.26.1 tree-sitter-swift==0.7.4 openstep-parser==2.0.3
"""
from pathlib import Path
import math, plistlib, json, datetime, xml.etree.ElementTree as ET
from tree_sitter import Language, Parser
import tree_sitter_swift
from openstep_parser import OpenStepDecoder
root=Path(__file__).resolve().parents[1]
parser=Parser(Language(tree_sitter_swift.language()))
files=list(root.glob('GhostStride/**/*.swift'))+list(root.glob('GhostStrideTests/*.swift'))
for path in files:
    tree=parser.parse(path.read_bytes())
    assert not tree.root_node.has_error, f'Swift syntax: {path}'
print(f'PASS Swift syntax trees: {len(files)} files (not type checking)')
with (root/'GhostStride.xcodeproj/project.pbxproj').open() as f: project=OpenStepDecoder.ParseFromFile(f)
objects=project['objects']
for obj in objects.values():
    for key in ['children','buildConfigurations','buildPhases','dependencies','targets','files']:
        for ref in obj.get(key,[]): assert ref in objects, (key,ref)
    for key in ['fileRef','target','targetProxy','containerPortal','remoteGlobalIDString','productReference','buildConfigurationList','mainGroup','productRefGroup']:
        if key in obj: assert obj[key] in objects, (key,obj[key])
    if obj['isa']=='PBXFileReference' and obj.get('sourceTree')=='<group>': assert (root/obj['path']).exists(), obj['path']
refs={o['path'] for o in objects.values() if o['isa']=='PBXFileReference' and o.get('lastKnownFileType')=='sourcecode.swift'}
assert refs == {p.relative_to(root).as_posix() for p in files}
scheme=ET.parse(root/'GhostStride.xcodeproj/xcshareddata/xcschemes/GhostStride.xcscheme')
for ref in scheme.iter('BuildableReference'): assert ref.attrib['BlueprintIdentifier'] in objects
info=plistlib.loads((root/'GhostStride/Resources/Info.plist').read_bytes())
assert 'NSLocationWhenInUseUsageDescription' in info and 'NSLocationAlwaysUsageDescription' not in info
assert 'UIBackgroundModes' not in info
print(f'PASS Xcode references: {len(objects)} objects; scheme, privacy plist, all source files')
ns={'g':'http://www.topografix.com/GPX/1/1'}
for name,count in [('TwoKilometers',21),('StaticLocation',1)]:
    file=root/f'Samples/{name}.gpx';tree=ET.parse(file);pts=tree.findall('g:wpt',ns);assert len(pts)==count
    coords=[(float(p.attrib['lat']),float(p.attrib['lon'])) for p in pts]
    assert all(-90<=a<=90 and -180<=b<=180 for a,b in coords)
    dates=[datetime.datetime.fromisoformat(p.find('g:time',ns).text.replace('Z','+00:00')) for p in pts]
    assert all(a<b for a,b in zip(dates,dates[1:]))
    assert file.read_bytes()==(root/f'GhostStride/Resources/{name}.gpx').read_bytes()
    if count>1:
        distance=sum(6371000*abs(math.radians(b[0]-a[0])) for a,b in zip(coords,coords[1:]))
        assert abs(distance-2000)<0.01
        assert (dates[-1]-dates[0]).total_seconds()==900
        print(f'PASS {name}: {distance:.3f} m, {count} points, 900 s at 8 km/h')
    else: print('PASS static GPX: one waypoint')
assets=root/'GhostStride/Resources/Assets.xcassets/AppIcon.appiconset'
for image in json.loads((assets/'Contents.json').read_text())['images']: assert (assets/image['filename']).exists()
print('PASS app icon asset references')
