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
class MembraneHeatPumpCoolingOnly < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Membrane Heat Pump Cooling Only"
  end

  # human readable description
  def description
    return "Unlike a standard heat pump with an electric compressor, a membrane heat pumps works in two stages.  First, latent cooling (moisture removal) is performed by using a vacuum pump to extract moisture from the airstream via a membrane that is moisture permeable but not air permeable.  Second, sensible cooling is provided via a chilled water loop, which is itself cooled by using the same vacuum pump to perform forced evaporative cooling via another membrane.  Moisture is rejected to the outdoor air via a third membrane. The entire system has peak EER of about 26, which is significantly higher than traditional DX cooling equipment.  However, the evaporative cooling process that cools the chilled water loop consumes roughly 3 gallons of water per ton-hour of sensible cooling."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Each DX cooling coil in the model is replaced by a membrane heat pump.  To represent the membrane heat pump, the DX cooling coil COP is increased to 7.62 (26 EER).  Additionally, add a water use equipment object to account for the 3 gallons of water used per ton*hr of sensible cooling process."
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
    
    #get all DX coils in model
    dx_single = workspace.getObjectsByType("Coil:Cooling:DX:SingleSpeed".to_IddObjectType)
    dx_two = workspace.getObjectsByType("Coil:Cooling:DX:TwoSpeed".to_IddObjectType)
    
    dx_single.each do |dx|
      dx_name = {}
      coil_name = dx.getString(0).get
      runner.registerInfo("DX coil: #{coil_name} Initial COP: #{dx.getDouble(4).get}")
      dx.setDouble(4,7.62)
      runner.registerInfo("DX coil: #{coil_name} Final COP: #{dx.getDouble(4).get}")
      dx_name[:dxname] = "#{coil_name}"
      results["#{coil_name}"] = dx_name
    end

    dx_two.each do |dx|
      dx_name = {}
      coil_name = dx.getString(0).get
      runner.registerInfo("DX coil: #{coil_name} Initial High COP: #{dx.getDouble(4).get}, Initial Low COP: #{dx.getDouble(16).get}")
      dx.setDouble(4,7.62)
      dx.setDouble(16,7.62)
      runner.registerInfo("DX coil: #{coil_name} Final High COP: #{dx.getDouble(4).get}, Final Low COP: #{dx.getDouble(16).get}")
      dx_name[:dxname] = "#{coil_name}"
      results["#{coil_name}"] = dx_name
    end
       
    if results.empty?
       runner.registerWarning("No DX coils are appropriate for this measure")
       runner.registerAsNotApplicable("No DX coils are appropriate for this measure")
    end
     
    #save airloop parsing results to ems_results.json
    runner.registerInfo("Saving ems_results.json")
    FileUtils.mkdir_p(File.dirname("ems_results.json")) unless Dir.exist?(File.dirname("ems_results.json"))
    File.open("ems_results.json", 'w') {|f| f << JSON.pretty_generate(results)}
    
    if results.empty?
       runner.registerWarning("No DX coils are appropriate for this measure")
       runner.registerAsNotApplicable("No DX coils are appropriate for this measure")
       #save blank ems_membrane_heat_pump_cooling_only.ems file so Eplus measure does not crash
       ems_string = ""
       runner.registerInfo("Saving blank ems_membrane_heat_pump_cooling_only file")
       FileUtils.mkdir_p(File.dirname("ems_membrane_heat_pump_cooling_only.ems")) unless Dir.exist?(File.dirname("ems_membrane_heat_pump_cooling_only.ems"))
       File.open("ems_membrane_heat_pump_cooling_only.ems", "w") do |f|
         f.write(ems_string)
       end
       return true
    end
    
    timeStep = model.getTimestep.numberOfTimestepsPerHour
    
    runner.registerInfo("Making EMS string for Membrane Heat Pump Cooling Only")
    #start making the EMS code
    ems_string = ""  #clear out the ems_string
    ems_string << "\n" 
    ems_string << "Output:Variable,*,Cooling Coil Sensible Cooling Energy,timestep; !- HVAC Sum [J]" + "\n"
    ems_string << "\n" 
      
    results.each_with_index do |(key, value), i|  
      ems_string << "EnergyManagementSystem:Sensor," + "\n"
      ems_string << "    MembraneHP#{i+1}SensibleClgJ," + "\n"
      ems_string << "    #{value[:dxname]}," + "\n"
      ems_string << "    Cooling Coil Sensible Cooling Energy;" + "\n"
      ems_string << "\n" 
      ems_string << "WaterUse:Equipment," + "\n"
      ems_string << "  MembraneHP#{i+1}WaterUse, !- Name" + "\n"
      ems_string << "  Membrane HP Cooling, !- End-Use Subcategory" + "\n"
      ems_string << "  0.003155, !- Peak Flow Rate {m3/s} = 3000 gal/hr" + "\n"
      ems_string << "  MembraneHP#{i+1}WaterUseSchedule; !- Flow Rate Fraction Schedule Name" + "\n"
      ems_string << "\n" 
      ems_string << "Schedule:Constant," + "\n"
      ems_string << "  MembraneHP#{i+1}WaterUseSchedule,          !- Name" + "\n"
      ems_string << "  ,                             !- Schedule Type Limits Name" + "\n"
      ems_string << "  1;                                      !- Hourly Value" + "\n"
      ems_string << "\n" 
      ems_string << "EnergyManagementSystem:Actuator," + "\n"
      ems_string << "    MembraneHP#{i+1}WaterUseCtrl," + "\n"
      ems_string << "    MembraneHP#{i+1}WaterUseSchedule," + "\n"
      ems_string << "    Schedule:Constant," + "\n"
      ems_string << "   Schedule Value;" + "\n"
      ems_string << "\n"   
    end
    ems_string << "EnergyManagementSystem:ProgramCallingManager," + "\n"
    ems_string << "    MembraneHPWaterUseProgramControl,    !- Name" + "\n"
    ems_string << "    AfterPredictorBeforeHVACManagers,  !- EnergyPlus Model Calling Point" + "\n"
    ems_string << "    MembraneHPWaterUseProgram;            !- Program Name 1" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Program," + "\n"
    ems_string << "    MembraneHPWaterUseProgram,        !- Name" + "\n"
    ems_string << "    SET TimeStepsPerHr = #{timeStep}" + "\n"
    results.each_with_index do |(key, value), i|
      ems_string << "    SET MembraneHP#{i+1}SensibleClgTonHr = MembraneHP#{i+1}SensibleClgJ * 0.0000007898," + "\n"
      ems_string << "    SET MembraneHP#{i+1}SensibleWtrGal = MembraneHP#{i+1}SensibleClgTonHr * 3.0," + "\n"
      ems_string << "    SET MembraneHP#{i+1}SensibleWtrGalPerHr = MembraneHP#{i+1}SensibleWtrGal * TimeStepsPerHr," + "\n"
      ems_string << "    SET MembraneHP#{i+1}WaterUseCtrl = MembraneHP#{i+1}SensibleWtrGalPerHr / 3000.0," + "\n"
    end    
    ems_string << "    SET UnusedLine = 0;" + "\n"
    
    #save EMS snippet
    runner.registerInfo("Saving ems_membrane_heat_pump_cooling_only file")
    FileUtils.mkdir_p(File.dirname("ems_membrane_heat_pump_cooling_only.ems")) unless Dir.exist?(File.dirname("ems_membrane_heat_pump_cooling_only.ems"))
    File.open("ems_membrane_heat_pump_cooling_only.ems", "w") do |f|
      f.write(ems_string)
    end
    
    #unique initial conditions based on
    runner.registerInitialCondition("The building has #{results.size} DX coils for which this measure is applicable.")

    #reporting final condition of model
    runner.registerFinalCondition("The efficiency of the following coils was increased to SEER 26 to reflect the replacement of these coils with membrane heatpumps: #{results.keys}")
    
    ems_path = '../MembraneHeatPumpCoolingOnly/ems_membrane_heat_pump_cooling_only.ems'
    json_path = '../MembraneHeatPumpCoolingOnly/ems_results.json'
    if File.exist? ems_path
      ems_string = File.read(ems_path)
      if File.exist? json_path
        json = JSON.parse(File.read(json_path))
      end
    else
      ems_path2 = Dir.glob('../../**/ems_membrane_heat_pump_cooling_only.ems')
      ems_path1 = ems_path2[0]
      json_path2 = Dir.glob('../../**/ems_results.json')
      json_path1 = json_path2[0]
      if ems_path2.size > 1
        runner.registerWarning("more than one ems_membrane_heat_pump_cooling_only.ems file found.  Using first one found.")
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
          runner.registerError("ems_membrane_heat_pump_cooling_only.ems file not located")
        end  
      else
        runner.registerError("ems_membrane_heat_pump_cooling_only.ems file not located")    
      end
    end
    if json.nil?
      runner.registerError("ems_results.json file not located")
      return false
    end
    
    if json.empty?
      runner.registerWarning("No DX coils are appropriate for this measure")
      return true
    end
        
    idf_file = OpenStudio::IdfFile::load(ems_string, 'EnergyPlus'.to_IddFileType).get
    runner.registerInfo("Adding EMS code to workspace")
    workspace.addObjects(idf_file.objects)
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
MembraneHeatPumpCoolingOnly.new.registerWithApplication