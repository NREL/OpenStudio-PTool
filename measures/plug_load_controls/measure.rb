# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class PlugLoadControls < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Plug Load Controls"
  end

  # human readable description
  def description
    return "Plug loads represent a significant fraction of the energy consumption in commercial buildings.  Turning plug loads off when not in use can save energy.  This can be accomplished through a variety of methods depending on the plug load being controlled.  Some options include occupancy sensors, scheduled outlets, advanced power strips, and equipment with built-in lower power modes."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Find all of the electric equipment schedules in the building. Reduce their fractional values by 10% during occupied hours (default 6pm-9am), and by 25% during unoccupied hours.  These savings represent the application of a variety of control strategies."
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

    #make an argument for reduction during unocciuped time
    unoc_pct_red = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("unoc_pct_red",true)
    unoc_pct_red.setDisplayName("Percent Reduction for Unoccupied Time.")
    unoc_pct_red.setDefaultValue(0.25)
    args << unoc_pct_red

    #make an argument for reduction during occiuped time
    oc_pct_red = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("oc_pct_red",true)
    oc_pct_red.setDisplayName("Percent Reduction for Occupied Time.")
    oc_pct_red.setDefaultValue(0.1)
    args << oc_pct_red    
    
    #apply to weekday
    apply_weekday = OpenStudio::Ruleset::OSArgument::makeBoolArgument("apply_weekday",true)
    apply_weekday.setDisplayName("Apply Schedule Changes to Weekday and Default Profiles?")
    apply_weekday.setDefaultValue(true)
    args << apply_weekday

    #weekday start time
    start_weekday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("start_weekday",true)
    start_weekday.setDisplayName("Weekday/Default Time to Start Unoccupied.")
    start_weekday.setUnits("24hr, use decimal for sub hour")
    start_weekday.setDefaultValue(18.0)
    args << start_weekday

    #weekday end time
    end_weekday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("end_weekday",true)
    end_weekday.setDisplayName("Weekday/Default Time to End Unoccupied.")
    end_weekday.setUnits("24hr, use decimal for sub hour")
    end_weekday.setDefaultValue(9.0)
    args << end_weekday

    #apply to saturday
    apply_saturday = OpenStudio::Ruleset::OSArgument::makeBoolArgument("apply_saturday",true)
    apply_saturday.setDisplayName("Apply Schedule Changes to Saturdays?")
    apply_saturday.setDefaultValue(true)
    args << apply_saturday

    #saturday start time
    start_saturday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("start_saturday",true)
    start_saturday.setDisplayName("Saturday Time to Start Unoccupied.")
    start_saturday.setUnits("24hr, use decimal for sub hour")
    start_saturday.setDefaultValue(18.0)
    args << start_saturday

    #saturday end time
    end_saturday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("end_saturday",true)
    end_saturday.setDisplayName("Saturday Time to End Unoccupied.")
    end_saturday.setUnits("24hr, use decimal for sub hour")
    end_saturday.setDefaultValue(9.0)
    args << end_saturday

    #apply to sunday
    apply_sunday = OpenStudio::Ruleset::OSArgument::makeBoolArgument("apply_sunday",true)
    apply_sunday.setDisplayName("Apply Schedule Changes to Sundays?")
    apply_sunday.setDefaultValue(true)
    args << apply_sunday

    #sunday start time
    start_sunday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("start_sunday",true)
    start_sunday.setDisplayName("Sunday Time to Start Unoccupied.")
    start_sunday.setUnits("24hr, use decimal for sub hour")
    start_sunday.setDefaultValue(18.0)
    args << start_sunday

    #sunday end time
    end_sunday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("end_sunday",true)
    end_sunday.setDisplayName("Sunday Time to End Unoccupied.")
    end_sunday.setUnits("24hr, use decimal for sub hour")
    end_sunday.setDefaultValue(9.0)
    args << end_sunday    
    
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
    

    unoc_pct_red = runner.getDoubleArgumentValue("unoc_pct_red",user_arguments)
    oc_pct_red = runner.getDoubleArgumentValue("oc_pct_red",user_arguments)
    apply_weekday = runner.getBoolArgumentValue("apply_weekday",user_arguments)
    start_weekday = runner.getDoubleArgumentValue("start_weekday",user_arguments)
    end_weekday = runner.getDoubleArgumentValue("end_weekday",user_arguments)
    apply_saturday = runner.getBoolArgumentValue("apply_saturday",user_arguments)
    start_saturday = runner.getDoubleArgumentValue("start_saturday",user_arguments)
    end_saturday = runner.getDoubleArgumentValue("end_saturday",user_arguments)
    apply_sunday = runner.getBoolArgumentValue("apply_sunday",user_arguments)
    start_sunday = runner.getDoubleArgumentValue("start_sunday",user_arguments)
    end_sunday = runner.getDoubleArgumentValue("end_sunday",user_arguments)
    
    #check the fraction for reasonableness
    if not 0 <= unoc_pct_red and unoc_pct_red <= 1
      runner.registerError("Unoccupied percent reduction needs to be between or equal to 0 and 1.")
      return false
    end

    #check the fraction for reasonableness
    if not 0 <= oc_pct_red and oc_pct_red <= 1
      runner.registerError("Occupied percent reduction needs to be between or equal to 0 and 1.")
      return false
    end    
    
    #check start_weekday for reasonableness and round to 15 minutes
    if not 0 <= start_weekday and start_weekday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24")
      return false
    else
      rounded_start_weekday = ((start_weekday*4).round)/4.0
      if not start_weekday == rounded_start_weekday
        runner.registerInfo("Weekday start time rounded to nearest 15 minutes: #{rounded_start_weekday}")
      end
      wk_after_hour = rounded_start_weekday.truncate
      wk_after_min = (rounded_start_weekday - wk_after_hour)*60
      wk_after_min = wk_after_min.to_i
    end

    #check end_weekday for reasonableness and round to 15 minutes
    if not 0 <= end_weekday and end_weekday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    elsif end_weekday > start_weekday
      runner.registerError("Please enter an end time earlier in the day than start time.")
      return false
    else
      rounded_end_weekday = ((end_weekday*4).round)/4.0
      if not end_weekday == rounded_end_weekday
        runner.registerInfo("Weekday end time rounded to nearest 15 minutes: #{rounded_end_weekday}")
      end
      wk_before_hour = rounded_end_weekday.truncate
      wk_before_min = (rounded_end_weekday - wk_before_hour)*60
      wk_before_min = wk_before_min.to_i
    end

    #check start_saturday for reasonableness and round to 15 minutes
    if not 0 <= start_saturday and start_saturday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    else
      rounded_start_saturday = ((start_saturday*4).round)/4.0
      if not start_saturday == rounded_start_saturday
        runner.registerInfo("Saturday start time rounded to nearest 15 minutes: #{rounded_start_saturday}")
      end
      sat_after_hour = rounded_start_saturday.truncate
      sat_after_min = (rounded_start_saturday - sat_after_hour)*60
      sat_after_min = sat_after_min.to_i
    end

    #check end_saturday for reasonableness and round to 15 minutes
    if not 0 <= end_saturday and end_saturday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    elsif end_saturday > start_saturday
      runner.registerError("Please enter an end time earlier in the day than start time.")
      return false
    else
      rounded_end_saturday = ((end_saturday*4).round)/4.0
      if not end_saturday == rounded_end_saturday
        runner.registerInfo("Saturday end time rounded to nearest 15 minutes: #{rounded_end_saturday}")
      end
      sat_before_hour = rounded_end_saturday.truncate
      sat_before_min = (rounded_end_saturday - sat_before_hour)*60
      sat_before_min = sat_before_min.to_i
    end

    #check start_sunday for reasonableness and round to 15 minutes
    if not 0 <= start_sunday and start_sunday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    else
      rounded_start_sunday = ((start_sunday*4).round)/4.0
      if not start_sunday == rounded_start_sunday
        runner.registerInfo("Sunday start time rounded to nearest 15 minutes: #{rounded_start_sunday}")
      end
      sun_after_hour = rounded_start_sunday.truncate
      sun_after_min = (rounded_start_sunday - sun_after_hour)*60
      sun_after_min = sun_after_min.to_i
    end

    #check end_sunday for reasonableness and round to 15 minutes
    if not 0 <= end_sunday and end_sunday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    elsif end_sunday > start_sunday
      runner.registerError("Please enter an end time earlier in the day than start time.")
      return false
    else
      rounded_end_sunday = ((end_sunday*4).round)/4.0
      if not end_sunday == rounded_end_sunday
        runner.registerInfo("Sunday end time rounded to nearest 15 minutes: #{rounded_end_sunday}")
      end
      sun_before_hour = rounded_end_sunday.truncate
      sun_before_min = (rounded_end_sunday - sun_before_hour)*60
      sun_before_min = sun_before_min.to_i
    end
    
    # Uniform reduction for all times
    wk_occ_red = oc_pct_red
    wk_unoc_red = unoc_pct_red
    sat_oc_red = oc_pct_red
    sat_unoc_red = unoc_pct_red
    sun_oc_red = oc_pct_red
    sun_unoc_red = unoc_pct_red

    # Get schedules from all electric equipment.
    # TODO Change to only impact computers, printer, etc. somehow,
    # which might require breaking out loads in reference buildings.
    original_equip_schs = []
    model.getElectricEquipments.each do |equip|
      if equip.schedule.is_initialized
        equip_sch = equip.schedule.get
        original_equip_schs << equip_sch
      end
    end

    #loop through the unique list of equip schedules, cloning
    #and reducing schedule fraction before and after the specified times
    original_equip_schs_new_schs = {}
    original_equip_schs.uniq.each do |equip_sch|
      if equip_sch.to_ScheduleRuleset.is_initialized
        new_equip_sch = equip_sch.clone(model).to_ScheduleRuleset.get
        new_equip_sch.setName("#{equip_sch.name} with Plug Load Controls")
        original_equip_schs_new_schs[equip_sch] = new_equip_sch
        new_equip_sch = new_equip_sch.to_ScheduleRuleset.get
        
        #method to reduce the values in a day schedule to a give number before and after a given time
        def reduce_schedule(day_sch, before_hour, before_min, oc_value, after_hour, after_min, unoc_value)
          before_time = OpenStudio::Time.new(0, before_hour, before_min, 0)
          after_time = OpenStudio::Time.new(0, after_hour, after_min, 0)
          day_end_time = OpenStudio::Time.new(0, 24, 0, 0)
          
          # Special situation for when start time and end time are equal,
          # meaning that a 24hr reduction is desired
          if before_time == after_time
            day_sch.clearValues
            day_sch.addValue(day_end_time, unoc_value)
            return
          end

          original_value_at_after_time = day_sch.getValue(after_time)
          original_value_at_before_time = day_sch.getValue(before_time)
          day_sch.addValue(before_time, original_value_at_before_time)
          day_sch.addValue(after_time, original_value_at_after_time)
          times = day_sch.times
          values = day_sch.values
          day_sch.clearValues

          new_times = []
          new_values = []
          for i in 0..(values.length - 1)
            if times[i] >= before_time and times[i] <= after_time
              new_times << times[i]
              new_values << values[i] * (1 - oc_value)
            else
              new_times << times[i]
              new_values << values[i] * (1 - unoc_value)
            end
          end

          #add the value for the time period from after time to end of the day
          # new_times << day_end_time
          # new_values << unoc_value

          for i in 0..(new_values.length - 1)
            day_sch.addValue(new_times[i], new_values[i])
          end
        end #end reduce schedule

        # Reduce default day schedules
        if new_equip_sch.scheduleRules.size == 0
          runner.registerWarning("Schedule '#{new_equip_sch.name}' applies to all days.  It has been treated as a Weekday schedule.")
        end
        reduce_schedule(new_equip_sch.defaultDaySchedule, wk_before_hour, wk_before_min, wk_occ_red, wk_after_hour, wk_after_min, wk_unoc_red)
        
        #reduce weekdays
        new_equip_sch.scheduleRules.each do |sch_rule|
          if apply_weekday
            if sch_rule.applyMonday or sch_rule.applyTuesday or sch_rule.applyWednesday or sch_rule.applyThursday or sch_rule.applyFriday
              reduce_schedule(sch_rule.daySchedule, wk_before_hour, wk_before_min, wk_occ_red, wk_after_hour, wk_after_min, wk_unoc_red)
            end
          end
        end

        #reduce saturdays
        new_equip_sch.scheduleRules.each do |sch_rule|
          if apply_saturday and sch_rule.applySaturday
            if sch_rule.applyMonday or sch_rule.applyTuesday or sch_rule.applyWednesday or sch_rule.applyThursday or sch_rule.applyFriday
              runner.registerWarning("Rule '#{sch_rule.name}' for schedule '#{new_equip_sch.name}' applies to both Saturdays and Weekdays.  It has been treated as a Weekday schedule.")
            else
              reduce_schedule(sch_rule.daySchedule, sat_before_hour, sat_before_min, sat_oc_red, sat_after_hour, sat_after_min, sat_unoc_red)
            end
          end
        end

        #reduce sundays
        new_equip_sch.scheduleRules.each do |sch_rule|
          if apply_sunday and sch_rule.applySunday
            if sch_rule.applyMonday or sch_rule.applyTuesday or sch_rule.applyWednesday or sch_rule.applyThursday or sch_rule.applyFriday
              runner.registerWarning("Rule '#{sch_rule.name}' for schedule '#{new_equip_sch.name}' applies to both Sundays and Weekdays.  It has been  treated as a Weekday schedule.")
            elsif sch_rule.applySaturday
              runner.registerWarning("Rule '#{sch_rule.name}' for schedule '#{new_equip_sch.name}' applies to both Saturdays and Sundays.  It has been treated as a Saturday schedule.")
            else
              reduce_schedule(sch_rule.daySchedule, sun_before_hour, sun_before_min, sun_oc_red, sun_after_hour, sun_after_min, sun_unoc_red)
            end
          end
        end
      else
        runner.registerWarning("Schedule '#{equip_sch_name}' isn't a ScheduleRuleset object and won't be altered by this measure.")
      end
    end #end of original_equip_schs.uniq.each do

    #loop through all electric equipment instances, replacing old equip schedules with the reduced schedules
    model.getElectricEquipments.each do |equip|
      if equip.schedule.empty?
        runner.registerWarning("There was no schedule assigned for the electric equipment object named '#{equip.name}. No schedule was added.'")
      else
        old_equip_sch = equip.schedule.get
        equip.setSchedule(original_equip_schs_new_schs[old_equip_sch])
        runner.registerInfo("Schedule for the electric equipment object named '#{equip.name}' was reduced to simulate the application of Plug Load Controls.")
      end
    end

    # NA if the model has no electric equipment
    if model.getElectricEquipments.size == 0
      runner.registerNotAsApplicable("Not Applicable - There is no electric equipment in the model.")
    end

    # Reporting final condition of model
    runner.registerFinalCondition("#{original_equip_schs.uniq.size} schedule(s) were edited to reflect the addition of Plug Load Controls to the plug loads in the building.")
    
    return true

  end
  
end

# register the measure to be used by the application
PlugLoadControls.new.registerWithApplication
