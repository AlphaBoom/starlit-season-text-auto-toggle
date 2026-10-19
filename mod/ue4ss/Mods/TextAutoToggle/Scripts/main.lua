-- Starlit Season 1.61 / UE 4.24. All Unreal calls run on the game thread.
local WAIT=1000000000.0
-- auto: game's native Xbox/PS4 selection; playstation/xbox: explicit icon skin.
-- Steam Input can expose a Sony pad as Xbox, so an explicit skin is useful.
local GAMEPAD_ICONS='auto'
local automatic=ModRef:GetSharedVariable('TextAutoToggle.Auto')
if automatic==nil then automatic=true end
local saved, messages, guides, labels = {}, {}, {}, {}
local released={}
local pc, lastY, lastA, frame = nil, false, false, 0
local device=ModRef:GetSharedVariable('TextAutoToggle.Device')or 0
local lastError=nil
local ownButtons,deviceChanged={},false
local function valid(o)return o and o:IsValid()end
for _,p in ipairs({{'TextAutoWait',PropertyTypes.FloatProperty,0x288},{'TextAutoElapsed',PropertyTypes.FloatProperty,0x294},{'TextAutoTyping',PropertyTypes.ByteProperty,0x270},{'TextAutoWaiting',PropertyTypes.ByteProperty,0x298},{'TextAutoTimedOnly',PropertyTypes.ByteProperty,0x2a4}}) do
 RegisterCustomProperty({Name=p[1],Type=p[2],BelongsToClass='/Script/imal.CommuScriptMessage',OffsetInternal=p[3]})
end
RegisterCustomProperty({Name='TextAutoSelectActive',Type=PropertyTypes.ByteProperty,BelongsToClass='/Script/imal.CommuScriptSelect',OffsetInternal=0x230})
RegisterCustomProperty({Name='TextAutoInputMode',Type=PropertyTypes.IntProperty,BelongsToClass='/Script/imal.CommuScriptInput',OffsetInternal=0x250})
RegisterCustomProperty({Name='TextAutoPaused',Type=PropertyTypes.ByteProperty,BelongsToClass='/Script/imal.CommuScriptPause',OffsetInternal=0x230})
RegisterCustomProperty({Name='TextAutoCommand',Type=PropertyTypes.IntProperty,BelongsToClass='/Script/imal.CommuScriptParser',OffsetInternal=0x61c})
-- Class default objects are looked up on use: mods can start before the engine has
-- loaded UMG, and an early lookup then stays empty for the whole session.
local cdoCache={}
local function cdo(path)
 local o=cdoCache[path]
 if o and o:IsValid()then return o end
 local c=StaticFindObject(path)
 o=c and c:IsValid()and c:GetCDO()or nil
 cdoCache[path]=o
 return o
end
local keys={{KeyName=FName('Gamepad_FaceButton_Top')},{KeyName=FName('XIGamePad_Button_Y')}}
local keyboardKey={KeyName=FName('A')}
local function active()
 for _,m in ipairs(messages)do
  if valid(m) and (m.TextAutoTyping~=0 or m.TextAutoWaiting~=0) and (valid(m._WidgetMessage)or valid(m._WidgetNovel)or valid(m._WidgetCinema))then return true end
 end
 return false
end
local function restoreWait(m)
 local id=m:GetAddress();local shared='TextAutoToggle.Wait.'..tostring(id)
 local original=saved[id]
 if original==nil then original=ModRef:GetSharedVariable(shared)end
 if m.TextAutoWait==WAIT and original~=nil then m.TextAutoWait=original end
 saved[id]=nil;ModRef:SetSharedVariable(shared,nil)
