# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class ReduceExteriorLightingFiftyPercent < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return " Reduce Exterior Lighting Fifty Percent"
  end

  # human readable description
  def description
    return "This is a test Measure to reduce exterior lighting power by 50%"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Not a real PTool Measure"
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

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    
  	# initialize variables
  	ext_ltg_pwr_reduction = 0.5

    # get model objects from model classes
	  ext_lights = model.getExteriorLightss #my precious

    # NA if no lights
		if ext_lights.empty?

			runner.registerAsNotApplicable("No exterior lights objects found in model.")
			return true

		else

			ext_lights.each do |ext_light|

        initial_mult = ext_light.multiplier
        
        new_mult = initial_mult * (1 - ext_ltg_pwr_reduction)
      
        ext_light.setMultiplier(new_mult)
      
        runner.registerInfo("Setting multiplier on #{ext_light.name} from #{initial_mult.round(2)} to #{new_mult.round(2)}")

			end

		end

  end #run method

end #class

# register the measure to be used by the application
ReduceExteriorLightingFiftyPercent.new.registerWithApplication
