#start the measure
class ChangeIndoorTemperature < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Change Indoor Temperature"
  end
  
  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end  

  # Define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure

    # Make an argument for reduction percentage
    indoor_temp_change_delta_f = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("indoor_temp_change_delta_f",true)
    indoor_temp_change_delta_f.setDisplayName("Indoor Temperature Change")
    indoor_temp_change_delta_f.setUnits("delta F")
    indoor_temp_change_delta_f.setDefaultValue(1.0)
    args << indoor_temp_change_delta_f

    return args
  end

  # Define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    

    indoor_temp_change_delta_f = runner.getDoubleArgumentValue("indoor_temp_change_delta_f",user_arguments)
    indoor_temp_change_delta_c = OpenStudio.convert(indoor_temp_change_delta_f, "R", "K").get
    
     
    
    # Check the indoor_temp_change_delta_f and for reasonableness
    if indoor_temp_change_delta_f > 5 || indoor_temp_change_delta_f < 0
      runner.registerError("Please Enter a Value between 0F and 5F for the Indoor Temperature Change.")
      return false
    end

    # Method to increase the setpoint values
    # in a day schedule by a specified amount
    def increase_day_sch_setpoint(day_sch, amount_c)
      times = day_sch.times
      values = day_sch.values
      day_sch.clearValues

      new_times = []
      new_values = []
      for i in 0..(values.length - 1)
        new_times << times[i]
        new_values << values[i] + amount_c
      end

      for i in 0..(new_values.length - 1)
        day_sch.addValue(new_times[i], new_values[i])
      end
    
    end

    # Method to increase the setpoint values
    # for all day schedules in a ruleset by a specified amount
    def increase_ruleset_sch_setpoint(sch, amount_c)
      # Skip non-ruleset schedules
      return false if sch.to_ScheduleRuleset.empty?
      sch = sch.to_ScheduleRuleset.get
  
      # Reduce default day schedules
      increase_day_sch_setpoint(sch.defaultDaySchedule, amount_c)

      # Summer design day
      if sch.isSummerDesignDayScheduleDefaulted == false
        increase_day_sch_setpoint(sch.summerDesignDaySchedule, amount_c)
      end

      # Winter design day
      if sch.isWinterDesignDayScheduleDefaulted == false
        increase_day_sch_setpoint(sch.winterDesignDaySchedule, amount_c)
      end
      
      # All other profiles
      sch.scheduleRules.each do |sch_rule|
        increase_day_sch_setpoint(sch_rule.daySchedule, amount_c)
      end
        
    end
        
    # Get all of the thermostats in the building
    htg_schedules = []
    clg_schedules = []
    model.getThermostatSetpointDualSetpoints.each do |thermostat|
      if thermostat.heatingSetpointTemperatureSchedule.is_initialized
        htg_schedules << thermostat.heatingSetpointTemperatureSchedule.get
      end
      if thermostat.coolingSetpointTemperatureSchedule.is_initialized
        clg_schedules << thermostat.coolingSetpointTemperatureSchedule.get
      end
    end
    
    # Register the initial condition
    # htg_setpoints = []
    # htg_schedules.uniq.each do |htg_sch|
      # htg_setpoints += htg_sch.values
    # end
    # max_htg_setpoint_f = OpenStudio.convert(htg_setpoints.max, "C", "F").get
    # min_htg_setpoint_f = OpenStudio.convert(htg_setpoints.min, "C", "F").get    
    # clg_setpoints = []
    # clg_schedules.uniq.each do |clg_sch|
      # clg_setpoints += clg_sch.values
    # end
    # max_clg_setpoint_f = OpenStudio.convert(clg_setpoints.max, "C", "F").get
    # min_clg_setpoint_f = OpenStudio.convert(clg_setpoints.min, "C", "F").get
    # runner.registerInitialCondition("The model started with heating setpoints ranging from #{max_htg_setpoint_f}F to #{min_htg_setpoint_f}F and cooling setpoints ranging from #{min_clg_setpoint_f}F to #{max_clg_setpoint_f}")
    
    # Decrease the heating setpoint by the specified amount
    # during each hour of the day.  This will apply to daytime
    # and nighttime, even if a setback is already present.
    htg_schedules.uniq.each do |htg_sch|
      increase_ruleset_sch_setpoint(htg_sch, -1*indoor_temp_change_delta_c)
      runner.registerInfo("Decreasing the setpoint in #{htg_sch.name} by #{indoor_temp_change_delta_f}F.")
    end
    
    # Increase the cooling setpoint by specified amount
    # during each hour of the day.  This will apply to daytime
    # and nighttime, even if a setback is already present.
    clg_schedules.uniq.each do |clg_sch|
      increase_ruleset_sch_setpoint(clg_sch, indoor_temp_change_delta_c)
      runner.registerInfo("Increasing the setpoint in #{clg_sch.name} by #{indoor_temp_change_delta_f}F.")
    end
    
    # Not applicable if no lights definitions were modified
    if htg_schedules.size == 0 && clg_schedules.size == 0
      runner.registerAsNotApplicable("Not Applicable because the building had no heating or cooling schedules.")
    end
    
    # Register the final condition
    # htg_setpoints = []
    # htg_schedules.uniq.each do |htg_sch|
      # htg_setpoints += htg_sch.values
    # end
    # max_htg_setpoint_f = OpenStudio.convert(htg_setpoints.max, "C", "F").get
    # min_htg_setpoint_f = OpenStudio.convert(htg_setpoints.min, "C", "F").get    
    # clg_setpoints = []
    # clg_schedules.uniq.each do |clg_sch|
      # clg_setpoints += clg_sch.values
    # end
    # max_clg_setpoint_f = OpenStudio.convert(clg_setpoints.max, "C", "F").get
    # min_clg_setpoint_f = OpenStudio.convert(clg_setpoints.min, "C", "F").get
    # runner.registerFinalCondition("The model ended with heating setpoints ranging from #{max_htg_setpoint_f}F to #{min_htg_setpoint_f}F and cooling setpoints ranging from #{min_clg_setpoint_f}F to #{max_clg_setpoint_f}")    
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
ChangeIndoorTemperature.new.registerWithApplication
