#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

require 'json'

#start the measure
class AdvancedRTUControlsEms < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "AdvancedRTUControlsEms"
  end

  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
    
    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end
    
    require 'json'
    
    # Get the last openstudio model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Could not load last OpenStudio model, cannot apply measure.")
      return false
    end
    model = model.get
    
    results = {}
    airloop_name = []
    # Loop over the airloops to find valid ones for this measure
    model.getAirLoopHVACs.each do |air_loop|
      found_coil = 0  #have not found any cooling coils
      found_hcoil = 0  #have not found any heating coils
      found_fan = 0   #have not found any fans 
      temp = {}
      air_loop.supplyComponents.each do |component|
        # Get the unitary equipment
        if component.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          unitary = component.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
          # Get the cooling coil from inside the unitary equipment
          if unitary.coolingCoil.to_CoilCoolingDXSingleSpeed.is_initialized
            clg_coil = unitary.coolingCoil.to_CoilCoolingDXSingleSpeed.get
            runner.registerInfo("Found #{clg_coil.name} on #{air_loop.name}")
            found_coil += 1  #found necessary cooling coil DX singlespeed
            temp[:cool_coil] = "#{clg_coil.name}"
          end
          # get heating coil
          if unitary.heatingCoil.to_CoilHeatingDXSingleSpeed.is_initialized
          htg_coil = unitary.heatingCoil.to_CoilHeatingDXSingleSpeed.get
            runner.registerInfo("Found #{htg_coil.name} on #{air_loop.name}")
            found_hcoil += 1  #found necessary cooling coil DX singlespeed
            temp[:heat_coil] = "#{htg_coil.name}"
          end
          # get the supply fan from inside the unitary equipment
          if unitary.supplyAirFan.to_FanConstantVolume.is_initialized
            supply_fan = unitary.supplyAirFan.to_FanConstantVolume.get
            runner.registerInfo("Found #{supply_fan.name} on #{air_loop.name}")
            found_fan += 1  #found necessary Fan object
            temp[:fan] = "#{supply_fan.name}"
          elsif unitary.supplyAirFan.to_FanOnOff.is_initialized
            supply_fan = unitary.supplyAirFan.to_FanOnOff.get
            runner.registerInfo("Found #{supply_fan.name} on #{air_loop.name}")
            found_fan += 1  #found necessary Fan object
            temp[:fan] = "#{supply_fan.name}"
          else
            runner.registerInfo("No OnOff or Constant Volume Fan in the Unitary system on #{air_loop.name}")  
          end
        end
        # Get the cooling coil directly from the airloop
        if component.to_CoilCoolingDXSingleSpeed.is_initialized
          clg_coil = component.to_CoilCoolingDXSingleSpeed.get
          runner.registerInfo("Found #{clg_coil.name} on #{air_loop.name}")
          found_coil += 1  #found necessary cooling coil DX singlespeed
          temp[:cool_coil] = "#{clg_coil.name}"
        
        # Get the heating coil directly from the airloop
        elsif component.to_CoilHeatingDXSingleSpeed.is_initialized
          htg_coil = component.to_CoilHeatingDXSingleSpeed.get
          runner.registerInfo("Found #{htg_coil.name} on #{air_loop.name}")
          found_hcoil += 1  #found necessary heating coil DX singlespeed
          temp[:heat_coil] = "#{htg_coil.name}"
        
        # Get the heating coil directly from the airloop
        elsif component.to_CoilHeatingGas.is_initialized
          htg_coil = component.to_CoilHeatingGas.get
          runner.registerInfo("Found #{htg_coil.name} on #{air_loop.name}")
          found_hcoil += 1  #found necessary heating coil gas
          temp[:heat_coil] = "#{htg_coil.name}"
        
        # Get the heating coil directly from the airloop
        elsif component.to_CoilHeatingElectric.is_initialized
          htg_coil = component.to_CoilHeatingElectric.get
          runner.registerInfo("Found #{htg_coil.name} on #{air_loop.name}")
          found_hcoil += 1  #found necessary heating coil gas
          temp[:heat_coil] = "#{htg_coil.name}"
        
        # get the supply fan directly from the airloop
        elsif component.to_FanConstantVolume.is_initialized
          supply_fan = component.to_FanConstantVolume.get
          runner.registerInfo("Found #{supply_fan.name} on #{air_loop.name}")
          found_fan += 1  #found necessary Fan object
          temp[:fan] = "#{supply_fan.name}"
        
        elsif component.to_FanOnOff.is_initialized
          supply_fan = component.to_FanOnOff.get
          runner.registerInfo("Found #{supply_fan.name} on #{air_loop.name}")
          found_fan += 1  #found necessary Fan object
          temp[:fan] = "#{supply_fan.name}"
        end
      end
      runner.registerInfo("airloop #{air_loop.name} found = #{(found_coil + found_fan)}")
      found_oa = 0
      found_act = 0
      found_oasch = 0
      found_oafsch = 0
      #found too many objects on an airloop
      if (found_coil + found_hcoil + found_fan) > 3
        runner.registerInfo("Too many objects on airloop #{air_loop.name}. Airloop N/A")
      #found a Fan and Cooling Coil DX Single Speed, get rest of info
      elsif (found_coil + found_hcoil + found_fan) < 3
        runner.registerInfo("Not enough objects on airloop #{air_loop.name}. Airloop N/A")
      elsif (found_coil + found_hcoil + found_fan) == 3 
          # get outdoorair controller
          if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
            controller_oa = air_loop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir
            runner.registerInfo("Found #{controller_oa.name} on #{air_loop.name}")
            found_oa += 1 #found necessary OA controller
            temp[:controller_oa] = "#{controller_oa.name}"
            # get actuator node name
            actuatorNodeName = air_loop.airLoopHVACOutdoorAirSystem.get.outboardOANode.get.name.get
            runner.registerInfo("Found #{actuatorNodeName} on #{air_loop.name}")
            found_act += 1  #found necessary actuator node
            temp[:actuatorNodeName] = "#{actuatorNodeName}"
            # get minimumFractionofOutdoorAirSchedule
            minimumFractionofOutdoorAirSchedule = controller_oa.minimumFractionofOutdoorAirSchedule
            # get minimumOutdoorAirSchedule
            minimumOutdoorAirSchedule = controller_oa.minimumOutdoorAirSchedule
            if minimumFractionofOutdoorAirSchedule.is_initialized && minimumOutdoorAirSchedule.is_initialized
              runner.registerWarning("Both minimumOutdoorAirSchedule and minimumFractionofOutdoorAirSchedule in Airloop #{air_loop.name} are missing.")
            end
            if minimumFractionofOutdoorAirSchedule.is_initialized
              runner.registerInfo("Found #{minimumFractionofOutdoorAirSchedule.get.name} on #{air_loop.name}")
              found_oafsch += 1 #found necessary fraction OA schedule
              temp[:minimumFractionofOutdoorAirSchedule] = "#{minimumFractionofOutdoorAirSchedule.get.name}"
            # else
              # always_on = model.alwaysOnDiscreteSchedule
              # controller_oa.setMinimumFractionofOutdoorAirSchedule(always_on)
              # runner.registerInfo("Added #{controller_oa.minimumFractionofOutdoorAirSchedule.get.name} on #{air_loop.name}")
              # runner.registerWarning("Added #{controller_oa.minimumFractionofOutdoorAirSchedule.get.name} on #{air_loop.name}")
              # found_oafsch += 1  #added necessary fraction OA schedule
              # temp[:minimumFractionofOutdoorAirSchedule] = "#{controller_oa.minimumFractionofOutdoorAirSchedule.get.name}"
            end
            if minimumOutdoorAirSchedule.is_initialized
              runner.registerInfo("Found #{minimumOutdoorAirSchedule.get.name} on #{air_loop.name}")
              found_oasch += 1 #found necessary OA schedule
              temp[:minimumOutdoorAirSchedule] = "#{minimumOutdoorAirSchedule.get.name}"
            else
              # always_on = model.alwaysOnDiscreteSchedule
              # controller_oa.setMinimumOutdoorAirSchedule(always_on)
              always_on_eplus = "Schedule:Constant,
                AlwaysOn,                  !- Name
                ,                          !- Schedule Type Limits Name
                1.0;                       !- Hourly Value
              "
              idfObject = OpenStudio::IdfObject::load(always_on_eplus)
              #add to workspace
              always_on_eplus_object = workspace.addObject(idfObject.get).get
              outdoorAirControllerObjects = workspace.getObjectsByType("Controller:OutdoorAir".to_IddObjectType)
              outdoorAirControllerObjects do |oa|
                if oa.name.to_s == controller_oa.name.to_s
                  oa.setPointer(17, always_on_eplus_object.handle)
                end
              end     
              runner.registerInfo("Added #{always_on_eplus_object.name.get} on #{air_loop.name}")
              runner.registerWarning("Added #{always_on_eplus_object.name.get} on #{air_loop.name}")
              found_oasch += 1 #added necessary OA schedule
              temp[:minimumOutdoorAirSchedule] = "#{always_on_eplus_object.name.get}"
            end
          end
          if (found_oasch + found_act + found_oa) == 3  #add valid air loop to results
            results["#{air_loop.name}"] = temp
            airloop_name << "#{air_loop.name}"
            runner.registerInfo("Adding valid AirLoop #{air_loop.name} to results.")
          end  
      end
    end
    #save airloop parsing results to ems_results.json
    runner.registerInfo("Saving ems_results.json")
    FileUtils.mkdir_p(File.dirname("ems_results.json")) unless Dir.exist?(File.dirname("ems_results.json"))
    File.open("ems_results.json", 'w') {|f| f << JSON.pretty_generate(results)}
    
    if results.empty?
       runner.registerWarning("No Airloops are appropriate for this measure")
       runner.registerAsNotApplicable("No Airloops are appropriate for this measure")
       #save blank ems_advanced_rtu_controls.ems file so Eplus measure does not crash
       ems_string = ""
       runner.registerInfo("Saving blank ems_advanced_rtu_controls file")
       FileUtils.mkdir_p(File.dirname("ems_advanced_rtu_controls.ems")) unless Dir.exist?(File.dirname("ems_advanced_rtu_controls.ems"))
       File.open("ems_advanced_rtu_controls.ems", "w") do |f|
         f.write(ems_string)
       end
       return true
    end
    
    runner.registerInfo("Making EMS string for Advanced RTU Controls")
    #start making the EMS code
    ems_string = ""  #clear out the ems_string
    
    ems_string << "EnergyManagementSystem:GlobalVariable," + "\n"
    ems_string << "    FanPwrExp,  ! Exponent used in fan power law" + "\n"
    ems_string << "    Stage1Speed,  ! Fan speed in cooling mode" + "\n"
    ems_string << "    HeatSpeed,    ! Fan speed in heating mode" + "\n"
    ems_string << "    VenSpeed,   ! Fan speed in ventilation mode" + "\n"
    ems_string << "    EcoSpeed; ! Fan speed in economizer mode" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Program," + "\n"
    ems_string << "    Set_FanCtl_Par1," + "\n"
    ems_string << "    SET FanPwrExp = 2.2," + "\n"
    ems_string << "    SET HeatSpeed = 0.9," + "\n"
    ems_string << "    SET VenSpeed = 0.4," + "\n"
    ems_string << "    SET Stage1Speed = 0.9," + "\n"
    ems_string << "    SET EcoSpeed = 0.75," + "\n"
    results.each_with_index do |(key, value), i|  
      if i < results.size - 1
      ems_string << "    SET PSZ#{i}_OADesignMass = PSZ#{i}_DesignOAFlowMass," + "\n"
      else
      ems_string << "    SET PSZ#{i}_OADesignMass = PSZ#{i}_DesignOAFlowMass;" + "\n"
      end
    end

    ems_string << "\n"
    ems_string << "EnergyManagementSystem:ProgramCallingManager," + "\n"
    ems_string << "    Fan_Parameter_manager,  !- Name" + "\n"
    ems_string << "    BeginNewEnvironment,  !- EnergyPlus Model Calling Point" + "\n"
    ems_string << "    Set_FanCtl_Par1;        !- Program Name 1" + "\n"
    ems_string << "\n"

    results.each_with_index do |(key, value), i|
    ems_string << "EnergyManagementSystem:InternalVariable," + "\n"
    ems_string << "    PSZ#{i}_DesignOAFlowMass, !- Name " + "\n"
    ems_string << "    #{value[:controller_oa]}, !- Internal Data Index Key Name" + "\n"
    ems_string << "    Outdoor Air Controller Minimum Mass Flow Rate; !- Internal Data Type" + "\n"
    ems_string << "\n"
    end

    results.each_with_index do |(key, value), i|
    ems_string << "EnergyManagementSystem:InternalVariable," + "\n"
    ems_string << "    PSZ#{i}_FanDesignPressure, !- Name " + "\n"
    ems_string << "    #{value[:fan]}, !- Internal Data Index Key Name" + "\n"
    ems_string << "    Fan Nominal Pressure Rise; !- Internal Data Type" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:InternalVariable," + "\n"
    ems_string << "    PSZ#{i}_DesignFlowMass, !- Name " + "\n"
    ems_string << "    #{value[:controller_oa]}, !- Internal Data Index Key Name" + "\n"
    ems_string << "    Outdoor Air Controller Maximum Mass Flow Rate; !- Internal Data Type" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Sensor," + "\n"
    ems_string << "    PSZ#{i}_OASch," + "\n"
    ems_string << "    #{value[:minimumOutdoorAirSchedule]}," + "\n"
    ems_string << "    Schedule Value;" + "\n"
    ems_string << "\n"
    if !value[:minimumFractionofOutdoorAirSchedule].nil?
      ems_string << "EnergyManagementSystem:Sensor," + "\n"
      ems_string << "    PSZ#{i}_OAFracSch," + "\n"
      ems_string << "    #{value[:minimumFractionofOutdoorAirSchedule]}," + "\n"
      ems_string << "    Schedule Value;" + "\n"
      ems_string << "\n"
    end
    ems_string << "EnergyManagementSystem:Sensor," + "\n"
    ems_string << "    PSZ#{i}_OAFlowMass," + "\n"
    ems_string << "    #{value[:actuatorNodeName]}," + "\n"
    ems_string << "    System Node Mass Flow Rate;" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Sensor," + "\n"
    ems_string << "    PSZ#{i}_HtgRTF," + "\n"
    ems_string << "    #{value[:heat_coil]}," + "\n"
    ems_string << "    Heating Coil Runtime Fraction;" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Sensor," + "\n"
    ems_string << "    PSZ#{i}_ClgRTF," + "\n"
    ems_string << "    #{value[:cool_coil]}," + "\n"
    ems_string << "    Cooling Coil Runtime Fraction;" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Actuator," + "\n"
    ems_string << "    PSZ#{i}_FanPressure, ! Name " + "\n"
    ems_string << "    #{value[:fan]}, ! Actuated Component Unique Name" + "\n"
    ems_string << "    Fan, ! Actuated Component Type" + "\n"
    ems_string << "    Fan Pressure Rise; ! Actuated Component Control Type" + "\n"
    ems_string << "\n"
    end

    results.each_with_index do |(key, value), i|
    ems_string << "EnergyManagementSystem:Program," + "\n"
    ems_string << "    PSZ#{i}_FanControl,        !- Name" + "\n"
    ems_string << "    IF PSZ#{i}_HtgRTF > 0," + "\n"
    ems_string << "     SET PSZ#{i}_Htg = PSZ#{i}_HtgRTF,      ! Percent of time in heating mode" + "\n"
    ems_string << "     SET PSZ#{i}_Ven = 1 - PSZ#{i}_HtgRTF,  ! Percent of time in ventilation mode" + "\n"
    ems_string << "     SET PSZ#{i}_Eco = 0,       ! Percent of time in economizer mode" + "\n"
    ems_string << "     SET PSZ#{i}_Stage1 = 0,    ! Percent of time in DX cooling" + "\n"
    ems_string << "    ELSE," + "\n"
    ems_string << "     SET PSZ#{i}_Htg = 0," + "\n"
    ems_string << "     SET PSZ#{i}_MinOA1 = PSZ#{i}_OADesignMass * PSZ#{i}_OASch," + "\n"
    if !value[:minimumFractionofOutdoorAirSchedule].nil?
      ems_string << "     SET PSZ#{i}_MinOA2 = PSZ#{i}_DesignFlowMass * PSZ#{i}_OAFracSch," + "\n"
      ems_string << "     SET PSZ#{i}_MinOA = @Max PSZ#{i}_MinOA1 PSZ#{i}_MinOA2,  " + "\n"
    else
      ems_string << "     SET PSZ#{i}_MinOA = PSZ#{i}_MinOA1,  " + "\n"
    end
    ems_string << "     IF  PSZ#{i}_ClgRTF > 0,    ! Mechanical cooling is on" + "\n"
    ems_string << "      SET PSZ#{i}_Stage1 = PSZ#{i}_ClgRTF," + "\n"
    ems_string << "      IF PSZ#{i}_OAFlowMass > PSZ#{i}_MinOA,  ! Integrated Economzing mode" + "\n"
    ems_string << "       SET PSZ#{i}_Eco = 1-PSZ#{i}_ClgRTF,  " + "\n"
    ems_string << "       SET PSZ#{i}_Ven = 0," + "\n"
    ems_string << "      ELSE," + "\n"
    ems_string << "       SET PSZ#{i}_Eco = 0," + "\n"
    ems_string << "       SET PSZ#{i}_Ven = 1-PSZ#{i}_ClgRTF," + "\n"
    ems_string << "      ENDIF," + "\n"
    ems_string << "     ELSE,               ! Mechanical cooling is off" + "\n"
    ems_string << "      SET PSZ#{i}_Stage1 = 0, " + "\n"
    ems_string << "      IF PSZ#{i}_OAFlowMass > PSZ#{i}_MinOA,  ! Economizer mode" + "\n"
    ems_string << "       SET PSZ#{i}_Eco = 1.0," + "\n"
    ems_string << "       SET PSZ#{i}_Ven = 0," + "\n"
    ems_string << "      ELSE," + "\n"
    ems_string << "       SET PSZ#{i}_Eco = 0," + "\n"
    ems_string << "       SET PSZ#{i}_Ven = 1.0," + "\n"
    ems_string << "      ENDIF," + "\n"
    ems_string << "     ENDIF," + "\n"
    ems_string << "    ENDIF," + "\n"
    ems_string << "\n"
    ems_string << "    ! For each mode, (percent time in mode) * (fanSpeed^PwrExp) is the contribution to weighted fan power over time step" + "\n"
    ems_string << "    SET PSZ#{i}_FPR = PSZ#{i}_Ven * (VenSpeed ^ FanPwrExp)," + "\n"
    ems_string << "    SET PSZ#{i}_FPR = PSZ#{i}_FPR + PSZ#{i}_Eco * (EcoSpeed ^ FanPwrExp)," + "\n"
    ems_string << "    SET PSZ#{i}_FPR1 = PSZ#{i}_Stage1 * (Stage1Speed ^ FanPwrExp)," + "\n"
    ems_string << "    SET PSZ#{i}_FPR = PSZ#{i}_FPR + PSZ#{i}_FPR1," + "\n"
    ems_string << "    SET PSZ#{i}_FPR3 = PSZ#{i}_Htg * (HeatSpeed ^ FanPwrExp)," + "\n"
    ems_string << "    SET PSZ#{i}_FanPwrRatio = PSZ#{i}_FPR +  PSZ#{i}_FPR3," + "\n"
    ems_string << "\n"
    ems_string << "   ! System fan power is directly proportional to static pressure, so this change linearly adjusts fan energy for speed control" + "\n"
    ems_string << "    SET PSZ#{i}_FanPressure = PSZ#{i}_FanDesignPressure * PSZ#{i}_FanPwrRatio;" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:ProgramCallingManager," + "\n"
    ems_string << "    PSZ#{i}_Fan_Manager,   !- Name" + "\n"
    ems_string << "    BeginTimestepBeforePredictor,  !- EnergyPlus Model Calling Point" + "\n"
    ems_string << "    PSZ#{i}_FanControl;        !- Program Name 1" + "\n"
    ems_string << "\n"
    end
    
    #save EMS snippet
    runner.registerInfo("Saving ems_advanced_rtu_controls file")
    FileUtils.mkdir_p(File.dirname("ems_advanced_rtu_controls.ems")) unless Dir.exist?(File.dirname("ems_advanced_rtu_controls.ems"))
    File.open("ems_advanced_rtu_controls.ems", "w") do |f|
      f.write(ems_string)
    end
    
    #unique initial conditions based on
    runner.registerInitialCondition("The building has #{results.length} constant air volume units for which this measure is applicable.")

    #reporting final condition of model
    runner.registerFinalCondition("VSDs and associated controls were applied to  #{results.length} single-zone, constant air volume units in the model.  Airloops affected were #{airloop_name}")

    
    ems_path = '../AdvancedRTUControlsEms/ems_advanced_rtu_controls.ems'
    json_path = '../AdvancedRTUControlsEms/ems_results.json'
    if File.exist? ems_path
      ems_string = File.read(ems_path)
      if File.exist? json_path
        json = JSON.parse(File.read(json_path))
      end
    else
      ems_path2 = Dir.glob('../../**/ems_advanced_rtu_controls.ems')
      ems_path1 = ems_path2[0]
      json_path2 = Dir.glob('../../**/ems_results.json')
      json_path1 = json_path2[0]
      if ems_path2.size > 1
        runner.registerWarning("more than one ems_advanced_rtu_controls.ems file found.  Using first one found.")
      end
      if !ems_path1.nil? 
        if File.exist? ems_path1
          ems_string = File.read(ems_path1)
          if File.exist? json_path1
            json = JSON.parse(File.read(json_path1))
          else
            runner.registerError("ems_results.json file not located") 
          end  
        else
          runner.registerError("ems_advanced_rtu_controls.ems file not located")
        end  
      else
        runner.registerError("ems_advanced_rtu_controls.ems file not located")    
      end
    end
    if json.nil?
      runner.registerError("ems_results.json file not located")
      return false
    end

    ##testing code
    # ems_string1 = "EnergyManagementSystem:Actuator,
    # PSZ0_FanPressure, ! Name 
    # Perimeter_ZN_4 ZN PSZ-AC Fan, ! Actuated Component Unique Name
    # Fan, ! Actuated Component Type
    # Fan Pressure Rise; ! Actuated Component Control Type"
    
    # idf_file1 = OpenStudio::IdfFile::load(ems_string1, 'EnergyPlus'.to_IddFileType).get
    # runner.registerInfo("Adding test EMS code to workspace")
    # workspace.addObjects(idf_file1.objects)
    
    if json.empty?
      runner.registerWarning("No Airloops are appropriate for this measure")
      return true
    end
    
    #get all emsActuators in model to test if there is an EMS conflict
    emsActuator = workspace.getObjectsByType("EnergyManagementSystem:Actuator".to_IddObjectType)

    if emsActuator.size == 0
      runner.registerInfo("The model does not contain any emsActuators, continuing")
    else
      runner.registerInfo("The model contains #{emsActuator.size} emsActuators, checking if any are attached to Fans.")
      emsActuator.each_with_index do |emsActuatorObject|
        emsActuatorObject_name =  emsActuatorObject.getString(1).to_s # Name
        runner.registerInfo("EMS string: #{emsActuatorObject_name}")
        json.each do |js|
          if (emsActuatorObject_name.eql? js[1]["fan"].to_s) && (emsActuatorObject.getString(2).to_s.eql? "Fan") && (emsActuatorObject.getString(3).to_s.eql? "Fan Pressure Rise")
            runner.registerInfo("Actuated Component Unique Name: #{emsActuatorObject.getString(1).to_s}")
            runner.registerInfo("Actuated Component Type: #{emsActuatorObject.getString(2).to_s}")
            runner.registerInfo("Actuated Component Control Type: #{emsActuatorObject.getString(3).to_s}")
            runner.registerInfo("EMS control logic modifying fan pressure rise  already exists in the model. EEM not applied")
            runner.registerAsNotApplicable("EMS control logic modifying fan pressure rise  already exists in the model. EEM not applied")
            return true
          else
            runner.registerInfo("EMS string: #{js[1]["fan"].to_s} has no EMS conflict")
          end
        end
      end
    end
    
    idf_file = OpenStudio::IdfFile::load(ems_string, 'EnergyPlus'.to_IddFileType).get
    runner.registerInfo("Adding EMS code to workspace")
    workspace.addObjects(idf_file.objects)
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
AdvancedRTUControlsEms.new.registerWithApplication