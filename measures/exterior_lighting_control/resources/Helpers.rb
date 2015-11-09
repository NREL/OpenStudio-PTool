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
    min_time = nil
    max_time = nil
    min_time_value = nil
    max_time_value = nil

    profiles.each do |profile|
      profile.times.each do |time|
        if min_time.nil?
          min_time = time
          min_time_value = profile.getValue(time)
        else
          if min_time > time then min_time = time end
        end
        if max_time.nil?
          max_time = time unless time.to_s == "24:00:00"
        else
          if max_time < time then max_time = time unless time.to_s == "24:00:00" end
        end
      end
    end

    result = {"min_time" => min_time, "max_time" => max_time}
    return result

  end #get_min_max_time

end #module
