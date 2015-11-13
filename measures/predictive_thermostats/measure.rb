# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class PredictiveThermostats < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Wireless Lighting Occupancy Sensors"
  end

  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
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

    # Make an argument for reduction percentage
    occ_threshold = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("occ_threshold",true)
    occ_threshold.setDisplayName("Occupancy Threshold For Setback")
    occ_threshold.setUnits("%")
    occ_threshold.setDefaultValue(10.0)
    args << occ_threshold    
    
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
    

    occ_threshold = runner.getDoubleArgumentValue("occ_threshold",user_arguments)
    occ_threshold_mult = occ_threshold/100
    
  

    # Method to find the maximum profile value for a schedule,
    # not including values from the summer and winter design days.
    def get_min_max_val(sch_ruleset)
      # Skip non-ruleset schedules
      return false if sch_ruleset.to_ScheduleRuleset.empty?
      sch_ruleset = sch_ruleset.to_ScheduleRuleset.get
    
      # Gather profiles
      profiles = []
      defaultProfile = sch_ruleset.to_ScheduleRuleset.get.defaultDaySchedule
      profiles << defaultProfile
      sch_ruleset.scheduleRules.each do |rule|
        profiles << rule.daySchedule
      end

      # Search all the profiles for the min and max
      min = nil
      max = nil
      profiles.each do |profile|
        profile.values.each do |value|
          if min.nil?
            min = value
          else
            if min > value then min = value end
          end
          if max.nil?
            max = value
          else
            if max < value then max = value end
          end
        end
      end
      
      return {"min" => min, "max" => max}

    end    

    # Method to increase the setpoint values
    # in a day schedule by a specified amount
    def adjust_pred_tstat_day_sch(day_sch, occ_threshold_pct, occ_temp_c , unocc_temp_c)
      occ_times = day_sch.times
      occ_values = day_sch.values
      day_sch.clearValues

      new_times = []
      new_values = []
      for i in 0..(occ_values.length - 1)
        occ_val = occ_values[i]
        if occ_val >= occ_threshold_pct
          new_values << occ_temp_c
          new_times << occ_times[i]
        else
          new_values << unocc_temp_c
          new_times << occ_times[i]
        end  
      end

      for i in 0..(new_values.length - 1)
        day_sch.addValue(new_times[i], new_values[i])
      end
    
    end

    # Method to increase the setpoint values
    # for all day schedules in a ruleset by a specified amount
    def create_pred_tstat_ruleset_sch(model, occ_sch, occ_threshold_pct, occ_temp_c , unocc_temp_c)
      # Skip non-ruleset schedules
      return false if occ_sch.to_ScheduleRuleset.empty?
      occ_sch = occ_sch.to_ScheduleRuleset.get
      pred_tstat_sch = occ_sch.clone(model).to_ScheduleRuleset.get
  
      # Default day schedule
      adjust_pred_tstat_day_sch(pred_tstat_sch.defaultDaySchedule, occ_threshold_pct, occ_temp_c , unocc_temp_c)
      
      # All other day profiles
      pred_tstat_sch.scheduleRules.each do |sch_rule|
        adjust_pred_tstat_day_sch(sch_rule.daySchedule, occ_threshold_pct, occ_temp_c , unocc_temp_c)
      end
        
      return pred_tstat_sch  
        
    end    
    
    # Loop through all zones in the model, get their thermostats,
    # and determine the heating and cooling setback and normal values.
    # Then, go through the occupancy schedule for each zone and set the
    # thermostat setpoint to the setback value for any hour where the
    # occupancy is less than the threshold.  If the original thermostat
    # has no setback, make the setback 5F and warn the user.\
    default_setback_delta_f = 5
    default_setback_delta_c = OpenStudio.convert(default_setback_delta_f, "R", "K").get.round(1)
    zones_changed = []
    occ_sch_to_htg_sch_map = {}
    occ_sch_to_clg_sch_map = {}
    model.getThermalZones.each do |zone|
      
      # Skip zones that have no occupants
      # or have occupants with no schedule
      people = []
      zone.spaces.each do |space|
        people += space.people
        if space.spaceType.is_initialized
          people += space.spaceType.get.people
        end
      end
      if people.size == 0
        runner.registerInfo("Zone #{zone.name} has no people, predictive thermostat not applicable.")
        next
      end
      occ = people[0]
      if occ.numberofPeopleSchedule.empty?
        runner.registerInfo("Zone #{zone.name} has people but no occupancy schedule, predictive thermostat not applicable.")
        next
      end
      occ_sch = occ.numberofPeopleSchedule.get
      
      # Skip zones with no thermostat or no dual-setpoint thermostat
      next if zone.thermostat.empty?
      if zone.thermostat.get.to_ThermostatSetpointDualSetpoint.empty?
        runner.registerInfo("Zone #{zone.name} has people no thermostat, predictive thermostat not applicable.")
        next      
      end
      tstat = zone.thermostat.get.to_ThermostatSetpointDualSetpoint.get
      
      # Skip thermostats that don't have both heating and cooling schedules
      if tstat.heatingSetpointTemperatureSchedule.empty? || tstat.coolingSetpointTemperatureSchedule.empty?
        runner.registerInfo("Zone #{zone.name} is missing either a heating or cooling schedule, predictive thermostat not applicable.")
        next
      end
      htg_sch = tstat.heatingSetpointTemperatureSchedule.get
      clg_sch = tstat.coolingSetpointTemperatureSchedule.get

      # Find the heating setup and setback temps
      htg_occ = get_min_max_val(htg_sch)["max"]
      htg_unocc = get_min_max_val(htg_sch)["min"]
      htg_setback = (htg_occ - htg_unocc).round(1)
      if htg_setback <= 1
        htg_unocc = htg_occ - htg_setback
        runner.registerWarning("Zone #{zone.name} had an insignificant/no heating setback of #{htg_setback} delta C.  Setback was changed to #{default_setback_delta_c} delta C because a predictive thermostat doesn't make sense without a setback.")
      end
      
      # Find the cooling setup and setback temps
      clg_occ = get_min_max_val(clg_sch)["min"]
      clg_unocc = get_min_max_val(clg_sch)["max"]
      clg_setback = (clg_unocc - clg_occ).round(1)
      if clg_setback <= 1
        clg_unocc = clg_occ + default_setback_delta_c
        runner.registerWarning("Zone #{zone.name} had an insignificant/no cooling setback of #{clg_setback} delta C.  Setback was changed to #{default_setback_delta_c} delta C because a predictive thermostat doesn't make sense without a setback.")
      end
      
      # Create predicitive thermostat schedules that go to
      # setback when occupancy is below the specified threshold
      # (or retrieve one previously created).
      # Heating sch
      pred_htg_sch = nil
      if occ_sch_to_htg_sch_map[occ_sch]
        pred_htg_sch = occ_sch_to_htg_sch_map[occ_sch]
      else
        pred_htg_sch = create_pred_tstat_ruleset_sch(model, occ_sch, occ_threshold_mult, htg_occ, htg_unocc)
        pred_htg_sch.setName("#{occ_sch.name} Predictive Htg Sch")
        occ_sch_to_htg_sch_map[occ_sch] = pred_htg_sch
      end
      # Cooling sch
      pred_clg_sch = nil
      if occ_sch_to_clg_sch_map[occ_sch]
        pred_clg_sch = occ_sch_to_clg_sch_map[occ_sch]
      else      
        pred_clg_sch = create_pred_tstat_ruleset_sch(model, occ_sch, occ_threshold_mult, clg_occ, clg_unocc)
        pred_clg_sch.setName("#{occ_sch.name} Predictive Clg Sch")
        occ_sch_to_clg_sch_map[occ_sch] = pred_clg_sch
      end
      
      # Assign the predictive thermostat schedules to the zone
      tstat.setHeatingSetpointTemperatureSchedule(pred_htg_sch)
      tstat.setCoolingSetpointTemperatureSchedule(pred_clg_sch)

      zones_changed << zone
      runner.registerInfo("Applied a predictive thermostat to #{zone.name}.")
      
    end
         
    # Report if the measure is not applicable
    if zones_changed.size == 0
      runner.registerAsNotApplicable("This measure is not applicable because none of the zones had both occupants and a thermostat.")
      return true
    end  
        
    # Report final condition
    runner.registerFinalCondition("Added predictive thermostats to #{zones_changed.size} zones in the building by setting the thermostat to a setback temperature if occupancy level was below #{occ_threshold}%.")

    return true

  end
  
end

# register the measure to be used by the application
PredictiveThermostats.new.registerWithApplication
