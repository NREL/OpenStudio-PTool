#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class CondenserWaterTemperatureReset < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "CondenserWaterTemperatureReset"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    require 'json'
    
    results = {}
    plantloop_name = []
    # Loop over the airloops to find valid ones for this measure
    model.getPlantLoops.each do |plant_loop|
      found_sm = 0  #have not found any cooling coils
      temp = {}
      if plant_loop.sizingPlant.loopType == 'Condenser' 
        setpointMan = plant_loop.loopTemperatureSetpointNode().setpointManagers()
        setpointManName = setpointMan[0].name
        sch = setpointMan[0].to_SetpointManagerScheduled.get.schedule
        setpointManSchName = sch.name
        
        found_sm += 1  #found necessary Fan object
        temp[:setpointmanager] = "#{setpointManName}"
        temp[:setpointmanagerschedule] = "#{setpointManSchName}"
      else
        #runner.registerInfo("No Condenser on plant loop #{plant_loop.name.to_s}")  
      end
      if (found_sm) == 1  #add valid plant loop to results
        results["#{plant_loop.name}"] = temp
        plantloop_name << "#{plant_loop.name.to_s}"
        #runner.registerInfo("Adding valid plantloop #{plant_loop.name.to_s} to results.")
      end  
      
    end

    #save airloop parsing results to ems_results.json
    runner.registerInfo("Saving ems_results.json")
    FileUtils.mkdir_p(File.dirname("ems_results.json")) unless Dir.exist?(File.dirname("ems_results.json"))
    File.open("ems_results.json", 'w') {|f| f << JSON.pretty_generate(results)}
    
    if results.empty?
       runner.registerWarning("No Plantloops are appropriate for this measure")
       runner.registerAsNotApplicable("No Plantloops are appropriate for this measure")
       #save blank ems_advanced_rtu_controls.ems file so Eplus measure does not crash
       ems_string = ""
       runner.registerInfo("Saving blank ems_condenser_water_temperature_reset file")
       FileUtils.mkdir_p(File.dirname("ems_condenser_water_temperature_reset.ems")) unless Dir.exist?(File.dirname("ems_condenser_water_temperature_reset.ems"))
       File.open("ems_condenser_water_temperature_reset.ems", "w") do |f|
         f.write(ems_string)
       end
       return true
    end
    
    if results.size > 1
      runner.registerError("more than one condenser found in model")
      return false
    end
    
    runner.registerInfo("Making EMS string for condenser_water_temperature_reset")
    #start making the EMS code
    ems_string = ""  #clear out the ems_string
    results.each_with_index do |(key, value), i|
      ems_string << "EnergyManagementSystem:Sensor," + "\n"
      ems_string << "    T_WB_OA,                 !- Name" + "\n"
      ems_string << "    ,                        !- Output:Variable or Output:Meter Index Key Name " + "\n"
      ems_string << "    Site Outdoor Air WetBulb Temperature;  !- Output:Variable or Output:Meter Name" + "\n"
      ems_string << "\n"
      ems_string << "EnergyManagementSystem:Actuator," + "\n"
      ems_string << "    Tower_TempSP_Actuator,   !- Name" + "\n"
      ems_string << "    #{value[:setpointmanagerschedule]},  !- Actuated Component Unique Name" + "\n"
      ems_string << "    Schedule:Year,        !- Actuated Component Type" + "\n"
      ems_string << "    Schedule Value;          !- Actuated Component Control Type" + "\n"
      ems_string << "\n"
      ems_string << "EnergyManagementSystem:ProgramCallingManager," + "\n"
      ems_string << "    Tower_TempReset_Manager, !- Name" + "\n"
      ems_string << "    AfterPredictorAfterHVACManagers,  !- EnergyPlus Model Calling Point" + "\n"
      ems_string << "    Tower_TempReset;         !- Program Name 1" + "\n"
      ems_string << "\n"
      ems_string << "EnergyManagementSystem:Program," + "\n"
      ems_string << "    Tower_TempReset,         !- Name" + "\n"
      ems_string << "    IF (T_WB_OA + 4) >= 18.3,  !- Program Line 1" + "\n"
      ems_string << "    	IF (T_WB_OA + 4) <= 26.7,  !- Program Line 2" + "\n"
      ems_string << "    	    SET Tower_TempSP_Actuator = T_WB_OA + 4,  !- A4" + "\n"
      ems_string << "    	ELSE,                    !- A5" + "\n"
      ems_string << "    	    SET Tower_TempSP_Actuator = 26.7," + "\n"
      ems_string << "    	ENDIF,                   !- A7" + "\n"
      ems_string << "   ELSE,                    !- A8" + "\n"
      ems_string << "    	SET Tower_TempSP_Actuator = 18.3,  !- A9" + "\n"
      ems_string << "    ENDIF;                   !- A10" + "\n"
      ems_string << "\n"
    end 
    #save EMS snippet
    runner.registerInfo("Saving ems_condenser_water_temperature_reset file")
    FileUtils.mkdir_p(File.dirname("ems_condenser_water_temperature_reset.ems")) unless Dir.exist?(File.dirname("ems_condenser_water_temperature_reset.ems"))
    File.open("ems_condenser_water_temperature_reset.ems", "w") do |f|
      f.write(ems_string)
    end
    
    #unique initial conditions based on
    runner.registerInitialCondition("The building has #{results.length} plant loops for which this measure is applicable.")

    #reporting final condition of model
    runner.registerFinalCondition("condenser_water_temperature_reset was applied to Plantloops #{plantloop_name}")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
CondenserWaterTemperatureReset.new.registerWithApplication