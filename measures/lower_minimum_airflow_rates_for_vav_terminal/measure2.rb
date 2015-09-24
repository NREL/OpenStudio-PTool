# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class LowerMinimumAirflowRatesForVAVTerminal < OpenStudio::Ruleset::ModelUserScript

	# human readable name
		def name
		return "Lower minimum airflow rates for VAV terminal"
	end

	# human readable description
		def description
		return "This energy efficiency measure (EEM) changes the VAV box minimum flow setting to 0.4 cfm/sf for all AirLoops in the model."
	end

	# human readable description of modeling approach
		def modeler_description
		return "This measure loops through the thermal zones in all air loops. It then selects the thermal zone area and then calculates the minimum flow rate of 0.4 cfm/sf. If the zone has an AirTerminalSingleDuct VAVReheat & AirTerminalSingleDuctVAVNoReheat terminal unit the measure changes the zone minimum air flow method to fixed flow rate and applies the calculated minimum flow rate."
	end

	# define the arguments that the user will input
		def arguments(model)
		args = OpenStudio::Ruleset::OSArgumentVector.new
		return args
	end #ends the argument


		
		
	# define what happens when the measure is run
	def run(model, runner, user_arguments)
		super(model, runner, user_arguments)

			
			def neat_numbers(number, roundto = 2) #round to 0 or 2)
				if roundto == 2
					number = sprintf "%.2f", number
				else
					number = number.round
				end
					#regex to add commas
					number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
			end #end def neat_numbers
			
			
			
			
		# use the built-in error checking
		if !runner.validateUserArguments(arguments(model), user_arguments)
			return false
		end

		# initialize the variables
		numb_airsingle_terminal_vavnoreheat = 0
			
		all_airloops = model.getAirLoopHVACs   # retrieving all the airloops

		if all_airloops.size == 0
			runner.registerAsNotApplicable("Model has no airloops. Measure is not applicable.") 
			return true
		end

		#loop through air loops
		all_airloops.each do |loop| 
			thermal_zones = loop.thermalZones

			
			#find airflow rates on loop
			thermal_zones.each do |thermal_zone|
				  
				# get the thermal zone area
				m2_thermal_zone_area = thermal_zone.floorArea
				
				sqft_thermal_zone_area = OpenStudio.convert(m2_thermal_zone_area,"m^2","ft^2").get
				ft2_thermal_zone_area = neat_numbers(sqft_thermal_zone_area,2)				
				# calc the minimum airflow rate needed for the zone
				thermal_zone_min_flow = (sqft_thermal_zone_area * 0.4)
				
				# thermal_zone_min_flow = (OpenStudio.convert(thermal_zone.floorArea,"m^2","ft^2").get * 0.4)
				
				
				
				
				#get the VAV boxes for the thermal zone
				zone_equip = thermal_zone.equipment
				 
				zone_equip.each do |vav_box|
					airterminal_singleduct_vavnoreheat = vav_box.to_AirTerminalSingleDuctVAVNoReheat   #alter equipment of the correct type
					
						if not airterminal_singleduct_vavnoreheat.empty?
							airterminal_singleduct_vavnoreheat = airterminal_singleduct_vavnoreheat.get
							#existing_method2 = airterminal_singleduct_vavreheat.zoneMinimumAirFlowInputMethod 
							#change the zoneMinimumAirFlowInputMethod 
							airterminal_singleduct_vavnoreheat.setZoneMinimumAirFlowInputMethod("FixedFlowRate")
							airterminal_singleduct_vavnoreheat.setFixedMinimumAirFlowRate(thermal_zone_min_flow)
							cubic_mps_2 = airterminal_singleduct_vavnoreheat.fixedMinimumAirFlowRate
							cubic_mps_2 = neat_numbers(cubic_mps_2,2)
							#short def to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure
							atsdvnr = airterminal_singleduct_vavnoreheat.name.get
							runner.registerInfo("Minimum Airflow rate for Single duct VAV named '#{atsdvnr}' with area #{ft2_thermal_zone_area} sqft  has been changed to a minimum fixed flow rate of #{cubic_mps_2} cfm.")
							#increment counter of above object by one
							numb_airsingle_terminal_vavnoreheat += 1
									
						end	
							
					
							
			
											
					#end		#ends the airterminal if statement			
								
				end #ends the do loop for zone equipments
					
			end #ends the do loop for thermal zones
			
		end #ends the do loop for ending the airloop loop
				
		total_modified_objects = numb_airsingle_terminal_vavnoreheat # total number of objects
			
		# report AsNotApplicable condition of model	
		if	
			total_modified_objects == 0
			runner.registerAsNotApplicable("The building contains no qualified objects. Measure is not applicable.") 	
			return true
		end
			
		# report initial condition of model
		runner.registerInitialCondition("The model begins with Single duct VAV with reheat objects & #{numb_airsingle_terminal_vavnoreheat} Single duct VAV with no reheat objects.") # report initial condition of model

		   
		# report final condition of model
		runner.registerFinalCondition("The model finished with #{total_modified_objects} objects having the 'zone minimum air flow method' set to 'fixed flow rate' and a minimum airflow rate of 0.4 cfm/sf.")  
			
		return true
		  
	end #ends the run method

end #ends the class



# register the measure to be used by the application
LowerMinimumAirflowRatesForVAVTerminal.new.registerWithApplication
