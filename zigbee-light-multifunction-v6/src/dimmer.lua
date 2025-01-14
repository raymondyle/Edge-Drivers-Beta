--- Smartthings library load ---
local capabilities = require "st.capabilities"
--local ZigbeeDriver = require "st.zigbee"
--local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
--local colorcontrol_defaults = require "st.zigbee.defaults.colorTemperature_defaults"
local Groups = zcl_clusters.Groups
local utils = require "st.utils"
local utils_xy = require "utils-xy-lidl"
local LAST_KELVIN_SET = "last_kelvin_set"
--local MONITORED_ATTRIBUTES_KEY = "__monitored_attributes"

local write = require "writeAttribute"
local child_devices = require "child-devices"

local ColorControl = zcl_clusters.ColorControl
local CURRENT_X = "current_x_value" -- y value from xyY color space
local CURRENT_Y = "current_y_value" -- x value from xyY color space
local Y_TRISTIMULUS_VALUE = "y_tristimulus_value" -- Y tristimulus value which is used to convert color xyY -> RGB -> HSV

local last_signal_emit_time = os.time()
local set_status_timer 

---- Load handlers written in dimmer.lua
local driver_handler = {}

------ dimming tables variables init
local progOn = {}
local onStatus = {}
local onTotalSteps = {}
local onStep = {}
local onNewLevel ={}
local onStepLevel = {}
local onTimer ={}
local onStartDim = {}
local dimJump = {}
local progOff = {}
local offStatus ={}
local offTotalSteps = {}
local offStep = {}
local offNewLevel ={}
local offStepLevel = {}
local offLevelStart = {}
local offJump = {}
local offTimer ={}
local device_running = {}
local oldPreferenceValue ={}
local newParameterValue ={}

-- Random tables variables
local random_Step = {}
local random_totalStep = {}
local random_timer = {}

--- Circadian Rhythm table sun angle
local circadian_Time_Angle ={
  ["06"] = 0,
  ["07"] = 15,
  ["08"] = 30,
  ["09"] = 45,
  ["10"] = 60,
  ["11"] = 75,
  ["12"] = 90,
  ["13"] = 75,
  ["14"] = 60,
  ["15"] = 45,
  ["16"] = 30,
  ["17"] = 15,
  ["18"] = 0,
  ["19"] = 0,
 }
local circadian_Running = {}
local circadian = {}

-- Color Change variables
local hueMin = {}
local hueMax = {}
local hueStep = {}

-- Custom Capability Declaration
local random_On_Off = capabilities["legendabsolute60149.randomOnOff1"]
local prog_On = capabilities["legendabsolute60149.progressiveOn1"]
local prog_Off = capabilities["legendabsolute60149.progressiveOff1"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep"]
local level_Steps = capabilities["legendabsolute60149.levelSteps"]
local color_Temperature_Steps = capabilities["legendabsolute60149.colorTemperatureSteps"]
local circadian_Light = capabilities["legendabsolute60149.circadian"]
local color_Changing = capabilities["legendabsolute60149.colorChanging"]
local color_Change_Timer = capabilities["legendabsolute60149.colorChangeTimer"]
local color_Change_Mode = capabilities["legendabsolute60149.colorChangeMode1"]
local driver_Version = capabilities["legendabsolute60149.driverVersion1"]
local forced_On_Level = capabilities["legendabsolute60149.forcedOnLevel"]
local mirror_Group_Function = capabilities["legendabsolute60149.mirrorGroupFunction"]
local effects_Set_Command = capabilities["legendabsolute60149.effectsSetCommand"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

----- do_init device tables create for dimming variables ----
function driver_handler.do_init (self, device)

  print("<<<<< Device Init >>>>>>")

  -- set ZLL_xy device to "no" defaults
  device:set_field("zll_xy", "no")

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NOT Child device)

    device_running[device]= device
    onStatus[device] = "stopped"
    onTotalSteps[device] = 2
    onStep[device] = 0
    onNewLevel[device] = 1
    onStepLevel[device] = 1
    onTimer[device]= 2
    dimJump[device] = "no"
    offStatus[device] = "stopped"
    offTotalSteps[device] = 2
    offStep[device] = 0
    offNewLevel[device] = 1
    offStepLevel[device] = 1
    offTimer[device]= 2
    offLevelStart[device] = 10
    offJump[device] = "no"
    random_Step[device] = 1
    random_totalStep[device] =2
    random_timer[device] = math.random(10, 20)

    ----- print device init values for debug------
    local id = device
    if device.preferences.logDebugPrint == true then
      print("<<<<<<<<< device_running[id] >>>>>>>>>>",device_running[id])
      print("progOn=",progOn[id])
      print("onStatus=",onStatus[id])
      print("onTotalSteps=", onTotalSteps[id])
      print("onStep=", onStep[id])
      print("deviceonNewLevel=",onNewLevel[id])
      print("offStepLevel=",onStepLevel[id])
      print("dimJump=", dimJump[id])
      print("progOff=",progOff[id])
      print("offStatus=", offStatus[id])
      print("offTotalSteps=", offTotalSteps[id])
      print("offStep=", offStep[id])
      print("offNewLevel=", offNewLevel[id])
      print("offStepLevel=", offStepLevel[id])
      print("offLevelStart=", offLevelStart[id])
      print("offJump=", offJump[id])
      print("random_Step=",random_Step[id])
      print("random_totalStep=",random_totalStep[id])
      print("random_timer=",random_timer[id])
      print("circadian_Running=",circadian_Running[id])
      print("circadian=",circadian[id])
    end
  end

  ----- INIT status for all devices real and child --------

  -- set profile
    if device.preferences.changeProfile == "20006500" then
      print("<< rgbw-level-colortemp-2000-6500 >>")
      device:try_update_metadata({profile = "rgbw-level-colortemp-2000-6500"})
    elseif device.preferences.changeProfile == "27006500" and device.preferences.colorTempMinim >= 2700 then
      print("<< rgbw-level-colortemp-2700-6500 >>")
      device:try_update_metadata({profile = "rgbw-level-colortemp-2700-6500"})
    elseif device.preferences.changeProfile == "22004000" and device.preferences.colorTempMaxim <= 4000 and device.preferences.colorTempMinim >= 2200 then
      print("<< rgbw-level-colortemp-2200-4000 >>")
      device:try_update_metadata({profile = "rgbw-level-colortemp-2200-4000"})
    elseif device.preferences.changeProfile == "RGB" then
      print("<< level-rgb-rgbw >>")
      device:try_update_metadata({profile = "level-rgb-rgbw"})
    end 

  --- restart prog-On status
  if device:get_field("progOn[device]") == nil then
    progOn[device] = "Inactive"
    device:set_field("progOn[device]", progOn[device], {persist = true})
    device:emit_event(prog_On.progOn("Inactive"))
  else
    progOn[device] = device:get_field("progOn[device]")
    device:emit_event(prog_On.progOn(progOn[device]))   
  end

  --- restart prog-Off status
  if device:get_field("progOff[device]") == nil then
    progOff[device] = "Inactive"
    device:set_field("progOff[device]", progOff[device], {persist = true})
    device:emit_event(prog_Off.progOff("Inactive"))
   else
    progOff[device] = device:get_field("progOff[device]")
    device:emit_event(prog_Off.progOff(progOff[device]))
   end

   -- restart Circadian status
   if device:get_field("circadian_Running[device]") == nil then
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    device:emit_event(circadian_Light.circadian("Inactive"))
   else
    circadian_Running[device] = device:get_field("circadian_Running[device]")
   end
 
   if device:get_field("circadian[device]") == nil then
    circadian[device] = "Inactive"
    device:set_field("circadian[device]", circadian[device], {persist = true})
   else
    circadian[device] = device:get_field("circadian[device]")
   end

  -- send zigbee event for random on-off if inactive or nil
  --print("<<<< random_state >>>>",device:get_field("random_state"))
  if device:get_field("random_state") == "Inactive" or device:get_field("random_state") == nil then
   device:emit_event(random_On_Off.randomOnOff("Inactive"))
   if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NOT Child device)
    device:emit_event(random_Next_Step.randomNext("Inactive"))
   end
   device:set_field("random_state", "Inactive", {persist = true})
  end

  -- restore forced level
  if device:get_field("forced_Level") == nil  then
    local forced_level= device:get_latest_state("main", forced_On_Level.ID, forced_On_Level.forcedOnLevel.NAME)
    if forced_level == nil then forced_level= 0 end
     device:set_field("forced_Level", forced_level, {persist = true})
  end
  device:emit_event(forced_On_Level.forcedOnLevel(device:get_field("forced_Level")))

  -- restore last level
  if device:get_field("last_Level") == nil  then
    device:set_field("last_Level", device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME), {persist = true})
  end
  if device:get_field("last_Level") == nil then
    if device:get_field("forced_Level") > 0 then
      --device:set_field("last_Level", device:get_field("forced_Level"), {persist = true})
    else
      device:set_field("last_Level", 100, {persist = true})
    end
  end

  --- ReStart Timer color chanaging function 
  if device:supports_capability_by_id(capabilities.colorControl.ID) then
    if device:get_field("colorTimer") == nil then
      device:set_field("colorTimer", 2 , {persist = true})
      device:emit_event(color_Change_Timer.colorChangeTimer(2))
    end

    if device:get_field("colorChangeModeList") == nil then
      device:set_field("colorChangeModeList", "Random", {persist = true})
      device:emit_event(color_Change_Mode.colorChangeMode("Random"))
    end

    if device:get_field("colorChanging") == "Active" then 
      device:set_field("colorChanging", "Continue", {persist = true})
      if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NOT Child device)
        driver_handler.color_Changing_handler(self,device,"Continue")
      end
    else
      device:emit_event(color_Changing.colorChanging("Inactive"))
    end
  end

  -- initialice mirror_Group_Function status
  if device:get_field("mirror_group_function") == nil then
    device:set_field("mirror_group_function", "Inactive", {persist = true})
  end
  device:emit_event(mirror_Group_Function.mirrorGroupFunction(device:get_field("mirror_group_function")))

  -- initialice effects_Set_Command_Function status
  if device:get_field("effects_set_command") == nil then
    device:set_field("effects_set_command", "Inactive", {persist = true})
  end
  device:emit_event(effects_Set_Command.effectsSetCommand(device:get_field("effects_set_command")))

  ----- restart timers if is ON ----------
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NOT Child device)

    --- restart random on-off if active
    if device.preferences.logDebugPrint == true then
      print("random_state >>>>>",device:get_field("random_state"))
    end
    if device:get_field("random_state") == "Active" then  
      driver_handler.random_on_off_handler(self,device,"Active")  
    end
  
    --- restart Circadian timer if activated
    if circadian_Running[device] == "running" and circadian[device] == "Active" then
      driver_handler.circadian_handler(self, device)
    end
  
    --- restart prog-On if is running
    --print("<< onStatus >>",device:get_field("onStatus"))
    if device:get_field("onStatus") == "running" then
      onStartDim[device] = -1 -- this value will made continue the dimming On with last levll
      driver_handler.on_handler (self, device, onStartDim[device])
    end
  
     --- restart prog-Off if is running
     --print("<< offStatus >>",device:get_field("offStatus"))
    if device:get_field("offStatus") == "running" then
      driver_handler.off_handler (self, device, "off")
    end

    -- restart effects timer command if on
    if device:get_field("effects_set_command") == nil  then
      device:set_field("effects_set_command", "Inactive", {persist = true})
    elseif device:get_field("effects_set_command") == "BlinkON" then
      driver_handler.effects_Set_handler(self, device, "BlinkON")
    end

  end
