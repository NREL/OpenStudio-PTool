# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class WidenThermostatSetpoint < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Widen Thermostat Setpoint"
  end

  # human readable description
  def description
    return "It is well understood that for many HVAC systems, significant energy can be saved by increasing the thermostat deadband-the range of zone temperatures at which neither heating nor cooling systems are needed. While saving energy, it is important to acknowledge that large or aggressive deadbands can result in occupant comfort issues and complaints. ASHRAE Standard 55 defines an envelope for thermal comfort, and predictions of thermal comfort should be analyzed to determine an appropriate balance between energy conservation and occupant comfort/productivity. This measure analyzes the heating and cooling setpoint schedules associated with each thermal zone in the model, and widens the temperature deadband of all schedule run period profiles from their existing value by 1.5 degrees F."
  end

  # human readable description of modeling approach
  def modeler_description
    return "The measure loops through the heating and cooling thermostat schedules associated each thermal zone. The existing heating and cooling schedules are cloned, and the all run period profiles are then modified by adding a +1.5 deg F shift to the all values of the cooling thermostat schedule and a -1.5 degree F shift to all values of the heating thermostat schedule.  Design Day profiles are not modified. The modified thermostat schedules are then assigned to the thermal zone.  For each Thermal Zone, ASHRAE 55 Thermal Comfort Warnings is also enabled. Zone Thermal Comfort ASHRAE 55 Adaptive Model 90% Acceptability Status output variables is also added to the model."
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

	#initialize variables
	tz_count = 0
	clg_tstat_schedule = []
	thermal_zone_array = []
		
	# get the thermal zones and loop through them 
	model.getThermalZones.each do |thermal_zone|
	
		thermal_zone_array << thermal_zone
		
		# test to see if thermal zone has a thermostat object assigned or is unconditioned. 
		if thermal_zone.thermostatSetpointDualSetpoint.is_initialized
			zone_thermostat = thermal_zone.thermostatSetpointDualSetpoint.get
			tz_count += 1
			
			if zone_thermostat.coolingSetpointTemperatureSchedule.is_initialized
				clg_tstat_schedule = zone_thermostat.coolingSetpointTemperatureSchedule.get
				
				# clone the existing cooling T-stat schedule in case it is used somewhere else in the model
				cloned_clg_tstat_schedule = clg_tstat_schedule.clone
				@new_clg_tstat_schedule_name = ("#{clg_tstat_schedule.name}+1.5F")
			
				if cloned_clg_tstat_schedule.to_ScheduleRuleset.is_initialized
					schedule = cloned_clg_tstat_schedule.to_ScheduleRuleset.get
					# gather profiles of cloned schedule
					profiles = []
					cooling_thermostat_array = []
					defaultProfile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
				
					profiles << defaultProfile
					rules = schedule.scheduleRules
				
					rules.each do |rule|
						profiles << rule.daySchedule
					end # end the do loop through the rulesetsdo

					#adjust profiles of temperature schedule of cloned schedule by + 1.5 deg F delta (0.833 C)
					profiles.each do |profile|
						time = profile.times
						i = 0
						#TODO - name new profile
						profile.values.each do |value|
							delta = 0.8333
							new_value = value + delta # Note this is where the cooling setpoint is raised
							profile.addValue(time[i], new_value)
							i += 1
							cloned_clg_tstat_schedule.setName(@new_clg_tstat_schedule_name)
							cooling_thermostat_array << cloned_clg_tstat_schedule
						end # end loop through each profile values
					end # end loop through each profile
					
					zone_thermostat.setCoolingSetpointTemperatureSchedule(cloned_clg_tstat_schedule.to_ScheduleRuleset.get)
					runner.registerInfo("The existing cooling thermostat '#{clg_tstat_schedule.name}' has been changed to #{cloned_clg_tstat_schedule.name}. Inspect the new schedule values using the OS App.")
				end # end if statement for cloning and modifying cooling tstat schedule object
			else
				runner.registerInfo("The dual setpoint thermostat object named #{zone_thermostat.name} serving thermal zone #{thermal_zone.name} did not have a cooling setpoint temperature schedule associated with it. The measure will not alter this thermostat object")
			end # end if statement for cooling Setpoint Temperature is initialized
			
			if zone_thermostat.heatingSetpointTemperatureSchedule.is_initialized
				htg_tstat_schedule = zone_thermostat.heatingSetpointTemperatureSchedule.get
						
				# clone the existing heating T-stat schedule in case it is used somewhere else
				cloned_htg_tstat_schedule = htg_tstat_schedule.clone
				
				#name cloned heating t-stat schedule
				cloned_htg_tstat_schedule.setName("#{htg_tstat_schedule.name}-1.5F")

				if cloned_htg_tstat_schedule.to_ScheduleRuleset.is_initialized
					schedule = cloned_htg_tstat_schedule.to_ScheduleRuleset.get
				
					# gather profiles of cloned schedule
					profiles_h = []
					defaultProfile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
					
					profiles_h << defaultProfile
					rules_h = schedule.scheduleRules
					rules_h.each do |rule_h|
						profiles_h << rule_h.daySchedule
					end # end the rule_h do

					#adjust profiles_h of temperature schedule of cloned schedule by + 1.5 deg F delta (0.833 C)
					profiles_h.each do |profile_h|
						time_h = profile_h.times
						i = 0
						#TODO - name new profile
						profile_h.values.each do |value_h|
							delta_h = 0.8333
							new_value_h = value_h - delta_h # Note this is where the heating setpoint is lowered 
							profile_h.addValue(time_h[i], new_value_h)
							i += 1
						end # end loop through each profile values
					end # end loop through each profile_h
					
					zone_thermostat.setHeatingSetpointTemperatureSchedule(cloned_htg_tstat_schedule.to_ScheduleRuleset.get)
					runner.registerInfo("The existing heating thermostat '#{htg_tstat_schedule.name}' has been changed to #{cloned_htg_tstat_schedule.name}. Inspect the new schedule values using the OS App.")
				end # end if statement for cloning and modifying heating tstat schedule object	
			else
				runner.registerInfo("The dual setpoint thermostat object named #{zone_thermostat.name} serving thermal zone #{thermal_zone.name} did not have a heating setpoint temperature schedule associated with it. The measure will not alter this thermostat object")
			end # end if statement for heating Setpoint Temperature is initialized
		end	# end if statement for zone_thermstat cooling schedule
		
	end # end loop through thermal zones			
			
	# Add ASHRAE 55 Comfort Warnings are applied to people objects
	# get people objects and people definitions in model
	people_defs = model.getPeopleDefinitions
	people_instances = model.getPeoples

	# loop through people objects
	people_def_counter = 0
	people_defs.sort.each do |people_def|
	  next if not people_def.instances.size > 0
	  people_def_counter += 1
	  people_def.setEnableASHRAE55ComfortWarnings(true)
	end
			
	reporting_frequency = "Timestep"
	outputVariable = OpenStudio::Model::OutputVariable.new("Zone Thermal Comfort ASHRAE 55 Adaptive Model 90% Acceptability Status []",model)
	outputVariable.setReportingFrequency(reporting_frequency)
	runner.registerInfo("Adding output variable for 'Zone Thermal Comfort ASHRAE 55 Adaptive Model 90% Acceptability Status' reporting '#{reporting_frequency}'")

	# write As Not Applicable message
	if tz_count == 0
		runner.registerAsNotApplicable("Measure is not applicable. There are no conditioned thermal zones in the model.")
		return true
	end

	# report initial condition of model
	runner.registerInitialCondition("The initial model contained #{tz_count} thermal zones with #{thermal_zone_array.length} 'Cooling Thermostat Schedule' and #{thermal_zone_array.length} 'Heating Thermostat Schedule' objects for which this measure is applicable.")

	# report final condition of model
	runner.registerFinalCondition("The #{thermal_zone_array.length} Heating and #{thermal_zone_array.length} Cooling Thermostats schedules for #{thermal_zone_array.length} Thermal Zones were altered to reflect a additional deadband width of 3 Deg F . ")
	return true

  end # end run method
  
end # end class

# register the measure to be used by the application
WidenThermostatSetpoint.new.registerWithApplication