# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class ReduceEconomizerDamperLeakage < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Reduce Economizer Damper Leakage"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) changes the minimum outdoor air flow requirement of all Controller:OutdoorAir objects present in a model to represent a value equal to a continuous 10% of outdoor air flow  damper leakage condition . For cases where the outdoor air controller is not configured for airside economizer operation, the measure calculates and assigns a minimum outdoor airflow rate value equal to 10% of the calculated system minimum outdoor air flow rate.  For cases of controllers capable of airside economizer operation,  the measure calculates and assigns a minimum outdoor airflow rate value equal to 10% of the calculated system maximum outdoor air flow rate.  For both cases, outdoor air damper leakage is set to occur for all hours of the simulation. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure loops through all 'Controller:OutdoorAir' objects present on all air loops in the model. If the Controller Economizer Control Type is set to 'No Economizer', the measure will examine the value for the 'Minimum Outdoor Air Flow Rate attribute'. . If it equals = 'Autosize', nothing is changed, If the value for the Minimum Outdoor Flow Rate = 0 then the attribute value is replaced with 'AutoSize'. An OpenStudio sizing run is executed, and the Autosized value for the Minimum Outdoor Air Flow Rate is retrieved from results. For both cases, a new value for the Minimum Outdoor Air Flow Rate value equal to 10% of the Autosized value is set. A schedule maintaining this minimum value for all hours of the year is created and assigned to the airflow is assigned to the field 'Minimum Outside Air Schedule'."
	end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
	
	
	require_relative 'resources/HVACSizing.Model'
	
    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
	
	# Open a channel to log info/warning/error messages
    @msg_log = OpenStudio::StringStreamLogSink.new
    @msg_log.setLogLevel(OpenStudio::Info)
	@runner = runner
	
	#STEP1 initialize the variables (arrays)
	airloops_array = []
	initial_oa_controller_array = []
	no_economizer_array_true = []
	no_economizer_array_false = []
	economizer_array = []
	#STEP2 retrieving all the airloops & OA controllers assigned	
	all_airloops = model.getAirLoopHVACs   
	all_airloops.each do |loop| 
	airloops_array << loop
		oa_air_sys = loop.airLoopHVACOutdoorAirSystem.get # getting all OA air systems
		@initial_oa_controller = oa_air_sys.getControllerOutdoorAir # getting all controllers
		initial_oa_controller_array << @initial_oa_controller # array for all controllers
		@econ_control_type_initial = @initial_oa_controller.getEconomizerControlType
			#Read value for autosizing MinimumOutdoorAirFlowRate
			min_oa_autosize_status = @initial_oa_controller.isMinimumOutdoorAirFlowRateAutosized
			runner.registerInfo("11111 = #{min_oa_autosize_status}")
				if min_oa_autosize_status == true && @econ_control_type_initial != "NoEconomizer"
					no_economizer_array_true << @initial_oa_controller
					runner.registerInfo("2222 #{no_economizer_array_true.length}")
						# Perform a sizing run for the autosized constant speed pump
						if model.runSizingRun("#{Dir.pwd}/SizingRun") == false
						   runner.registerError("Sizing Run for determining flow of autosized constant speed pump failed to complete - check eplusout.err to debug.")
						  # log_msgs
						  return false
						else 
							runner.registerInfo("A sizing run for determining the rated flow rate of the autosized secondary hot water constant speed pump namempleted - look in folder #{Dir.pwd}/SizingRun for results.")
						end

						# Retrieve value for autosized constant speed rated flow
						autosized_min_oa_rate = nil
						if @initial_oa_controller.autosizedMinimumOutdoorAirFlowRate.is_initialized
							autosized_min_oa_rate = @initial_oa_controller.autosizedMinimumOutdoorAirFlowRate.get
							runner.registerInfo(" #{autosized_min_oa_rate}")
						else
							runner.registerError("A sizing run for determining the rated flow rate of the autosized secondary hot water constant speed pump nameddid not result in a value for pump rated flow rate.")
						end
					
					
					
					
					
					
					
				elsif min_oa_autosize_status == false && @econ_control_type_initial == "NoEconomizer"
					no_economizer_array_false << @econ_control_type_initial
					runner.registerInfo("3333 #{no_economizer_array_false.length}")
				end
	end
	
	# not applicable message if there is no airloop or OA controller
	if all_airloops.size == 0 or initial_oa_controller_array.length == 0
		runner.registerAsNotApplicable("Model has no airloops. Measure is not applicable.") 
		return true
	end

    # report initial condition of model
    runner.registerInitialCondition("The initial model contained '#{all_airloops.length}' airloops with '#{initial_oa_controller_array.length}' Outdoor Air Controller objects for which this measure is applicable.")
	
    # report final condition of model
    runner.registerFinalCondition("A continuous outdoor air damper leakage condition representing poor damper/actuator control has been applied to '#{initial_oa_controller_array.length}' Outdoor Air Controllers.")
	
	def log_msgs
    @msg_log.logMessages.each do |msg|
      # DLM: you can filter on log channel here for now
      if /openstudio.*/.match(msg.logChannel) #/openstudio\.model\..*/
        # Skip certain messages that are irrelevant/misleading
        next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
            msg.logChannel.include?("runmanager") || # RunManager messages
            msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
            msg.logChannel.include?("Translator") || # Forward translator and geometry translator
            msg.logMessage.include?("UseWeatherFile") # 'UseWeatherFile' is not yet a supported option for YearDescription
            
        # Report the message in the correct way
        if msg.logLevel == OpenStudio::Info
          @runner.registerInfo(msg.logMessage)
        elsif msg.logLevel == OpenStudio::Warn
          @runner.registerWarning("[#{msg.logChannel}] #{msg.logMessage}")
        elsif msg.logLevel == OpenStudio::Error
          @runner.registerError("[#{msg.logChannel}] #{msg.logMessage}")
        elsif msg.logLevel == OpenStudio::Debug && @debug
          @runner.registerInfo("DEBUG - #{msg.logMessage}")
        end
      end
    end
  end
  
	log_msgs
    return true
	
	end
  
end

# register the measure to be used by the application
ReduceEconomizerDamperLeakage.new.registerWithApplication
