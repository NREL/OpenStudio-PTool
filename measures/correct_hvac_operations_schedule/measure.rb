# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require "#{File.dirname(__FILE__)}/resources/Standards.ThermalZoneHVAC"
require "#{File.dirname(__FILE__)}/resources/Standards.AirLoopHVAC"

# start the measure
class CorrectHVACOperationsSchedule < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Correct HVAC Operations Schedule"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) modifies the availability schedules of HVAC fans, pumps, chillers, and zone thermostats to represent a movement to an occupancy based scheduling of HVAC equipment, allowing the building to coast towards its unoccupied state while it is still partially occupied. An AirLoop occupancy threshold value of lower than 5 percent of peak occupancy is considered to define when HVAC equipment should not operate.  Energy can be saved by shutting down cooling equipment when it is not needed, as soon as occupants leave the building and prior to their arrival. While this measure may save energy, unmet hours and occupant thermal comfort conditions during transient startup periods should be closely monitored. The measure also adds heating and cooling unmet hours and Simplified ASHRAE Standard 55 Thermal Comfort warning reporting variable to each thermal zone. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "The measure loops through the AirLoops associated with the model, and determines an occupancy weighted schedule with values of 1 or 0 based on the percent of peak occupancy at the timestep being above or below a set threshold value of 5 percent. The resulting occupancy schedule is applied to the airloop attribute for the availability schedule.  The measure then loops through all thermal zones, examining if there are zone equipment objects attached. If there are one or more zone equipment object attached to the zone, a thermal zone occupancy weighted schedule with values of 1 or 0 based on the percent of peak occupancy at the timestep being above or below a set threshold value of 5 percent is generated. The schedule is then assigned to the availability schedule of the associated zone equipment. To prevent energy use by any corresponding plant loops, the pump control type attribute of Constant or Variable speed pump objects in the model are set to intermittent. The measure them adds heating and cooling unmet hours and Simplified ASHRAE Standard 55 warning reporting variable to each thermal zone. "
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

	return args
  end
  
 def set_equip_availability_schedule (occ_sch, zone_equip_hvac_obj)
 	object_name = zone_equip_hvac_obj.name
	old_schedule = zone_equip_hvac_obj.availabilitySchedule
	old_schedule_name = old_schedule.name
	zone_equip_hvac_obj.setAvailabilitySchedule(occ_sch)
	return old_schedule_name
