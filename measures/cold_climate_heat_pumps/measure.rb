# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class ColdClimateHeatPumps < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "cold_climate_heat_pumps"
  end

  # human readable description
  def description
    return "asdf"
  end

  # human readable description of modeling approach
  def modeler_description
    return "asdf"
  end

  # define the arguments that the user will input
  def arguments(model)
   
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
   
  end
  
end

# register the measure to be used by the application
ColdClimateHeatPumps.new.registerWithApplication