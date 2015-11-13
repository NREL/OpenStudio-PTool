# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class HotWaterSupplyTempReset < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Hot Water Supply Temp Reset"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) adds a set point reset to all hot water loops present in the OpenStudio model. The hot water supply temperature reset will be based on outdoor-air temperature (OAT). The specific sequence is that as outdoor-air temperature (OAT) lowers from 60F (15.6C) down to 20F (-6.67C), the hot water supply temperature set point will increase from 160F (71.1C) up to 180F (82.2C).  This sequence provides a 20F (11.1C) change in the Hot Water Set Point, over a 40F (22.2C) temperature change in the OAT. This sequence assumes all boilers serving the hot water plant loops are non-condensing and should not receive return water below 140F (60.0C)."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This EEM applies an OS:SetpointMsanager:OutdoorAirReset controller to the supply outlet node of all PlantLoop objects where OS:Sizing:Plant.LoopType = 'Heating'.
"
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
      
			# Initialize variables for allowing variable scopes within the method
			setpoint_OA_reset_array = []
			setpoint_scheduled_array = []
			setpoint_scheduled_dual_array = []
			setpoint_follow_oa_temp_array = []

			# Create array of all plant loops where plantLoop.SizingPlant.Looptype = "Heating" 
			heating_plant_loop_array_initial = []
			heating_plant_loop_array = []
			model.getPlantLoops.each do |plantLoop|
				loop_type = plantLoop.sizingPlant.loopType
				total_loop = plantLoop.sizingPlant.loopType.length
				loop_temp = plantLoop.sizingPlant.designLoopExitTemperature
				if loop_type == "Heating" && loop_temp > 43.33 # finding all the 'heating' type loops
					heating_plant_loop_array_initial << plantLoop	
				end #end the heating loop condition		
			end #end loop through plant loops
			
			# remove any heating plant loop that have water use connection objects associated
			heating_plant_loop_array = heating_plant_loop_array_initial.select {|l| not l.demandComponents.any? {|dc| dc.to_WaterUseConnections.is_initialized}} # removing SWH loops from all heating loops considering all SWH will have wateruseconnections for DHW consumptions
			heating_plant_loop_array.each do |l| 
			end
			
			if
				heating_plant_loop_array.length == 0
				runner.registerAsNotApplicable ("No Heating PlantLoop objects found. EEM is not applicable.")
			end #end the not applicable if condition for heating plant loop
			
			eligible_heatingloop_names = heating_plant_loop_array.collect{ |l| l.name.to_s }.join(', ') # to get all the names of heating array objects
			
			# Loop through heating_plant_loop_array to find setpoint objects	
			heating_plant_loop_array.each do |pl| #runner.registerInfo("XXX = #{pl.supplyComponents.length}") 
			pl.supplyComponents.each do |sc|
				if sc.iddObjectType.valueDescription == "OS:Node"
					@setpoint_list = sc.to_Node.get.setpointManagers #runner.registerInfo("list of setpoints = #{@setpoint_list.length}") 
				end
				
				@setpoint_list.each do |managertype|
					# get count of OS:SetpointManagerOutdoorAirReset objects & assign a new setpoint manager:OA reset to the same node the existing one was attached
					if managertype.to_SetpointManagerOutdoorAirReset.is_initialized
						setpoint_OA_reset_array << managertype.to_SetpointManagerOutdoorAirReset.get
						setpoint_OA_reset_array.each do |sp|
							if sp.setpointNode.is_initialized
								set_point_node_oa = sp.setpointNode.get
								new_setpoint_OA_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
								new_setpoint_OA_reset.addToNode(set_point_node_oa)
								new_setpoint_OA_reset.setName("#{managertype.name}_replaced")
								new_setpoint_OA_reset.setOutdoorHighTemperature(15.56)
								new_setpoint_OA_reset.setOutdoorLowTemperature(-6.67)
								new_setpoint_OA_reset.setSetpointatOutdoorHighTemperature(71.1)
								new_setpoint_OA_reset.setSetpointatOutdoorLowTemperature(82.2)
								runner.registerInfo("An outdoor air reset setpoint manager object named #{new_setpoint_OA_reset.name} has replaced the existing outdoor air reset setpoint manager object serving the hot water plant loop named #{pl.name}. The setpoint manager resets the hot water setpoint from 71.1 deg C to 82.2 deg C between outdoor air temps of 15.56 Deg C and -6.67 Deg C.")
							end
						end
					end
				
					# get count of OS:SetpointManagerScheduled objects	& assign a new setpoint manager:OA reset to the same node the existing one was attached	
					if managertype.to_SetpointManagerScheduled.is_initialized
						setpoint_scheduled_array << managertype.to_SetpointManagerScheduled.get
						setpoint_scheduled_array.each do |sp1|
							if sp1.setpointNode.is_initialized
								set_point_node_sched = sp1.setpointNode.get
								new_setpoint_sched = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
								new_setpoint_sched.addToNode(set_point_node_sched)
								new_setpoint_sched.setName("#{managertype.name}_replaced")
								new_setpoint_sched.setOutdoorHighTemperature(15.56)
								new_setpoint_sched.setOutdoorLowTemperature(-6.67)
								new_setpoint_sched.setSetpointatOutdoorHighTemperature(71.1)
								new_setpoint_sched.setSetpointatOutdoorLowTemperature(82.2)
								runner.registerInfo("An outdoor air reset setpoint manager object named #{new_setpoint_sched.name} has replaced the existing scheduled setpoint manager object serving the hot water plant loop named #{pl.name}. The setpoint manager resets the hot water setpoint from 71.1 deg C to 82.2 deg C between outdoor air temps of 15.56 Deg C and -6.67 Deg C.")
							end
						end # end setpoint scheduled array do loop
					end	# end if statement for managertype =setpoint manager scheduled object
					
					# get count of OS:SetpointManagerScheduledDualSetpoint objects	& assign a new setpoint manager:OA reset to the same node the existing one was attached	
					if managertype.to_SetpointManagerScheduledDualSetpoint.is_initialized
						setpoint_scheduled_dual_array << managertype.to_SetpointManagerScheduledDualSetpoint.get
						setpoint_scheduled_dual_array.each do |sp2|
							if sp2.setpointNode.is_initialized
								set_point_node_dual = sp2.setpointNode.get
								new_setpoint_dual = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
								new_setpoint_dual.addToNode(set_point_node_dual)
								new_setpoint_dual.setName("#{managertype.name}_replaced")
								new_setpoint_dual.setOutdoorHighTemperature(15.56)
								new_setpoint_dual.setOutdoorLowTemperature(-6.67)
								new_setpoint_dual.setSetpointatOutdoorHighTemperature(71.1)
								new_setpoint_dual.setSetpointatOutdoorLowTemperature(82.2)
								runner.registerInfo("An outdoor air reset setpoint manager object named #{new_setpoint_OA_reset.name} has replaced the existing dual setpoint setpoint manager object serving the hot water plant loop named #{pl.name}. The setpoint manager resets the hot water setpoint from 71.1 deg C to 82.2 deg C between outdoor air temps of 15.56 Deg C and -6.67 Deg C.")
							end
						end
					end
					
					# get count of OS:SetpointManagerFollowOutdoorAirTemperature objects & assign a new setpoint manager:OA reset to the same node the existing one was attached		
					if managertype.to_SetpointManagerFollowOutdoorAirTemperature.is_initialized
						setpoint_follow_oa_temp_array << managertype.to_SetpointManagerFollowOutdoorAirTemperature.get
						setpoint_follow_oa_temp_array.each do |sp3|
							if sp3.setpointNode.is_initialized
								set_point_node_follow_oa = sp3.setpointNode.get
								new_setpoint_follow_oa = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
								new_setpoint_follow_oa.addToNode(set_point_node_follow_oa)
								new_setpoint_follow_oa.setName("#{managertype.name}_replaced")
								new_setpoint_follow_oa.setOutdoorHighTemperature(15.555)
								new_setpoint_follow_oa.setOutdoorLowTemperature(-6.666)
								new_setpoint_follow_oa.setSetpointatOutdoorHighTemperature(71.12)
								new_setpoint_follow_oa.setSetpointatOutdoorLowTemperature(82.23)
								runner.registerInfo("An outdoor air reset setpoint manager object named #{new_setpoint_OA_reset.name} has replaced the existing follow outdoor air temperature setpoint manager object serving the hot water plant loop named #{pl.name}. The setpoint manager resets the hot water setpoint from 71.1 deg C to 82.2 deg C between outdoor air temps of 15.56 Deg C and -6.67 Deg C.")

							end
						end
					end			
					
				end #loop through setpoint do loop
					
			end # end supply component do loop
		
			# report initial condition of model
			runner.registerInitialCondition("There are '#{heating_plant_loop_array.length}' eligible heating loops out of '#{model.getPlantLoops.length}' plant loops. \nEligible loops name(s): '#{eligible_heatingloop_names}'")

			# report final condition of model
			runner.registerFinalCondition("Hot Water Supply Temperature Reset has been applied to #{heating_plant_loop_array.length} plant loop(s). \nPlant Loops affected are: '#{eligible_heatingloop_names}'.")
			return true

		end #end the loop through the heating plant array
	  
	end # end the run method

 end # end the class
# register the measure to be used by the application
HotWaterSupplyTempReset.new.registerWithApplication