end # end set equip method
  
   
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

	#initialize variables
	zone_hvac_equip_count = 0
	pump_count = 0
	air_loop_count = 0
	
	#loop through each air loop in the model
	model.getAirLoopHVACs.sort.each do |air_loop|
   
		# call the method to generate a new occupancy schedule based on a 5% threshold
		occ_sch = air_loop.get_occupancy_schedule(0.05)
		# set the availability schedule of the airloop to the newly generated  schedule
		air_loop.setAvailabilitySchedule(occ_sch)
		air_loop_count =+1
		
	end # end loop through airloops

	#loop through each thermal zone
	model.getThermalZones.sort.each do |thermal_zone|
	
		thermal_zone_equipment = thermal_zone.equipment # zone equipments assigned to thermal zones
		if thermal_zone_equipment.size >= 1
			# run schedule method to create a new schedule ruleset, routines 
			occ_sch = thermal_zone.get_occupancy_schedule(0.05)
			
			#loop through Zone HVAC Equipment
			thermal_zone_equipment.each do |equip|
			
				equip_type = equip.iddObjectType
				
				if equip_type == OpenStudio::Model::FanZoneExhaust.iddObjectType
					zone_equip_hvac_obj = equip.to_FanZoneExhaust.get
					object_name = zone_equip_hvac_obj.name
					old_schedule = zone_equip_hvac_obj.availabilitySchedule.get
					old_sch_name = old_schedule.name
					zone_equip_hvac_obj.setAvailabilitySchedule(occ_sch)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Fan Zone Exhaust Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")
					zone_hvac_equip_count =+ 1 
				end 	
						
				if equip_type == OpenStudio::Model::RefrigerationAirChiller.iddObjectType
					zone_equip_hvac_obj = equip.to_RefrigerationAirChiller.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Refrigeration Air Chiller Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")
					zone_hvac_equip_count =+ 1 
				end 	
			
				if equip_type == OpenStudio::Model::WaterHeaterHeatPump.iddObjectType
					zone_equip_hvac_obj = equip.to_WaterHeaterHeatPump.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Water Heater Heat Pump Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")
					zone_hvac_equip_count =+ 1 
				end 	
						
				if equip_type == OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACBaseboardConvectiveElectric.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Baseboard Convective Electric Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")
					zone_hvac_equip_count =+ 1 
				end 	
				
				if equip_type == OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACBaseboardConvectiveWater.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Baseboard Convective Water Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")
					zone_hvac_equip_count =+ 1 
				end 	
				
				if equip_type == OpenStudio::Model::ZoneHVACBaseboardRadiantConvectiveElectric.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACBaseboardRadiantConvectiveElectric.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Baseboard Radiant and Convective Electric Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")
					zone_hvac_equip_count =+ 1 
				end 	
				
				if equip_type == OpenStudio::Model::ZoneHVACBaseboardRadiantConvectiveWater.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACBaseboardRadiantConvectiveWater.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Baseboard Radiant and Convective Water Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")
					zone_hvac_equip_count =+ 1 
				end 	
				
				if equip_type == OpenStudio::Model::ZoneHVACDehumidifierDX.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACDehumidifierDX.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Dehumidifier Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")
					zone_hvac_equip_count =+ 1 
				end 	
			
				if equip_type == OpenStudio::Model::ZoneHVACEnergyRecoveryVentilator.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACEnergyRecoveryVentilator.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Energy Recovery Ventilator Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	

				if equip_type == OpenStudio::Model::ZoneHVACFourPipeFanCoil.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACFourPipeFanCoil.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Four Pipe Fan Coil Unit Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	

				if equip_type == OpenStudio::Model::ZoneHVACHighTemperatureRadiant.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACHighTemperatureRadiant.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC High Temperature Radiant Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	

				if equip_type == OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACIdealLoadsAirSystem.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Ideal Air Loads System Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	

				if equip_type == OpenStudio::Model::ZoneHVACLowTemperatureRadiantElectric.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACLowTemperatureRadiantElectric.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Low Temperature Radiant Electric Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	

				if equip_type == OpenStudio::Model::ZoneHVACLowTempRadiantConstFlow.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACLowTempRadiantConstFlow.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Low Temperature Radiant Constant Flow Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 	
				end 	

				if equip_type == OpenStudio::Model::ZoneHVACLowTempRadiantVarFlow.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACLowTempRadiantVarFlow.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Low Temperature Radiant Variable Flow Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	
				
				if equip_type == OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACPackagedTerminalAirConditioner.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Packaged Terminal Air Conditioner Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	

				if equip_type == OpenStudio::Model::ZoneHVACPackagedTerminalHeatPump.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACPackagedTerminalHeatPump.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Packaged Terminal Heat Pump Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 
				
				if equip_type == OpenStudio::Model::ZoneHVACTerminalUnitVariableRefrigerantFlow.iddObjectType
					equip.to_ZoneHVACTerminalUnitVariableRefrigerantFlow.get.setTerminalUnitAvailabilityschedule(occ_sch)
					runner.registerInfo("The availability schedule for the Zone HVAC Terminal Unit Variable Refrigerant Flow Object has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	

				if equip_type == OpenStudio::Model::ZoneHVACUnitHeater.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACUnitHeater.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Unit Heater Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	
				
				if equip_type == OpenStudio::Model::ZoneHVACUnitVentilator.iddObjectType
					zone_equip_hvac_obj = equip.to_ZoneHVACUnitVentilator.get
					old_sch_name = set_equip_availability_schedule(occ_sch, zone_equip_hvac_obj)
					runner.registerInfo("The availability schedule named #{old_sch_name} for the Zone HVAC Unit Ventilator Object named #{zone_equip_hvac_obj.name} has been replaced with a new schedule named #{occ_sch.name} representing the occupancy profile of the thermal zone named #{thermal_zone.name}.")					
					zone_hvac_equip_count =+ 1 
				end 	

				if equip_type == OpenStudio::Model::ZoneVentilationDesignFlowRate.iddObjectType
					runner.registerInfo("Thermal Zone named #{thermal_zone.name} has a Zone Ventilation Design Flow Rate object attacjhed as a ZoneHVACEquipment object. No modification were made to this object.")		
				end 	
			
			end # end loop through Zone HVAC Equipment
			
		else
			runner.registerInfo("Thermal Zone named #{thermal_zone.name} has no Zone HVAC Equipment objects attached - therefore no schedule objects have been altered.")	
		end # end of if statement
	
	end # end loop through thermal zones

	# Change pump control status
	
	# get all plantloops
	model.getPlantLoops.each do |plantLoop|
		loop_name = plantLoop.name.to_s
		#Loop through each plant loop demand component
		plantLoop.demandComponents.each do |dc|
			if dc.to_PumpConstantSpeed.is_initialized
				cs_pump = dc.to_PumpConstantSpeed.get
				if cs_pump.pumpControlType == ("Intermittent")
					runner.registerInfo("Demand side Constant Speed Pump object named #{cs_pump.name} on the plant loop named #{dc.name} had a pump control type attribute already set to intermittent. No changes will be made to this object.")
				else 
					cs_pump.setPumpControlType("Intermittent")
					runner.registerInfo("Pump Control Type attribute of Demand side Constant Speed Pump object named #{cs_pump.name} on the plant loop named #{dc.name} was changed from continuous to intermittent.")
					pump_count =+1
					end #end if statement	
			end #end if statement for changing demand side constant speed pump objects
			
			if dc.to_PumpVariableSpeed.is_initialized
				vs_pump = dc.to_to_PumpVariableSpeed.get
				if vs_pump.pumpControlType == ("Intermittent")
					runner.registerInfo("Deamdn side Variable Speed Pump named #{vs_pump.name} on the plant loop named #{dc.name} had a pump control type attribute already set to intermittent. No changes will be made to this object.")
				else 
					cs_pump.setPumpControlType("Intermittent")
					runner.registerInfo("Demand side Pump Control Type attribute of Variable Speed Pump named #{vs_pump.name} on the plant loop named #{dc.name} was changed from continuous to intermittent.")
					pump_count =+1
				end #end if statement	
			end #end if statement for changing demand side variable speed pump objects
		end # end loop throught plant loop demand components
		
		#Loop through each plant loop supply component
		plantLoop.supplyComponents.each do |sc|
			if sc.to_PumpConstantSpeed.is_initialized
				cs_pump = sc.to_PumpConstantSpeed.get
				if cs_pump.pumpControlType == ("Intermittent")
					runner.registerInfo("Supply side Constant Speed Pump object named #{cs_pump.name} on the plant loop named #{sc.name} had a pump control type attribute already set to intermittent. No changes will be made to this object.")
				else 
					cs_pump.setPumpControlType("Intermittent")
					runner.registerInfo("Supply Side Pump Control Type atteribute of Constant Speed Pump named #{cs_pump.name} on the plant loop named #{sc.name} was changed from continuous to intermittent.")
					pump_count =+1
					end #end if statement	
			end #end if statement for changing supply component constant speed pump objects
			
			if sc.to_PumpVariableSpeed.is_initialized
				vs_pump = sc.to_PumpVariableSpeed.get
				if vs_pump.pumpControlType == ("Intermittent")
					runner.registerInfo("Supply side Variable Speed Pump object named #{vs_pump.name} on the plant loop named #{sc.name} had a pump control type attribute already set to intermittent. No changes will be made to this object.")
				else 
					cs_pump.setPumpControlType("Intermittent")
					runner.registerInfo("Pump Control Type attribute of Supply Side Variable Speed Pump named #{vs_pump.name} on the plant loop named #{sc.name} was changed from continuous to intermittent.")
					pump_count =+1
				end #end if statement	
			end #end if statement for changing supply component variable speed pump objects
			
		end # end loop throught plant loop supply side components
		
	end # end loop through plant loops
	
	
	#Write N/A message
	if air_loop_count == 0 and zone_hvac_equip_count == 0 and pump_count == 0 
		runner.registerAsNotApplicable("The model did not contain any Airloops, Thermal Zones having ZoneHVACEquipment objects or associated plant loop pump objects to act upon. The measure is not applicable.")
		return true
	end	
			
	#report initial condition of model
    runner.registerInitialCondition("The model started with #{air_loop_count} AirLoops, #{zone_hvac_equip_count} Zone HVAC Equipment Object and #{pump_count} pump objects subject to modifications.")
	
    # report final condition of model
    runner.registerFinalCondition("The measure modified the availability schedules of #{air_loop_count} AirLoops and #{zone_hvac_equip_count} Zone HVAC Equipment objects. #{pump_count} pump objects had control settings modified.")
  

	# Add ASHRAE Standard 55 warnings
	
	reporting_frequency = "Timestep"
	outputVariable = OpenStudio::Model::OutputVariable.new("Zone Thermal Comfort ASHRAE 55 Adaptive Model 90% Acceptability Status []",model)
    outputVariable.setReportingFrequency(reporting_frequency)
    runner.registerInfo("Adding output variable for 'Zone Thermal Comfort ASHRAE 55 Adaptive Model 90% Acceptability Status' reporting at the model timestep.")
	return true
	
  end # end run method
  
end # end class

# register the measure to be used by the application
CorrectHVACOperationsSchedule.new.registerWithApplication
