#include "zml_plugin.h"
#include "patch.hpp"
#include <filesystem>
#include <fstream>
#include <iterator>
namespace {
const ZmlHost* host{};
std::string script;
int convert(void*,const char* bytes,size_t size,ZmlSink sink,void* writer) {
    if(!bytes || !sink) return 0;
    try {
        std::string result;
        if(!watch_layout::patch(std::string_view(bytes,size),script,result)) {
            host->log(host->owner,"WatchCtrl patch rejected");return 0;
        }
        sink(writer,result.data(),result.size());return 1;
    }catch(...){return 0;}
}
int start(const ZmlHost* api) {
    if(!api || api->size!=sizeof(ZmlHost) || api->abi!=1 || !api->mod_directory || !api->log || !api->transform_lua) return 0;
    try {
        auto dir=std::filesystem::path(std::u8string(reinterpret_cast<const char8_t*>(api->mod_directory)));
        auto file=dir/L"watch-layout.lua";
        auto size=std::filesystem::file_size(file);
        if(!size || size>64*1024) return 0;
        std::ifstream in(file,std::ios::binary);
        std::string data{std::istreambuf_iterator<char>(in),{}};
        if(!in.eof() && !in.good()) return 0;
        if(data.empty() || data.find('\0')!=data.npos || data.find("ZMLWatchLayout")==data.npos) return 0;
        script=std::move(data);host=api;
        return api->transform_lua(api->owner,"UI/Panels/Watch/WatchCtrl",convert,nullptr);
    }catch(...){return 0;}
}
const ZmlPlugin descriptor{sizeof(ZmlPlugin),1,"watch-layout",start};
}
extern "C" __declspec(dllexport) const ZmlPlugin* ZML_PluginV1(){return &descriptor;}
