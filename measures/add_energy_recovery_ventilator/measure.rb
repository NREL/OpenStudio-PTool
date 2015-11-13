# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class AddEnergyRecoveryVentilator < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Add Energy Recovery Ventilator"
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
    
    # Increased fan pressure drop from ERV
    fan_pressure_increase_inH2O = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_pressure_increase_inH2O", false)
    fan_pressure_increase_inH2O.setDisplayName("Increase in Fan Pressure from ERV")
    fan_pressure_increase_inH2O.setUnits("in H2O")
    fan_pressure_increase_inH2O.setDefaultValue(1.0)
    args << fan_pressure_increase_inH2O	    
    
    # Sensible Effectiveness at 100% Heating Air Flow (default of 0.76)
    sensible_eff_at_100_heating = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sensible_eff_at_100_heating", false)
    sensible_eff_at_100_heating.setDisplayName("Sensible Effectiveness at 100% Heating Air Flow")
    sensible_eff_at_100_heating.setDefaultValue(0.76)
    args << sensible_eff_at_100_heating	
    
    # Latent Effectiveness at 100% Heating Air Flow (default of 0.76)
    latent_eff_at_100_heating = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("latent_eff_at_100_heating", false)
    latent_eff_at_100_heating.setDisplayName("Latent Effectiveness at 100% Heating Air Flow")
    latent_eff_at_100_heating.setDefaultValue(0.68)
    args << latent_eff_at_100_heating		
   
    # Sensible Effectiveness at 75% Heating Air Flow (default of 0.76)
    sensible_eff_at_75_heating = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sensible_eff_at_75_heating", false)
    sensible_eff_at_75_heating.setDisplayName("Sensible Effectiveness at 75% Heating Air Flow")
    sensible_eff_at_75_heating.setDefaultValue(0.81)
    args << sensible_eff_at_75_heating	
    
    # Latent Effectiveness at 100% Heating Air Flow (default of 0.76)
    latent_eff_at_75_heating = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("latent_eff_at_75_heating", false)
    latent_eff_at_75_heating.setDisplayName("Latent Effectiveness at 75% Heating Air Flow")
    latent_eff_at_75_heating.setDefaultValue(0.73)
    args << latent_eff_at_75_heating		

    # Sensible Effectiveness at 100% Cooling Air Flow (default of 0.76)
    sensible_eff_at_100_cooling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sensible_eff_at_100_cooling", false)
    sensible_eff_at_100_cooling.setDisplayName("Sensible Effectiveness at 100% Cooling Air Flow")
    sensible_eff_at_100_cooling.setDefaultValue(0.76)
    args << sensible_eff_at_100_cooling	
    
    # Latent Effectiveness at 100% Cooling Air Flow (default of 0.76)
    latent_eff_at_100_cooling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("latent_eff_at_100_cooling", false)
    latent_eff_at_100_cooling.setDisplayName("Latent Effectiveness at 100% Cooling Air Flow")
    latent_eff_at_100_cooling.setDefaultValue(0.68)
    args << latent_eff_at_100_cooling		
   
    # Sensible Effectiveness at 75% Cooling Air Flow (default of 0.76)
    sensible_eff_at_75_cooling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sensible_eff_at_75_cooling", false)
    sensible_eff_at_75_cooling.setDisplayName("Sensible Effectiveness at 75% Cooling Air Flow")
    sensible_eff_at_75_cooling.setDefaultValue(0.81)
    args << sensible_eff_at_75_cooling	
    
    # Latent Effectiveness at 100% Cooling Air Flow (default of 0.76)
    latent_eff_at_75_cooling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("latent_eff_at_75_cooling", false)
    latent_eff_at_75_cooling.setDisplayName("Latent Effectiveness at 75% Cooling Air Flow")
    latent_eff_at_75_cooling.setDefaultValue(0.73)
    args << latent_eff_at_75_cooling

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    

    fan_pressure_increase_inH2O = runner.getDoubleArgumentValue("fan_pressure_increase_inH2O",user_arguments)
    
    sensible_eff_at_100_heating = runner.getDoubleArgumentValue("sensible_eff_at_100_heating",user_arguments)		
    latent_eff_at_100_heating = runner.getDoubleArgumentValue("latent_eff_at_100_heating",user_arguments)	
    sensible_eff_at_75_heating = runner.getDoubleArgumentValue("sensible_eff_at_75_heating",user_arguments)	
    latent_eff_at_75_heating = runner.getDoubleArgumentValue("latent_eff_at_75_heating",user_arguments)
      
    sensible_eff_at_100_cooling = runner.getDoubleArgumentValue("sensible_eff_at_100_cooling",user_arguments)	
    latent_eff_at_100_cooling = runner.getDoubleArgumentValue("latent_eff_at_100_cooling",user_arguments)	
    sensible_eff_at_75_cooling = runner.getDoubleArgumentValue("sensible_eff_at_75_cooling",user_arguments)	
    latent_eff_at_75_cooling = runner.getDoubleArgumentValue("latent_eff_at_75_cooling",user_arguments)	
    
    
    
    # Convert fan pressure rise to SI units
    fan_pressure_increase_Pa = OpenStudio.convert(fan_pressure_increase_inH2O,"inH_{2}O","Pa").get
    
    # Count the number of airloops to determine if measure is applicable
    initial_airloops = model.getAirLoopHVACs
    if initial_airloops.size == 0
      runner.registerAsNotApplicable("Not Applicable - this model has no airloops to which ERVs can be added.")
      return true
    end
    
    # Number of ERVs initially
    initial_ervs = model.getHeatExchangerAirToAirSensibleAndLatents.size
    if initial_ervs == 0
      runner.registerInitialCondition("This building has #{initial_airloops.size} air systems, none of which have energy recovery devices on their outdoor air systems.")
    else
      runner.registerInitialCondition("This building has #{initial_airloops.size} air systems, #{initial_ervs} of which have energy recovery devices on their outdoor air systems.")
    end
    
    # Loop through all air loops and add an ERV if one is not present
    airloops_ervd = []
    airloops_already_erv = []
    model.getAirLoopHVACs.each do |air_loop|	
      # Skip to the next airloop if this airloop already has an ERV
      has_erv = false
      air_loop.oaComponents.each do |oa_comp|
        if oa_comp.to_HeatExchangerAirToAirSensibleAndLatent.is_initialized
          has_erv = true
          break
        end
      end
      if has_erv == true
        runner.registerInfo("#{air_loop.name} already has an ERV.")
        airloops_already_erv << air_loop 
        next
      end
      
      # Skip to the next airloop if this airloop has no OA intake to do heat recovery on
      if air_loop.airLoopHVACOutdoorAirSystem.empty?
        runner.registerInfo("#{air_loop.name} has no OA intake, cannot add ERV.")
        next
      end      
      
      # Get the OA system and its outboard OA node
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_node = oa_system.outboardOANode	
      if oa_node.empty?
        runner.registerError("OA intake on #{air_loop.name} has no outboard OA node, cannot continue.")
      end
      oa_node = oa_node.get
      
      # Create the ERV and set its properties
      erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
      airloops_ervd << air_loop
      erv.addToNode(oa_node)	
      erv.setHeatExchangerType("Rotary")
      # TODO Come up with scheme for estimating power of ERV motor wheel
      # which might require knowing airlow (like prototype buildings do).
      # erv.setNominalElectricPower(value_new)
      # TODO Fix these methods
      #erv.setEconomizerLockout('Yes')
      erv.setEconomizerLockout(true)
      #erv.setString(23, "Yes")

      #erv.setSupplyAirOutletTemperatureControl ('No')
      erv.setSupplyAirOutletTemperatureControl (false)
      #erv.setString(17, "No")
      
      erv.setSensibleEffectivenessat100CoolingAirFlow(sensible_eff_at_100_cooling)
      erv.setSensibleEffectivenessat75CoolingAirFlow(sensible_eff_at_75_cooling)
      erv.setLatentEffectivenessat100CoolingAirFlow(latent_eff_at_100_cooling)
      erv.setLatentEffectivenessat75CoolingAirFlow(latent_eff_at_75_cooling)
      
      erv.setSensibleEffectivenessat100HeatingAirFlow(sensible_eff_at_100_heating)
      erv.setSensibleEffectivenessat75HeatingAirFlow(sensible_eff_at_75_heating)
      erv.setLatentEffectivenessat100HeatingAirFlow(latent_eff_at_100_heating)
      erv.setLatentEffectivenessat75HeatingAirFlow(latent_eff_at_75_heating)

      # Increase fan pressure caused by the ERV
      fans = []
      fans += air_loop.supplyComponents("OS:Fan:VariableVolume".to_IddObjectType)
      fans += air_loop.supplyComponents("OS:Fan:ConstantVolume".to_IddObjectType)
      if fans.size == 0
        runner.registerWarning("#{air_loop.name.get} has no fan; fan pressure for ERV not modified")
      else
        if fans[0].to_FanConstantVolume.is_initialized
          fans[0].to_FanConstantVolume.get.setPressureRise(fan_pressure_increase_Pa)
        elsif fans[0].to_FanVariableVolume.is_initialized
          fans[0].to_FanVariableVolume.get.setPressureRise(fan_pressure_increase_Pa)
        end
      end
         
    end
         
    # Not applicable if no ERVs were added
    if airloops_ervd.size == 0
      runner.registerAsNotApplicable("Not Applicable - no ERVs were added to this model.")
      return true
    end
    
    # Not applicable if all airloops already had ERVs
    if initial_airloops.size == airloops_already_erv.size
      runner.registerAsNotApplicable("Not Applicable - all airloops already had ERVs.")
      return true
    end    
    
    # Report the final condition
    runner.registerFinalCondition("ERVs were added to #{airloops_ervd.size} air systems in the building.")

    return true

  end
  
end

# register the measure to be used by the application
AddEnergyRecoveryVentilator.new.registerWithApplication