end

---- do_removed device procedure: delete all device data
function driver_handler.do_removed(self,device)
  for id, value in pairs(device_running) do
    if device_running[id] == device then
    device_running[device] =nil
    progOn[device] = nil
    onStatus[device] = nil
    onTotalSteps[device] = nil
    onStep[device] = nil
    onNewLevel[device] = nil
    onStepLevel[device] = nil
    onStartDim[device]= nil
    onTimer[device]= nil
    dimJump[device] = nil
    progOff[device] = nil
    offStatus[device] =nil
    offTotalSteps[device] = nil
    offStep[device] = nil
    offNewLevel[device] = nil
    offStepLevel[device] = nil
    offLevelStart[device] = nil
    offTimer[device]= nil
    offJump[device] = nil

    random_Step[device] = nil
    random_totalStep[device] = nil
    random_timer[device] = nil
    circadian_Running[device] = nil
    circadian[device] = nil

    hueMin[device] = nil
    hueMax[device] = nil
    hueStep[device] = nil
   end
  end
  
  -----print tables of devices no removed from driver ------
  if device.preferences.logDebugPrint == true then
    for id, value in pairs(device_running) do
      print("<<<<<<<<< device_running[id] >>>>>>>>>>",device_running[id])
      print("progOn=",progOn[id])
      print("onStatus=",onStatus[id])
      print("onTotalSteps=", onTotalSteps[id])
      print("onStep=", onStep[id])
      print("deviceonNewLevel=",onNewLevel[id])
      print("offStepLevel=",onStepLevel[id])
      print("dimJump=", dimJump[id])
      print("progOff=",progOff[id])
      print("offStatus=", offStatus[id])
      print("offTotalSteps=", offTotalSteps[id])
      print("offStep=", offStep[id])
      print("offNewLevel=", offNewLevel[id])
      print("offStepLevel=", offStepLevel[id])
      print("offLevelStart=", offLevelStart[id])
      print("offJump=", offJump[id])
      print("random_Step=",random_Step[id])
      print("random_totalStep=",random_totalStep[id])
      print("random_timer=",random_timer[id])
      print("circadian_Running=",circadian_Running[id])
      print("circadian=",circadian[id])
      print("hueMin=", hueMin[id])
      print("hueMax=", hueMax[id])
      print("hueStep=", hueStep[id])
    end
  end
end

-----------------------------------------------
---------------- Timers Cancel ----------------
local function timers_Cancel(driver,device)
  if device.preferences.logDebugPrint == true then
    print("<<< timers_Cancel >>>")
  end
  if circadian_Running[device] == "stopped" or circadian[device] == "Inactive" then
    if onStatus[device] == "running" or device:get_field("onStatus") == "running" then
      onStatus[device] ="stopped"
      device:set_field("onStatus", onStatus[device], {persist = true})
    end
    if offStatus[device] == "running" or device:get_field("offStatus") == "running" then
      offStatus[device] = "stopped"
      device:set_field("offStatus", offStatus[device], {persist = true})
    end

    set_status_timer = device:get_field("timer_random")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        --print("set_status_timer >>>",set_status_timer)
        print("<<<<< Cancelando Random timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_random", nil)
    end
    set_status_timer = device:get_field("timer_progOn")
    if set_status_timer then
      print("<<<<< Cancelando ProgOn timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_progOn", nil)
    end
    set_status_timer = device:get_field("timer_progOff")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancelando ProgOff timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_progOff", nil)
    end
    set_status_timer = device:get_field("timer_circadian")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancelando Circadian timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_circadian", nil)
    end
    set_status_timer = device:get_field("timer_color")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancelando Color Changing timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_color", nil)
    end
  end
end

--- Update preferences after infoChanged recived---
function driver_handler.do_Preferences (self, device)
  for id, value in pairs(device.preferences) do
    if device.preferences.logDebugPrint == true then
      print("device.preferences[infoChanged]=",id, device.preferences[id])
    end
    oldPreferenceValue = device:get_field(id)
    newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      if device.preferences.logDebugPrint == true then
        print("<<< Preference changed:",id,"Old Value:",oldPreferenceValue,"New Value:", newParameterValue)
      end

    --- Groups code preference value changed
      if id == "groupAdd" then
        if device.preferences[id] > 0 then
          print("Add Groups >>>>>>>>>>>>>>>>>")
          local data = device.preferences[id]
          device:send(Groups.server.commands.AddGroup(device, data, "Group"..tostring(data)))
          device:send(Groups.server.commands.GetGroupMembership(device, {}))
        else
          device:send(Groups.server.commands.GetGroupMembership(device, {}))
        end
      end
 
      if id == "groupRemove" then
        print("Remove Groups >>>>>>>>>>>>>>>>>")
        if device.preferences[id] > 0 then
        device:send(Groups.server.commands.RemoveGroup(device, device.preferences[id]))
        else
        device:send(Groups.server.commands.RemoveAllGroups(device, {}))
        end
        device:send(Groups.server.commands.GetGroupMembership(device, {}))
      end

     ------ Change profile RGBW color temperature
      if id == "changeProfile" then
        if newParameterValue == "20006500" then
          print("<< rgbw-level-colortemp-2000-6500 >>")
          device:try_update_metadata({profile = "rgbw-level-colortemp-2000-6500"})
        elseif newParameterValue == "27006500" and device.preferences.colorTempMinim >= 2700 then
          print("<< rgbw-level-colortemp-2700-6500 >>")
          device:try_update_metadata({profile = "rgbw-level-colortemp-2700-6500"})
        elseif newParameterValue == "22004000" and device.preferences.colorTempMaxim <= 4000 and device.preferences.colorTempMinim >= 2200 then
          print("<< rgbw-level-colortemp-2200-4000 >>")
          device:try_update_metadata({profile = "rgbw-level-colortemp-2200-4000"})
        elseif newParameterValue == "RGB" then
          print("<< level-rgb-rgbw >>")
          -- stop circadian function if active
          if circadian[device] == "Active" then
            ---- Timers Cancel ------
            circadian_Running[device] = "stopped"
            device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
            timers_Cancel(self,device)
            device:emit_event(circadian_Light.circadian("Inactive"))
            circadian[device] = "Inactive"
            device:set_field("circadian[device]", circadian[device], {persist = true})
          end

          device:try_update_metadata({profile = "level-rgb-rgbw"})
        end 
      end
      --- Configure on-off cluster, attributte 0x8002 and 4003 to value restore state in preferences
      if id == "restoreState" then
        if device.preferences.logDebugPrint == true then
          print("<<< Write restore state >>>")
        end
        local value_send = tonumber(newParameterValue)
        local data_value = {value = value_send, ID = 0x30}
        local cluster_id = {value = 0x0006}
        --write atribute for standard devices
        local attr_id = 0x4003
        write.write_attribute_function(device, cluster_id, attr_id, data_value)

        --write atribute for Tuya devices (Restore previous state = 0x02)
        if newParameterValue == "255" then data_value = {value = 0x02, ID = 0x30} end
        attr_id = 0x8002
        write.write_attribute_function(device, cluster_id, attr_id, data_value)
      end
      -- Call to Create child device
      if id == "groupChild" then
        if oldPreferenceValue ~= nil and newParameterValue == true then
         child_devices.create_new_device(self, device, "main", "child-rgbw-2000-6500")
        end 
      end
    end
  end
  
  -- ********* Emit event for new driver version availabale ********

  --local new_version = " New Driver Version 6 Available: " .. os.date("%Y:%m:%d",os.time())
  --print("new_version >>>>>",new_version)
  --device:emit_event(driver_Version.driverVersion(new_version))

  -- ***************************************************************

  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len)
  local firmware_full_version = device.data.firmwareFullVersion
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

