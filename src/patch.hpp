#pragma once
#include <string>
#include <string_view>
#include <vector>
#include <algorithm>
namespace watch_layout {
inline bool patch(std::string_view source, std::string_view extension, std::string& output) {
    if(source.find("ZMLWatchLayout")!=source.npos || extension.empty()) return false;
    struct Change {size_t at, count; std::string value;};
    std::vector<Change> plan;
    auto change=[&](std::string_view anchor, std::string replacement) {
        auto pos=source.find(anchor);
        if(pos==source.npos || source.find(anchor,pos+anchor.size())!=source.npos) return false;
        plan.push_back({pos,anchor.size(),std::move(replacement)});return true;
    };
    auto repeated=[&](std::string_view anchor, std::string replacement, size_t expected) {
        size_t count=0,at=0;
        while((at=source.find(anchor,at))!=source.npos){plan.push_back({at,anchor.size(),replacement});at+=anchor.size();++count;}
        return count==expected;
    };
    // Patch Watch layout refresh
    if(!change("self:_SnapshotRightList()", "_G.ZMLWatchLayout.prepare(self, RIGHT_BTN_ORDER)\n    self:_SnapshotRightList()") ||
       !change("self:SetNaviTarget(self.view.buttonCharInfo.btn)", "self:SetNaviTarget(_G.ZMLWatchLayout.firstLeft(self) or self.view.settingNode.btn)") ||
       !repeated("self:SetNaviTarget(self.cacheNaviTarget and self.cacheNaviTarget or self.view.buttonCharInfo.btn)",
          "self:SetNaviTarget(_G.ZMLWatchLayout.target(self, self.cacheNaviTarget))",2) ||
       !change("for _, key in ipairs(RIGHT_BTN_ORDER) do",
        "for _, key in ipairs(_G.ZMLWatchLayout.order(self, RIGHT_BTN_ORDER)) do") ||
       !change("WatchCtrl._RefreshBtnLockState = HL.Method() << function(self)",
        "WatchCtrl._RefreshBtnLockState = HL.Method() << function(self)\n    _G.ZMLWatchLayout.refresh(self, RIGHT_BTN_ORDER)") ||
       !change("self:SetNaviTarget(self.view.adventureBookNode.btn)",
        "self:SetNaviTarget(_G.ZMLWatchLayout.first(self, RIGHT_BTN_ORDER) or _G.ZMLWatchLayout.firstLeft(self) or self.view.settingNode.btn)") ||
       !repeated("for _,index in pairs(BTN_CONST.RIGHT) do",
          "for _,index in ipairs(_G.ZMLWatchLayout.order(self, RIGHT_BTN_ORDER)) do",2) ||
       !change("HL.Commit(WatchCtrl)",std::string(extension)+"\nHL.Commit(WatchCtrl)")) return false;
    for(auto contract:{"local RIGHT_BTN_ORDER = {}", "table.sort(RIGHT_BTN_ORDER)",
      "self:_SnapshotRightList()", "self:_RelayoutRightList()", "self:_RebuildRightListNavigation(btnGrid)",
      "data.column = nil", "if data.needHide then", "data.view.transform:SetParent(group, false)",
      "PhaseManager:OpenPhase(data.phaseId, data.openPhaseArg)"})
        if(source.find(contract)==source.npos) return false;
    std::sort(plan.begin(),plan.end(),[](auto& a,auto& b){return a.at>b.at;});
    std::string result(source);
    for(auto& c:plan) result.replace(c.at,c.count,c.value);
    output=std::move(result);return true;
}
}
