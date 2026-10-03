"""Unit tests with mocked UI environment."""
import argparse, pathlib, subprocess, sys, re, tempfile, base64
p=argparse.ArgumentParser();p.add_argument('--lupa-dir');p.add_argument('--services',required=True);p.add_argument('--patched');a=p.parse_args()
if a.lupa_dir:sys.path.insert(0,a.lupa_dir)
from lupa.lua54 import LuaRuntime
root=pathlib.Path(__file__).resolve().parents[1]
temp=tempfile.TemporaryDirectory(prefix='watch-layout-services-');fixture=pathlib.Path(temp.name)
(fixture/'mod.ini').write_text('[mod]\nid=watch-layout-fixture\nname=Fixture\nlibrary=Fixture.dll\napi=1\nenabled=true\nicon=icon.png\n',encoding='utf-8')
(fixture/'icon.png').write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
server=subprocess.Popen([str(pathlib.Path(a.services).resolve()),'--serve',str(fixture/'mod.ini'),str(root/'mod/mod.ini')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def route(_,path):
 server.stdin.write((path+'\n').encode());server.stdin.flush();n=int(server.stdout.readline());data=server.stdout.read(n);assert len(data)==n;return data.decode()
try:
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().native_route=route
 lua.execute('loadstring=load; LuaManagerInst={LoadLua=function(self,p)return native_route(self,p)end}')
 lua.execute(route(None,'ZML/Api'))
 icon=(root/'mod/icon.png').read_bytes()
 assert len(icon)<=65536 and icon[:8]==b'\x89PNG\r\n\x1a\n'
 assert int.from_bytes(icon[16:20],'big')==256 and int.from_bytes(icon[20:24],'big')==256
 encoded=lua.execute('assert(ZML.mod("watch-layout").icon=="png"); return assert(ZML.icon_data("watch-layout"))')
 assert base64.b64decode(encoded)==icon,'Public API must serve the actual metadata icon'

 lua.execute((root/'tests/mock.lua').read_text(encoding='utf-8'))
 lua.execute((root/'mod/watch-layout.lua').read_text(encoding='utf-8'))
 lua.globals().entry=lua.execute((root/'mod/config-entry.lua').read_text(encoding='utf-8'))
 if a.patched:
  source=pathlib.Path(a.patched).read_text(encoding='utf-8')
  lua.execute('assert(load(...,"@current-watch"))',source)
  body=re.search(r"WatchCtrl\._RelayoutRightList = HL\.Method\(\) << function\(self\)\n(.*?)\nend\s+WatchCtrl\._RebuildRightListNavigation",source,re.S)
  assert body, 'Actual native relayout contract changed'
  lua.globals().NativeRelayout=lua.execute('local RIGHT_BTN_ORDER={11,12,21,22,31,32,41,42,51,52,61,62,71,72,81,82,91,92,93}\nreturn function(self)\n'+body.group(1)+'\nend')
  refresh=re.search(r"WatchCtrl\._RefreshBtnLockState = HL\.Method\(\) << function\(self\)\n(.*?)\nend\s+WatchCtrl\.OnFriendBusinessInfoChange",source,re.S)
  assert refresh,'Actual native unlock refresh contract changed'
  lua.globals().NativeRefresh=lua.execute('local RIGHT_BTN_ORDER={11,12,21,22,31,32,41,42,51,52,61,62,71,72,81,82,91,92,93}\nreturn function(self)\n'+refresh.group(1)+'\nend')
  click=re.search(r"WatchCtrl\.GenClickCallBack = HL\.Method\(HL\.Int\)\.Return\(HL\.Function\) << function\(self, key\)\n(.*?)\nend\s+WatchCtrl\.InitWatchNodes",source,re.S)
  assert click,'Actual native click contract changed'
  lua.globals().NativeGenClick=lua.execute('return function(self,key)\n'+click.group(1)+'\nend')
  special=re.search(r"WatchCtrl\._InitSpecialRoll = HL\.Method\(\) << function\(self\)\n(.*?)\nend\s+WatchCtrl\._GetRollUpPosition",source,re.S)
  assert special,'Actual native scroll binding contract changed'
  lua.globals().NativeSpecialRoll=lua.execute('local RIGHT_BTN_ORDER={11,12,21,22,31,32,41,42,51,52,61,62,71,72,81,82,91,92,93}\nreturn function(self)\n'+special.group(1)+'\nend')
  dots=re.search(r"WatchCtrl\._RefreshRightListRedDots = HL\.Method\(\) << function\(self\)\n(.*?)\nend\s+WatchCtrl\.OnClose",source,re.S)
  assert dots,'Actual native viewport red-dot contract changed'
  lua.globals().NativeRightDots=lua.execute('local RIGHT_BTN_ORDER={11,12,21,22,31,32,41,42,51,52,61,62,71,72,81,82,91,92,93}\nreturn function(self)\n'+dots.group(1)+'\nend')
 lua.execute('verifyRuntime(); verifyUI(entry)')
 print('PASS: actual service custom-only manifest, schema/save, strict production drag UI, native order/hide/restore/rebuild/forbidden/navigation/lifecycle')
finally:
 server.stdin.close();server.wait(timeout=5)
 temp.cleanup()
 if server.returncode:raise RuntimeError(server.stderr.read().decode(errors='replace'))