---------------------------------------------------------
------------- color_Changing_handler --------------------

function driver_handler.color_Changing_handler(driver,device,command)

  if command.args.value == device:get_field("colorChanging") then return end

    ---- Timers Cancel ------
    timers_Cancel(driver,device)

  local colorChanging = device:get_field("colorChanging")

  if colorChanging ~= "Continue" then
      -----cancel progressive ON & OFF and Circadian
    if progOn[device] == "Active" then
      progOn[device] = "Inactive"
      device:set_field("progOn[device]", progOn[device], {persist = true})
      device:emit_event(prog_On.progOn("Inactive"))
    end
    if progOff[device] == "Active" then
     progOff[device] = "Inactive"
      device:set_field("progOff[device]", progOff[device], {persist = true})
      device:emit_event(prog_Off.progOff("Inactive"))
    end
    if circadian[device] == "Active" then
      device:emit_event(circadian_Light.circadian("Inactive"))
      circadian[device] = "Inactive"
      device:set_field("circadian[device]", circadian[device], {persist = true})
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    end
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:set_field("random_state", "Inactive", {persist = true})
      device:emit_event(random_Next_Step.randomNext("Inactive"))
    end
  end

  if colorChanging == "Continue" then
    colorChanging = "Active"
  else
    if device.preferences.logDebugPrint == true then
      print("colorChanging Value", command.args.value)
    end
    colorChanging = command.args.value
  end

  if colorChanging == "Inactive" then
    device:set_field("colorChanging", colorChanging, {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))

  else
    device:set_field("colorChanging", colorChanging, {persist = true})
    device:emit_event(color_Changing.colorChanging("Active"))
    
    --- Set ColorChangeMode
    local colorChangeMode = device:get_field("colorChangeMode")
    if colorChangeMode == nil then colorChangeMode = 1 end
    local colorTimer = device:get_field("colorTimer")
    if colorTimer == nil then colorTimer = 1 end
    -- Set steps numbers to 0
    local stepsNumber = device:get_field("stepsNumber")
    if stepsNumber == nil then stepsNumber = 0 end
    local stepsNumberMax = device:get_field("stepsNumberMax")
    if stepsNumberMax == nil then stepsNumberMax = 100 end
    local direction = math.random(1, 10)
    if direction <= 5 then direction = 1 else direction = -1 end
    --print("<<< Direction >>>", direction)

    local colorChangeModeList = device:get_field("colorChangeModeList")
    hueMin[device], hueMax[device] = 1, 255
    local satMin, satMax = 190, 240
    local saturationStep = 2
    hueStep[device] = -1
    if colorChangeModeList == "Random" then
      colorChangeMode = 2
    elseif colorChangeModeList == "AllModes" then
      colorChangeMode = math.random(1, 2)
      colorTimer = math.random(1, 2)
      stepsNumberMax = math.random(50, 100)
      saturationStep = 0.5
      hueStep[device] = -2 * direction
      device:emit_event(color_Change_Timer.colorChangeTimer(colorTimer))
    else
      colorChangeMode = 1
      if colorChangeModeList == "Continuousallcolors" then
        hueMin[device] = 1
        hueMax[device] = 255
        saturationStep = 0.5
        hueStep[device] = -2 * direction
      elseif colorChangeModeList == "Continuousredorange" then
        hueMin[device] = 1
        hueMax[device] = 34
      elseif colorChangeModeList == "Continuousorangeyellow" then
        hueMin[device] = 20
        hueMax[device] = 48
      elseif colorChangeModeList == "Continuousyellowgreen" then
        hueMin[device] = 36
        hueMax[device] = 114
      elseif colorChangeModeList == "Continuousgreen" then
        hueMin[device] = 51
        hueMax[device] = 114
      elseif colorChangeModeList == "Continuousgreenblue" then
        hueMin[device] = 51
        hueMax[device] = 191
      elseif colorChangeModeList == "Continuousblue" then
        hueMin[device] = 115
        hueMax[device] = 191
      elseif colorChangeModeList == "Continuousbluepurple" then
        hueMin[device] = 115
        hueMax[device] = 238
      elseif colorChangeModeList == "Continuouspurplered" then
        hueMin[device] = 193
        hueMax[device] = 255
      end
    end

    device:set_field("colorChangeMode", colorChangeMode, {persist = true})
    device:set_field("colorTimer",  colorTimer, {persist = true})
    device:set_field("stepsNumber",  stepsNumber, {persist = false})
    device:set_field("stepsNumberMax",  stepsNumberMax, {persist = false})

    local newSaturation = math.random(satMin, satMax)
    --print("<<<<< newSaturation >>>>>",newSaturation )
    device:set_field("newSaturation",  newSaturation, {persist = false})
    local newHue = math.random(hueMin[device], hueMax[device])
    --print("<<<<< newHue >>>>>",newHue)
    device:set_field("newHue", newHue, {persist = false})

    -- send zigbee On event
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
      device:send(zcl_clusters.OnOff.server.commands.On(device))
    end

    -- Emit first command and color event
    --print("ZLL device >>>>>>>",device:get_field("zll_xy"))
    if device:get_field("zll_xy") == "no" then
      --print("ZLL device No >>>>>>>",device:get_field("zll_xy"))
      device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToHueAndSaturation(device, newHue, newSaturation, 0x0000))    
    else
      --print("<<<< convert to x,y >>>>")
      local hue = math.floor(newHue / 0xFE * 100) > 99 and 99 or math.floor(newHue / 0xFE * 100)
      local sat = math.floor(newSaturation / 0xFE * 100)
      local x, y, Y = 0,0,0
      if device:get_manufacturer()=="IKEA of Sweden" then
       x, y, Y = utils.safe_hsv_to_xy(hue, sat)
      else
        x, y, Y = utils_xy.safe_hsv_to_xy(hue, sat)
      end
      device:set_field(Y_TRISTIMULUS_VALUE, Y)
      device:set_field(CURRENT_X, x)
      device:set_field(CURRENT_Y, y)
      if device.preferences.logDebugPrint == true then
        print(">>>>> CURRENT_X=",x)
        print(">>>>> CURRENT_Y=",y)
        print(">>>>> Y_TRISTIMULUS_VALUE=",Y)
      end

      device:send(ColorControl.commands.MoveToColor(device, x, y, 0x0000))
    end
    device:emit_event_for_endpoint("main",capabilities.colorControl.hue({value = math.floor(newHue / 0xFE * 100)}, {visibility = {displayed = false }}))
    device:emit_event_for_endpoint("main",capabilities.colorControl.saturation({value = math.floor(newSaturation / 0xFE * 100)}, {visibility = {displayed = false }}))
    --child device emit event
    local child_device = device:get_child_by_parent_assigned_key("main")
    if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
      child_device:emit_event(capabilities.colorControl.hue({value = math.floor(newHue / 0xFE * 100)}, {visibility = {displayed = false }}))
      child_device:emit_event(capabilities.colorControl.saturation({value = math.floor(newSaturation / 0xFE * 100)}, {visibility = {displayed = false }}))
    end

    ------ Timer Color Changing activation
    set_status_timer = device.thread:call_on_schedule(colorTimer,
    function ()
      
      -- Incremet steps for AllModes Ramdom Mode
      if colorChangeModeList == "AllModes" then
       stepsNumber = device:get_field("stepsNumber")
       stepsNumber = stepsNumber + 1
       if stepsNumber >= device:get_field("stepsNumberMax") and colorChangeModeList == "AllModes" then
        device:set_field("colorChanging", "Continue", {persist = true})
        driver_handler.color_Changing_handler(driver,device,"Continue")
        stepsNumber = 0
       end
       device:set_field("stepsNumber",  stepsNumber, {persist = false})

       if device.preferences.logDebugPrint == true then
        print("<< stepsNumber, stepsNumberMax >>", stepsNumber, stepsNumberMax)
       end

       colorChangeMode = device:get_field("colorChangeMode")
       if colorChangeMode == nil then colorChangeMode = 2 end
      end

      if device.preferences.logDebugPrint == true then
        print("<<<<<<<< Color Changing Mode >>>>>>>", colorChangeMode)
        print("*** color Timer ***", colorTimer)
      end

      if colorChangeMode == 1 then
        newSaturation = newSaturation + saturationStep
        if newSaturation > satMax then 
          saturationStep = saturationStep * -1
          newSaturation = satMax
        elseif newSaturation < satMin then
          saturationStep = saturationStep * -1
          newSaturation = satMin
        end
        newHue = newHue + hueStep[device]
        if newHue > hueMax[device] then
          if colorChangeModeList == "Continuousallcolors" then
            newHue = hueMin[device]
          else
            hueStep[device] = hueStep[device] * -1
            newHue = hueMax[device]
          end
        elseif newHue < hueMin[device] then
          if colorChangeModeList == "Continuousallcolors" then
            newHue = hueMax[device]
          else
            hueStep[device] = hueStep[device] * -1
            newHue = hueMin[device]
          end
        end
   
      elseif colorChangeMode == 2 then
        newSaturation = math.random(satMin, satMax)
        newHue = math.random(hueMin[device], hueMax[device])
        if device.preferences.logDebugPrint == true then
          print("<<<<< newSaturation >>>>>",newSaturation )
          print("<<<<< newHue >>>>>",newHue)
        end
      end
    
      -- Emit command and color event
      --print("ZLL device >>>>>>>",device:get_field("zll_xy"))
      if device:get_field("zll_xy") == "no" then
        --print("ZLL device No >>>>>>>",device:get_field("zll_xy"))
        device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToHueAndSaturation(device, newHue, newSaturation, 0x0000))    
      else
        --print("<<<< convert to x,y >>>>")
        local hue = math.floor(newHue / 0xFE * 100) > 99 and 99 or math.floor(newHue / 0xFE * 100)
        local sat = math.floor(newSaturation / 0xFE * 100)
        local x, y, Y = 0,0,0
        if device:get_manufacturer()=="IKEA of Sweden" then
         x, y, Y = utils.safe_hsv_to_xy(hue, sat)
        else
          x, y, Y = utils_xy.safe_hsv_to_xy(hue, sat)
        end
        device:set_field(Y_TRISTIMULUS_VALUE, Y)
        device:set_field(CURRENT_X, x)
        device:set_field(CURRENT_Y, y)
        if device.preferences.logDebugPrint == true then
          print(">>>>> CURRENT_X=",x)
          print(">>>>> CURRENT_Y=",y)
          print(">>>>> Y_TRISTIMULUS_VALUE=",Y)
        end

        device:send(ColorControl.commands.MoveToColor(device, x, y, 0x0000))
      end
      
      device:emit_event_for_endpoint("main",capabilities.colorControl.hue({value = math.floor(newHue / 0xFE * 100)}, {visibility = {displayed = false }}))
      device:emit_event_for_endpoint("main",capabilities.colorControl.saturation({value = math.floor(newSaturation / 0xFE * 100)}, {visibility = {displayed = false }}))
      --child device emit event
      child_device = device:get_child_by_parent_assigned_key("main")
      if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
        child_device:emit_event(capabilities.colorControl.hue({value = math.floor(newHue / 0xFE * 100)}, {visibility = {displayed = false }}))
        child_device:emit_event(capabilities.colorControl.saturation({value = math.floor(newSaturation / 0xFE * 100)}, {visibility = {displayed = false }}))
      end
    end
     ,'ColorChanging')
     device:set_field("timer_color", set_status_timer) 
  end
