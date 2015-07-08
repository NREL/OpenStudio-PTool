#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class PlantShutdown < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "PlantShutdown"
  end

  #define the arguments that the user will input
  def arguments(model)
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
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end
    
    require 'json'
    
    def pump_control(pump, pumps, runner)
      changed = false
      runner.registerInfo("pump control type #{pump.pumpControlType}")
      if pump.pumpControlType == "Continuous"
        runner.registerInfo("setting pump #{pump.name.to_s} control type to Intermittent")
        pump.setPumpControlType("Intermittent")
        pumps << pump.name.to_s
        changed = true
      end
      if pump.pumpFlowRateSchedule.is_initialized
        runner.registerInfo("resetting pump #{pump.name.to_s} pumpFlowRateSchedule")
        pump.resetPumpFlowRateSchedule
      end
      return changed
    end

    def check_supply_side(plantLoop, i, pumps, runner)
      changed = false
      plantLoop.supplyComponents.each_with_index do |comp, index|
        pump = comp.to_PumpConstantSpeed
        if pump.is_initialized
          runner.registerInfo("plant loop #{i.to_s} has constant pump")
          changed = pump_control(pump.get, pumps, runner)
        end
        pump = comp.to_PumpVariableSpeed
        if pump.is_initialized
          runner.registerInfo("plant loop #{i.to_s} has variable pump")
          changed = pump_control(pump.get, pumps, runner)
        end
      end
      return changed
    end

    results = []
    skipped = []
    na = []
    pumps = []

    model.getPlantLoops.each_with_index do |plantLoop, index|
      changed = false
      skip = false
      plantLoop.demandComponents.each do |comp|
        if comp.to_WaterUseConnections.is_initialized
          runner.registerInfo("plant loop #{index.to_s} uses water, skipping")
          skip = true
          skipped << plantLoop.name.to_s
        end
        break if skip == true
      end
      changed = check_supply_side(plantLoop, index, pumps, runner) if skip == false
      if skip == false
        changed == true ? results << plantLoop.name.to_s : na << plantLoop.name.to_s
      end  
    end
        
    #unique initial conditions based on
    if !results.empty?
      runner.registerInitialCondition("The initial model has #{results.length} pumps set to operate continuously; this measure is applicable.")
    end

    if results.empty?
      runner.registerAsNotApplicable("No continuously operating chilled-water loop, hot-water loop, or condenser loop pumps were found. EEM not applied")
      return true
    end
    
    #reporting final condition of model
    runner.registerFinalCondition("The following pumps were set to operate intermittently: #{results} \n The following pumps were skipped: #{skipped} \n The following pumps were not applicable: #{na}")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
PlantShutdown.new.registerWithApplication