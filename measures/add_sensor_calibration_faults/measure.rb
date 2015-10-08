# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

#	╔═╗┌─┐┬─┐┌─┐┌─┐┬─┐┌┬┐┌─┐┌┐┌┌─┐┌─┐  
#	╠═╝├┤ ├┬┘├┤ │ │├┬┘│││├─┤││││  ├┤   
#	╩  └─┘┴└─└  └─┘┴└─┴ ┴┴ ┴┘└┘└─┘└─┘  
#	╔═╗┬ ┬┌─┐┌┬┐┌─┐┌┬┐┌─┐              
#	╚═╗└┬┘└─┐ │ ├┤ │││└─┐              
#	╚═╝ ┴ └─┘ ┴ └─┘┴ ┴└─┘              
#	╔╦╗┌─┐┬  ┬┌─┐┬  ┌─┐┌─┐┌┬┐┌─┐┌┐┌┌┬┐ 
#	 ║║├┤ └┐┌┘├┤ │  │ │├─┘│││├┤ │││ │  
#	═╩╝└─┘ └┘ └─┘┴─┘└─┘┴  ┴ ┴└─┘┘└┘ ┴  
                                  
# start the measure
class AddSensorCalibrationFaults < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "add sensor calibration faults"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) adds sensor drift faults to airside economizer controls by adding  FaultModel:TemperatureSensorOffset:OutdoorAir and FaultModel:TemperatureSensorOffset:ReturnAir objects to all Controller:OutdoorAir objects attached to air loops and having functioning airside economizers present in the model.  The sensor faults are configured based on the pre-existing setting for 'Economizer Control Type'. The sensor drifts are hard coded to values of +2F for the OA Dry Bulb Sensor and -2F for the RA Dry Bulb Sensor and +5 Btu/lb for the OA Enthalpy Calculation and -5 Btu/lb for the RA Enthalpy Calculation.  The enthalpy error is equivalent to having a Relative Humidity sensor error of +/- 4% RH accuracy and Dry Bulb Temperature Sensor of +/-2F accuracy.  Sensor drift limits are hard coded to reasonable values for sensor quality based on published ASHRAE documentation."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This energy efficiency measure (EEM) loops through all Controller:OutdoorAir objects and adds sensor faults to economizer sensor nodes. As appropriate, sensor drifts for return and outside air temperature and enthalpy are added to the model, based on the 'Economizer Control Type' setting. If the Economizer Control Type is set to 'No Economizer', no actions are taken. Drift limits are hard coded to reasonable values for sensor quality based on published ASHRAE documentation."
  end

  # define the arguments that the user will input
  def arguments(workspace)
	args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end 

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
	# Initialize counter variables
	no_economizer = 0
	fixed_dry_bulb = 0
	differential_dry_bulb = 0	
	fixed_enthalpy = 0
	differential_enthalpy = 0
	fixed_dew_point_and_dry_bulb = 0
	electronic_enthalpy = 0
	differential_dry_bulb_and_enthalpy = 0
	
	# Retrieve all Controller:Outdoor air objects in the idf  	
	oa_controllers = workspace.getObjectsByType("Controller:OutdoorAir".to_IddObjectType)
	
	# Get the names of each Controller:Outdoor Air object
	oa_controllers.each do |oa_controller|

		oa_controller_name = oa_controller.getString(0).to_s #(0) is field Name
		oa_controller_economizer_control_type = oa_controller.getString(7).to_s #(7) is field Economizer Control Type
	
		# test for presence No economizer controller setting 
		if oa_controller_economizer_control_type == "NoEconomizer"  # or empty
			runner.registerInfo("The Controller:Outdoor air object named #{oa_controller_name} has a disabled airside economizer. Economizer sensor faults will not be added.")
			no_economizer = no_economizer + 1
		end
		
		# test for presence of differential dry bulb economizer controller setting 
		if oa_controller_economizer_control_type == "DifferentialDryBulb"
			# Initialize array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:TemperatureSensorOffset:OutdoorAir 
			string_object = "
				FaultModel:TemperatureSensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Temp Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				1.11; 											!- Temperature Sensor Offset 
				"
											
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)

			# Create IDF object text for FaultModel:TemperatureSensorOffset:ReturnAir
			string_object = "
				FaultModel:TemperatureSensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Temp Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-1.11; 											!- Temperature Sensor Offset 
				"
			
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			differential_dry_bulb = differential_dry_bulb + 1

			runner.registerInfo("To model dry bulb sensor drift, a FaultModel:TemperatureSensorOffset:ReturnAir object with an offset of -2 deg F and a FaultModel:TemperatureSensorOffset:OutdoorAir object with an offset of +2 deg F has been added to the #{oa_controller_economizer_control_type} controlled airside economizer associated with the Controller:Outdoor air object named #{oa_controller_name}. The fault availability is scheduled using the 'Always On Discrete' schedule.")
			

		end # OA Controller Type DifferentialDryBulb

		# test for presence of fixed dry bulb economizer controller setting 
		if oa_controller_economizer_control_type == "FixedDryBulb"
			# Initialize array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:TemperatureSensorOffset:OutdoorAir
			string_object = "
				FaultModel:TemperatureSensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Temp Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				1.11; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			# Create IDF object text for FaultModel:TemperatureSensorOffset:ReturnAir
			string_object = "
				FaultModel:TemperatureSensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Temp Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-1.11; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			runner.registerInfo("To model dry bulb sensor drift, a FaultModel:TemperatureSensorOffset:ReturnAir object with an offset of -2 deg F and a FaultModel:TemperatureSensorOffset:OutdoorAir object with an offset of +2 deg F has been added to the #{oa_controller_economizer_control_type} controlled airside economizer associated with the Controller:Outdoor air object named #{oa_controller_name}. The fault availability is scheduled using the 'Always On Discrete' schedule.")
			fixed_dry_bulb = fixed_dry_bulb + 1
			
		end # OA Controller Type = FixedDryBulb 		
		
		# test for presence of fixed enthalpy economizer controller setting 				
		if oa_controller_economizer_control_type == "FixedEnthalpy"
			# Initialze array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:EnthalpySensorOffset:OutdoorAir
			string_object = "
				FaultModel:EnthalpySensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				5; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			# Create IDF object text for FaultModel:EnthalpySensorOffset:ReturnAir
			string_object = "
				FaultModel:EnthalpySensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-5; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			wworkspace.addObject(object)

			runner.registerInfo("To model enthalpy sensor drift, a FaultModel:EnthalpySensorOffset:ReturnAir object with an offset of -2 Btu/lb and a FaultModel:EnthalpySensorOffset:OutdoorAir object with an offset of +2 Btu/lb have been added to the #{oa_controller_economizer_control_type} controlled airside economizer associated with the Controller:Outdoor air object named #{oa_controller_name}. The fault availability is scheduled using the 'Always On Discrete' schedule.")
			fixed_enthalpy = fixed_enthalpy + 1
		end # OA Controller Type = FixedEnthalpy 
		
		# test for presence of differential enthalpy economizer controller setting 		
		if oa_controller_economizer_control_type == "DifferentialEnthalpy"
			# Initialze array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:EnthalpySensorOffset:OutdoorAir
			string_object = "
				FaultModel:EnthalpySensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				5; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			# Create IDF object text for FaultModel:EnthalpySensorOffset:ReturnAir
			string_object = "
				FaultModel:EnthalpySensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-5; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)

			runner.registerInfo("To model enthalpy sensor drift, a FaultModel:EnthalpySensorOffset:ReturnAir object with an offset of -2 Btu/lb and a FaultModel:EnthalpySensorOffset:OutdoorAir object with an offset of +2 Btu/lb have been added to the #{oa_controller_economizer_control_type} controlled airside economizer associated with the Controller:Outdoor air object named #{oa_controller_name}. The fault availability is scheduled using the 'Always On Discrete' schedule.")
			differential_enthalpy = differential_enthalpy + 1
			
		end # OA Controller Type ="Differential Enthalpy"		
		
	
		# test for presence of electronic enthalpy economizer controller setting 
		if oa_controller_economizer_control_type == "ElectronicEnthalpy"
			# Initialze array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:EnthalpySensorOffset:OutdoorAir
			string_object = "
				FaultModel:EnthalpySensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				5; 												!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			# Create IDF object text for FaultModel:EnthalpySensorOffset:ReturnAir
			string_object = "
				FaultModel:EnthalpySensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-5; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)

			runner.registerInfo("To model enthalpy sensor drift, a FaultModel:EnthalpySensorOffset:ReturnAir object with an offset of -2 Btu/lb and a FaultModel:EnthalpySensorOffset:OutdoorAir object with an offset of +2 Btu/lb have been added to the #{oa_controller_economizer_control_type} controlled airside economizer associated with the Controller:Outdoor air object named #{oa_controller_name}. The fault availability is scheduled using the 'Always On Discrete' schedule.")
			electronic_enthalpy = electronic_enthalpy + 1

		end # OA Controller Type = "ElectronicEnthalpy" 		
		
		# test for presence of fixed dew point and dry bulb economizer controller setting 
		if oa_controller_economizer_control_type == "FixedDewPointAndDryBulb" 
			# Initialze array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:EnthalpySensorOffset:OutdoorAir
			string_object = "
				FaultModel:EnthalpySensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				5; 												!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			# Create IDF object text for FaultModel:EnthalpySensorOffset:ReturnAir
			string_object = "
				FaultModel:EnthalpySensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-5; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			# Initialize array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:TemperatureSensorOffset:OutdoorAir
			string_object = "
				FaultModel:TemperatureSensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Temp Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				1.11; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			# Create IDF object text for FaultModel:TemperatureSensorOffset:ReturnAir
			string_object = "
				FaultModel:TemperatureSensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Temp Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-1.11; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)

			runner.registerInfo("To model both enthalpy and dry bulb sensor drift, a FaultModel:EnthalpySensorOffset:ReturnAir object with an offset of -2 Btu/lb and a FaultModel:EnthalpySensorOffset:OutdoorAir object with an offset of +2 Btu/lb and a FaultModel:TemperatureSensorOffset:ReturnAir object with an offset of -2 deg F and a FaultModel:TemperatureSensorOffset:OutdoorAir object with an offset of +2 deg have been added to the #{oa_controller_economizer_control_type} controlled airside economizer associated with the Controller:Outdoor air object named #{oa_controller_name}. The fault availability is scheduled using the 'Always On Discrete' schedule.")
			fixed_dew_point_and_dry_bulb = fixed_dew_point_and_dry_bulb + 1

		end # OA Controller Type = "FixedDewPointAndDryBulb" 
	
		# test for presence of differential dry bulb and enthalpy economizer controller setting 		
		if oa_controller_economizer_control_type == "DifferentialDryBulbAndEnthalpy"
			# Initialze array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:EnthalpySensorOffset:OutdoorAir
			string_object = "
				FaultModel:EnthalpySensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				5; 												!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
		
			# Create IDF object text for FaultModel:EnthalpySensorOffset:ReturnAir
			string_object = "
				FaultModel:EnthalpySensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Enthalpy Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-5; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
			
			# Initialize array to hold new IDF objects
			string_object = []
			# Create IDF object text for FaultModel:TemperatureSensorOffset:OutdoorAir
			string_object = "
				FaultModel:TemperatureSensorOffset:OutdoorAir,
				#{oa_controller_name}_Outdoor Air Temp Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				1.11; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)
						
			# Create IDF object text for FaultModel:TemperatureSensorOffset:ReturnAir
			string_object = "
				FaultModel:TemperatureSensorOffset:ReturnAir,
				#{oa_controller_name}_Return Air Temp Sensor Bias,   !- Name
				Always On Discrete, 							!- Availability Schedule Name
				, 												!- Severity Schedule Name
				Controller:OutdoorAir, 							!- Controller Object Type
				#{oa_controller_name}, 							!- Controller Object Name
				-1.11; 											!- Temperature Sensor Offset 
				"
			# Add string object to workspace to create idf object
			idfObject = OpenStudio::IdfObject::load(string_object)
			object = idfObject.get
			workspace.addObject(object)

			runner.registerInfo("To model both enthalpy and dry bulb sensor drift, a FaultModel:EnthalpySensorOffset:ReturnAir object with an offset of -2 Btu/lb and a FaultModel:EnthalpySensorOffset:OutdoorAir object with an offset of +2 Btu/lb and a FaultModel:TemperatureSensorOffset:ReturnAir object with an offset of -2 deg F and a FaultModel:TemperatureSensorOffset:OutdoorAir object with an offset of +2 deg have been added to the #{oa_controller_economizer_control_type} controlled airside economizer associated with the Controller:Outdoor air object named #{oa_controller_name}. The fault availability is scheduled using the 'Always On Discrete' schedule.")
			differential_dry_bulb_and_enthalpy = differential_dry_bulb_and_enthalpy + 1
		end # OA Controller Type "DifferentialDryBulbAndEnthalpy"
		
				
	end # end loop through oa controller objects

	# reporting when N/A condition is appropriate
	if fixed_dry_bulb +	differential_dry_bulb + fixed_enthalpy + differential_enthalpy + fixed_dew_point_and_dry_bulb +	electronic_enthalpy + differential_dry_bulb_and_enthalpy == 0
		runner.registerAsNotApplicable("Measure not applicable because the model contains no OutdoorAir:Controller objects with operable economizers.")
	end
	
	total = fixed_dry_bulb + differential_dry_bulb + fixed_enthalpy + differential_enthalpy + fixed_dew_point_and_dry_bulb + electronic_enthalpy + differential_dry_bulb_and_enthalpy
	
	# reporting initial condition of model
	runner.registerInitialCondition("The measure started with #{total} Outdoor Air Controllers configured for operational airside economizers. #{no_economizer} Outdoor Air Controller had the Economizer Contrrol Type set to 'NoEconomizer'.")
	# reporting final condition of model
	runner.registerFinalCondition("The measure finished by adding outdoor and return air temperature and enthalpy sensor faults to #{total} economizer configurations.")
  
    return true
 
  end # end run method

end # end class definition

# register the measure to be used by the application
AddSensorCalibrationFaults.new.registerWithApplication