end

---------------------------------------------------------
--------------- color_Change_Timer_handler --------------

function driver_handler.color_Change_Timer_handler(driver, device, command)
  if command.args.value == device:get_field("colorTimer") then return end
  if device.preferences.logDebugPrint == true then
    print("colorChangeTimer Value >>>", command.args.value)
  end
  local colorTimer = command.args.value
  device:set_field("colorTimer", colorTimer, {persist = true})
  device:emit_event(color_Change_Timer.colorChangeTimer(colorTimer))

  --- goto color chanaging function
  if device:get_field("colorChanging") == "Active" then 
    device:set_field("colorChanging", "Continue", {persist = true})
    driver_handler.color_Changing_handler(driver,device,"Continue")
  end
end

--------------------------------------------------------
------------- color_Change_Mode_handler ----------------

function driver_handler.color_Change_Mode_handler(driver,device,command)
  if command.args.value == device:get_field("colorChangeModeList") then return end
  if device.preferences.logDebugPrint == true then
    print("colorChangeMode Value >>>", command.args.value)
  end
  local colorChangeModeList = command.args.value
  device:set_field("colorChangeModeList", colorChangeModeList, {persist = true})
  device:emit_event(color_Change_Mode.colorChangeMode(colorChangeModeList))

  --- goto color chanaging function
  if device:get_field("colorChanging") == "Active" then 
    device:set_field("colorChanging", "Continue", {persist = true})
    driver_handler.color_Changing_handler(driver,device,"Continue")
  end
end

 --------------------------------------------------------
 --------- Handler Random ON-OFF ------------------------

function driver_handler.random_on_off_handler(driver,device,command)
  if command == nil then
    if command.args.value == device:get_field("random_state") then return end
  end
  local random_state = "-"
  if command == "Active" then -- re-actiate timer random due to driver init or hub reboot
    random_state = "Active"
  else
    random_state = command.args.value
  end
  if device.preferences.logDebugPrint == true then
    print("randomOnOff Value >>>", random_state)
  end
  if random_state == "Inactive" then

    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:set_field("random_state", "Inactive", {persist = true})
    -- send zigbee event
    device:send(OnOff.server.commands.Off(device))
    if device:supports_capability_by_id(capabilities.colorTemperature.ID) then
      circadian_Running[device]= "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    end

    ---- All Timers Cancel ------
    timers_Cancel(driver,device)

    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    --emit time for next change
    local nextChange = "Inactive"
    device:emit_event(random_Next_Step.randomNext(nextChange))

  elseif random_state == "Active" then

    device:emit_event(random_On_Off.randomOnOff("Active"))
    device:set_field("random_state", "Active", {persist = true})

    -----cancel progressive ON & OFF, Circadian and Color Changing
    if progOn[device] == "Active" then
      progOn[device] = "Inactive"
      device:set_field("progOn[device]", progOn[device], {persist = true})
      device:emit_event(prog_On.progOn("Inactive"))
    end
    if progOff[device] == "Active" then
      progOff[device] = "Inactive"
      device:set_field("progOff[device]", progOff[device], {persist = true})
      device:emit_event(prog_Off.progOff("Inactive"))
    end
    if device:supports_capability_by_id(capabilities.colorTemperature.ID) and circadian[device] == "Active" then
      device:emit_event(circadian_Light.circadian("Inactive"))
      circadian[device] = "Inactive"
      device:set_field("circadian[device]", circadian[device], {persist = true})
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    end
    if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = true})
    end

    ---- All Timers Cancel ------
    timers_Cancel(driver,device)

    random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
    random_Step[device] = 0
    random_totalStep[device] = math.ceil(random_timer[device] / 30)

    local nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)

    --emit time for next change
    device:emit_event(random_Next_Step.randomNext(nextChange))
    if device.preferences.logDebugPrint == true then
      print("random_totalStep=",random_totalStep[device])
      print("NextChange=",nextChange)
    end

    ------ Timer activation
    set_status_timer = device.thread:call_on_schedule(30,
      function ()
        random_Step[device] = random_Step[device] + 1
        if random_Step[device] >= random_totalStep[device] then
          -- emit on-off command
          if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
            device:send(OnOff.server.commands.Off(device))
          else
            device:send(OnOff.server.commands.On(device))
          end

          random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
          random_Step[device] = 0
          random_totalStep[device] = math.ceil(random_timer[device] / 30)
          nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)

          --emit time for next change
          device:emit_event(random_Next_Step.randomNext(nextChange))
          if device.preferences.logDebugPrint == true then
            print("NEW-random_totalStep=",random_totalStep[device])
            print("NextChange=",nextChange)
          end
        end
      end
      ,'Random-ON-OFF')
      device:set_field("timer_random", set_status_timer) 
  end
end

----------------------------------------------------------------
-------- Progressive ON activation & deativation ---------------

function driver_handler.prog_On_handler(driver, device, command)
  if command.args.value == device:get_field("progOn[device]") then return end
  if device.preferences.logDebugPrint == true then
    print("ProgOn Value >>>", command.args.value)
  end
  if command.args.value == "Inactive" then
    progOn[device] = "Inactive"
    device:set_field("progOn[device]", progOn[device], {persist = true})
    device:emit_event(prog_On.progOn("Inactive"))
      if onStatus[device] == "running" then
        ---- Timers Cancel ------
        timers_Cancel(driver,device)
      end
  elseif command.args.value == "Active" then
    progOn[device] = "Active"
    device:set_field("progOn[device]", progOn[device], {persist = true})
    device:emit_event(prog_On.progOn("Active"))
    
    ---- Cancel Random On-OFF color Changing and Circadian
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:emit_event(random_Next_Step.randomNext("Inactive"))
      device:set_field("random_state", "Inactive", {persist = true})

    elseif circadian[device] == "Active" then
      device:emit_event(circadian_Light.circadian("Inactive"))
      circadian[device] = "Inactive"
      device:set_field("circadian[device]", circadian[device], {persist = true})
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})

    elseif device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = true})

    end
    ---- Timers Cancel ------
    timers_Cancel(driver,device)
  end
  
end

-----------------------------------------------------------------
-------- Progressive OFF activation & deativation ---------------

