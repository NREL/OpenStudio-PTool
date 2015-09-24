# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class Model30RefrigerantUnderChargeScenario < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Model 30% Refrigerant UnderCharge Scenario"
  end

  # human readable description
  def description
    return "This energy efficiency degradation measure applies a performance degradation factor to all existing DX heating and cooling coils in a model, representing the estimated impact of a 30 percent refrigerant undercharge scenario. An estimated degradation of the coil's rated COP equal to 11.02 percent for cooling and 8.24 percent for heating is applied. The values for the degradation factors are based on research work recently performed by NIST in collaboration with ACCA and published under IEA Annex 36 in 2015. NOTE: This measure WILL NOT CONSERVE ENERGY, but will rather the modified objects will use MORE ENERGY then the base systems."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This energy efficiency measure (EEM) loops through all DX Coil objects of these types: 1) OS:CoilCoolingDXMultiSpeed, 2) OS:CoilCoolingDXSingleSpeed, 3) OS:CoilCoolingDXTwoSpeed, 4) OS:CoilCoolingDXTwoStageWithHumidityControlMode and 5) OS:CoilHeatingDXSingleSpeed. For each DX Cooling Coil object type, the initial Rated COP is modified (reduced) by 11.02%, representing a 30% refrigerant undercharge scenario. For each DX Heating Coil object type, the initial Rated COP is modified (reduced) by 8.24%, representing a 30% refrigerant undercharge scenario."
  end

  # Define the arguments that the user will input
  # No arguments for this measure
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

   return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
	
	# initilaize variables

	number_of_coil_cooling_dx_single_speed = 0
	number_of_coil_cooling_dx_two_speed = 0
	number_of_coil_cooling_dx_two_speed_with_humidity_control = 0
	number_of_coil_heating_dx_single_speed = 0
	number_of_coil_cooling_dx_multi_speed = 0

	model.getModelObjects.each do |model_object|
	
		if model_object.to_CoilCoolingDXSingleSpeed.is_initialized
			coil_cooling_dx_single_speed = model_object.to_CoilCoolingDXSingleSpeed.get
			coil_name = coil_cooling_dx_single_speed.name
			if coil_cooling_dx_single_speed.ratedCOP.is_initialized
				@initial_cop = coil_cooling_dx_single_speed.ratedCOP.get
			end

			# Modified COP values are determined from recent NIST published report for quantifying the effect of refrigerant 
			# undercharging - Sensitivity Analysis of Installation Faults on Heat Pump Performance 
			# http://nvlpubs.nist.gov/nistpubs/TechnicalNotes/NIST.TN.1848.pdf
			# Spreadsheet analysis of the regression coefficiencts for modeling heating and cooling annual COP
			# degredation were performed. The result predict a degradation of 11.02% of annual COP (for cooling)

			modified_cop = (@initial_cop * (1 - 0.1102)) 
			coil_cooling_dx_single_speed.setName("#{coil_name} +30 Percent undercharge")
			coil_cooling_dx_single_speed.setRatedCOP((OpenStudio::OptionalDouble.new(modified_cop)))
			number_of_coil_cooling_dx_single_speed += 1
			runner.registerInfo("Single Speed DX Cooling Coil object renamed #{coil_name} +30 Percent undercharge has had initial COP value of #{@initial_cop} derated to a COP value of #{modified_cop} representing a 30 percent by volume refrigerant undercharge scenario.")
		end 
			
		if model_object.to_CoilCoolingDXTwoSpeed.is_initialized
			coil_cooling_dx_two_speed = model_object.to_CoilCoolingDXTwoSpeed.get
			coil_name = coil_cooling_dx_two_speed.name
			if coil_cooling_dx_two_speed.ratedHighSpeedCOP.is_initialized
				@initial_high_speed_cop = coil_cooling_dx_two_speed.ratedHighSpeedCOP.get
			end
			if coil_cooling_dx_two_speed.ratedLowSpeedCOP.is_initialized
				@initial_low_speed_cop = coil_cooling_dx_two_speed.ratedLowSpeedCOP.get
			end
			
			modified_high_speed_cop = (@initial_high_speed_cop * (1 - 0.1102)) 
			modified_low_speed_cop = (@initial_low_speed_cop * (1 - 0.1102)) 
			
			coil_cooling_dx_two_speed.setName("#{coil_name} +30 Percent undercharge")
			coil_cooling_dx_two_speed.setRatedHighSpeedCOP(modified_high_speed_cop)
			coil_cooling_dx_two_speed.setRatedLowSpeedCOP(modified_low_speed_cop)
			
			number_of_coil_cooling_dx_two_speed += 1
			runner.registerInfo("Two Speed DX Cooling Coil object renamed #{coil_name} +30 Percent undercharge has had initial high speed COP value of #{@initial_high_speed_cop} derated to a COP value of #{modified_high_speed_cop} and an initial lowspeed COP value of #{@initial_low_speed_cop} derated to a COP value of #{modified_low_speed_cop} representing a 30 percent by volume refrigerant undercharge scenario.")
		end 

		if model_object.to_CoilHeatingDXSingleSpeed.is_initialized
			coil_heating_dx_single_speed = model_object.to_CoilHeatingDXSingleSpeed.get
			coil_name = coil_heating_dx_single_speed.name
		
			@initial_cop = coil_heating_dx_single_speed.ratedCOP

			# Modified COP values are determined from recent NIST published report for quantifying the effect of refrigerant 
			# undercharging - Sensitivity Analysis of Installation Faults on Heat Pump Performance 
			# http://nvlpubs.nist.gov/nistpubs/TechnicalNotes/NIST.TN.1848.pdf
			# Spreadsheet analysis of the regression coefficiencts for modeling heating and cooling annual COP
			# degredation were performed. The result predict a degradation of 11.02% of annual COP (for cooling)

			modified_cop = (@initial_cop * (1 - 0.0824)) 
			coil_heating_dx_single_speed.setName("#{coil_name} +30 Percent undercharge")
			coil_heating_dx_single_speed.setRatedCOP(modified_cop)
			number_of_coil_heating_dx_single_speed += 1
			runner.registerInfo("Single Speed DX Heating Coil object renamed #{coil_name} +30 Percent undercharge has had initial COP value of #{@initial_cop} derated to a COP value of #{modified_cop} representing a 30 percent by volume refrigerant undercharge scenario.")
		end 
	
		if model_object.to_CoilCoolingDXTwoStageWithHumidityControlMode.is_initialized
			coil_cooling_two_stage_with_humidity_control_mode = model_object.to_CoilCoolingDXTwoStageWithHumidityControlMode.get
			coil_name = coil_cooling_two_stage_with_humidity_control_mode.name
			
			if coil_cooling_two_stage_with_humidity_control_mode.normalModeStage1CoilPerformance.is_initialized
				normal_mode_stage_1 = coil_cooling_two_stage_with_humidity_control_mode.normalModeStage1CoilPerformance.get
				normal_mode_stage_1_initial_COP = normal_mode_stage_1.grossRatedCoolingCOP
				normal_mode_stage_1_modified_COP = (normal_mode_stage_1_initial_COP * (1 - 0.1102)) 
				normal_mode_stage_1.setGrossRatedCoolingCOP(normal_mode_stage_1_modified_COP)
			end
			
			if coil_cooling_two_stage_with_humidity_control_mode.normalModeStage1Plus2CoilPerformance.is_initialized
				normal_mode_stage_1_plus_2 = coil_cooling_two_stage_with_humidity_control_mode.normalModeStage1Plus2CoilPerformance.get
				normal_mode_stage_1_plus_2_initial_COP = normal_mode_stage_1_plus_2.grossRatedCoolingCOP
				normal_mode_stage_1_plus_2_modified_COP = (normal_mode_stage_1_plus_2_initial_COP * (1 - 0.1102)) 
				normal_mode_stage_1_plus_2.setGrossRatedCoolingCOP(normal_mode_stage_1_plus_2_modified_COP)
			end
							
			if coil_cooling_two_stage_with_humidity_control_mode.dehumidificationMode1Stage1CoilPerformance.is_initialized
				dehumid_mode_stage_1 = coil_cooling_two_stage_with_humidity_control_mode.dehumidificationMode1Stage1CoilPerformance.get
				dehumid_mode_stage_1_initial_COP = normal_mode_stage_1_plus_2.grossRatedCoolingCOP
				dehumid_mode_stage_1_modified_COP = (dehumid_mode_stage_1_initial_COP * (1 - 0.1102)) 
				dehumid_mode_stage_1.setGrossRatedCoolingCOP(dehumid_mode_stage_1_modified_COP)
			end
			
			if coil_cooling_two_stage_with_humidity_control_mode.dehumidificationMode1Stage1Plus2CoilPerformance.is_initialized
				dehumid_mode_stage_1_plus_2 = coil_cooling_two_stage_with_humidity_control_mode.dehumidificationMode1Stage1Plus2CoilPerformance.get
				dehumid_mode_stage_1_plus_2_initial_COP = normal_mode_stage_1_plus_2.grossRatedCoolingCOP
				dehumid_mode_stage_1_plus_2_modified_COP = (dehumid_mode_stage_1_plus_2_initial_COP * (1 - 0.1102)) 
				dehumid_mode_stage_1_plus_2.setGrossRatedCoolingCOP(dehumid_mode_stage_1_plus_2_modified_COP)
			end
		
			runner.registerInfo("Two Stage DX Cooling Coil with humidity control renamed #{coil_name} + 30 percent undercharge.")
			runner.registerInfo("Normal Mode Stage 1 modified with initial COP value of #{normal_mode_stage_1_initial_COP} derated to a COP value of #{normal_mode_stage_1_modified_COP}.")
			runner.registerInfo("Normal Mode Stage 1 plus 2 modified with initial COP value of #{normal_mode_stage_1_plus_2_initial_COP} derated to a COP value of #{normal_mode_stage_1_plus_2_modified_COP}.")
			runner.registerInfo("Dehumidification Mode Stage 1 modified with initial COP value of #{dehumid_mode_stage_1_initial_COP} derated to a COP value of #{dehumid_mode_stage_1_modified_COP}.")
			runner.registerInfo("Dehumidification Mode Stage 1 plus 2 modified with initial COP value of #{dehumid_mode_stage_1_plus_2_initial_COP} derated to a value of #{dehumid_mode_stage_1_plus_2_modified_COP}.")

			number_of_coil_cooling_dx_two_speed_with_humidity_control += 1

		end 

		if model_object.to_CoilCoolingDXMultiSpeed.is_initialized
			coil_cooling_dx_multispeed = model_object.to_CoilCoolingDXMultiSpeed.get
			coil_name = coil_cooling_dx_multispeed.name
			dx_stages = coil_cooling_dx_multispeed.stages
			dx_stages.each do |dx_stage|
				count = count +1
				initial_cop = dx_stage.grossRatedCoolingCOP
				modified_cop = (initial_cop  * (1 - 0.1102)) 
				dx_stage.setGrossRatedCoolingCOP(modified_cop)
				runner.registerInfo("Stage #{count} of Multispeed DX Cooling coil named #{coil_name} had the initial COP value of #{initial_cop} derated to a value of #{final_cop} to represent a 30 percent refrigerant underchange scenario.")
			end # end loop through dx stages
			number_of_coil_cooling_dx_multi_speed +=1
		end # end loop through to_CoilCoolingDXMultiSpeed objects  
		
	end # end loop through all model objects

	total = number_of_coil_cooling_dx_single_speed + number_of_coil_cooling_dx_two_speed + number_of_coil_cooling_dx_two_speed_with_humidity_control + number_of_coil_heating_dx_single_speed + number_of_coil_cooling_dx_multi_speed = 0
	
	if total == 0 
		runner.registerAsNotApplicable("No qualifed DX cooling or heating objects are present in this model. The measure is not applicible.")
		return true
	end
	runner.registerInitialCondition("The measure began with #{total} objects which can be modified to represent a 30% refrigerant undercharge condition.")
	runner.registerFinalCondition("The measure modified #{number_of_coil_cooling_dx_single_speed} Coil Cooling DX Single Speed Objects, #{number_of_coil_cooling_dx_two_speed} Coil Cooling DX Two Speed Objects, #{number_of_coil_cooling_dx_two_speed_with_humidity_control} Coil Cooling DX Two Speed with Humidity Control Objects, #{number_of_coil_heating_dx_single_speed} Coil Heating DX Single Speed Objects and #{number_of_coil_cooling_dx_multi_speed} Coil Cooling DX MultiSpeed objects.")
	return true

  end # end of run method
  
end # end of class 

# register the measure to be used by the application
Model30RefrigerantUnderChargeScenario.new.registerWithApplication
