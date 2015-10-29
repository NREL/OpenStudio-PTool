module Helpers

  # modified from: https://github.com/NREL/OpenStudio-PTool/blob/master/measures/predictive_thermostats/measure.rb
  def Helpers.get_min_max_time(sch_ruleset)
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
      profile.times.each do |time|
        if min.nil?
          min = time
        else
          if min > time then min = time end
        end
        if max.nil?
          max = time unless time.to_s == "24:00:00"
        else
          if max < time then max = time unless time.to_s == "24:00:00" end 
        end
      end
    end

    result = {"min" => min, "max" => max}
    return result

  end #get_min_max_time

  # SOURCE: OsLib_Schedules.rb
  # create a ruleset schedule with a basic profile
  def Helpers.createSimpleSchedule(model, options = {})

    defaults = {
        "name" => nil,
        "winterTimeValuePairs" => {24.0 => 0.0},
        "summerTimeValuePairs" => {24.0 => 1.0},
        "defaultTimeValuePairs" => {24.0 => 1.0},
    }

    # merge user inputs with defaults
    options = defaults.merge(options)

    #ScheduleRuleset
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    if name
      sch_ruleset.setName(options["name"])
    end

    #Winter Design Day
    winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
    winter_dsn_day = sch_ruleset.winterDesignDaySchedule
    winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")
    options["winterTimeValuePairs"].each do |k,v|
      hour = k.truncate
      min = ((k - hour)*60).to_i
      winter_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0),v)
    end

    #Summer Design Day
    summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
    summer_dsn_day = sch_ruleset.summerDesignDaySchedule
    summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")
    options["summerTimeValuePairs"].each do |k,v|
      hour = k.truncate
      min = ((k - hour)*60).to_i
      summer_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0),v)
    end

    #All Days
    default_day = sch_ruleset.defaultDaySchedule
    default_day.setName("#{sch_ruleset.name} Schedule Week Day")
    options["defaultTimeValuePairs"].each do |k,v|
      hour = k.truncate
      min = ((k - hour)*60).to_i
      default_day.addValue(OpenStudio::Time.new(0, hour, min, 0),v)
    end

    result = sch_ruleset
    return result

  end #end of OsLib_Schedules.createSimpleSchedule
'
  # find the maximum profile value for a schedule
  def OsLib_Schedules.getMinMaxAnnualProfileValue(model, schedule)

    # gather profiles
    profiles = []
    defaultProfile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
    profiles << defaultProfile
    rules = schedule.scheduleRules
    rules.each do |rule|
      profiles << rule.daySchedule
    end

    # test profiles
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

    result = {"min" => min, "max" => max} # this doesnt include summer and winter design day
    return result

  end #end of OsLib_Schedules.getMaxAnnualProfileValue
' 
end #module