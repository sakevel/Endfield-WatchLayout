-- Watch menu layout adapter.
do
    if not _G.ZMLWatchLayout then
        local U=CS.UnityEngine
        local W={states=setmetatable({},{__mode="k"}),leftIds={101,102,103,104},last=nil}
        _G.ZMLWatchLayout=W
        local api
        local names={[101]="干员",[102]="活动",[103]="寻访",[104]="采购中心"}
        local sides={"left","right","hidden"}
        local function report(event,err)
            if api then pcall(api.report,"watch-layout",event) end
            if err then pcall(function()logger.error("ZML WatchLayout:",tostring(err))end)end
        end
        function W.isLeft(id)return id>=101 and id<=104 end
        function W.decode(value)
            if type(value)~="string" or #value>1024 then return nil end
            local parts={};for part in (value.."|"):gmatch("(.-)|")do parts[#parts+1]=part end
            if #parts~=2 and #parts~=3 then return nil end
            local seen={};local function parse(part)
                if not part:match("^[%d,]*$") or part:find(",,",1,true) or part:sub(1,1)=="," or part:sub(-1)=="," then return nil end
                local list={}
                for token in part:gmatch("[^,]+")do
                    local id=tonumber(token)
                    if not id or id<1 or id>100000 or id%1~=0 or tostring(id)~=token or seen[id] then return nil end
                    seen[id]=true;list[#list+1]=id;if #list>256 then return nil end
                end
                return list
            end
            local out={left={},right={},hidden={}}
            if #parts==2 then out.right=parse(parts[1]);out.hidden=parse(parts[2])
            else out.left=parse(parts[1]);out.right=parse(parts[2]);out.hidden=parse(parts[3])end
            if not out.left or not out.right or not out.hidden or #out.left>4 then return nil end
            return out
        end
        function W.encode(layout)
            local result=table.concat(layout.left,",").."|"..table.concat(layout.right,",").."|"..table.concat(layout.hidden,",")
            assert(W.decode(result),"Invalid layout");return result
        end
        function W.normalize(value,defaults)
            local out={left={},right={},hidden={}};local input=W.decode(value) or out
            local valid,seen={},{};for _,id in ipairs(defaults)do valid[id]=true end
            for _,side in ipairs(sides)do for _,id in ipairs(input[side])do
                if valid[id] and not seen[id]then out[side][#out[side]+1]=id;seen[id]=true end
            end end
            for _,id in ipairs(defaults)do if not seen[id]then
                local side=W.isLeft(id)and #out.left<4 and"left"or"right";out[side][#out[side]+1]=id;seen[id]=true
            end end
            return out
        end
        function W.move(layout,id,side,index)
            if side~="left" and side~="right" and side~="hidden" then return nil,"未知区域" end
            local out={left={},right={},hidden={}};local found=false;local from,fromIndex
            for _,s in ipairs(sides)do for i,key in ipairs(layout[s])do
                if key==id then found=true;from=s;fromIndex=i else out[s][#out[s]+1]=key end
            end end
            if not found then return nil,"入口已不存在" end
            table.insert(out[side],math.max(1,math.min(index,#out[side]+1)),id)
            -- Handle slot overflow when inserting into left column
            if #out.left>4 then
                local displaced=table.remove(out.left)
                table.insert(out[from],math.min(fromIndex,#out[from]+1),displaced)
            end
            return out
        end
        local function config()
            if not api then
                local ok,value=pcall(function()return assert(loadstring(LuaManagerInst:LoadLua("ZML/Api"),"@ZML/Api"))()end)
                if ok and value.config_menu_version==1 then api=value end
            end
            return api and api.get("watch-layout")or{enabled="false",layout="||"}
        end
        local fields={"anchorMin","anchorMax","pivot","sizeDelta","localScale","localRotation","anchoredPosition3D"}
        local function snapshot(rect)
            local slot={parent=rect.parent};for _,field in ipairs(fields)do slot[field]=rect[field] end;return slot
        end
        local function place(rect,slot)
            rect:SetParent(slot.parent,false);for _,field in ipairs(fields)do rect[field]=slot[field] end
        end
        local function sourceIcon(view)
            if view.icon and view.icon.sprite then return view.icon end
            local images=view.gameObject:GetComponentsInChildren(typeof(U.UI.Image),true)
            for i=0,images.Length-1 do
                local image=images[i];local name=image.gameObject.name:lower()
                if image.sprite and name:find("icon",1,true)and not name:find("lock",1,true)and not name:find("safe",1,true)then return image end
            end
        end
        local function title(view,id)
            return (view.text and view.text.text~="" and view.text.text)or names[id]or("按钮 "..id)
        end
        local function cloneView(source,parent,name)
            local object=U.Object.Instantiate(source.gameObject,parent,false);object.name=name
            local copy=Utils.wrapLuaNode(object)
            assert(copy.btn and copy.text and copy.icon and copy.lockIcon,"Native cloned entry contract changed")
            copy.btn.onClick:RemoveAllListeners();copy.btn.onIsNaviTargetChanged=nil
            object:SetActive(false);return copy
        end
        local function bindShell(s,index,id)
            local shell=s.leftShells[index];local source=s.original[id]
            local binding=s.leftBindings[index]
            if not binding or binding.id~=id or binding.source~=source then
                s.leftBindings[index]={id=id,source=source}
                shell.text.richText=false;shell.text.text=title(source,id)
                local icon=sourceIcon(source);shell.icon.sprite=icon and icon.sprite or nil
                if icon then shell.icon.color=icon.color;shell.icon.preserveAspect=icon.preserveAspect end
                shell.icon.gameObject:SetActive(true);shell.text.gameObject:SetActive(true)
                shell.lockIcon.gameObject:SetActive(false)
                -- Apply safe zone rules from source entry
                shell.safeZoneIcon=source.safeZoneIcon and s.leftSafe[index]or nil
                if s.leftSafe[index]then s.leftSafe[index].gameObject:SetActive(false)end
            end
            return shell
        end
        function W.prepare(self,defaults)
            local previous=W.states[self]
            if previous and previous.ready then return true end
            local s={base={},original={},records={},copies={},leftShells={},leftSafe={},leftBindings={},slots={},defaults={},owned={},ready=false}
            W.states[self]=s
            local ok,err=xpcall(function()
                local template=assert(self.m_btnData[11],"Native right template missing").view
                assert(template.btn and template.text and template.icon and template.lockIcon,"Right template contract changed")
                for _,id in ipairs(defaults)do local data=self.m_btnData[id]
                    if data and data.view then s.defaults[#s.defaults+1]=id;s.original[id]=data.view;s.base[id]=data.needHide==true;s.records[id]=data end
                end
                for _,id in ipairs(W.leftIds)do
                    local data=assert(self.m_btnData[id],"Native left entry missing")
                    s.defaults[#s.defaults+1]=id;s.original[id]=data.view;s.base[id]=data.needHide==true;s.records[id]=data
                    s.slots[#s.slots+1]=snapshot(data.view.transform)
                    assert(data.view.btn and data.view.text and data.view.icon and data.view.lockIcon,"Native left silhouette contract changed")
                end
                -- Reserve grid rows before snapshot pass
                local rightList=self.view.rightList;local groups={}
                for i=0,rightList.childCount-1 do local row=rightList:GetChild(i)
                    if row.name:sub(1,5)=="Group"then groups[#groups+1]=row end
                end
                assert(#groups>=2,"Native row geometry unavailable")
                local last=groups[#groups];local before=groups[#groups-1]
                local step=last.anchoredPosition.y-before.anchoredPosition.y;assert(step<0,"Native row step changed")
                local extra=math.max(0,math.ceil(#s.defaults/2)-#groups)
                for i=1,extra do
                    local object=U.Object.Instantiate(last.gameObject,rightList,false);s.owned[#s.owned+1]=object
                    object.name="GroupZMLWatchLayout"..i
                    local rect=object.transform
                    for j=rect.childCount-1,0,-1 do U.Object.DestroyImmediate(rect:GetChild(j).gameObject)end
                    rect.anchoredPosition=U.Vector2(last.anchoredPosition.x,last.anchoredPosition.y+step*i)
                    object:SetActive(false)
                end
                local store=U.GameObject("ZMLWatchLayout.Store");s.owned[#s.owned+1]=store
                local storeRect=store:AddComponent(typeof(U.RectTransform));storeRect:SetParent(rightList,false)
                store.layer=rightList.gameObject.layer;store:SetActive(false);s.store=storeRect
                for _,id in ipairs(W.leftIds)do
                    local copy=cloneView(template,storeRect,"ZMLWatchLayout.Right."..id)
                    copy.text.richText=false;copy.text.text=title(s.original[id],id)
                    local icon=sourceIcon(s.original[id]);copy.icon.sprite=icon and icon.sprite or nil
                    if not s.original[id].safeZoneIcon and copy.safeZoneIcon then
                        copy.safeZoneIcon.gameObject:SetActive(false);copy.safeZoneIcon=nil
                    end
                    s.copies[id]=copy
                end
                local safeSource
                for _,id in ipairs(s.defaults)do if s.original[id].safeZoneIcon then safeSource=s.original[id].safeZoneIcon;break end end
                for index,id in ipairs(W.leftIds)do
                    -- Clone slot plate and transforms
                    local copy=cloneView(s.original[id],storeRect,"ZMLWatchLayout.LeftSlot."..index)
                    s.leftShells[index]=copy
                    if copy.safeZoneIcon then copy.safeZoneIcon.gameObject:SetActive(false)end
                    if safeSource then
                        local object=U.Object.Instantiate(safeSource.gameObject,copy.icon.gameObject.transform.parent,false)
                        object.name="ZMLWatchLayout.SafeZone"
                        local slot=snapshot(copy.lockIcon.gameObject.transform)
                        place(object.transform,slot);object:SetActive(false)
                        s.leftSafe[index]={gameObject=object}
                    end
                    copy.safeZoneIcon=nil
                end
                self.view.scrollViewContent.sizeDelta=U.Vector2(self.view.scrollViewContent.sizeDelta.x,
                    self.view.scrollViewContent.sizeDelta.y+extra*math.abs(step)*rightList.localScale.y)
                s.ready=true;report("bidirectional_adapter_ready")
            end,debug.traceback)
            if not ok then
                for i=#s.owned,1,-1 do if NotNull(s.owned[i])then U.Object.DestroyImmediate(s.owned[i])end end
                s.failed=err;report("layout_prepare_error",err)
            end
            return ok
        end
        function W.order(self,defaults)
            local s=W.states[self];if not s or not s.ready then return defaults end
            local values=config();local layout=W.normalize(values.enabled=="true" and values.layout or"||",s.defaults)
            local zones={};for _,side in ipairs(sides)do for _,id in ipairs(layout[side])do zones[id]=side end end
            -- Rebuild metadata from original presentation
            local catalog={}
            for _,id in ipairs(s.defaults)do
                local data=self.m_btnData[id]
                if data~=s.records[id]then
                    -- Refresh cached entries
                    s.records[id]=data;s.base[id]=data.needHide==true;s.original[id]=data.view
                end
                catalog[id]={id=id,name=title(s.original[id],id),icon=sourceIcon(s.original[id]),restricted=s.base[id],origin=W.isLeft(id)and"left"or"right"}
            end
            local cachedId
            for _,id in ipairs(s.defaults)do
                if self.cacheNaviTarget==self.m_btnData[id].view.btn then cachedId=id;break end
            end
            local selected={};local oldViews={}
            for _,id in ipairs(s.defaults)do
                local data=self.m_btnData[id];local side=zones[id];oldViews[id]=data.view
                local nextView=side=="right"and W.isLeft(id)and s.copies[id]or s.original[id]
                if side=="left"then
                    -- Assigned below, using this slot's own native silhouette.
                    data.column=nil
                else
                    if data.view~=nextView or side~="right"then data.column=nil end
                    data.view=nextView
                end
                data.needHide=s.base[id]or side=="hidden"
                if side=="right"then selected[data.view]=not data.needHide end
            end
            s.leftAssignment=s.leftAssignment or{}
            for index,id in ipairs(layout.left)do
                local data=self.m_btnData[id]
                -- Bind view for target slot
                data.view=id==W.leftIds[index]and s.original[id]or bindShell(s,index,id)
                if oldViews[id]~=data.view or s.leftAssignment[index]~=id then place(data.view.transform,s.slots[index])end
                selected[data.view]=not data.needHide
            end
            s.leftAssignment=layout.left
            local function visibility(view)
                local active=selected[view]==true
                if view.gameObject.activeSelf~=active then view.gameObject:SetActive(active)end
            end
            -- Query current order without mutating card states
            for _,id in ipairs(s.defaults)do visibility(s.original[id])end
            for index,id in ipairs(W.leftIds)do visibility(s.copies[id]);visibility(s.leftShells[index])end
            if cachedId then
                local data=self.m_btnData[cachedId]
                self.cacheNaviTarget=not data.needHide and data.view.btn or nil
            end
            local ordered={};for _,side in ipairs({"right","hidden"})do for _,id in ipairs(layout[side])do
                if side=="right"or not W.isLeft(id)then ordered[#ordered+1]=id end
            end end
            s.layout=layout;s.catalog=catalog;W.last=self;return ordered
        end
        function W.navigation(self)
            local s=W.states[self];if not s or not s.layout then return end
            local left,right={},{}
            for _,id in ipairs(s.layout.left)do local data=self.m_btnData[id]
                if not data.needHide then left[#left+1]=data.view.btn end
            end
            for _,id in ipairs(s.layout.right)do local data=self.m_btnData[id]
                if not data.needHide and data.column then
                    right[data.column]=right[data.column]or{};table.insert(right[data.column],data.view.btn)
                end
            end
            for i,btn in ipairs(left)do
                btn.useExplicitNaviSelect=true
                btn:SetExplicitSelectOnUp(left[i-1]or self.view.settingNode.btn);btn.banExplicitOnUp=false
                btn:SetExplicitSelectOnDown(left[i+1]);btn.banExplicitOnDown=left[i+1]==nil
                btn:SetExplicitSelectOnLeft(nil);btn.banExplicitOnLeft=true
                local row=right[math.min(i,#right)];btn:SetExplicitSelectOnRight(row and row[1]);btn.banExplicitOnRight=row==nil
            end
            for i,row in ipairs(right)do
                local btn=row[1];local target=left[math.min(i,#left)]
                btn:SetExplicitSelectOnLeft(target);btn.banExplicitOnLeft=target==nil
            end
        end
        function W.refresh(self,defaults)
            local ok,err=xpcall(function()
                W.order(self,defaults)
                if self.m_rightGroups then self:_RelayoutRightList()end
                if DeviceInfo and DeviceInfo.usingController then
                    W.navigation(self)
                    if self._InitSpecialRoll then
                        local scroll=self.view.scrollViewScrollRect;local position=scroll and scroll.verticalNormalizedPosition
                        self:_InitSpecialRoll()
                        if scroll and position then scroll.verticalNormalizedPosition=position end
                    end
                end
            end,debug.traceback)
            if not ok then report("layout_apply_error",err)end
        end
        function W.first(self,defaults)
            for _,id in ipairs(W.order(self,defaults))do local data=self.m_btnData[id]
                if data and not data.needHide then return data.view.btn end
            end
        end
        function W.firstLeft(self)
            local s=W.states[self]
            if s and s.layout then for _,id in ipairs(s.layout.left)do local data=self.m_btnData[id]
                if data and not data.needHide then return data.view.btn end
            end end
        end
        function W.target(self,cached)
            if cached then for _,data in pairs(self.m_btnData)do if data.view and data.view.btn==cached and not data.needHide then return cached end end end
            return W.firstLeft(self)or W.first(self,RIGHT_BTN_ORDER)or self.view.settingNode.btn
        end
        function W.catalog()
            local s=W.last and W.states[W.last]
            if not s then return nil end
            return s.catalog,s.defaults,s.original
        end
    end
end