end
local function shouldHold(m)
 local id=m:GetAddress()
 if released[id]then
  -- A timed-only caption ignores native confirm (+0x2a4). Leave its real
  -- threshold in place until a later native tick has completed this caption.
  local parser=m._SaveParser
  if valid(parser)and parser.TextAutoCommand==released[id]and m.TextAutoTyping==0 and m.TextAutoWaiting~=0 then return false end
  released[id]=nil
 end
 if not valid(m:GetWorld())or(m.TextAutoTyping==0 and m.TextAutoWaiting==0)then return false end
 if not(valid(m._WidgetMessage)or valid(m._WidgetNovel)or valid(m._WidgetCinema))then return false end
 local parser=m._SaveParser
 if valid(parser)then
  local select=parser.CommuScriptSelect
  if valid(select)and select.TextAutoSelectActive~=0 then return false end
 end
 return true
end
local function applyWait()
 for _,m in ipairs(messages)do if valid(m)then
  local id=m:GetAddress();local wait=m.TextAutoWait
  local shared='TextAutoToggle.Wait.'..tostring(id)
  if saved[id]==nil then saved[id]=ModRef:GetSharedVariable(shared)end
  if not automatic and shouldHold(m)then
   if wait~=WAIT then saved[id]=wait;ModRef:SetSharedVariable(shared,wait);m.TextAutoWait=WAIT end
  else if automatic then released[id]=nil end;restoreWait(m)end
 end end
end
-- Native confirmation copies Wait into Elapsed and runs the next script command
-- synchronously. Never let our sentinel enter that command/choice transition.
-- Restoring only the threshold leaves typing, voice stopping and selection to
-- the game's original confirmation handler. Reapply after it has changed state.
local function beforeNativeInput(self,action)
 if automatic then return end
 -- In v1.61 OnPressed_Commu's switch maps action 22 to the next-message
 -- delegate. Other actions (pause, log, skip, etc.) must not release a line.
 if action:get()~=22 then return end
 local input=self:get();local parser=input._SaveParser
 if not valid(parser)then return end
 local m=parser.CommuScriptMessage
 if not valid(m)then return end
 restoreWait(m)
 local pause=parser.CommuScriptPause
 if input.TextAutoInputMode==1 and(not valid(pause)or pause.TextAutoPaused==0)
  and m.TextAutoTimedOnly~=0 and m.TextAutoTyping==0 and m.TextAutoWaiting~=0 then
  released[m:GetAddress()]=parser.TextAutoCommand
  -- Do not clear the native input lock or call a voice/selection function.
  -- Satisfy only the current caption's timer; native UpdateWait still waits
  -- for its voice and performs the normal command/choice handoff next tick.
  m.TextAutoElapsed=m.TextAutoWait
  print('[TextAutoToggle] Released timed-only caption for native next tick\n')
 end
end
RegisterHook('/Script/imal.CommuScriptInput:OnPressed_Commu',beforeNativeInput,function()applyWait()end)
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
   if not cdo('/Script/UMG.WidgetBlueprintLibrary')or not cdo('/Script/Engine.KismetTextLibrary')or not valid(ref)then return end
   g=cdo('/Script/UMG.WidgetBlueprintLibrary'):Create(w:GetWorld(),ref:GetClass(),pc)
   g.bBindInputManager=false;g.KeyType=0;g.DispConfigType=2
   for _,name in ipairs({'KeyButtonScale','KeyButtonPadding','TextPadding','TextColorAndOpacity','Font','ShadowOffset','ShadowColorAndOpacity'})do g[name]=ref[name]end
   g.DisplayText=cdo('/Script/Engine.KismetTextLibrary'):Conv_StringToText('AUTO OFF')
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
  g.DisplayText=cdo('/Script/Engine.KismetTextLibrary'):Conv_StringToText(label)
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
print('[TextAutoToggle] Ready v3: manual confirm supports timed-only captions before choices.\n')
LoopInGameThreadWithDelay(20,function()
  local ok,err=pcall(function()
   frame=frame+1
   if frame%25==1 then
    messages=FindAllOf('CommuScriptMessage')or{}
    for _,m in ipairs(messages)do if valid(m) and valid(m:GetWorld())then pc=cdo('/Script/Engine.GameplayStatics'):GetPlayerController(m:GetWorld(),0);break end end
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
