
	
	# Open a channel to log info/warning/error messages
    @msg_log = OpenStudio::StringStreamLogSink.new
    @msg_log.setLogLevel(OpenStudio::Info)
	@runner = runner
	
	#STEP1 initialize the variables (arrays)
	sizing_run_required = false
	airloops_array = []
	initial_oa_controller_array = []
	no_economizer_array_true = []
	economizer_array_false = []
	economizer_array_true = []
	#STEP2 retrieving all the airloops & OA controllers assigned	
	all_airloops = model.getAirLoopHVACs   
	all_airloops.each do |loop| 
		airloops_array << loop
		oa_air_sys = loop.airLoopHVACOutdoorAirSystem.get # getting OA air system
		@initial_oa_controller = oa_air_sys.getControllerOutdoorAir # getting the controller OA object
		initial_oa_controller_array << @initial_oa_controller # array for all controllers
		@econ_control_type_initial = @initial_oa_controller.getEconomizerControlType
		#Read value for autosizing MinimumOutdoorAirFlowRate
		if @econ_control_type_initial == "NoEconomizer"
			no_economizer_array_true << @initial_oa_controller	
			runner.registerAsNotApplicable("The measure is not applicable for air loop '#{loop.name}' as the OA controllers for given loop has economizer control type = 'no economizer'.")	
		end		
		min_oa_autosize_status = @initial_oa_controller.isMinimumOutdoorAirFlowRateAutosized
		if @econ_control_type_initial != "NoEconomizer" && min_oa_autosize_status == true
			sizing_run_required = true
			economizer_array_true << @initial_oa_controller	
			runner.registerinfo("'#{economizer_array_true.length}' ")
		end				
	end # end the do loop through airloops
	# execute the sizing run
	if sizing_run_required == true
		if model.runSizingRun("#{Dir.pwd}/SizingRun") == false
			runner.registerError("Sizing Run for determining the autosizing of minimum OA flow rate '#{@initial_oa_controller.name}' failed to complete - check eplusout.err to debug.")
			return false
		else 
			runner.registerInfo("A sizing run for determining minimum OA flow rate '#{@initial_oa_controller.name}' completed - look in folder #{Dir.pwd}/SizingRun for results.")
			
		end
	end # end the sizing run
	
	
	# Retrieve value for autosized !!!!!constant speed rated flow!!!!
	autosized_min_oa_rate = nil
	# purpose of this do loop is to 
	model.getAirLoopHVACs.each do |loop|   
		oa_air_sys = loop.airLoopHVACOutdoorAirSystem.get # getting OA air system
		@initial_oa_controller = oa_air_sys.getControllerOutdoorAir # getting the controller OA object
		
		
		
		
		if @initial_oa_controller.autosizedMinimumOutdoorAirFlowRate.is_initialized
			autosized_min_oa_rate = @initial_oa_controller.autosizedMinimumOutdoorAirFlowRate.get
			runner.registerInfo(" #{autosized_min_oa_rate}")
		else
			runner.registerError("A sizing run for determining the rated flow rate of the autosized secondary hot water constant speed pump nameddid not result in a value for pump rated flow rate.")
		end
	
	end # end the do loop
	
	
	
	
	
	
	
	
	# not applicable message if there is no airloop or economizer control = no economizer
	if all_airloops.size == 0 or initial_oa_controller_array.length == 0 or no_economizer_array_true.length == initial_oa_controller_array.length
		runner.registerAsNotApplicable("Measure is not applicable. Please check if no. of airloops in the model = 0; or all the airloops have control type = 'no economizer'.") 
		return true
	end

    # report initial condition of model
    runner.registerInitialCondition("The initial model contained '#{all_airloops.length}' airloops with '#{initial_oa_controller_array.length}' Outdoor Air Controller objects. The measure is applicable for '#{economizer_array_true.length}' objects with some kind of economizer as control type.")
	
    # report final condition of model
    runner.registerFinalCondition("A continuous outdoor air damper leakage condition representing poor damper/actuator control has been applied to '#{economizer_array_true.length}' Outdoor Air Controllers. There are '#{no_economizer_array_true.length}' objects with control type = 'no economizer'.")
	
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

	return true

  end
end