function driver_handler.prog_Off_handler(driver, device, command)
  if command.args.value == device:get_field("progOff[device]") then return end
  if device.preferences.logDebugPrint == true then
    print("ProgOff Value >>>", command.args.value)
  end
  if command.args.value == "Inactive" then
    progOff[device] = "Inactive"
    device:set_field("progOff[device]", progOff[device], {persist = true})
    device:emit_event(prog_Off.progOff("Inactive"))
    if offStatus[device] == "running" then
      ---- Timers Cancel ------
      timers_Cancel(driver,device)
    end
  elseif command.args.value == "Active" then
    progOff[device] = "Active"
    device:set_field("progOff[device]", progOff[device], {persist = true})
    device:emit_event(prog_Off.progOff("Active"))

    ---- Cancel Random On-OFF color Changing and Circadian
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:emit_event(random_Next_Step.randomNext("Inactive"))
      device:set_field("random_state", "Inactive", {persist = true})
    elseif circadian[device] == "Active" then
      device:emit_event(circadian_Light.circadian("Inactive"))
      circadian[device] = "Inactive"
     device:set_field("circadian[device]", circadian[device], {persist = true})
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    elseif device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = true})
    end
    ---- Timers Cancel ------
    timers_Cancel(driver,device)
  end
end

-----------------------------------------------
--------- level_Steps_handler -----------------

function driver_handler.level_Steps_handler(driver, device, command)

  ---- Cancel Random On-OFF color Changing and Circadian stopped
  if device:get_field("random_state") == "Active" then
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    device:set_field("random_state", "Inactive", {persist = true})
  end
  if circadian_Running[device] == "running" then
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
  end
  if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})
  end

  ---- Timers Cancel ------
  timers_Cancel(driver,device)

  ---- next level calculation  
  if device.preferences.logDebugPrint == true then
    print("Level Steps Value =", command.args.value)
  end
  local level = command.args.value
  device:emit_event(level_Steps.levelSteps(level))
  
  local direction = 0x00
  if level < 0 then direction = 0x01 end

  if device.preferences.levelTransTime == 0 then
    local command1 = zcl_clusters.Level.commands.StepWithOnOff(device, direction, math.floor((math.abs(level)/100.0 * 254)), 0xFFFF)
    if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
      command1.body.zcl_body.options_mask = nil
      command1.body.zcl_body.options_override = nil
    end
    device:send(command1)
    --device:send(zcl_clusters.Level.commands.StepWithOnOff(device, direction, math.floor((math.abs(level)/100.0 * 254)), 0xFFFF))
  else
    local command1 = zcl_clusters.Level.commands.StepWithOnOff(device, direction, math.floor((math.abs(level)/100.0 * 254)), device.preferences.levelTransTime * 10)
    if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
      command1.body.zcl_body.options_mask = nil
      command1.body.zcl_body.options_override = nil
    end
    device:send(command1)
    --device:send(zcl_clusters.Level.commands.StepWithOnOff(device, direction, math.floor((math.abs(level)/100.0 * 254)), math.floor(device.preferences.levelTransTime * 10)))
  end

  level = level + device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)

  if level < 0 then 
    level = 0 
  elseif level > 100 then
    level = 100
  end
  device:set_field("last_Level", level, {persist = true})

  local level_read = function(d)
    device:send_to_component(command.component, zcl_clusters.Level.attributes.CurrentLevel:read(device))
  end
  device.thread:call_with_delay(device.preferences.levelTransTime + 1, level_read, "setLevel delayed read")

end

-----------------------------------------------
--------- color_Temperature_Steps_handler -----------------

function driver_handler.color_Temperature_Steps_handler(driver, device, command)

  if device.preferences.logDebugPrint == true then
    print("Color Temperature Steps Value >>>", command.args.value)
  end

    ---- Cancel Random On-OFF color Changing and Circadian stopped
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:emit_event(random_Next_Step.randomNext("Inactive"))
      device:set_field("random_state", "Inactive", {persist = true})
    end
    if circadian_Running[device] == "running" then
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    end
    if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = true})
    end
  
    ---- Timers Cancel ------
    timers_Cancel(driver,device)

    ---Next Color Temperature calculation
    local colorTemp = command.args.value
    device:emit_event(color_Temperature_Steps.colorTempSteps(colorTemp))
    colorTemp = math.floor(utils.round(colorTemp + device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME)))
    
    -- check if colortemp is limited
    if device.preferences.limitColorTemp == true then 
      if colorTemp > device.preferences.colorTempMaxim then 
        colorTemp = tonumber(math.floor(device.preferences.colorTempMaxim))
      elseif colorTemp < device.preferences.colorTempMinim then 
        colorTemp = tonumber(math.floor(device.preferences.colorTempMinim))
      end
    end

    --print("colorTemp", colorTemp)
    device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
    local colorTemp_Mireds = utils.round(1000000 / colorTemp)
    --print("colorTemp Mired", colorTemp_Mireds)
    device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, math.floor(device.preferences.tempTransTime * 10)))

    local color_temp_read = function(d)
      device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
    end
    device.thread:call_with_delay(device.preferences.tempTransTime + 1, color_temp_read, "setColorTemp delayed read")
end

-----------------------------------------------
----------- circadian_Light_handler -----------

function driver_handler.circadian_Light_handler(driver, device, command)
  if command.args.value == device:get_field("circadian[device]") then return end
  if device.preferences.logDebugPrint == true then
    print("Circadian Value", command.args.value)
  end

  if command.args.value == "Inactive" then
    device:emit_event(circadian_Light.circadian("Inactive"))
    circadian[device] = "Inactive"
    device:set_field("circadian[device]", circadian[device], {persist = true})
    
    ---- Timers status ------
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    ---- Timers Cancel ------
    --timers_Cancel(driver,device)

  else
    device:emit_event(circadian_Light.circadian("Active"))
    circadian[device] = "Active"
    device:set_field("circadian[device]", circadian[device], {persist = true})
    -----cancel progressive ON & OFF color Changing and Random On-Off
    if progOn[device] == "Active" then
      progOn[device] = "Inactive"
      device:set_field("progOn[device]", progOn[device], {persist = true})
      device:emit_event(prog_On.progOn("Inactive"))
    end
    -- cancel progressive Off --------
    if progOff[device] == "Active" then
      progOff[device] = "Inactive"
      device:set_field("progOff[device]", progOff[device], {persist = true})
      device:emit_event(prog_Off.progOff("Inactive"))
    end
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:set_field("random_state", "Inactive", {persist = true})
      device:emit_event(random_Next_Step.randomNext("Inactive"))
    --end
    elseif device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = true})
    end
  end
  ---- Timers Cancel ------
  timers_Cancel(driver,device)  
end

