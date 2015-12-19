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
class HotWaterCoilValveLeakage < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Hot Water Coil Valve Leakage"
  end

  # human readable description
  def description
    return "The valves that control the flow of hot water to heating coils can sometimes leak, adding unwanted heat to the airstream during cooling operation.  Adding this extra heat means that extra chilled water is needed to bring the air down to the desired temperature.  Identifying and fixing these leaks can help save cooling energy."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This Measure actually introduces coil leakage to the model; to determine savings, you should apply this to an unleaking baseline model, and the savings will be the inverse of normal.  This measure introduces leaks to hot water heating coils in VAV air handlers with hot water reheat.  This is modeled by increasing the coil outlet setpoint by 5C anytime the system is in cooling mode.  This causes the hot water flow rate to increase."
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
    
    # Report that this is an anti-measure
    runner.registerValue('anti_measure',true)    
    
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
      found_vav_hwcoil = 0  #have not found any cooling coils
      found_hwcoil = 0  #have not found any heating coils
      found_fan = 0   #have not found any fans 
      found_mixed_oa_node = 0
      temp = {}
      temp2 = []
      #is supply fan variable volume
      if air_loop.supplyFan.is_initialized
        if air_loop.supplyFan.get.to_FanVariableVolume.is_initialized
          runner.registerInfo("Found #{air_loop.supplyFan.get.to_FanVariableVolume.get.name.get} on #{air_loop.name}")
          temp[:fan] = "#{air_loop.supplyFan.get.to_FanVariableVolume.get.name.get}"
          found_fan += 1
        end
      else
        runner.registerInfo("no VAV on airloop #{air_loop.name}, skipping")
        next
      end
      
      air_loop.supplyComponents.each do |component|      
        # Get the cooling coil directly from the airloop
        if component.to_CoilHeatingWater.is_initialized
          hw_coil = component.to_CoilHeatingWater.get
          runner.registerInfo("Found #{hw_coil.name} on #{air_loop.name}")
          found_hwcoil += 1  #found necessary coil heating water
          temp[:hw_coil] = "#{hw_coil.name}"
          hw_coil_outnode = hw_coil.to_WaterToAirComponent.get.airOutletModelObject.get.name.get
          runner.registerInfo("Found #{hw_coil_outnode} on #{air_loop.name}")
          temp[:hw_coil_outnode] = hw_coil_outnode
        end
      end
      
      next if found_hwcoil == 0
      
      air_loop.demandComponents.each do |component|      
        # Get the cooling coil directly from the airloop
        if component.to_AirTerminalSingleDuctVAVReheat.is_initialized
          if component.to_AirTerminalSingleDuctVAVReheat.get.reheatCoil.to_CoilHeatingWater.is_initialized
            vav_hw_coil = component.to_AirTerminalSingleDuctVAVReheat.get.reheatCoil.to_CoilHeatingWater.get.name.get
            runner.registerInfo("Found #{vav_hw_coil} on #{air_loop.name}")
            found_vav_hwcoil += 1  #found necessary coil heating water
            temp2 << "#{vav_hw_coil}"
          end
        end
      end
      temp[:vav_hwcoil] = temp2
      
      next if found_vav_hwcoil == 0
      
      if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
        mixed_oa_node = air_loop.airLoopHVACOutdoorAirSystem.get.mixedAirModelObject.get.name.get
        temp[:mixed_oa_node] = "#{mixed_oa_node}"
        runner.registerInfo("Found #{mixed_oa_node} on #{air_loop.name}")
        found_mixed_oa_node += 1
      end
      
      next if found_mixed_oa_node == 0
      
      supply_outnode = air_loop.supplyOutletNode.name.get
      temp[:supply_outnode] = "#{supply_outnode}"
      runner.registerInfo("Found #{supply_outnode} on #{air_loop.name}")
      if (found_vav_hwcoil + found_hwcoil + found_fan) >= 3
        results["#{air_loop.name}"] = temp
        airloop_name << "#{air_loop.name}"
        runner.registerInfo("Adding valid AirLoop #{air_loop.name} to results.")
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
       FileUtils.mkdir_p(File.dirname("ems_hot_water_coil_valve_leakage.ems")) unless Dir.exist?(File.dirname("ems_hot_water_coil_valve_leakage.ems"))
       File.open("ems_hot_water_coil_valve_leakage.ems", "w") do |f|
         f.write(ems_string)
       end
       return true
    end
    
    runner.registerInfo("Making EMS string for Hot Water Coil Valve Leakage")
    #start making the EMS code
    ems_string = ""  #clear out the ems_string
    results.each_with_index do |(key, value), i|
      values = value[:vav_hwcoil]
      j = 0
      values.each do |value2|
        j +=1
        ems_string << "\n"
        ems_string << "EnergyManagementSystem:Sensor," + "\n"
        ems_string << "    VAV#{i+1}_#{j}," + "\n"
        ems_string << "    #{value2}," + "\n"
        ems_string << "    Heating Coil Heating Rate;" + "\n"
      end
      ems_string << "\n"    
      ems_string << "EnergyManagementSystem:Sensor," + "\n"
      ems_string << "    VAV#{i+1}_MA_Temp," + "\n"
      ems_string << "    #{value[:mixed_oa_node]}," + "\n"
      ems_string << "    System Node Temperature;" + "\n"
      ems_string << "\n"
      ems_string << "EnergyManagementSystem:Sensor," + "\n"
      ems_string << "    VAV#{i+1}_TempSP," + "\n"
      ems_string << "    #{value[:supply_outnode]}," + "\n"
      ems_string << "    System Node Setpoint Temperature;" + "\n"
      ems_string << "\n" 
      ems_string << "EnergyManagementSystem:Actuator," + "\n"
      ems_string << "    VAV#{i+1}_HeatC_TempSP," + "\n"
      ems_string << "    #{value[:hw_coil_outnode]}," + "\n"
      ems_string << "    System Node Setpoint," + "\n"
      ems_string << "    Temperature Setpoint;" + "\n"
      ems_string << "\n" 
      ems_string << "EnergyManagementSystem:ProgramCallingManager," + "\n"
      ems_string << "    LeakageHeat_Manager#{i+1}," + "\n"
      ems_string << "    AfterPredictorAfterHVACManagers," + "\n"
      ems_string << "    AHU#{i+1}HWCoilLeakage;" + "\n"
      ems_string << "\n"
      ems_string << "EnergyManagementSystem:Program," + "\n"
      ems_string << "    AHU#{i+1}HWCoilLeakage," + "\n"
      ems_string << "    ! Determine if any of the reheat coils are calling for heating" + "\n"
      ems_string << "    SET HW_Flow = 0," + "\n"
      values = value[:vav_hwcoil]
      j = 0
      values.each do |value2|
      j += 1
        ems_string << "    IF VAV#{i+1}_#{j} > 0," + "\n"
        ems_string << "      SET HW_Flow = 1," + "\n"
        ems_string << "    ENDIF," + "\n"
      end
      ems_string << "    ! Change the heating coil outlet setpoint" + "\n"
      ems_string << "    IF HW_Flow == 1," + "\n"
      ems_string << "      IF VAV#{i+1}_MA_Temp < VAV#{i+1}_TempSP," + "\n"
      ems_string << "        SET VAV#{i+1}_HeatC_TempSP = VAV1_TempSP," + "\n"
      ems_string << "      ELSE," + "\n"
      ems_string << "        SET VAV1_HeatC_TempSP = VAV1_MA_Temp + 5,  " + "\n"
      ems_string << "      ENDIF," + "\n"
      ems_string << "    ELSE," + "\n"
      ems_string << "      SET VAV#{i+1}_HeatC_TempSP = VAV#{i+1}_TempSP," + "\n"
      ems_string << "    ENDIF;" + "\n"
      ems_string << "\n"
    end
    #save EMS snippet
    runner.registerInfo("Saving ems_hot_water_coil_valve_leakage file")
    FileUtils.mkdir_p(File.dirname("ems_hot_water_coil_valve_leakage.ems")) unless Dir.exist?(File.dirname("ems_hot_water_coil_valve_leakage.ems"))
    File.open("ems_hot_water_coil_valve_leakage.ems", "w") do |f|
      f.write(ems_string)
    end
    
    #unique initial conditions based on
    runner.registerInitialCondition("The model contained #{airloop_name.size} number of VAV systems with hot water heating and reheat")

    #reporting final condition of model
    runner.registerFinalCondition("The following systems had leakage introduced to the hot water coils in their air handlers: #{airloop_name}")

    
    ems_path = '../HotWaterCoilValveLeakage/ems_hot_water_coil_valve_leakage.ems'
    json_path = '../HotWaterCoilValveLeakage/ems_results.json'
    if File.exist? ems_path
      ems_string = File.read(ems_path)
      if File.exist? json_path
        json = JSON.parse(File.read(json_path))
      end
    else
      ems_path2 = Dir.glob('../../**/ems_hot_water_coil_valve_leakage.ems')
      ems_path1 = ems_path2[0]
      json_path2 = Dir.glob('../../**/ems_results.json')
      json_path1 = json_path2[0]
      if ems_path2.size > 1
        runner.registerWarning("more than one ems_hot_water_coil_valve_leakage.ems file found.  Using first one found.")
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
          runner.registerError("ems_hot_water_coil_valve_leakage.ems file not located")
        end  
      else
        runner.registerError("ems_hot_water_coil_valve_leakage.ems file not located")    
      end
    end
    if json.nil?
      runner.registerError("ems_results.json file not located")
      return false
    end

    
    if json.empty?
      runner.registerWarning("No Airloops are appropriate for this measure")
      return true
    end
        
    idf_file = OpenStudio::IdfFile::load(ems_string, 'EnergyPlus'.to_IddFileType).get
    runner.registerInfo("Adding EMS code to workspace")
    workspace.addObjects(idf_file.objects)
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
HotWaterCoilValveLeakage.new.registerWithApplication