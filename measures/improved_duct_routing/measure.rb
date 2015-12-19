# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class ImprovedDuctRouting < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Improved Duct Routing"
  end

  # human readable description
  def description
    return "The more restrictions and bends in the ductwork that air must move through to reach a space, the greater the fan energy required to move the air.  Using larger ducts or routing them to avoid restrictions and bends can decrease fan energy."
  end

  # human readable description of modeling approach
  def modeler_description
    return "For each AirLoop in the model, reduce the fan pressure drop by the user-specified amount (default 10%).  This default is a conservative estimate; further reductions may be achieved, but may not be practical based on size and cost constraints."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure 
    
    # Make an argument for the percent pressure drop reduction
    pressure_drop_reduction_pct = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("pressure_drop_reduction_pct",true)
    pressure_drop_reduction_pct.setDisplayName("Pressure Drop Reduction Percent")
    pressure_drop_reduction_pct.setUnits("%")
    pressure_drop_reduction_pct.setDefaultValue(10.0)
    args << pressure_drop_reduction_pct

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    

    pressure_drop_reduction_pct = runner.getDoubleArgumentValue("pressure_drop_reduction_pct",user_arguments)

    # Convert the pressure drop reduction to a multiplier
    pd_mult = (100 - pressure_drop_reduction_pct)/100
    
  
    
    # Check arguments for reasonableness
    if pressure_drop_reduction_pct <= 0 || pressure_drop_reduction_pct >= 100 
      runner.registerError("Pressure drop reduction percent must be between 0 and 100.")
      return false
    end

    # Loop through all air loops, find the fan,
    # and reduce the pressure drop to model the impact
    # of lower pressure drop filters.
    air_loops_pd_lowered = []
    air_loops = []
    model.getAirLoopHVACs.each do |air_loop|
      air_loops << air_loop
      air_loop.supplyComponents.each do |supply_comp|
        fan = nil
        if supply_comp.to_FanConstantVolume.is_initialized
          fan = supply_comp.to_FanConstantVolume.get
        elsif supply_comp.to_FanVariableVolume.is_initialized
          fan = supply_comp.to_FanVariableVolume.get
        end
        if !fan.nil?
          current_pd_pa = fan.pressureRise
          current_pd_inh2o = OpenStudio.convert(current_pd_pa, "Pa", "inH_{2}O").get
          new_pd_inh2o = current_pd_inh2o * pd_mult
          new_pd_pa = OpenStudio.convert(new_pd_inh2o, "inH_{2}O", "Pa").get
          fan.setPressureRise(new_pd_pa)
          runner.registerInfo("Lowered pressure drop on #{air_loop.name} by #{pressure_drop_reduction_pct}% from #{current_pd_inh2o.round(1)} in W.C to #{new_pd_inh2o.round(1)} in W.C.")
          air_loops_pd_lowered << air_loop
        end
      end
    end
    
    # Not applicable if no air loops
    if air_loops.size == 0
      runner.registerAsNotApplicable("This measure is not applicable because there were no airloops in the building.")
      return true    
    end
    
    # Not applicable if no airloops were modified
    if air_loops_pd_lowered.size == 0
      runner.registerAsNotApplicable("This measure is not applicable because none of the airloops in the model were impacted.")
      return true
    end  
        
    # Report final condition
    runner.registerFinalCondition("Lowered fan static pressure on #{air_loops_pd_lowered.size} air loops to reflect improved duct routing.")

    return true

  end
  
end

# register the measure to be used by the application
ImprovedDuctRouting.new.registerWithApplication