----------------------------------------------- 
---------- Circadian rhythm Timer run-------------------
function driver_handler.circadian_handler(self, device)

  if device.preferences.logDebugPrint == true then
    print("<<<<<<<<<<<<<<< In Circadian timer On >>>>>>>>>>>>>>>>")
  end

  local colorTemp = device.preferences.colorTempMinim --2700
  local colorTempHour = device.preferences.colorTempMinim --2700
  local colorTempNextHour = device.preferences.colorTempMinim --2700
  local newLevel = (device.preferences.circadLevelMin + device.preferences.circadLevelMax) / 2
  local localHour= os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600))
  local localNextHour= os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600) + 3600)
  local localMinutes= os.date("%M",os.time() + device.preferences.localTimeOffset)
  if device.preferences.logDebugPrint == true then
    print("localHour, localMinutes =", localHour, localMinutes)
  end
  if tonumber(localHour) > 5 and tonumber(localHour) < 18 then
    circadian_Running[device] = "running"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    if device.preferences.logDebugPrint == true then
      print("circadian_Running=", circadian_Running[device])
    end
    -- set initial color temperature 
    colorTempHour = device.preferences.colorTempMinim + ((device.preferences.colorTempMaxim - device.preferences.colorTempMinim) * math.sin(math.rad(circadian_Time_Angle[localHour])))
    colorTempNextHour = device.preferences.colorTempMinim + ((device.preferences.colorTempMaxim - device.preferences.colorTempMinim) * math.sin(math.rad(circadian_Time_Angle[localNextHour])))
    --print("TempHour, TempNextHour",colorTempHour,colorTempNextHour)
    colorTemp =  math.floor(utils.round(colorTempHour + ((colorTempNextHour - colorTempHour) * tonumber(localMinutes) /60)))
    --- new level calculation
    newLevel = math.ceil(device.preferences.circadLevelMin + (((colorTemp - device.preferences.colorTempMinim) / (device.preferences.colorTempMaxim - device.preferences.colorTempMinim)) * (device.preferences.circadLevelMax - device.preferences.circadLevelMin)))
    --print("New Level=", newLevel)

    -- detect if forced Level actived
    if device:get_field("forced_Level") > 0 then
      if newLevel >= device:get_field("forced_Level") then
        newLevel = device:get_field("forced_Level")
      end
    end
    device:set_field("last_Level", newLevel, {persist = true})

    --send initial values
    if device:get_manufacturer() == "IKEA of Sweden" then
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0x0))
    else
      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(newLevel/100.0 * 254), 0xFFFF)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0xFFFF)) 
    end
    --print("colorTemp =", colorTemp)
    device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
    local colorTemp_Mireds = utils.round(1000000 / colorTemp)
    --print("colorTemp Mired", colorTemp_Mireds)
    device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
    local color_temp_read = function(d)
      device:send_to_component("main", zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
    end
    device.thread:call_with_delay(2, color_temp_read, "setColorTemp delayed read")

    ---- Set timer for circadian cycle
    set_status_timer = device.thread:call_on_schedule(300, 
    function ()
      localHour= os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600))
      localNextHour= os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600) + 3600)
      localMinutes= os.date("%M",os.time() + device.preferences.localTimeOffset)
      if device.preferences.logDebugPrint == true then
        print("localHour, localMinutes =", localHour, localMinutes)
      end
      if tonumber(localHour) > 5 and tonumber(localHour) < 18 then

        --- New colorTemperature Calculation
        colorTempHour = device.preferences.colorTempMinim + ((device.preferences.colorTempMaxim - device.preferences.colorTempMinim) * math.sin(math.rad(circadian_Time_Angle[localHour])))
        colorTempNextHour = device.preferences.colorTempMinim + ((device.preferences.colorTempMaxim - device.preferences.colorTempMinim) * math.sin(math.rad(circadian_Time_Angle[localNextHour])))
        colorTemp =  math.floor(utils.round(colorTempHour + ((colorTempNextHour - colorTempHour) * tonumber(localMinutes) /60)))
        --- new level calculation)
        newLevel = math.ceil(device.preferences.circadLevelMin + (((colorTemp - device.preferences.colorTempMinim) / (device.preferences.colorTempMaxim - device.preferences.colorTempMinim)) * (device.preferences.circadLevelMax - device.preferences.circadLevelMin)))

        if device.preferences.logDebugPrint == true then
          print("TempHour, TempNextHour",colorTempHour,colorTempNextHour)
          print("New Level=", newLevel)
        end

        -- detect if forced Level actived
        if device:get_field("forced_Level") > 0 then
          if newLevel >= device:get_field("forced_Level") then
            newLevel = device:get_field("forced_Level")
          end
        end
        device:set_field("last_Level", newLevel, {persist = true})

        --send values
        if device:get_manufacturer() == "IKEA of Sweden" then
          device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0x0))
        else
          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(newLevel/100.0 * 254), 0xFFFF)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0xFFFF)) 
        end

        --print("colorTemp =", colorTemp)
        device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
        colorTemp_Mireds = utils.round(1000000 / colorTemp)
        --print("colorTemp Mired", colorTemp_Mireds)
        device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
        color_temp_read = function(d)
          device:send_to_component("main", zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
        end
        device.thread:call_with_delay(2, color_temp_read, "setColorTemp delayed read")
      end
    end,
    "Circadian_timer")
    device:set_field("timer_circadian", set_status_timer)
  else
    if device.preferences.logDebugPrint == true then
      print("<<< Circadian time hour < 5 or > 17 >>>")
    end
    if device.preferences.circadianNightSetting == false then
      --print("<<<<<<< circadianNightSetting (false)>>>>>>>>>",device.preferences.circadianNightSetting)
      local on_Level = device:get_field("last_Level")
      -- detect if forced Level actived
      if device:get_field("forced_Level") > 0 then
        if on_Level >= device:get_field("forced_Level") then
          on_Level = device:get_field("forced_Level")
          device:set_field("last_Level", on_Level, {persist = true})
        end
      end
      if device.preferences.onTransTime == 0 then
        --device:send(OnOff.server.commands.On(device))
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1) 
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
      else
        --print("Turn On >>>>>>>>>>>>>>>>")
        if on_Level == nil then on_Level = device.preferences.onLevelEnd end
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), device.preferences.onTransTime * 10)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), math.floor(device.preferences.onTransTime * 10)))
      end
      device:send(OnOff.server.commands.On(device))
    else
      --print("<<<<<<< circadianNightSetting (true)>>>>>>>>>",device.preferences.circadianNightSetting)
      local on_Level = device.preferences.circadLevelMin
      device:set_field("last_Level", on_Level, {persist = true})
      if device:get_manufacturer() == "IKEA of Sweden" then
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0x0))
      else
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1) 
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF)) 
      end

      colorTemp = math.floor(device.preferences.colorTempMinim)
      device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
      local colorTemp_Mireds = utils.round(1000000 / colorTemp)
      device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
      device:send(OnOff.server.commands.On(device))
      local color_temp_read = function(d)
        device:send_to_component("main", zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
      end
      device.thread:call_with_delay(2, color_temp_read, "setColorTemp delayed read")
    end
  end
end

-----------------------------------------------
---------------- TURN ON handler --------------

function driver_handler.on_handler (driver, device, command)
  print("Turn On handler >>>>>>>>>>>")
      -- capability reference
  local attr = capabilities.switch.switch
    
  --if device.preferences.onTransTime == 0 then
    ----print(" <<<<< Turn On transition Time = = 0 >>>>>")
    --if device:get_field("last_Level") == nil or device:get_field("last_Level") < 1 then device:set_field("last_Level", device.preferences.onLevelEnd, {persist = true}) end

    ---- detect if forced Level actived
    --if device:get_field("forced_Level") > 0 then
      --device:set_field("last_Level", device:get_field("forced_Level"), {persist = true})
    --end
    ---- set level from preferences if current level < 1 ----
    --if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) == nil then
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device:get_field("last_Level")/100.0 * 254), 0xFFFF))
      --device:emit_event(capabilities.switchLevel.level(math.floor((device:get_field("last_Level")/ 254.0 * 100) + 0.5)))
    --elseif (device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)) < 1 then
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device:get_field("last_Level")/100.0 * 254), 0xFFFF))
      --device:emit_event(capabilities.switchLevel.level(math.floor((device:get_field("last_Level")/ 254.0 * 100) + 0.5)))
    --end
  --end

   ----- detect progressive turn On activated--
    if progOn[device]  ==  "Active" and circadian[device] == "Inactive" then
      if device.preferences.logDebugPrint == true then
        print ("turnOn.onStatus =", onStatus[device])
      end
      if onStatus[device] =="stopped" then

        if device.preferences.ifPushSwitch == "Change" or onStartDim[device] == -1 then
          --print("<<<<<<<< Estoy en change on start Dim")
          if onStartDim[device] == -1 then
            onStartDim[device] = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
          else
            onStartDim[device] = device.preferences.onLevelStart
            -- detect if forced Level actived
            if device:get_field("forced_Level") > 0 then
              if onStartDim[device] > device:get_field("forced_Level") then
                onStartDim[device] = device:get_field("forced_Level")
              end
            end
          end
        else
          onStartDim[device] = device.preferences.onLevelStart
          -- detect if forced Level actived
          if device:get_field("forced_Level") > 0 then
            if onStartDim[device] > device:get_field("forced_Level") then
              onStartDim[device] = device:get_field("forced_Level")
            end
          end
        end

      --ON dimming timer calculation
      local diff_level = device.preferences.onLevelEnd - onStartDim[device]
      if diff_level == 0 then 
        onTimer[device] = 1
      else
        onTimer[device] = math.abs(device.preferences.onTimeMax * 60 / diff_level)
        if onTimer[device] < 0.3 then onTimer[device] = 0.3 end
      end
      onTotalSteps[device] = math.floor(device.preferences.onTimeMax * 60 / onTimer[device])
      onStepLevel[device] = ((device.preferences.onLevelEnd - onStartDim[device])+ 0.1) / onTotalSteps[device]

      if device.preferences.logDebugPrint == true then
        print("<< onTimer =",onTimer[device])
        print ("turnOn.onTotalSteps =", onTotalSteps[device])
        print ("turnOn.onStepLevel =", onStepLevel[device])
      end

      onStep[device] = 0
      onStatus[device] ="running"
      device:set_field("onStatus", onStatus[device], {persist = true})

      -- set the initial level On
      onNewLevel[device] = onStartDim[device]
      onStep[device] = onStep[device] + 1

      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1) 
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF))

      device:send(OnOff.server.commands.On(device))
      device:emit_event(attr.on())

      ---- Change Temp Color if option activated -----
      if device.preferences.progLevelColor == "Yes" then
        local colorTemp =  math.floor((utils.round(onNewLevel[device])/100 * ((device.preferences.colorTempMaxim) - device.preferences.colorTempMinim)) + device.preferences.colorTempMinim)
        device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
        local colorTemp_Mireds= utils.round(1000000/colorTemp)
        device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
        device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
      end

      -------- turn on: timer dimming ON --------
      set_status_timer = device.thread:call_on_schedule(onTimer[device], 
      function ()
        if onStatus[device] =="running" then
          onStep[device] = onStep[device] + 1 
          onNewLevel[device] = onNewLevel[device] + onStepLevel[device]
          if device.preferences.logDebugPrint == true then
            print("onStep=",onStep[device])
          end
          if device.preferences.onLevelEnd >= device.preferences.onLevelStart then
            if onNewLevel[device] >= device.preferences.onLevelEnd or onStep[device] >= onTotalSteps[device] then 
              onNewLevel[device] = device.preferences.onLevelEnd
              onStatus[device] ="stopped"
              device:set_field("onStatus", onStatus[device], {persist = true})
              --cancel timer
              local timer = device:get_field("timer_progOn")
              if timer then
                if device.preferences.logDebugPrint == true then
                  print("<<< Cancel Prog On timer >>>")
                end
                device.thread:cancel_timer(timer)
                device:set_field("timer_progOn", nil)
              end             
            end
          else
            if onNewLevel[device] < device.preferences.onLevelEnd and onStep[device] >= onTotalSteps[device] then
              onNewLevel[device] = device.preferences.onLevelEnd
              onStatus[device] ="stopped"
              device:set_field("onStatus", onStatus[device], {persist = true})
              --cancel timer
              local timer = device:get_field("timer_progOn")
              if timer then
                if device.preferences.logDebugPrint == true then
                  print("<<< Cancel Prog On timer >>>")
                end
                device.thread:cancel_timer(timer)
                device:set_field("timer_progOn", nil)
              end         
            end
          end

          if device.preferences.logDebugPrint == true then
            print ("turnOn.onNewLevel=",onNewLevel[device])
            print("Last Level=", device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
          end

          -- detect if forced Level actived
          if device:get_field("forced_Level") > 0 then
            if onNewLevel[device] > device:get_field("forced_Level") then
              onNewLevel[device] = device:get_field("forced_Level")
              --stop dimming and cancel timer
              onStatus[device] ="stopped"
              device:set_field("onStatus", onStatus[device], {persist = true})
              local timer = device:get_field("timer_progOn")
              if timer then
                if device.preferences.logDebugPrint == true then
                  print("<<< Cancel Prog On timer >>>")
                end
                device.thread:cancel_timer(timer)
                device:set_field("timer_progOn", nil)
              end 
            end
          end

          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF))

          ---- Change Temp Color if option activated -----
          if device.preferences.progLevelColor == "Yes" then
            local colorTemp =  math.floor((utils.round(onNewLevel[device])/100 * ((device.preferences.colorTempMaxim) - device.preferences.colorTempMinim)) + device.preferences.colorTempMinim)
            device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
            local colorTemp_Mireds = utils.round(1000000 / colorTemp)
            --print("Color Temp K;  colorTemp Mired", math.floor(colorTemp), colorTemp_Mireds)
            device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
            device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
          end
        end
       end)
       device:set_field("timer_progOn", set_status_timer)
     end
    end

    --- send status ON without dimming---
    if progOn[device]  ==  "Inactive" and circadian[device] == "Inactive" and onStatus[device] =="stopped" then
      if device:get_field("last_Level") == nil or device:get_field("last_Level") < 1 then device:set_field("last_Level", device.preferences.onLevelEnd, {persist = true}) end
      local on_Level = device:get_field("last_Level")
      --if on_Level == nil then on_Level = device.preferences.onLevelEnd end

      -- detect if forced Level actived
      if device:get_field("forced_Level") > 0 then
          on_Level = device:get_field("forced_Level")
          device:set_field("last_Level", on_Level, {persist = true})
      end
      print("Turn On >>>>>>>>>>>>>>>>")
      if device.preferences.onTransTime == 0 then
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
      else
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), device.preferences.onTransTime * 10)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), math.floor(device.preferences.onTransTime * 10)))
      end
      device:send(OnOff.server.commands.On(device))
      device:emit_event(attr.on())

      if device:get_field("zll_xy") == "yes" then
        device.thread:call_with_delay(2, function(d)
          device:refresh()
        end)
      end
    end

    if device.preferences.logDebugPrint == true then
      print("<<<<<<<<<< device", device)
      print("<<<<<<<<<< circadian[device]",circadian[device])
    end
    if device:get_field("circadian_Running[device]") == "stopped" and circadian[device] == "Active" then
      circadian_Running[device] = "stopped"
      driver_handler.circadian_handler(driver, device)
    end
  end
 
  -----------------------------------------
  ------------ TURN OFF handler -----------
  
