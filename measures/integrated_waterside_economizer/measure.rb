#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class IntegratedWatersideEconomizer < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "IntegratedWatersideEconomizer"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure    
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    
    require 'json'
    results = {}
    
    def find_chiller_hookup_hx(model, plantLoop, results, runner)
      plantLoop.demandComponents.each do |comp|
        if comp.to_ChillerElectricEIR.is_initialized
          runner.registerInfo("Found Chiller: #{comp.name.to_s}")
          # Make the water to water heat exchanger (HX)
          runner.registerInfo("creating HeatExchanger")
          hx = OpenStudio::Model::HeatExchangerFluidToFluid.new(model)
          hx.setName("Integrated Waterside Economizer HX")
          hx.setHeatExchangeModelType("CounterFlow")
          hx.setControlType("CoolingDifferentialOnOff")
          hx.setMinimumTemperatureDifferencetoActivateHeatExchanger(5)
          hx.setHeatTransferMeteringEndUseType("FreeCooling")
          hx.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
          results[:hx_avail_schedule] = hx.availabilitySchedule.get.name.to_s
          # Add the HX to the supply side of the CHW loop
          # on the supply inlet node of the chiller, which is
          # typically on the suction side of the pump.
          # This puts the HX in series with the chiller(s).
          runner.registerInfo("hooking up chilled water side of HX")
          hx.addToNode(comp.to_ChillerElectricEIR.get.plantLoop.get.supplyInletNode)
          results[:chilled_loop_schedule] = comp.to_ChillerElectricEIR.get.plantLoop.get.loopTemperatureSetpointNode.setpointManagers[0].to_SetpointManagerScheduled.get.schedule.name.to_s
          results[:condenser_loop_schedule] = comp.to_ChillerElectricEIR.get.secondaryPlantLoop.get.loopTemperatureSetpointNode.setpointManagers[0].to_SetpointManagerScheduled.get.schedule.name.to_s
          # Add the HX to the demand side of the CW loop
          runner.registerInfo("hooking up condenser water side of HX")
          plantLoop.addDemandBranchForComponent(hx)
        end
      end
    end
    
    model.getPlantLoops.each_with_index do |plantLoop, index|
      if plantLoop.sizingPlant.loopType == 'Condenser' 
        skip = false
        plantLoop.supplyComponents.each do |comp|
          if comp.to_CoolingTowerVariableSpeed.is_initialized or comp.to_CoolingTowerSingleSpeed.is_initialized or comp.to_CoolingTowerTwoSpeed.is_initialized
            runner.registerInfo("cooling tower found on conderser loop #{plantLoop.name.to_s}")
            skip = true        
          end
          if skip == true
            plantLoop.setMinimumLoopTemperature(4)
            runner.registerInfo("setting Minimum loop temp to 4 on #{plantLoop.name.to_s}")
            runner.registerInfo("adding heat exchanger")
            find_chiller_hookup_hx(model, plantLoop, results, runner)
            break
          end
        end  
      else
         puts "No Condenser on plant loop #{plantLoop.name.to_s}"   
      end
    end

    #save plantloop parsing results to ems_results.json
    runner.registerInfo("Saving ems_results.json")
    FileUtils.mkdir_p(File.dirname("ems_results.json")) unless Dir.exist?(File.dirname("ems_results.json"))
    File.open("ems_results.json", 'w') {|f| f << JSON.pretty_generate(results)}
    
    if results.empty?
       runner.registerWarning("No Plantloops are appropriate for this measure")
       runner.registerAsNotApplicable("No Plantloops are appropriate for this measure")
       #save blank ems_advanced_rtu_controls.ems file so Eplus measure does not crash
       ems_string = ""
       runner.registerInfo("Saving blank integrated_waterside_economizer file")
       FileUtils.mkdir_p(File.dirname("integrated_waterside_economizer.ems")) unless Dir.exist?(File.dirname("integrated_waterside_economizer.ems"))
       File.open("integrated_waterside_economizer.ems", "w") do |f|
         f.write(ems_string)
       end
       return true
    end
    
    runner.registerInfo("Making EMS string for Integrated Waterside Economizer")
    #start making the EMS code
    ems_string = ""  #clear out the ems_string
    
    ems_string << "EnergyManagementSystem:Sensor," + "\n"
    ems_string << "TWb,                     !- Name" + "\n"
    ems_string << "*,                       !- Output:Variable or Output:Meter Index Key Name" + "\n"
    ems_string << "Site Outdoor Air WetBulb Temperature;  !- Output:Variable or Output:Meter Name" + "\n"
    ems_string << "" + "\n"
    ems_string << "EnergyManagementSystem:ProgramCallingManager," + "\n"
    ems_string << "    WSE_Manager,             !- Name" + "\n"
    ems_string << "    BeginTimestepBeforePredictor,  !- EnergyPlus Model Calling Point" + "\n"
    ems_string << "    WSE_Control;             !- Program Name 1" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Program," + "\n"
    ems_string << "    WSE_Control," + "\n"
    ems_string << "    IF TWb < 6," + "\n"
    ems_string << "      SET WSE = 1," + "\n"
    ems_string << "      SET ChWT = @Max Twb+4.5 6.67," + "\n"
    ems_string << "      SET TowerT = ChWT - 0.5," + "\n"
    ems_string << "    ELSE," + "\n"
    ems_string << "      SET WSE = 0," + "\n"
    ems_string << "      SET TowerT = 26.7," + "\n"
    ems_string << "      SET ChWT = 6.67," + "\n"
    ems_string << "    ENDIF;" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Actuator," + "\n"
    ems_string << "    WSE,                     !- Name" + "\n"
    ems_string << "   #{results[:hx_avail_schedule]},  !- Actuated Component Unique Name" + "\n"
    ems_string << "   Schedule:Constant,       !- Actuated Component Type" + "\n"
    ems_string << "   Schedule Value;          !- Actuated Component Control Type" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Actuator," + "\n"
    ems_string << "    TowerT,                  !- Name" + "\n"
    ems_string << "    #{results[:condenser_loop_schedule]},  !- Actuated Component Unique Name" + "\n"
    ems_string << "    Schedule:Year,        !- Actuated Component Type" + "\n"
    ems_string << "    Schedule Value;          !- Actuated Component Control Type" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Actuator," + "\n"
    ems_string << "    ChwT,                    !- Name" + "\n"
    ems_string << "    #{results[:chilled_loop_schedule]},  !- Actuated Component Unique Name" + "\n"
    ems_string << "    Schedule:Year,        !- Actuated Component Type" + "\n"
    ems_string << "    SChedule Value;          !- Actuated Component Control Type" + "\n"
    ems_string << "\n"
       
    #save EMS snippet
    runner.registerInfo("Saving integrated_waterside_economizer file")
    FileUtils.mkdir_p(File.dirname("integrated_waterside_economizer.ems")) unless Dir.exist?(File.dirname("integrated_waterside_economizer.ems"))
    File.open("integrated_waterside_economizer.ems", "w") do |f|
      f.write(ems_string)
    end   
    
    
    #unique initial conditions based on
    #runner.registerInitialCondition("The building has #{results.length} constant air volume units for which this measure is applicable.")

    #reporting final condition of model
    #runner.registerFinalCondition("VSDs and associated controls were applied to  #{results.length} single-zone, constant air volume units in the model.  Airloops affected were #{airloop_name}")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
IntegratedWatersideEconomizer.new.registerWithApplication