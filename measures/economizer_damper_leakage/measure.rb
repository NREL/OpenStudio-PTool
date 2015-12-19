# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require_relative 'resources/HVACSizing.Model'

# start the measure
class EconomizerDamperLeakage < OpenStudio::Ruleset::ModelUserScript
	
	# human readable name
	def name
		return "Economizer Damper Leakage"
	end
	
	# human readable description
	def description
		return "This energy efficiency measure (EEM) changes the minimum outdoor air flow requirement of all Controller:OutdoorAir objects present in a model to represent a value equal to a continuous 10% of outdoor air flow  damper leakage condition . For cases where the outdoor air controller is not configured for airside economizer operation, the measure triggers an NA message. For cases of controllers configured for airside economizer operation, the measure calculates and assigns a minimum outdoor airflow rate value equal to 10% of the calculated system maximum outdoor air flow rate.  For the economizer case, outdoor air damper leakage is set to occur for all hours of the simulation."
	end
	
	# human readable description of modeling approach
	def modeler_description
		return "This measure loops through all 'Controller:OutdoorAir' objects present on all air loops in the model. If the Controller Economizer Control Type is set to 'No Economizer', the measure will show 'not applicable' message. If the Controller Economizer Control Type is not set to 'No Economizer', the attribute of 'IsMaximumOutdoorAirFlowRateAutosized will be examined. If it is 'true', sizing run will be initiated & value of 'MaximumOutdoorAirflowRate' will be retrieved. If it is 'false', the value of 'MaximumOutdoorAirflowRate' will be retrieved. In any case, the value of 'MaximumOutdoorAirflowRate' will be multiplied by 0.10 & assigned to the 'MinimumOutdoorAirflowRate' attribute. A schedule maintaining this minimum value for all hours of the year is created and assigned to attribute 'Minimum Outside Air Schedule'. "
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
		
		# define neat numbers	
		def neat_numbers(number, roundto = 2) #round to 0 or 2)
			if roundto == 2
				number = sprintf "%.2f", number
				else
				number = number.round
			end
			#regex to add commas
			number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
		end #end def neat_numbers
		
		# use the built-in error checking
		if !runner.validateUserArguments(arguments(model), user_arguments)
			return false
		end
		
    # Report that this is an anti-measure
    runner.registerValue('anti_measure',true)
    
    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    
		#initializing variables
		sizing_run_required_counter = 0
		initial_oa_controller_array = []
		economizer_array_true = []
		economizer_array_false = []
		economizer_settings_changed_count = 0
		#create new constant 'always ON' schedule object
		always_on = model.alwaysOnDiscreteSchedule
		
		# determine if autosizing is needed
			# if any minimum OA air flow rate attribute to a OA controller object is set to autosized
		# we will need to run a sizing run
		model.getAirLoopHVACs.each do |loop|
			oa_air_sys = loop.airLoopHVACOutdoorAirSystem.get 
			@initial_oa_controller = oa_air_sys.getControllerOutdoorAir
			max_oa_autosize_status = @initial_oa_controller.isMaximumOutdoorAirFlowRateAutosized
			@econ_control_type_initial = @initial_oa_controller.getEconomizerControlType
			if @econ_control_type_initial != "NoEconomizer"
				if max_oa_autosize_status == true
					sizing_run_required_counter +=1
				end # end the min_oa_autosize if statement
			end	 # end control type if statement
		end # end the do loop through airloops
		# execute the sizing run
		if sizing_run_required_counter !=0
			if model.runSizingRun("#{Dir.pwd}/SizingRun") == false
				runner.registerError("Sizing Run for determining the autosizing of maximum OA flow rate '#{@initial_oa_controller.name}' failed to complete - check eplusout.err to debug.")
				return false
				else 
				runner.registerInfo("A sizing run for determining maximum OA flow rate '#{@initial_oa_controller.name}' completed - look in folder #{Dir.pwd}/SizingRun for results.")
			end # end model.sizing run if statement
		end # end the sizing run
		# set the value of min_oa_flow for autosized or hardsized conditions
		all_airloops = model.getAirLoopHVACs
		all_airloops.each do |loop|
			oa_air_sys = loop.airLoopHVACOutdoorAirSystem.get 
			# get OA controllers
			@initial_oa_controller = oa_air_sys.getControllerOutdoorAir
			initial_oa_controller_array << @initial_oa_controller # array for all controllers
			@econ_control_type_initial = @initial_oa_controller.getEconomizerControlType
			# if condition if control type is not equal to 'noEconomizer'
			if @econ_control_type_initial != "NoEconomizer"
				economizer_array_true << @initial_oa_controller
				# check autosizing for maximum OA air flowrate	
				max_oa_autosize_status = @initial_oa_controller.isMaximumOutdoorAirFlowRateAutosized
				# if condition when status is true
				if max_oa_autosize_status == true
					autosized_max_oa_rate = @initial_oa_controller.autosizedMaximumOutdoorAirFlowRate.get
					# convert existing CFM into IP unit
					existing_cfm = OpenStudio.convert(autosized_max_oa_rate,"m^3/s","cfm")
					existing_cfm = neat_numbers(existing_cfm,2)
					# Setting minimum OA flow rate equals to 10% of autosized max OA rate
					new_value_OA = 0.1 * autosized_max_oa_rate
					#conversion
					new_cfm = OpenStudio.convert(new_value_OA,"m^3/s","cfm")
					new_cfm = neat_numbers(new_cfm,2)
					#assign the new value for min OA air flow
					@initial_oa_controller.setMinimumOutdoorAirFlowRate(new_value_OA)
					# assign the new schedule = always ON
					@initial_oa_controller.setMinimumOutdoorAirSchedule(always_on)
					economizer_settings_changed_count +=1
					runner.registerInfo("The airloop '#{loop.name}' with OA controller named '#{@initial_oa_controller.name}' has had a minimum OA rate set to #{new_cfm} from #{existing_cfm}.")
				else
					# testing to see if maximum OA flow rate is empty
					if @initial_oa_controller.maximumOutdoorAirFlowRate.is_initialized
						init_max_oa_rate = @initial_oa_controller.maximumOutdoorAirFlowRate.get	
						# convert existing CFM into IP unit
						existing_cfm = OpenStudio.convert(init_max_oa_rate,"m^3/s","cfm")
						existing_cfm = neat_numbers(existing_cfm,2)
					end	
					# Setting minimum OA flow rate equals to 10% of autosized max OA rate
					new_value_OA = init_max_oa_rate * 0.1
					new_cfm = OpenStudio.convert(new_value_OA,"m^3/s","cfm")
					new_cfm = neat_numbers(new_cfm,2)
					# assign new values & schedules
					@initial_oa_controller.setMinimumOutdoorAirFlowRate(new_value_OA)
					@initial_oa_controller.setMinimumOutdoorAirSchedule(always_on)
					runner.registerInfo("the OA controller named '#{@initial_oa_controller.name}' has had a minimum OA rate set to #{new_cfm} from #{existing_cfm}.")
					economizer_settings_changed_count += 1
				end # end if max autosize equal true 
			else
				economizer_array_false << @initial_oa_controller
			end # end if @econ_control_type_initial != "NoEconomizer"
				
		end # end the do loop through all airloops
		
		# report N/A condition of model
		if economizer_settings_changed_count == 0
			runner.registerAsNotApplicable("The model contains no OA controllers which are currently configured for operable economizer controls. This measure is not applicable.")
			return true
		end
		
		# report initial condition of model
		runner.registerInitialCondition("The initial model contained #{all_airloops.length} airloops with #{initial_oa_controller_array.length} Outdoor Air Controller objects. The measure is applicable for #{economizer_array_true.length} objects with functioning economizer controls.")
		
		# report final condition of model
		runner.registerFinalCondition("A continuous outdoor air damper leakage condition representing poor damper/actuator control has been applied to #{economizer_array_true.length} Outdoor Air Controllers. There are #{economizer_array_false.length} objects with control type = 'no economizer'.")
		
	end # end the run method	
end # end the class	

# register the measure to be used by the application
EconomizerDamperLeakage.new.registerWithApplication
