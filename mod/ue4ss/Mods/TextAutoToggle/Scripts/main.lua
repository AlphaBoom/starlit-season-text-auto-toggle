-- Starlit Season 1.61 / UE 4.24. All Unreal calls run on the game thread.
local WAIT=1000000000.0
-- auto: game's native Xbox/PS4 selection; playstation/xbox: explicit icon skin.
-- Steam Input can expose a Sony pad as Xbox, so an explicit skin is useful.
local GAMEPAD_ICONS='auto'
local automatic=ModRef:GetSharedVariable('TextAutoToggle.Auto')
if automatic==nil then automatic=true end
local saved, messages, guides, labels = {}, {}, {}, {}
local pc, lastY, lastA, frame = nil, false, false, 0
local device=ModRef:GetSharedVariable('TextAutoToggle.Device')or 0
local lastError=nil
local ownButtons,deviceChanged={},false
local function valid(o)return o and o:IsValid()end
for _,p in ipairs({{'TextAutoWait',PropertyTypes.FloatProperty,0x288},{'TextAutoTyping',PropertyTypes.ByteProperty,0x270},{'TextAutoWaiting',PropertyTypes.ByteProperty,0x298}}) do
 RegisterCustomProperty({Name=p[1],Type=p[2],BelongsToClass='/Script/imal.CommuScriptMessage',OffsetInternal=p[3]})
end
local textlib=StaticFindObject('/Script/Engine.KismetTextLibrary'):GetCDO()
local gameplay=StaticFindObject('/Script/Engine.GameplayStatics'):GetCDO()
local widgets=StaticFindObject('/Script/UMG.WidgetBlueprintLibrary'):GetCDO()
local keys={{KeyName=FName('Gamepad_FaceButton_Top')},{KeyName=FName('XIGamePad_Button_Y')}}
local keyboardKey={KeyName=FName('A')}
local function active()
 for _,m in ipairs(messages)do
  if valid(m) and (m.TextAutoTyping~=0 or m.TextAutoWaiting~=0) and (valid(m._WidgetMessage)or valid(m._WidgetNovel)or valid(m._WidgetCinema))then return true end
 end
 return false
end
local function applyWait()
 for _,m in ipairs(messages)do if valid(m)then
  local id=m:GetAddress();local wait=m.TextAutoWait
  local shared='TextAutoToggle.Wait.'..tostring(id)
  if saved[id]==nil then saved[id]=ModRef:GetSharedVariable(shared)end
  if not automatic then
   if wait~=WAIT then saved[id]=wait;ModRef:SetSharedVariable(shared,wait);m.TextAutoWait=WAIT end
  elseif wait==WAIT and saved[id]~=nil then m.TextAutoWait=saved[id];saved[id]=nil;ModRef:SetSharedVariable(shared,nil)end
 end end