function driver_handler.off_handler (driver, device, command)
  print("Turn Off handler >>>>>>>>>>>")
  -- set to no jump the dimming
  dimJump[device] = "no"
  -- save last level
  local last_Level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
  -- detect if forced Level actived
  if device:get_field("forced_Level") > 0 then
      last_Level = device:get_field("forced_Level")
  end
  device:set_field("last_Level", last_Level, {persist = true})
  
   ---deactivate color Continous Change
  if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})

    set_status_timer = device:get_field("timer_color")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancel Color Changing timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_color", nil)
    end
  end

  -- capability reference
  local attr = capabilities.switch.switch

      -- detect switch Pushsed when progressive On or Off running ---
  if onStatus[device] == "running" or offStatus[device] == "running" then

    ---- Cancel Timers
    local timer = device:get_field("timer_progOn")
    if timer then
      if device.preferences.logDebugPrint == true then
        print("<<< Cancel Prog On timer >>>")
      end
      device.thread:cancel_timer(timer)
      device:set_field("timer_progOn", nil)
    end
    timer = device:get_field("timer_progOff")
    if timer then
      if device.preferences.logDebugPrint == true then
        print("<<< Cancel Prog Off timer >>>")
      end
      device.thread:cancel_timer(timer)
      device:set_field("timer_progOff", nil)
    end 

     -- progressive Off is running
    if offStatus[device] == "running" then
      offStatus[device]="stopped"
      device:set_field("offStatus", offStatus[device], {persist = true})
      device:emit_event(attr.off())
      if (device.preferences.ifPushSwitch == "Change") then
        device:emit_event(attr.on())
        if progOn[device] == "Active" then
          device:emit_event(attr.on())
          onStartDim[device] = -1
          driver_handler.on_handler(driver,device, onStartDim[device])
          offJump[device]="yes"
        end
        dimJump[device] ="yes" 
      else
        dimJump[device] ="yes"
        offJump[device] = "yes"
        if (device.preferences.ifPushSwitch == "Off")  then device:send(OnOff.server.commands.Off(device))end
        if (device.preferences.ifPushSwitch == "End") then
          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor((device.preferences.offLevelEnd+0.1)/100.0 * 254), 0xFFFF)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor((device.preferences.offLevelEnd+0.1)/100.0 * 254), 0xFFFF))
          device:emit_event(attr.on())
          device:send(zcl_clusters.OnOff.attributes.OnOff:read(device))
        end
        if (device.preferences.ifPushSwitch == "Stop") then device:emit_event(attr.on()) end
      end
    else
      --- progressive On is running
      onStatus[device]="stopped"
      device:set_field("onStatus", onStatus[device], {persist = true})
      device:emit_event(attr.off())
      if (device.preferences.ifPushSwitch == "Change") then
       if progOff[device] == "Active" then
        device:emit_event(attr.on())
        offJump[device] = "yes"
        dimJump[device] = "no"
       else
        dimJump[device] = "yes"
       end
      else   
        dimJump[device] = "yes"
        if (device.preferences.ifPushSwitch == "End") then
          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(device.preferences.onLevelEnd /100.0 * 254), 0xFFFF)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device.preferences.onLevelEnd / 100.0 * 254), 0xFFFF))
          offJump[device] = "yes"
          device:emit_event(attr.on())
        else
          if device.preferences.ifPushSwitch == "Stop" then offJump[device] = "yes" end
          device:emit_event(attr.on())
        end 
      end 
    end
  end 
  
  ---- detect progressive turn OFF is activated -----
  if (onStatus[device] == "stopped" and offStatus[device] == "stopped" and circadian[device] == "Inactive") then
      ---- dimJump is "no" because need change direction of dimming
    if progOff[device]  ==  "Active" and dimJump[device]== "no" then 
      if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) <= device.preferences.offLevelEnd then     
        if offStatus[device] =="stopped" and onStatus[device] =="stopped" then offJump[device] = "no" end
      elseif offStatus[device] =="stopped" then

        -- OFF timer calculation
        offLevelStart[device] = math.floor(device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
        local diff_level = device.preferences.offLevelEnd - offLevelStart[device]
        if diff_level == 0 then 
            offTimer[device] = 1
        else
            offTimer[device] = math.abs(device.preferences.offTimeMax * 60 / diff_level)
            if offTimer[device] < 0.3 then offTimer[device] = 0.3 end
        end
        offTotalSteps[device] = math.floor(device.preferences.offTimeMax * 60 / offTimer[device])
        offStepLevel[device] = ((offLevelStart[device]+ 0.1) - device.preferences.offLevelEnd) / offTotalSteps[device]
        if device.preferences.logDebugPrint == true then
            print("<< offTimer =",offTimer[device])
            print("<< offLevelStart =",offLevelStart[device])
            print ("turnOff.offTotalSteps =", offTotalSteps[device])
            print ("turnOff.offStepLevel =", offStepLevel[device])
        end
        offStepLevel[device] = ((offLevelStart[device]+ 0.1)- device.preferences.offLevelEnd) / offTotalSteps[device]

        offStep[device] = 0
        offStatus[device] ="running"
        device:set_field("offStatus", offStatus[device], {persist = true})

        offNewLevel[device] =  offLevelStart[device]
        offStep[device] = offStep[device] + 1
        device:emit_event(attr.off())
        device:send(OnOff.server.commands.On(device))
        device:emit_event(attr.on())
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF))

      --- Start timer for dimming off ------
      set_status_timer = device.thread:call_on_schedule(offTimer[device], 
        function ()
          if offStatus[device] =="running" then
            offStep[device] = offStep[device] + 1 
            offNewLevel[device] = (offNewLevel[device] - offStepLevel[device])
            if device.preferences.logDebugPrint == true then
              print("offStep=", offStep[device])
            end
            if offNewLevel[device] <= device.preferences.offLevelEnd or offStep[device] >= offTotalSteps[device] then 
              offNewLevel[device] = device.preferences.offLevelEnd
              offStatus[device] ="stopped"
              device:set_field("offStatus", offStatus[device], {persist = true})

              -- Cancel timer
              local timer = device:get_field("timer_progOff")
              if timer then
                if device.preferences.logDebugPrint == true then
                  print("<<< Cancel Prog Off timer >>>")
                end
                device.thread:cancel_timer(timer)
                device:set_field("timer_progOff", nil)
              end
            end
            
            if device.preferences.logDebugPrint == true then
              print ("turnOff.offNewLevel=",offNewLevel[device])
            end
            local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF)
            if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
              command1.body.zcl_body.options_mask = nil
              command1.body.zcl_body.options_override = nil
            end
            device:send(command1)
            --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF))

            ---- Change Temp Color if option activated -----
            if device.preferences.progLevelColor == "Yes" then
              local colorTemp =  math.floor((utils.round(onNewLevel[device])/100 * ((device.preferences.colorTempMaxim) - device.preferences.colorTempMinim)) + device.preferences.colorTempMinim)
              device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
              local colorTemp_Mireds = utils.round(1000000 / colorTemp)
              --print("Color Temp K;  colorTemp Mired", math.floor(colorTemp), colorTemp_Mireds)
              device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
              device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
            end
          end
        end)
        device:set_field("timer_progOff", set_status_timer)
      end
    end
  end
  
   -- send status Off if needed
    if offJump[device] == "no" and (offStatus[device] == "stopped" and onStatus[device] == "stopped") then
      if progOff[device]  ==  "Inactive" or device.preferences.ifPushSwitch == "Off" or offJump[device] == "no" then
        print("Turn OFF >>>>>>>>>>>>>>>>")
          -- send zigbee event
        if device.preferences.onTransTime == 0 then
          device:send(OnOff.server.commands.Off(device))
          device:emit_event(attr.off())
        else
          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(0.1/100.0 * 254), device.preferences.onTransTime * 10)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(0.1/100.0 * 254), math.floor(device.preferences.onTransTime * 10)))
        end
        --device:emit_event(attr.off())

       ---- Cancel Timers
       --circadian_Running[device] = "stopped"
       --device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
       --timers_Cancel(driver, device)
        set_status_timer = device:get_field("timer_color")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancel Color Changing timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_color", nil)
        end
        set_status_timer = device:get_field("timer_progOn")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancelando ProgOn timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_progOn", nil)
          onStatus[device] ="stopped"
          device:set_field("onStatus", onStatus[device], {persist = true})
        end
        set_status_timer = device:get_field("timer_progOff")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancelando ProgOff timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_progOff", nil)
          offStatus[device] ="stopped"
          device:set_field("offStatus", offStatus[device], {persist = true})
        end
        set_status_timer = device:get_field("timer_circadian")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancelando Circadian timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_circadian", nil)
          circadian_Running[device] = "stopped"
          device:set_field("circadian_Running[device]", "stopped", {persist = true})
        end
      end
      if device:get_field("zll_xy") == "yes" then
        device.thread:call_with_delay(2, function(d)
          device:refresh()
        end)
      end
    end

    offJump[device] = "no"
    dimJump[device]= "no"
  end

