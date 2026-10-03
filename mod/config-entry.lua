-- Drag-and-drop layout editor for Watch menu.
return {
    api=1,presentation="full",
    create=function(ctx)
        assert(ctx.presentation=="full","请更新模组菜单到 0.3.3 或更新版本")
        local U,E=CS.UnityEngine,CS.UnityEngine.EventSystems
        local W=assert(_G.ZMLWatchLayout,"请先打开一次 ESC 菜单")
        local catalog,defaults,original=W.catalog();assert(catalog,"原生菜单初始化失败；请查看本 Mod 的错误记录")
        local values=assert(ctx.get());local layout=W.normalize(values.layout,defaults)
        local width,height=ctx.width,ctx.height;local unit=math.min(width/1920,height/1080)
        local layer=ctx.parent.gameObject.layer;local alive=true;local drag,render,cancel,status
        local cards,zones,triggers={},{},{}
        local colors={ink=U.Color(49/255,49/255,49/255,1),paper=U.Color(.88,.88,.88,1),white=U.Color(1,1,1,1),
            yellow=U.Color(1,239/255,0,1),muted=U.Color(.64,.64,.64,1),line=U.Color(.42,.42,.42,1)}
        local function node(parent,name,x,y,w,h)
            local object=U.GameObject(name);object.layer=layer
            local rect=object:AddComponent(typeof(U.RectTransform));rect:SetParent(parent,false)
            rect.anchorMin=U.Vector2(0,1);rect.anchorMax=U.Vector2(0,1);rect.pivot=U.Vector2(0,1)
            rect.anchoredPosition=U.Vector2(x,-y);rect.sizeDelta=U.Vector2(w,h);rect.localScale=U.Vector3.one
            return rect
        end
        local root=node(ctx.parent,"WatchLayout.FullEditor",0,0,width,height)
        local function image(parent,name,x,y,w,h,color,sprite,kind,hit)
            local rect=node(parent,name,x,y,w,h)
            local graphic=rect.gameObject:AddComponent(typeof(U.UI.Image));graphic.color=color
            graphic.raycastTarget=hit==true
            if sprite then graphic.sprite=sprite;graphic.type=kind or U.UI.Image.Type.Sliced end
            return rect,graphic
        end
        local fontSource=assert(original[11].text,"Native Watch font missing")
        assert(fontSource.font,"Native Watch font unavailable")
        layer=fontSource.gameObject.layer;root.gameObject.layer=layer
        local function text(parent,name,value,x,y,w,h,size,color,align)
            local rect=node(parent,name,x,y,w,h)
            local label=rect.gameObject:AddComponent(typeof(CS.TMPro.TextMeshProUGUI))
            label.font=fontSource.font;label.fontSharedMaterial=fontSource.fontSharedMaterial
            label.fontSize=size;label.color=color or colors.white;label.text=value
            label.richText=false;label.raycastTarget=false;label.enableAutoSizing=false
            label.alignment=align or CS.TMPro.TextAlignmentOptions.Left
            label.overflowMode=CS.TMPro.TextOverflowModes.Ellipsis
            return label
        end
        local function surface(view)
            local found,area
            local images=view.gameObject:GetComponentsInChildren(typeof(U.UI.Image),true)
            for i=0,images.Length-1 do local graphic=images[i]
                if graphic.sprite and graphic~=view.icon then
                    local r=graphic.rectTransform.rect;local size=r.width*r.height
                    if not area or size>area then found,area=graphic,size end
                end
            end
            return found
        end
        local skin={left=surface(original[101]),right=surface(original[11])};local leftSkins={}
        for index,id in ipairs(W.leftIds)do leftSkins[index]=surface(original[id])end
        -- Reference native plate sprites and fonts
        local function plate(parent,name,x,y,w,h,kind,color,hit)
            local source=skin[kind]or skin.right
            -- Button background and silhouette styling
            local rect,fill=image(parent,name,x,y,w,h,color,nil,nil,hit)
            local _,frame=image(rect,name..".NativeFrame",0,0,w,h,U.Color(.70,.70,.70,.22),
                source and source.sprite,source and source.type,false)
            return rect,fill,frame
        end
        local function bind(rect,event,fn)
            local trigger=rect.gameObject:GetComponent(typeof(E.EventTrigger))
            if not trigger then trigger=rect.gameObject:AddComponent(typeof(E.EventTrigger));triggers[#triggers+1]=trigger end
            local entry=E.EventTrigger.Entry();entry.eventID=event
            entry.callback:AddListener(function(data)
                if not alive then return end
                local ok,err=xpcall(function()fn(data)end,debug.traceback)
                if not ok then
                    if cancel then cancel()end
                    if status then status.text="操作失败："..tostring(err)end
                    pcall(function()logger.error("ZML WatchLayout:",tostring(err))end)
                end
            end)
            trigger.triggers:Add(entry)
        end
        local margin=48*unit;local top=176*unit;local bottom=96*unit;local gap=32*unit
        image(root,"Backdrop",0,0,width,height,U.Color(.075,.075,.065,.99))
        image(root,"Accent",margin,44*unit,5*unit,50*unit,colors.yellow)
        text(root,"Title","ESC 菜单整理",margin+20*unit,36*unit,width/2,64*unit,36*unit)
        text(root,"Instruction","拖拽调整入口卡片排列；拖入隐藏区可隐藏对应按钮。",margin,104*unit,width-2*margin,40*unit,23*unit,colors.muted)
        image(root,"HeaderLine",margin,156*unit,width-2*margin,1*unit,colors.line)
        status=text(root,"Status","",margin,height-bottom+20*unit,width-2*margin-620*unit,44*unit,22*unit,colors.muted)
        local function point(rect,data)
            local ok,p=U.RectTransformUtility.ScreenPointToLocalPointInRectangle(rect,data.position,data.pressEventCamera)
            if ok then return p end
        end
        local function button(name,title,x,w,fn)
            local rect,bg=plate(root,name,x,height-78*unit,w,48*unit,"right",colors.white,true)
            local label=text(rect,"Caption",title,0,0,w,48*unit,22*unit,colors.ink,CS.TMPro.TextAlignmentOptions.Center)
            bind(rect,E.EventTriggerType.PointerClick,function(data)if data.button==E.PointerEventData.InputButton.Left and not drag then fn()end end)
            bind(rect,E.EventTriggerType.PointerEnter,function()bg.color=colors.paper end)
            bind(rect,E.EventTriggerType.PointerExit,function()bg.color=colors.white end)
            return label
        end
        local enabledLabel=button("ToggleLayout",values.enabled=="true"and"布局已启用"or"布局已停用",width-610*unit,230*unit,function()
            local current=assert(ctx.get());local ok,err=ctx.set("enabled",current.enabled~="true")
            if not ok then status.text="保存失败："..tostring(err)end
        end)
        button("RestoreLayout","恢复原布局",width-352*unit,190*unit,function()
            local ok,err=ctx.set("layout","||");if not ok then status.text="保存失败："..tostring(err)end
        end)
        local closeRect,closeBg=plate(root,"Close",width-margin-56*unit,40*unit,56*unit,56*unit,"right",colors.white,true)
        for _,angle in ipairs({45,-45})do
            local line=image(closeRect,"Cross",12*unit,26*unit,32*unit,4*unit,colors.ink)
            line.pivot=U.Vector2(.5,.5);line.anchoredPosition=U.Vector2(28*unit,-28*unit)
            line.localRotation=U.Quaternion.Euler(0,0,angle)
        end
        bind(closeRect,E.EventTriggerType.PointerClick,function(data)if data.button==E.PointerEventData.InputButton.Left then cancel();ctx.back()end end)
        local available=width-2*margin-2*gap
        local leftWidth=available*.23;local rightWidth=available*.49;local hiddenWidth=available-leftWidth-rightWidth
        local specs={{side="left",title="左侧入口",x=margin,w=leftWidth,cols=1},
            {side="right",title="右侧功能",x=margin+leftWidth+gap,w=rightWidth,cols=2},
            {side="hidden",title="已隐藏",x=margin+leftWidth+gap+rightWidth+gap,w=hiddenWidth,cols=2}}
        local viewportHeight=height-top-bottom-50*unit
        assert(viewportHeight>100*unit,"Editor viewport too short")
        for _,spec in ipairs(specs)do
            local label=text(root,"ZoneTitle."..spec.side,spec.title,spec.x,top,spec.w,42*unit,28*unit)
            image(root,"ZoneAccent."..spec.side,spec.x,top+45*unit,48*unit,3*unit,colors.yellow)
            local viewport=node(root,"Zone."..spec.side,spec.x,top+60*unit,spec.w,viewportHeight-60*unit)
            local bg=viewport.gameObject:AddComponent(typeof(U.UI.Image));bg.color=U.Color(.19,.19,.17,.4);bg.raycastTarget=true
            viewport.gameObject:AddComponent(typeof(U.UI.RectMask2D))
            local content=node(viewport,"Content",0,0,spec.w-16*unit,viewport.sizeDelta.y)
            local scroll=viewport.gameObject:AddComponent(typeof(U.UI.ScrollRect))
            scroll.content=content;scroll.viewport=viewport;scroll.horizontal=false;scroll.vertical=true
            scroll.movementType=U.UI.ScrollRect.MovementType.Clamped;scroll.inertia=false;scroll.scrollSensitivity=80*unit
            local rail= image(viewport,"ScrollRail",spec.w-6*unit,0,4*unit,viewport.sizeDelta.y,colors.line)
            local thumb,thumbImage=image(rail,"ScrollThumb",0,0,4*unit,50*unit,colors.white,nil,nil,true)
            local bar=rail.gameObject:AddComponent(typeof(U.UI.Scrollbar))
            bar.direction=U.UI.Scrollbar.Direction.BottomToTop;bar.handleRect=thumb;bar.targetGraphic=thumbImage
            scroll.verticalScrollbar=bar
            local cellWidth=(content.sizeDelta.x-(spec.cols-1)*12*unit)/spec.cols
            local cellHeight=spec.side=="left"and cellWidth*.54 or cellWidth*.78
            zones[spec.side]={viewport=viewport,content=content,scroll=scroll,label=label,name=spec.title,cols=spec.cols,
                cellWidth=cellWidth,cellHeight=cellHeight,pitchX=cellWidth+12*unit,pitchY=cellHeight+14*unit}
        end
        local placeholder,placeholderBg,placeholderFrame=plate(root,"DropSlot",0,0,100,100,"right",colors.yellow,false)
        placeholder.gameObject:SetActive(false)
        local function resize(card,w,h,side,index)
            card.rect.sizeDelta=U.Vector2(w,h)
            local source=side=="left"and leftSkins[index]or skin.right
            card.frame.sprite=source and source.sprite;card.frame.type=source and source.type or U.UI.Image.Type.Simple
            card.frame.rectTransform.sizeDelta=U.Vector2(w,h)
            local large=side=="left";local iconSize=math.min(w*(large and .32 or .48),h*.52)
            card.icon.rectTransform.sizeDelta=U.Vector2(iconSize,iconSize)
            card.icon.rectTransform.anchoredPosition=U.Vector2((w-iconSize)/2,-h*.12)
            card.title.rectTransform.anchoredPosition=U.Vector2(12*unit,-h*.65)
            card.title.rectTransform.sizeDelta=U.Vector2(w-24*unit,h*.29)
            card.title.fontSize=math.min(27*unit,w*.13)
            card.index.rectTransform.anchoredPosition=U.Vector2(10*unit,-8*unit)
            card.index.rectTransform.sizeDelta=U.Vector2(w/3,22*unit)
            card.flag.rectTransform.anchoredPosition=U.Vector2(w-32*unit,-8*unit)
        end
        render=function(draft)
            draft=draft or layout
            for _,side in ipairs({"left","right","hidden"})do
                local zone=zones[side];local items=draft[side]
                zone.label.text=zone.name.."  / "..#items
                zone.content.sizeDelta=U.Vector2(zone.content.sizeDelta.x,math.max(zone.viewport.sizeDelta.y,math.ceil(#items/zone.cols)*zone.pitchY))
                for i,id in ipairs(items)do
                    local card=cards[id];local x=((i-1)%zone.cols)*zone.pitchX;local y=math.floor((i-1)/zone.cols)*zone.pitchY
                    if not drag or drag.id~=id then
                        card.side=side;card.indexValue=i;card.rect:SetParent(zone.content,false)
                        card.rect.anchoredPosition=U.Vector2(x,-y);resize(card,zone.cellWidth,zone.cellHeight,side,i)
                        card.index.text=string.format("%02d",i);card.bg.color=colors.white
                    else
                        placeholder:SetParent(zone.content,false);placeholder.sizeDelta=U.Vector2(zone.cellWidth,zone.cellHeight)
                        placeholder.anchoredPosition=U.Vector2(x,-y);placeholder.gameObject:SetActive(true)
                        local source=side=="left"and leftSkins[i]or skin.right
                        placeholderFrame.sprite=source and source.sprite;placeholderFrame.type=source and source.type or U.UI.Image.Type.Simple
                        placeholderFrame.rectTransform.sizeDelta=placeholder.sizeDelta
                    end
                end
            end
        end
        cancel=function()
            if drag then
                local card=cards[drag.id];card.group.blocksRaycasts=true;card.group.alpha=1
                drag=nil
            end
            placeholder.gameObject:SetActive(false);render()
        end
        local function destination(data)
            for _,side in ipairs({"left","right","hidden"})do
                local zone=zones[side];local p=point(zone.viewport,data)
                if p and p.x>=0 and p.x<=zone.viewport.sizeDelta.x and p.y<=0 and p.y>=-zone.viewport.sizeDelta.y then
                    local direction=p.y>-24*unit and 1 or(p.y<24*unit-zone.viewport.sizeDelta.y and-1 or 0)
                    if direction~=0 then
                        zone.scroll.verticalNormalizedPosition=math.max(0,math.min(1,zone.scroll.verticalNormalizedPosition+direction*U.Time.unscaledDeltaTime*1.8))
                        U.Canvas.ForceUpdateCanvases()
                    end
                    local localPoint=point(zone.content,data);if not localPoint then return end
                    local col=math.max(0,math.min(zone.cols-1,math.floor(localPoint.x/zone.pitchX)))
                    local row=math.max(0,math.floor(-localPoint.y/zone.pitchY))
                    local count=#layout[side]-(drag.side==side and 1 or 0)
                    return side,math.max(1,math.min(row*zone.cols+col+1,side=="left"and math.min(4,count+1)or count+1))
                end
            end
        end
        for _,id in ipairs(defaults)do
            local item=catalog[id];local rect,bg,frame=plate(root,"Card."..id,0,0,100,100,"right",colors.white,true)
            local group=rect.gameObject:AddComponent(typeof(U.CanvasGroup))
            local iconRect,icon=image(rect,"Icon",0,0,40,40,colors.ink,item.icon and item.icon.sprite,U.UI.Image.Type.Simple,false)
            icon.preserveAspect=true
            if not item.icon then iconRect.gameObject:SetActive(false)end
            local title=text(rect,"Name",item.name,0,0,100,40,26*unit,colors.ink,CS.TMPro.TextAlignmentOptions.Center)
            local number=text(rect,"Index","",0,0,60,24*unit,17*unit,colors.ink)
            local flag=text(rect,"Restriction",item.restricted and "!"or"",0,0,24*unit,24*unit,24*unit,colors.ink,CS.TMPro.TextAlignmentOptions.Center)
            local card={rect=rect,bg=bg,frame=frame,icon=icon,title=title,index=number,flag=flag,group=group};cards[id]=card
            bind(rect,E.EventTriggerType.PointerEnter,function()if not drag then bg.color=colors.paper end end)
            bind(rect,E.EventTriggerType.PointerExit,function()if not drag then bg.color=colors.white end end)
            bind(rect,E.EventTriggerType.InitializePotentialDrag,function(data)data.useDragThreshold=true end)
            bind(rect,E.EventTriggerType.BeginDrag,function(data)
                if data.button~=E.PointerEventData.InputButton.Left then return end
                cancel();local p=point(rect,data);local r=point(root,data);if not p or not r then return end
                drag={id=id,side=card.side,index=card.indexValue,pointer=data.pointerId,grab=p}
                card.rect:SetParent(root,false);card.rect.anchoredPosition=U.Vector2(r.x-p.x,r.y-p.y)
                card.rect:SetAsLastSibling();card.group.blocksRaycasts=false;card.group.alpha=.94
                bg.color=colors.white;render();status.text="拖动中 · 松开确认 · 拖出区域取消"
            end)
            bind(rect,E.EventTriggerType.Drag,function(data)
                if not drag or drag.id~=id or data.pointerId~=drag.pointer then return end
                local p=point(root,data);if p then card.rect.anchoredPosition=U.Vector2(p.x-drag.grab.x,p.y-drag.grab.y)end
                local side,index,why=destination(data)
                if side then render(assert(W.move(layout,id,side,index)));status.text="放入「"..zones[side].name.."」 · 第 "..index.." 位"
                else placeholder.gameObject:SetActive(false);status.text=why or"区域外 · 松开取消"end
            end)
            bind(rect,E.EventTriggerType.EndDrag,function(data)
                if not drag or drag.id~=id or data.pointerId~=drag.pointer then return end
                local side,index=destination(data);local nextLayout=side and W.move(layout,id,side,index)
                cancel()
                if nextLayout then
                    local ok,err=ctx.set("layout",W.encode(nextLayout))
                    if ok then layout=nextLayout;render();status.text="已保存 · 返回 ESC 菜单查看"
                    else status.text="保存失败，已还原："..tostring(err)end
                else status.text="已取消，排列未改变"end
            end)
            bind(rect,E.EventTriggerType.Scroll,function(data)zones[card.side].scroll:OnScroll(data)end)
        end
        render()
        local unsubscribe=ctx.subscribe(function(_,_,changed)
            if not alive then return end
            cancel();values=changed;layout=W.normalize(changed.layout,defaults);render()
            enabledLabel.text=changed.enabled=="true"and"布局已启用"or"布局已停用"
            if changed.layout=="||"then for _,zone in pairs(zones)do zone.scroll.verticalNormalizedPosition=1 end end
        end)
        return function()
            if not alive then return end
            cancel();alive=false;unsubscribe()
            for _,trigger in ipairs(triggers)do if NotNull(trigger)then trigger.triggers:Clear()end end
        end
    end,
}
