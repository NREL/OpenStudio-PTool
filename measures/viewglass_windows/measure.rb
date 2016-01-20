# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require_relative 'resources/HVACSizing.Model'
require_relative 'resources/Standards.Construction'

# start the measure
class ViewglassWindows < OpenStudio::Ruleset::ModelUserScript
	
	# human readable name
	def name
		return "Viewglass Windows"
	end
	
	# human readable description
	def description
		return "Add some Viewglass Windows"
	end
	
	# human readable description of modeling approach
	def modeler_description
		return "Add some Viewglass Windows"
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
    
		# Run the sizing run
    if model.runSizingRun("#{Dir.pwd}/SizingRun") == false
      runner.registerError("Sizing Run for determining the VT and SHGC failed to complete - check eplusout.err to debug.")
      return false
    end

    # Look up the SGHC and VT for all the 
    # fenestration constructions in the model 
    # from the E+ output SQL file.
    model.getConstructions.each do |const|
      next unless const.isFenestration
      next unless const.getNetArea > 0.0
      shgc = const.calculated_solar_heat_gain_coefficient
      vt = const.calculated_visible_transmittance
      u_factor = const.calculated_u_factor
      runner.registerInfo("#{const.name} = *#{const.name.get.to_s.upcase}*")
      runner.registerInfo("--E+ calc'd VT = #{vt}")
      runner.registerInfo("--E+ calc'd SHGC = #{shgc}")
      runner.registerInfo("--E+ calc'd U-Factor = #{u_factor} W/m^2*K")
    end
    
    # TODO the other stuff happens here
	
	end
end

# register the measure to be used by the application
ViewglassWindows.new.registerWithApplication
