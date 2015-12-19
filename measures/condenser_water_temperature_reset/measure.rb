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
class CondenserWaterTemperatureReset < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Condenser Water Temperature Reset"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) lowers the condenser loop set point temperature to take advantage of free cooling when the outdoor air wet bulb temperature is low enough. By providing cooler temperature condenser water (when available), the compressor is able to operate more efficiently, using less energy to provide the same amount of cooling to the building."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This EEM adds EMS logic to the model that actuates the condenser loop setpoint manager. The added logic first checks the outdoor air wet-bulb temperature (OAWBT). If OAWBT is between 14.3C and 22.7C then the condenser loop setpoint temperature is set to OAWBT + 4C. If the OAWBT is above 22.7C, the condenser loop setpoint temperature is set to 26.7C. If the OAWBT is below 14.3C, the condenser loop setpoint temperature is set to 18.3C."
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
    
    
    ems_path = '../CondenserWaterTemperatureReset/ems_condenser_water_temperature_reset.ems'
    json_path = '../CondenserWaterTemperatureReset/ems_results.json'
    if File.exist? ems_path
      ems_string = File.read(ems_path)
      if File.exist? json_path
        json = JSON.parse(File.read(json_path))
      end
    else
      ems_path2 = Dir.glob('../../**/ems_condenser_water_temperature_reset.ems')
      ems_path1 = ems_path2[0]
      json_path2 = Dir.glob('../../**/ems_results.json')
      json_path1 = json_path2[0]
      if ems_path2.size > 1
        runner.registerWarning("more than one ems_condenser_water_temperature_reset.ems file found.  Using first one found.")
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
          runner.registerError("ems_condenser_water_temperature_reset.ems file not located")
        end  
      else
        runner.registerError("ems_condenser_water_temperature_reset.ems file not located")    
      end
    end
    if json.nil?
      runner.registerError("ems_results.json file not located")
      return false
    end
    
    if json.empty?
      runner.registerWarning("No Plantloops are appropriate for this measure")
      return true
    end
       
    idf_file = OpenStudio::IdfFile::load(ems_string, 'EnergyPlus'.to_IddFileType).get
    runner.registerInfo("Adding EMS code to workspace")
    workspace.addObjects(idf_file.objects)
    
    #unique initial conditions based on
    #runner.registerInitialCondition("The building has #{emsProgram.size} EMS objects.")

    #reporting final condition of model
    #runner.registerFinalCondition("The building finished with #{emsProgram.size} EMS objects.")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
CondenserWaterTemperatureReset.new.registerWithApplication