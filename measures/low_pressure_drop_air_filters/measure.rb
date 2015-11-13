# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class LowPressureDropAirFilters < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Low Pressure Drop Air Filters"
  end

  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
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
    pressure_drop_reduction_inh2o = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("pressure_drop_reduction_inh2o",true)
    pressure_drop_reduction_inh2o.setDisplayName("Pressure Drop Reduction")
    pressure_drop_reduction_inh2o.setUnits("in W.C.")
    pressure_drop_reduction_inh2o.setDefaultValue(1.0)
    args << pressure_drop_reduction_inh2o

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
    

    pressure_drop_reduction_inh2o = runner.getDoubleArgumentValue("pressure_drop_reduction_inh2o",user_arguments)

  
    
    # Check arguments for reasonableness
    if pressure_drop_reduction_inh2o >= 4
      runner.registerError("Pressure drop reduction must be less than 4 in W.C. to be reasonable.")
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
          new_pd_inh2o = current_pd_inh2o - pressure_drop_reduction_inh2o
          # Error if requested pressur drop less than 0
          if new_pd_inh2o <= 0
            runner.registerWarning("Initial pressure drop of #{air_loop.name} was #{current_pd_inh2o.round(1)}, less than the requested pressure drop reduction of #{pressure_drop_reduction_inh2o.round(1)}.  Pressure drop for this loop was unchanged.")
            next # Next airloop
          end
          new_pd_pa = OpenStudio.convert(new_pd_inh2o, "inH_{2}O", "Pa").get
          fan.setPressureRise(new_pd_pa)
          runner.registerInfo("Lowered pressure drop on #{air_loop.name} by #{pressure_drop_reduction_inh2o} in W.C. from #{current_pd_inh2o.round(1)} in W.C to #{new_pd_inh2o.round(1)} in W.C.")
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
    runner.registerFinalCondition("Lowered pressure drop on air filters in #{air_loops_pd_lowered.size} air loops.")

    return true

  end
  
end

# register the measure to be used by the application
LowPressureDropAirFilters.new.registerWithApplication