---- On-Off Emit event
function driver_handler.on_off_attr_handler(driver, device, value, zb_rx)
  if device.preferences.logDebugPrint == true then
    print("<<<<< Emit on_off >>>>>>")
  end
  --print("table zb_rx >>>>>>",utils.stringify_table(zb_rx))

  --print("LQI >>>>>",zb_rx.lqi.value)
  --print("RSSI >>>>>",zb_rx.rssi.value)
  --print (string.format("src_Address: 0x%04X", zb_rx.address_header.src_addr.value))

   ---deactivate color Continous Change  
  if value.value == false then
    if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = true})
    end
    set_status_timer = device:get_field("timer_color")
    if set_status_timer then
      --print("<<<<< Cancel Color Changing timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_color", nil)
    end
    set_status_timer = device:get_field("timer_progOn")
    if set_status_timer then
      print("<<<<< Cancelando ProgOn timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_progOn", nil)
      onStatus[device] ="stopped"
      device:set_field("onStatus", onStatus[device], {persist = true})
    end
    set_status_timer = device:get_field("timer_progOff")
    if set_status_timer then
      --print("<<<<< Cancelando ProgOff timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_progOff", nil)
      offStatus[device] ="stopped"
      device:set_field("offStatus", offStatus[device], {persist = true})
    end
    set_status_timer = device:get_field("timer_circadian")
    if set_status_timer then
      --print("<<<<< Cancelando Circadian timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_circadian", nil)
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", "stopped", {persist = true})
    end
    set_status_timer = device:get_field("timer_blink")
    if set_status_timer then
      --print("<<<<< Cancel Blink timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_blink", nil)
    end
  end

  local visible_satate = false
  if device.preferences.signalMetricsVisibles == "Yes" then
    visible_satate = true
  end
  
  if os.time() - last_signal_emit_time > 22 then
    local gmt = os.date("%Y/%m/%d Time: %H:%M",os.time())
    local dni = string.format("0x%04X", zb_rx.address_header.src_addr.value)
    local metrics = "<em table style='font-size:75%';'font-weight: bold'</em>".. "<b>GMT: </b>".. gmt .."<BR>"
    metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
    last_signal_emit_time = os.time()
    device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))
  end

  local attr = capabilities.switch.switch
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, value.value and attr.on() or attr.off())

  -- emit event in child device
  local child_device = device:get_child_by_parent_assigned_key("main")
  if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
    child_device:emit_event(value.value and attr.on() or attr.off())
  end
end
  -----------------------------------------------
--------- effects_Set_Command_handler ---------

function driver_handler.effects_Set_handler(driver, device, command)

  local effects_set_command = "Inactive"
  if command == "BlinkON" then 
    effects_set_command = "BlinkON"
    --print("<<< command:", command)
  else
    effects_set_command = command.args.value
    --print("<<< command.args.value:", command.args.value)
  end

  --device:send(zcl_clusters.OnOff.server.commands.On(device))
  device:emit_event(effects_Set_Command.effectsSetCommand(effects_set_command))
  device:set_field("effects_set_command", effects_set_command, {persist = true})

  if effects_set_command == "BlinkON" then
    --device:emit_event(effects_Set_Command.effectsSetCommand("Blink ON"))
    device:send(zcl_clusters.OnOff.server.commands.On(device))
    if device:get_manufacturer() == "OSRAM" then
      device:send(zcl_clusters.Identify.commands.Identify(device, 3600)) -- command blink with time 15 sec
    else
      device:send(zcl_clusters.Identify.commands.TriggerEffect(device, 0x01,0x00))
      set_status_timer = device.thread:call_on_schedule(3,
      function ()
        device:send(zcl_clusters.Identify.commands.TriggerEffect(device, 0x01,0x00))
      end,
      "blink")
      device:set_field("timer_blink", set_status_timer)
    end
    
  elseif effects_set_command == "BlinkOFF" or  effects_set_command == "Inactive" then
    --device:emit_event(effects_Set_Command.effectsSetCommand(effects_set_command))
    if device:get_manufacturer() == "OSRAM" then
      device:send(zcl_clusters.Identify.commands.Identify(device, 0)) -- command blink with time 0 sec
    else 
      device:send(zcl_clusters.Identify.commands.TriggerEffect(device, 0xFF,0x00))
    end

    ---- Blink Timers Cancel ------
    set_status_timer = device:get_field("timer_blink")
    if set_status_timer then
      --print("<<<<< Cancel Blink timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_blink", nil)
    end

    --- restart Circadian timer if activated
    if circadian_Running[device] == "running" and circadian[device] == "Active" then
      driver_handler.circadian_handler(driver, device)
    end

    --- restart prog-On if is running
    if device:get_field("onStatus") == "running" then
      onStartDim[device] = -1 -- this value will made continue the dimming On with last level
      onStatus[device] ="stopped"
      driver_handler.on_handler (driver, device, onStartDim[device])
    end

    --- restart prog-Off if is running
    if device:get_field("offStatus") == "running" then
      offStatus[device] ="stopped"
      driver_handler.off_handler (driver, device, "off")
    end
    
    --- ReStart Timer color chanaging function
    if device:supports_capability_by_id(capabilities.colorControl.ID) then
      if device:get_field("colorTimer") == nil then
        device:set_field("colorTimer", 2 , {persist = true})
        device:emit_event(color_Change_Timer.colorChangeTimer(2))
      end
  
      if device:get_field("colorChangeModeList") == nil then
        device:set_field("colorChangeModeList", "Random", {persist = true})
        device:emit_event(color_Change_Mode.colorChangeMode("Random"))
      end
  
      if device:get_field("colorChanging") == "Active" then 
        device:set_field("colorChanging", "Continue", {persist = true})
        driver_handler.color_Changing_handler(driver,device,"Continue")
      else
        device:emit_event(color_Changing.colorChanging("Inactive"))
      end
    end
  
    --- restart random on-off if active
    if device.preferences.logDebugPrint == true then
      print("random_state >>>>>",device:get_field("random_state"))
    end
    if device:get_field("random_state") == "Active" then  
      driver_handler.random_on_off_handler(driver,device,"Active")  
    end
  end
  --device:send(zcl_clusters.ColorControl.commands.ColorLoopSet(device, 0xFF,0x01,0x01,0xFFFF, 0x01, 0x00, 0x00)) -- command Colorloop
  --device:send(zcl_clusters.Identify.commands.Identify(device, 15)) -- command blink with time 15 sec
end

  return driver_handler