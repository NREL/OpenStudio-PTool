# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

#require_relative '/resources/Standards.ThermalZoneHVAC'
#require_relative '/resources/Standards.AirLoopHVAC'

# start the measure
class CorrectHvacOperationSchedules < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "correct_hvac_operation_schedules"
  end

  # human readable description
  def description
    return "xx"
	
	#"This energy efficiency measure (EEM) modifies the availability schedules of HVAC fans, pumps, chillers, and zone thermostats to represent a movement to an occupancy based scheduling of HVAC equipment, allowing the building to coast towards its unoccupied state while it is still partially occupied. An AirLoop occupancy threshold value of lower than 5 percent of peak occupancy is considered to define when HVAC equipment should not operate.  Energy can be saved by shutting down cooling equipment when it is not needed, as soon as occupants leave the building and prior to their arrival. While this measure may save energy, unmet hours and occupant thermal comfort conditions during transient startup periods should be closely monitored. The measure also adds heating and cooling unmet hours and Simplified ASHRAE Standard 55 Thermal Comfort warning reporting variable to each thermal zone. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "yyy" 
	# "The measure loops through the AirLoops associated with the model, and determines an occupancy weighted schedule with values of 1 or 0 based on the percent of peak occupancy at the timestep being above or below a set threshold value of 5 percent. The resulting occupancy schedule is applied to the airloop attribute for the availability schedule.  The measure then loops through all thermal zones, examining if there are zone equipment objects attached. If there are one or more zone equipment object attached to the zone, a thermal zone occupancy weighted schedule with values of 1 or 0 based on the percent of peak occupancy at the timestep being above or below a set threshold value of 5 percent is generated. The schedule is then assigned to the availability schedule of the associated zone equipment. To prevent energy use by any corresponding plant loops, the pump control type attribute of Constant or Variable speed pump objects in the model are set to intermittent. The measure them adds heating and cooling unmet hours and Simplified ASHRAE Standard 55 warning reporting variable to each thermal zone."
  end

  # define the arguments that the user will input
  def arguments(model)
    
  end

 
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
  
  
#  zone_name =

# sch = zone_name.get_occupancy_schedule(0.05) # Threshold = 0.05 of peak occupancy 
  

  
  
  
  end
  
end

# register the measure to be used by the application
CorrectHvacOperationSchedules.new.registerWithApplication
