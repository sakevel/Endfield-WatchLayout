-- Mock test environment for Watch layout.
local function vector(x,y,z)return{x=x,y=y,z=z}end
local function color(r,g,b,a)return{r=r,g=g,b=b,a=a}end
local function event()return{callbacks={},AddListener=function(s,f)s.callbacks[#s.callbacks+1]=f end,
    RemoveAllListeners=function(s)s.callbacks={}end,Invoke=function(s,d)for _,f in ipairs(s.callbacks)do f(d)end end}end
local function list()return{items={},Add=function(s,o)s.items[#s.items+1]=o end,Clear=function(s)s.items={}end}end
local function class(name,fields)return setmetatable(fields or {},{__tostring=function()return name end})end
local U={Color=color,Vector2=setmetatable({zero=vector(0,0)},{__call=function(_,...)return vector(...)end}),
    Vector3=setmetatable({one=vector(1,1,1)},{__call=function(_,...)return vector(...)end}),
    RectTransform=class('RectTransform'),Transform=class('Transform'),CanvasGroup=class('CanvasGroup'),
    Quaternion={Euler=function(x,y,z)return vector(x,y,z)end},
    Time={unscaledDeltaTime=1/60},Canvas={ForceUpdateCanvases=function()end},UI={}}
U.UI.Image=class('Image',{Type={Simple=0,Sliced=1}});U.UI.RectMask2D=class('RectMask2D')
U.UI.ScrollRect=class('ScrollRect',{MovementType={Clamped=1}});U.UI.Scrollbar=class('Scrollbar',{Direction={BottomToTop=1}})
local E={EventTrigger=class('EventTrigger',{Entry=function()return{callback=event()}end}),
    EventTriggerType={PointerClick=1,PointerEnter=2,PointerExit=3,InitializePotentialDrag=4,BeginDrag=5,Drag=6,EndDrag=7,Scroll=8},PointerEventData={InputButton={Left=0}}}
U.EventSystems=E
local TMP=class('TMP');CS={UnityEngine=U,TMPro={TextMeshProUGUI=TMP,TextAlignmentOptions={Left=1,Center=2},TextOverflowModes={Ellipsis=1}}}
DeviceInfo={usingController=true};CSIndex=function(i)return i-1 end
typeof=function(o)return o end;NotNull=function(o)return o and not o.destroyed end
logger={error=function(...)lastRuntimeError={...}end}
local all={};local camera={};local scale=2
local function detach(rect)
    if rect.parent then local p=rect.parent;for i,x in ipairs(p.children)do if x==rect then table.remove(p.children,i);break end end;p.childCount=#p.children end
end
local function make(name)
    local go={name=name,layer=5,activeSelf=true,components={}}
    local rect={name=name,gameObject=go,children={},childCount=0,sizeDelta=vector(100,100),rect={width=100,height=100},
        anchoredPosition=vector(0,0),anchoredPosition3D=vector(0,0,0),localScale=vector(1,1,1),localRotation=vector(0,0,0),
        anchorMin=vector(0,1),anchorMax=vector(0,1),pivot=vector(0,1)}
    go.transform=rect
    function rect:SetParent(p)detach(self);self.parent=p;if p then p.children[#p.children+1]=self;p.childCount=#p.children end end
    function rect:GetChild(i)assert(self.children[i+1],'Invalid child index');return self.children[i+1]end
    function rect:SetAsLastSibling()local p=self.parent;if p then self:SetParent(p)end end
    function rect:SetSiblingIndex(i)local p=self.parent;if p then detach(self);self.parent=p;table.insert(p.children,i+1,self);p.childCount=#p.children end end
    function go:SetActive(v)self.activeWrites=(self.activeWrites or 0)+1;self.activeSelf=v end
    go.SetActiveIfNecessary=go.SetActive
    function go:GetComponent(t)if t==U.RectTransform then return rect end;return self.components[t]end
    function go:AddComponent(t)
        if t==U.RectTransform then assert(not self.rectAdded,'Duplicate rect');self.rectAdded=true;return rect end
        assert(not self.components[t],'Duplicate component')
        local c={gameObject=self,rectTransform=rect}
        if t==U.UI.Image then c.color=color(1,1,1,1);c.type=U.UI.Image.Type.Simple
        elseif t==TMP then c.text='';c.font={name='native-font'};c.fontSharedMaterial={}
        elseif t==E.EventTrigger then c.triggers=list()
        elseif t==U.CanvasGroup then c.alpha=1;c.blocksRaycasts=true
        elseif t==U.UI.ScrollRect then c.verticalNormalizedPosition=1;function c:OnScroll(d)self.wheels=(self.wheels or 0)+1 end
        else assert(t==U.UI.RectMask2D or t==U.UI.Scrollbar,'Unknown component') end
        self.components[t]=c;return c
    end
    function go:GetComponentsInChildren(t)
        local result={Length=0};local function walk(r)
            local c=r.gameObject.components[t];if c then result[result.Length]=c;result.Length=result.Length+1 end
            for _,child in ipairs(r.children)do walk(child)end
        end;walk(rect);return result
    end
    all[name]=rect;return go
end
U.GameObject=make
U.Object={}
U.Object.DestroyImmediate=function(go)
    for i=go.transform.childCount,1,-1 do U.Object.DestroyImmediate(go.transform.children[i].gameObject)end
    go.destroyed=true;detach(go.transform)
end
local function node(parent,name,x,y,w,h)
    local go=make(name);local rect=go:AddComponent(U.RectTransform);rect:SetParent(parent)
    rect.anchoredPosition=vector(x,-y);rect.anchoredPosition3D=vector(x,-y,0);rect.sizeDelta=vector(w,h);rect.rect={width=w,height=h};return rect
end
local function nativeView(rect,id)
    local bg=rect.gameObject:AddComponent(U.UI.Image);bg.sprite={name='native-watch-plate.'..id};bg.type=1
    local iconRect=node(rect,'Icon.'..id,30,20,40,40);local icon=iconRect.gameObject:AddComponent(U.UI.Image);icon.sprite={name='glyph.'..id}
    local labelRect=node(rect,'Label.'..id,0,65,100,30);local label=labelRect.gameObject:AddComponent(TMP);label.text='功能 '..id
    local btn={id=id,onClick=event()}
    for _,direction in ipairs({'Up','Down','Left','Right'})do
        btn['SetExplicitSelectOn'..direction]=function(s,target)s['select'..direction]=target end
    end
    btn.onClick:AddListener(function()error('template listener leaked')end)
    local lock=node(rect,'Lock.'..id,0,0,20,20)
    local dot=node(rect,'Dot.'..id,0,0,20,20)
    dot.position=vector(0,200);local redDot={transform=dot,gameObject=dot.gameObject,InitRedDot=function(s,key)s.key=key end}
    local view={gameObject=rect.gameObject,transform=rect,btn=btn,text=label,icon=icon,lockIcon={gameObject=lock.gameObject},redDot=redDot}
    if id==11 or id==1000 then local safe=node(rect,'Safe.'..id,0,0,20,20);view.safeZoneIcon={gameObject=safe.gameObject}end
    return view
end
U.Object.Instantiate=function(template,parent)
    local src=template.transform;local rect=node(parent,'clone',src.anchoredPosition.x,-src.anchoredPosition.y,src.sizeDelta.x,src.sizeDelta.y)
    rect.localScale=src.localScale;rect.localRotation=src.localRotation
    if template.boundView then
        rect.gameObject.boundView=nativeView(rect,1000)
        rect.gameObject.components[U.UI.Image].sprite=template.components[U.UI.Image].sprite
    else for i=1,src.childCount do node(rect,'copied-native-child',0,0,10,10)end end
    return rect.gameObject
end
Utils={wrapLuaNode=function(go)assert(go.boundView,'No clone reference');return go.boundView end,isInSafeZone=function()return true end}
PhaseId={Watch='Watch'}
PhaseManager={GetPhaseRedDotName=function(_,id)return 'phase.'..id end,
    OpenPhase=function(_,id,arg)lastPhase={id=id,arg=arg}end,
    ExitPhaseFast=function(_,id)lastExit=id end}
string.isEmpty=function(value)return value==nil or value=='' end
local function origin(rect)
    if not rect.parent then return rect.anchoredPosition.x,-rect.anchoredPosition.y end
    local x,y=origin(rect.parent);local scroll=rect.parent.gameObject.components[U.UI.ScrollRect]
    if scroll and scroll.content==rect then y=y-(1-scroll.verticalNormalizedPosition)*math.max(0,rect.sizeDelta.y-rect.parent.sizeDelta.y)end
    return x+rect.anchoredPosition.x,y-rect.anchoredPosition.y
end
U.RectTransformUtility={ScreenPointToLocalPointInRectangle=function(rect,pos,cam)
    assert(cam==camera,'Wrong canvas pointer camera');local x,y=origin(rect);return true,vector(pos.x/scale-x,-(pos.y/scale-y))
end}
local right={11,12,21,22,31,32,41,42,51,52,61,62,71,72,81,82,91,92,93}
local controller
local function makeWatch()
    local root=node(nil,'NativeWatch',0,0,1920,1080)
    local rightList=node(root,'RightList',0,0,600,1000)
    local ctrl={m_btnData={},view={rightList=rightList,scrollViewContent={sizeDelta=vector(600,1200)},settingNode={btn={id=201}}},nativeCalls=0}
    for i=1,10 do local group=node(rightList,'Group'..i,0,(i-1)*100,600,100)
        for slot=1,2 do node(group,'OriginalGroupChild',0,0,100,100)end
    end
    for _,id in ipairs(right)do local rect=node(root,'NativeButton.'..id,0,0,100,100);local view=nativeView(rect,id);rect.gameObject.boundView=view
        ctrl.m_btnData[id]={view=view,needHide=id==92,phaseId=id,callback=function()end,needRefreshUnlock=true,needShowRedDot=true}
    end
    for _,id in ipairs({101,102,103,104})do local rect=node(root,'NativeButton.'..id,20,(id-101)*170,320,150);local view=nativeView(rect,id);rect.gameObject.boundView=view
        ctrl.m_btnData[id]={view=view,phaseId=id,callback=function()end,needRefreshUnlock=true,needShowRedDot=true}
    end
    ctrl.view.scrollViewScrollRect={verticalNormalizedPosition=1}
    ctrl.view.scrollViewContent.rect={height=1400}
    ctrl.view.scrollViewRectTransform={rect={height=100,yMin=-100,yMax=0},InverseTransformPoint=function(_,p)return p end}
    ctrl.view.rightMoreUpRedDot={InitRedDot=function(s,key,names)s.names=names end}
    ctrl.view.rightMoreDownRedDot={InitRedDot=function(s,key,names)s.names=names end}
    function ctrl:_InitSpecialRoll()if NativeSpecialRoll then NativeSpecialRoll(self)end end
    function ctrl:_RollTo(column)self.rolledColumn=column end
    function ctrl:_CheckUnlock(id)return not(self.locked and self.locked[id])end
    function ctrl:GenClickCallBack(id)if NativeGenClick then return NativeGenClick(self,id)end;return self.m_btnData[id].onClick or self.m_btnData[id].callback end
    function ctrl:_RebuildRightListNavigation(grid)self.grid=grid;self.nativeCalls=self.nativeCalls+1 end
    function ctrl:_SnapshotRightList()
        self.m_rightGroups={};for _,group in ipairs(rightList.children)do if group.gameObject.name:sub(1,5)=='Group'then self.m_rightGroups[#self.m_rightGroups+1]=group end end
        self.m_rightContentOriginalHeight=self.view.scrollViewContent.sizeDelta.y;self.m_rightGroupSpacing=100
    end
    function ctrl:_RelayoutRightList()
        if NativeRelayout then return NativeRelayout(self)end
        local active={};for _,id in ipairs(ZMLWatchLayout.order(self,right))do local data=self.m_btnData[id]
            data.column=nil;if data.needHide then data.view.gameObject:SetActive(false)else active[#active+1]=id end
        end
        self.m_rightListLength=math.ceil(#active/2);local grid={}
        for i,id in ipairs(active)do local row=math.ceil(i/2);local data=self.m_btnData[id]
            data.column=row;data.view.transform:SetParent(self.m_rightGroups[row]);data.view.gameObject:SetActive(true)
            grid[row]=grid[row]or{};grid[row][#grid[row]+1]=data.view.btn
        end
        self.view.scrollViewContent.sizeDelta.y=self.m_rightContentOriginalHeight-(#self.m_rightGroups-self.m_rightListLength)*100
        self:_RebuildRightListNavigation(grid)
    end
    return ctrl
end
function verifyRuntime()
    local W=ZMLWatchLayout
    assert(ZML.mod('watch-layout').config_menu=='custom' and ZML.config_entry('watch-layout').presentation=='full')
    for _,bad in ipairs({'1|1','01|','1,,2|','1,|','-1|','1|x','1|2|3|4','11,12,21,22,101||','101,101||','100001||','<b>|',''})do assert(not W.decode(bad),bad)end
    assert(W.encode(W.decode('101,102|11,93|12'))=='101,102|11,93|12')
    controller=makeWatch();local ctrl=controller
    local originals={};for id,data in pairs(ctrl.m_btnData)do originals[id]={view=data.view,callback=data.callback,phaseId=data.phaseId}end
    assert(W.prepare(ctrl,right),lastRuntimeError and tostring(lastRuntimeError[2]));ctrl:_SnapshotRightList()
    assert(#ctrl.m_rightGroups==12 and ctrl.m_rightContentOriginalHeight==1400)
    assert(ctrl.m_rightGroups[1].childCount==2,'Must not destroy native buttons')
    W.refresh(ctrl,right);assert(ctrl.grid[1][1].id==11 and ctrl.m_btnData[101].view==originals[101].view)
    assert(ctrl.view.scrollViewContent.sizeDelta.y==1100 and W.firstLeft(ctrl).id==101)
    local columns={};for _,id in ipairs(right)do columns[id]=ctrl.m_btnData[id].column end
    local writes=ctrl.m_btnData[11].view.gameObject.activeWrites
    ctrl.view.scrollViewScrollRect.verticalNormalizedPosition=.4
    W.refresh(ctrl,right)
    assert(ctrl.view.scrollViewScrollRect.verticalNormalizedPosition==.4,'Rebinding native scroll must preserve current position')
    writes=ctrl.m_btnData[11].view.gameObject.activeWrites
    assert(W.first(ctrl,right)==ctrl.m_btnData[11].view.btn)
    assert(ctrl.m_btnData[11].view.gameObject.activeWrites==writes,'Order query must not reset native animator activity')
    for _,id in ipairs(right)do
        assert(ctrl.m_btnData[id].column==columns[id],'Order queries must not erase native columns')
        assert(ctrl.m_btnData[id].view.gameObject.activeSelf==not ctrl.m_btnData[id].needHide,'Order query must not hide current grid')
    end
    local catalog,defaults=W.catalog();assert(#defaults==23 and catalog[104].origin=='left')
    local old=W.normalize('93,11|12',defaults);assert(old.right[1]==93 and old.hidden[1]==12 and #old.left==4,'v0.1 migration')
    local moved=assert(W.move(old,11,'left',1))
    assert(#moved.left==4 and moved.left[1]==11 and moved.right[2]==104,'Full left ejects last to source position')
    assert(W.decode('11,12,21,22||'),'Any entry may occupy left silhouettes')
    assert(#W.normalize('11,12,21,22||',defaults).left==4,'Missing default LEFT cards must not create fifth slot')
    assert(ZML.set('watch-layout','layout','104,102|101,103,93,12,11|21'))
    ctrl.cacheNaviTarget=originals[101].view.btn
    W.refresh(ctrl,right)
    assert(ctrl.m_btnData[101].view~=originals[101].view and not originals[101].view.gameObject.activeSelf)
    assert(ctrl.grid[1][1]==ctrl.m_btnData[101].view.btn and ctrl.grid[1][2]==ctrl.m_btnData[103].view.btn)
    assert(ctrl.m_btnData[101].view.safeZoneIcon==nil,'Do not inherit unrelated template safe-zone behavior')
    assert(ctrl.m_btnData[101].column==1 and ctrl.m_btnData[101].phaseId==originals[101].phaseId and ctrl.m_btnData[101].callback==originals[101].callback)
    assert(ctrl.cacheNaviTarget==ctrl.m_btnData[101].view.btn and not ctrl.m_btnData[21].view.gameObject.activeSelf)
    assert(ctrl.m_btnData[104].view.transform.anchoredPosition3D.y==0 and ctrl.m_btnData[102].view.transform.anchoredPosition3D.y==-170)
    assert(ctrl.m_btnData[92].needHide,'Native forbidden visibility survives')
    if NativeSpecialRoll then
        local copy=ctrl.m_btnData[101];assert(copy.view.btn.onIsNaviTargetChanged,'Migrated LEFT receives native grid-focus callback')
        copy.view.btn.onIsNaviTargetChanged(true);assert(ctrl.rolledColumn==copy.column)
    end
    if NativeRightDots then
        NativeRightDots(ctrl)
        local names={};for _,key in ipairs(ctrl.view.rightMoreUpRedDot.names)do names[key]=true end
        assert(names['phase.101'] and not names['phase.104'],'Grid dots follow presentation, not origin RIGHT ids')
    end
    if NativeRefresh then
        ctrl.locked={[103]=true};NativeRefresh(ctrl)
        assert(ctrl.m_btnData[103].view.lockIcon.gameObject.activeSelf and not ctrl.m_btnData[103].view.text.gameObject.activeSelf)
        assert(ctrl.m_btnData[101].view.icon.gameObject.activeSelf and ctrl.m_btnData[101].view.redDot.key=='phase.101')
        assert(#ctrl.m_btnData[101].view.btn.onClick.callbacks==1)
        if not NativeGenClick then assert(ctrl.m_btnData[101].view.btn.onClick.callbacks[1]==originals[101].callback)end
        ctrl.locked={};NativeRefresh(ctrl);assert(not ctrl.m_btnData[103].view.lockIcon.gameObject.activeSelf)
    end
    -- Test right entry placement in slot silhouettes
    local data11=ctrl.m_btnData[11];data11.openPhaseArg={panelId='fixture-panel'}
    local navTarget
    for slot=1,4 do
        local layout=W.normalize('||',defaults);layout=assert(W.move(layout,11,'left',slot))
        ctrl.cacheNaviTarget=data11.view.btn
        assert(ZML.set('watch-layout','layout',W.encode(layout)));W.refresh(ctrl,right)
        local shell=data11.view
        assert(shell~=originals[11].view and not originals[11].view.gameObject.activeSelf)
        assert(shell.text.text==originals[11].view.text.text and shell.icon.sprite==originals[11].view.icon.sprite)
        assert(shell.gameObject.components[U.UI.Image].sprite.name=='native-watch-plate.'..(100+slot),'Destination silhouette, not stretched right plate')
        assert(shell.transform.anchoredPosition3D.y==-(slot-1)*170 and data11.column==nil)
        assert(ctrl.m_btnData[11]==data11 and data11.openPhaseArg.panelId=='fixture-panel')
        assert(data11.phaseId==originals[11].phaseId and data11.callback==originals[11].callback)
        assert(ctrl.cacheNaviTarget==shell.btn and #ctrl.grid[1]>=1)
        assert(shell.btn.onIsNaviTargetChanged==nil,'Left silhouette must not inherit a right focus-roll callback')
        W.navigation(ctrl)
        assert(shell.btn.selectRight==ctrl.grid[math.min(slot,#ctrl.grid)][1])
        if NativeRefresh then
            ctrl.locked={[11]=true};NativeRefresh(ctrl)
            assert(shell.lockIcon.gameObject.activeSelf and not shell.icon.gameObject.activeSelf and not shell.text.gameObject.activeSelf)
            ctrl.locked={};NativeRefresh(ctrl)
            assert(shell.safeZoneIcon and shell.safeZoneIcon.gameObject.activeSelf and not shell.icon.gameObject.activeSelf,'Source safe zone, not slot semantics')
            assert(shell.redDot.key=='phase.11' and #shell.btn.onClick.callbacks==1)
            if NativeGenClick then
                shell.btn.onClick:Invoke();assert(lastPhase.id==11 and lastPhase.arg==data11.openPhaseArg)
            end
        end
        navTarget=shell.btn
        assert(ZML.set('watch-layout','layout','||'));W.refresh(ctrl,right)
        assert(data11.view==originals[11].view and data11.column~=nil and not shell.gameObject.activeSelf)
        assert(ctrl.cacheNaviTarget==data11.view.btn)
    end
    -- Verify distinct onClick priority
    local customClicks=0;local data93=ctrl.m_btnData[93];data93.onClick=function()customClicks=customClicks+1 end
    data93.needCloseWatch=true;data93.afterCloseWatch=function()afterClose=true end
    assert(ZML.set('watch-layout','layout','93,12,92,11|101,102,103,104|'));W.refresh(ctrl,right)
    assert(data93.view~=originals[93].view and data93.view.safeZoneIcon==nil)
    assert(ctrl.m_btnData[92].needHide and not ctrl.m_btnData[92].view.gameObject.activeSelf,'Forbidden cannot become visible on left')
    if NativeRefresh then
        NativeRefresh(ctrl);data93.view.btn.onClick:Invoke();assert(customClicks==1 and not afterClose)
        local inventory=ctrl.m_btnData[12];inventory.needCloseWatch=true;inventory.afterCloseWatch=function()afterClose=true end
        inventory.openPhaseArg={kind='inventory'}
        inventory.view.btn.onClick:Invoke()
        if NativeGenClick then assert(afterClose and lastExit==PhaseId.Watch and lastPhase.id==12 and lastPhase.arg==inventory.openPhaseArg)end
    end
    assert(ZML.set('watch-layout','layout','93,11|101,102,103,104|12,92'));W.refresh(ctrl,right)
    assert(not originals[12].view.gameObject.activeSelf and data93.view.text.text==originals[93].view.text.text)
    assert(ZML.set('watch-layout','enabled',false));W.refresh(ctrl,right)
    for id,original in pairs(originals)do assert(ctrl.m_btnData[id].view==original.view,'Disable restores every source view')end
    assert(ZML.set('watch-layout','enabled',true));assert(ZML.set('watch-layout','layout','||'));W.refresh(ctrl,right)
    local order=W.normalize('101,102,103,104||',defaults)
    for _,id in ipairs({101,102,103,104})do order=assert(W.move(order,id,'right',1))end
    assert(ZML.set('watch-layout','layout',W.encode(order)));W.refresh(ctrl,right)
    assert(W.firstLeft(ctrl)==nil and ctrl.m_rightListLength==11,'4 left entries fit original+owned rows')
    -- Verify view restoration on disable
    local copies={};for _,id in ipairs(W.leftIds)do copies[id]=ctrl.m_btnData[id].view end
    assert(ZML.set('watch-layout','enabled',false));W.refresh(ctrl,right)
    for _,id in ipairs(W.leftIds)do
        assert(ctrl.m_btnData[id].view==originals[id].view and originals[id].view.gameObject.activeSelf)
        assert(not copies[id].gameObject.activeSelf and ctrl.m_btnData[id].view.transform.anchoredPosition3D.y==-(id-101)*170)
        assert(ctrl.m_btnData[id].column==nil)
    end
    assert(ZML.set('watch-layout','enabled',true));assert(ZML.set('watch-layout','layout','||'));W.refresh(ctrl,right)
    -- Hiding all cards leaves native settings available as navigation fallback.
    local hidden={};for _,id in ipairs(defaults)do hidden[#hidden+1]=tostring(id)end
    assert(ZML.set('watch-layout','layout','||'..table.concat(hidden,',')));W.refresh(ctrl,right)
    assert(ctrl.m_rightListLength==0 and W.firstLeft(ctrl)==nil and W.target(ctrl,nil)==ctrl.view.settingNode.btn)
    assert(ZML.set('watch-layout','layout','||'));W.refresh(ctrl,right)
    assert(not ZML.set('watch-layout','layout',string.rep('1',1025)))
    -- Verify rollback on missing native contract
    local bad=makeWatch();bad.m_btnData[11].view.lockIcon=nil
    local original=bad.m_btnData[101].view
    assert(not W.prepare(bad,right) and bad.m_btnData[101].view==original and #bad.view.rightList.children==10)
    -- Verify rollback on constructor failure
    local late=makeWatch();local wrap=Utils.wrapLuaNode;local calls=0
    Utils.wrapLuaNode=function(go)calls=calls+1;if calls==2 then error('fixture copy binding failure')end;return wrap(go)end
    local leftOriginal=late.m_btnData[101].view
    assert(not W.prepare(late,right) and late.view.rightList.childCount==10 and late.view.scrollViewContent.sizeDelta.y==1200)
    assert(late.m_btnData[101].view==leftOriginal and #leftOriginal.btn.onClick.callbacks==1)
    Utils.wrapLuaNode=wrap
    W.order(ctrl,right)
end
function verifyUI(factory)
    local ctx={api=1,presentation='full',width=1920,height=1080,mod=ZML.mod('watch-layout')}
    ctx.parent=node(nil,'OwnedFullRoot',0,0,1920,1080);ctx.parent.gameObject.layer=0
    local failSave,subscriptions,back=false,0,false
    ctx.get=function()return ZML.get('watch-layout')end
    ctx.set=function(k,v)if failSave then return false,'disk failure'end;return ZML.set('watch-layout',k,v)end
    ctx.back=function()back=true end
    ctx.subscribe=function(fn)local un=ZML.subscribe('watch-layout',fn);subscriptions=subscriptions+1;local alive=true
        return function()if alive then alive=false;subscriptions=subscriptions-1;un()end end
    end
    for _,name in ipairs({'text','button','panel','input'})do ctx[name]=function()error('Must not borrow setting control: '..name)end end
    local cleanup=factory.create(ctx);assert(subscriptions==1 and all['WatchLayout.FullEditor'].gameObject.layer==5)
    local function emit(rect,kind,x,y,pointer,button)
        local trigger=rect.gameObject:GetComponent(E.EventTrigger);assert(trigger,'Whole card must be draggable')
        local data={position=vector(x*scale,y*scale),pressEventCamera=camera,pointerId=pointer or 7,button=button or 0}
        for _,entry in ipairs(trigger.triggers.items)do if entry.eventID==kind then entry.callback:Invoke(data)end end
        return data
    end
    local function center(rect)local x,y=origin(rect);return x+rect.sizeDelta.x/2,y+rect.sizeDelta.y/2 end
    local function drop(card,zone,index)
        local x,y=center(card);emit(card,E.EventTriggerType.BeginDrag,x,y)
        assert(card.parent==all['WatchLayout.FullEditor'] and not card.gameObject.components[U.CanvasGroup].blocksRaycasts)
        local px,py=origin(zone);local cols=zone==all['Zone.left']and 1 or 2
        local content=zone.gameObject.components[U.UI.ScrollRect].content
        local cw=(content.sizeDelta.x-(cols-1)*12)/cols
        local ch=zone==all['Zone.left']and cw*.54 or cw*.78
        local tx=px+((index-1)%cols)*(cw+12)+cw/2
        local ty=py+math.floor((index-1)/cols)*(ch+14)+ch/2
        local before=ctx.get().layout
        emit(card,E.EventTriggerType.Drag,tx,ty)
        assert(ctx.get().layout==before,'Preview must not save')
        assert(card.parent==all['WatchLayout.FullEditor'],'Actual card follows pointer, not a handle/ghost')
        emit(card,E.EventTriggerType.EndDrag,tx,ty)
        return tx,ty
    end
    for _,id in ipairs(select(2,ZMLWatchLayout.catalog()))do
        local rect=all['Card.'..id];local fill=rect.gameObject.components[U.UI.Image]
        assert(fill.sprite==nil and fill.color.r==1 and fill.color.g==1 and fill.color.b==1 and fill.color.a==1,'Opaque white surface independent of native sprite alpha')
        local frame=all['Card.'..id..'.NativeFrame'].gameObject.components[U.UI.Image]
        assert(not frame.raycastTarget and frame.rectTransform.sizeDelta.x==rect.sizeDelta.x,'Native frame scales without intercepting drag')
    end
    local card=all['Card.101'];local nativeCallback=controller.m_btnData[101].callback
    drop(card,all['Zone.right'],1)
    local layout=ZMLWatchLayout.decode(ctx.get().layout)
    assert(layout.right[1]==101 and layout.left[1]==102 and #layout.left==3)
    assert(card.parent==all['Zone.right'].gameObject.components[U.UI.ScrollRect].content)
    assert(card.gameObject.components[U.CanvasGroup].blocksRaycasts)
    drop(card,all['Zone.hidden'],1);assert(ZMLWatchLayout.decode(ctx.get().layout).hidden[1]==101)
    drop(card,all['Zone.left'],1);assert(ZMLWatchLayout.decode(ctx.get().layout).left[1]==101)
    local rightCard=all['Card.11'];local before=ctx.get().layout
    drop(rightCard,all['Zone.left'],1)
    local crossed=ZMLWatchLayout.decode(ctx.get().layout)
    assert(crossed.left[1]==11 and #crossed.left==4 and crossed.right[1]==104,'Right to full left displaces last into source')
    assert(all['Card.11.NativeFrame'].gameObject.components[U.UI.Image].sprite.name=='native-watch-plate.101','Preview uses destination-slot skin')
    assert(ZML.set('watch-layout','layout',before))
    -- Real pointer offset is preserved, rather than snapping its center.
    local x,y=origin(card);emit(card,E.EventTriggerType.BeginDrag,x+20,y+25)
    emit(card,E.EventTriggerType.Drag,900,500)
    assert(card.anchoredPosition.x==880 and card.anchoredPosition.y==-475)
    emit(card,E.EventTriggerType.EndDrag,-100,-100);assert(ctx.get().layout==before)
    -- Ignore non-left-click drag events
    x,y=center(card);emit(card,E.EventTriggerType.BeginDrag,x,y,7,1);assert(card.parent~=all['WatchLayout.FullEditor'])
    emit(card,E.EventTriggerType.BeginDrag,x,y,7);emit(card,E.EventTriggerType.EndDrag,-100,-100,8)
    assert(card.parent==all['WatchLayout.FullEditor']);emit(card,E.EventTriggerType.EndDrag,-100,-100,7)
    failSave=true;drop(card,all['Zone.right'],1);assert(ctx.get().layout==before,'Failed commit rolls back visual layout');failSave=false
    local rightZone=all['Zone.right'];rightZone.gameObject.components[U.UI.ScrollRect].verticalNormalizedPosition=0
    local rx,ry=center(rightCard);emit(rightCard,E.EventTriggerType.Scroll,rx,ry)
    assert(rightZone.gameObject.components[U.UI.ScrollRect].wheels==1)
    local restore=all['RestoreLayout'];x,y=center(restore);emit(restore,E.EventTriggerType.PointerClick,x,y)
    assert(ctx.get().layout=='||' and rightZone.gameObject.components[U.UI.ScrollRect].verticalNormalizedPosition==1)
    local toggle=all['ToggleLayout'];x,y=center(toggle);emit(toggle,E.EventTriggerType.PointerClick,x,y);assert(ctx.get().enabled=='false')
    assert(ZML.set('watch-layout','enabled',true))
    x,y=center(card);emit(card,E.EventTriggerType.BeginDrag,x,y)
    local close=all['Close'];x,y=center(close);emit(close,E.EventTriggerType.PointerClick,x,y);assert(back)
    cleanup();cleanup();assert(subscriptions==0)
    for _,id in ipairs(select(2,ZMLWatchLayout.catalog()))do assert(#all['Card.'..id].gameObject.components[E.EventTrigger].triggers.items==0)end
    assert(controller.m_btnData[101].callback==nativeCallback,'Config editor must never invoke business clicks')
end