end
local function guide(m)
 local w=m._WidgetMessage
 if not valid(w)then return end
 local row=w._PanelGuide
 if not valid(row)then return end
 local id=w:GetAddress();local g=guides[id]
 if not valid(g)then
  local root=w.WidgetTree.RootWidget
  for i=root:GetChildrenCount()-1,0,-1 do
   local c=root:GetChildAt(i)
   if c:GetFName():ToString()=='TextAutoToggleStatus'then c:RemoveFromParent()end
  end
  for i=0,row:GetChildrenCount()-1 do
   local c=row:GetChildAt(i)
   if c:IsA('/Script/imal.WidgetControlGuide') and c.KeyType==0 then g=c;break end
  end
  if not valid(g)then
   local ref=row:GetChildAt(0)
   g=widgets:Create(w:GetWorld(),ref:GetClass(),pc)
   g.bBindInputManager=false;g.KeyType=0;g.DispConfigType=2
   for _,name in ipairs({'KeyButtonScale','KeyButtonPadding','TextPadding','TextColorAndOpacity','Font','ShadowOffset','ShadowColorAndOpacity'})do g[name]=ref[name]end
   g.DisplayText=textlib:Conv_StringToText('AUTO OFF')
   row:AddChildToHorizontalBox(g)
   g:SetUp()
   local slot=row.Slot
   slot:SetAutoSize(true)
   local a=slot:GetAlignment();local anchors=slot:GetAnchors();local pos=slot:GetPosition()
   a.X=1;anchors.Minimum.X=1;anchors.Maximum.X=1;pos.X=-10
   slot:SetAlignment(a);slot:SetAnchors(anchors);slot:SetPosition(pos)
   print('[TextAutoToggle] Added native control guide\n')
  end
  g:SetVisibility(4)
  guides[id]=g
 end
 local label=automatic and 'AUTO ON' or 'AUTO OFF'
 if labels[id]~=label then
  g.DisplayText=textlib:Conv_StringToText(label)
  if valid(g.TextWidget)then g.TextWidget:SetText(g.DisplayText)end
  labels[id]=label
 end
 if valid(g.ButtonWidget)then
  local button=g.ButtonWidget
  ownButtons[button:GetAddress()]=true
  -- TRIANGLE is the game's symbolic top face button. Rebuild its native cache
  -- so changes to the game's PS4 icon setting take effect without restarting.
  -- Native SetKey selects ImageSettingDefault / ImageSettingPS4 itself.
  button.bAutoSetting=false
  button:SetKey(5,true)
  button:OnChangeView(device,2,false)
  -- Native TRIANGLE maps to keyboard R. Our shortcut is A, so only the
  -- keyboard texture needs an override; never overwrite a native pad icon.
  local asset,key=nil,nil
  if device==1 then asset,key=button.ImageSettingDefault,38
  elseif GAMEPAD_ICONS=='playstation'then asset,key=button.ImageSettingPS4,142
  elseif GAMEPAD_ICONS=='xbox'then asset,key=button.ImageSettingDefault,142 end
  if valid(asset)then
   local map=asset.ImalKeySettings
   if map:Contains(key)then
    local info=map:Find(key):get();local image=button.ButtonImage
    if valid(image)and valid(info.Texture)then
     image:SetBrushFromTexture(info.Texture,false);image:SetBrushSize(info.Size)
    end
   end
  end
 end
end
-- Follow the device the game's own guide icons show (keyboard / pad), not only
-- the device last used for our toggle. Native buttons switch through OnChangeView.
RegisterHook('/Script/imal.WidgetKeyButtonBase:OnChangeView',function(self,deviceType)
 local b=self:get()
 if ownButtons[b:GetAddress()]then return end
 local d=deviceType:get()
 if(d==0 or d==1)and d~=device then
  device=d;ModRef:SetSharedVariable('TextAutoToggle.Device',device);deviceChanged=true
 end
end)
local function refreshUI()for _,m in ipairs(messages)do if valid(m)then guide(m)end end end
local function toggle(source)
 if not active()then return end
 automatic=not automatic
 ModRef:SetSharedVariable('TextAutoToggle.Auto',automatic)
 ModRef:SetSharedVariable('TextAutoToggle.Device',device)
 applyWait();refreshUI()
 print('[TextAutoToggle] '..source..' -> '..(automatic and 'AUTO' or 'MANUAL')..'\n')
end
-- One persistent game-thread timer: never enqueue closures from an async/keybind
-- thread while Lua is running (UE4SS upstream issue #1445).
print('[TextAutoToggle] Ready: gamepad Y / Triangle, keyboard A. Native Xbox / PS4 icons. Single game-thread timer.\n')
LoopInGameThreadWithDelay(20,function()
  local ok,err=pcall(function()
   frame=frame+1
   if frame%25==1 then
    messages=FindAllOf('CommuScriptMessage')or{}
    for _,m in ipairs(messages)do if valid(m) and valid(m:GetWorld())then pc=gameplay:GetPlayerController(m:GetWorld(),0);break end end
   end
   local down=false
   if valid(pc)then for _,key in ipairs(keys)do if pc:IsInputKeyDown(key)then down=true;break end end end
   local keyboardDown=valid(pc)and pc:IsInputKeyDown(keyboardKey)or false
   if down and not lastY then device=0;toggle('Gamepad top (Y / Triangle)')end
   if keyboardDown and not lastA and not down then device=1;toggle('Keyboard A')end
   lastY=down
   lastA=keyboardDown
   applyWait()
   if deviceChanged or frame%10==1 then deviceChanged=false;refreshUI()end
  end)
  if not ok and err~=lastError then lastError=err;print('[TextAutoToggle] '..tostring(err)..'\n')end
end)
