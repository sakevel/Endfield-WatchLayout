#include "patch.hpp"
#include "zml_plugin.h"
#include <Windows.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
namespace {
void check(bool ok,const char* m){if(!ok)throw std::runtime_error(m);}
std::string read(const std::filesystem::path& p){std::ifstream f(p,std::ios::binary);check(bool(f),"File missing");return {std::istreambuf_iterator<char>(f),{}};}
struct Capture {ZmlLuaTransform fn{};void* data{};int registrations{},writes{},logs{};std::string result;};
void log(void* p,const char*){++static_cast<Capture*>(p)->logs;}
int reg(void* p,const char* path,ZmlLuaTransform fn,void* data){auto& c=*static_cast<Capture*>(p);check(std::string(path)=="UI/Panels/Watch/WatchCtrl","Unexpected module");c.fn=fn;c.data=data;++c.registrations;return 1;}
void sink(void* p,const char* b,size_t n){auto& c=*static_cast<Capture*>(p);c.result.assign(b,n);++c.writes;}
std::string fixture(){return
 "local RIGHT_BTN_ORDER = {}\ntable.sort(RIGHT_BTN_ORDER)\nself:BuildData()\nself:_SnapshotRightList()\n"
 "self:_RelayoutRightList()\nWatchCtrl._RelayoutRightList\nfor _, key in ipairs(RIGHT_BTN_ORDER) do\n"
 "data.column = nil\nif data.needHide then\ndata.view.transform:SetParent(group, false)\n"
 "self:_RebuildRightListNavigation(btnGrid)\nWatchCtrl._RefreshBtnLockState = HL.Method() << function(self)\n"
 "self:SetNaviTarget(self.view.buttonCharInfo.btn)\n"
 "self:SetNaviTarget(self.cacheNaviTarget and self.cacheNaviTarget or self.view.buttonCharInfo.btn)\n"
 "self:SetNaviTarget(self.cacheNaviTarget and self.cacheNaviTarget or self.view.buttonCharInfo.btn)\n"
 "for _,index in pairs(BTN_CONST.RIGHT) do\nfor _,index in pairs(BTN_CONST.RIGHT) do\n"
 "self:SetNaviTarget(self.view.adventureBookNode.btn)\nPhaseManager:OpenPhase(data.phaseId, data.openPhaseArg)\nHL.Commit(WatchCtrl)";}
}
int main(int argc,char** argv){HMODULE dll{},other{};try {
 check(argc>=2,"DLL argument missing");std::string output="unchanged";auto base=fixture();
 check(watch_layout::patch(base,"local ZMLWatchLayout={}",output),"Valid contract");auto patched=output;
 check(!watch_layout::patch(patched,"extension",output)&&output==patched,"Idempotent/atomic");
 for(auto anchor:{"for _, key in ipairs(RIGHT_BTN_ORDER) do","WatchCtrl._RefreshBtnLockState = HL.Method() << function(self)",
    "self:SetNaviTarget(self.view.adventureBookNode.btn)","HL.Commit(WatchCtrl)"}) {
  auto broken=base;broken.erase(broken.find(anchor),std::string(anchor).size());
  check(!watch_layout::patch(broken,"extension",output)&&output==patched,"Missing anchor atomic");
  check(!watch_layout::patch(base+anchor,"extension",output)&&output==patched,"Ambiguous anchor atomic");
 }
 auto oneCached=base;const std::string cached="self:SetNaviTarget(self.cacheNaviTarget and self.cacheNaviTarget or self.view.buttonCharInfo.btn)";
 oneCached.erase(oneCached.find(cached),cached.size());
 check(!watch_layout::patch(oneCached,"extension",output)&&output==patched,"Missing repeated cached-navigation anchor atomic");
 check(!watch_layout::patch(base+cached,"extension",output)&&output==patched,"Extra cached-navigation anchor atomic");
 const std::string gridLoop="for _,index in pairs(BTN_CONST.RIGHT) do";
 auto missingLoop=base;missingLoop.erase(missingLoop.find(gridLoop),gridLoop.size());
 check(!watch_layout::patch(missingLoop,"extension",output)&&output==patched,"Missing grid business loop atomic");
 check(!watch_layout::patch(base+gridLoop,"extension",output)&&output==patched,"Ambiguous grid business loop atomic");
 check(!watch_layout::patch(base,"",output),"Empty extension rejected");
 auto path=std::filesystem::absolute(argv[1]);dll=LoadLibraryW(path.c_str());check(dll!=nullptr,"LoadLibrary");
 auto entry=reinterpret_cast<ZmlPluginEntry>(GetProcAddress(dll,"ZML_PluginV1"));check(entry!=nullptr,"Entry");
 auto* plugin=entry();check(plugin&&plugin->abi==1&&plugin->size==sizeof(ZmlPlugin)&&std::string(plugin->id)=="watch-layout","Descriptor");
 Capture captures[2];auto utf8=path.parent_path().u8string();std::string dir(reinterpret_cast<const char*>(utf8.data()),utf8.size());
 ZmlHost hosts[2]{{sizeof(ZmlHost),1,&captures[0],dir.c_str(),"",log,reg},{}};
 auto bad=hosts[0];bad.abi=99;check(!plugin->start(nullptr)&&!plugin->start(&bad),"Reject ABI");
 bad=hosts[0];bad.mod_directory="does-not-exist";check(!plugin->start(&bad)&&captures[0].registrations==0,"Missing data no registration");
 bad=hosts[0];bad.log=nullptr;check(!plugin->start(&bad),"Missing callback");
 check(plugin->start(&hosts[0])&&captures[0].registrations==1,"Registration");
 auto& c=captures[0];check(c.fn(nullptr,base.data(),base.size(),sink,&c)==1&&c.writes==1,"Actual transform");
 check(c.result.find("function W.move")!=c.result.npos&&c.result.find("__ZML_")==c.result.npos,"Actual script loaded");
 auto duplicate=c.result;check(!c.fn(nullptr,duplicate.data(),duplicate.size(),sink,&c)&&c.writes==1,"Sink unchanged on reject");
 check(!c.fn(nullptr,nullptr,0,sink,&c)&&!c.fn(nullptr,base.data(),base.size(),nullptr,&c),"Null input/sink");
 if(argc>=3){base=read(argv[2]);check(c.fn(nullptr,base.data(),base.size(),sink,&c)==1,"Current readonly Watch source");}
 if(argc>=4){
  auto op=std::filesystem::absolute(argv[3]);other=LoadLibraryW(op.c_str());check(other!=nullptr,"Menu DLL");
  auto oe=reinterpret_cast<ZmlPluginEntry>(GetProcAddress(other,"ZML_PluginV1"));check(oe!=nullptr,"Menu entry");
  auto od8=op.parent_path().u8string();std::string od(reinterpret_cast<const char*>(od8.data()),od8.size());
  hosts[1]={sizeof(ZmlHost),1,&captures[1],od.c_str(),"",log,reg};check(oe()->start(&hosts[1])==1,"Menu init");
  auto& m=captures[1];check(m.fn(m.data,base.data(),base.size(),sink,&m)==1,"Menu first");
  check(c.fn(c.data,m.result.data(),m.result.size(),sink,&c)==1,"Layout after menu");
  check(c.result.find("_G.ZMLModMenu.mount(self)")!=c.result.npos,"Mount survives");
  check(c.fn(c.data,base.data(),base.size(),sink,&c)==1,"Layout first");
  check(m.fn(m.data,c.result.data(),c.result.size(),sink,&m)==1,"Menu after layout");
  check(m.result.find("ZMLWatchLayout.order(self")!=m.result.npos,"Ordering survives");
  if(argc>=5){std::ofstream(argv[4],std::ios::binary)<<m.result;}
 }
 if(other)FreeLibrary(other);FreeLibrary(dll);
 std::cout<<"PASS: atomic contract, actual ABI1 DLL, optional current source and two-way ModMenu composition\n";return 0;
}catch(const std::exception& e){if(other)FreeLibrary(other);if(dll)FreeLibrary(dll);std::cerr<<e.what()<<'\n';return 1;}}
