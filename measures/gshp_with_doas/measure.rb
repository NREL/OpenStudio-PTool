#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#load OpenStudio measure libraries
# require "#{File.dirname(__FILE__)}/resources/OsLib_AedgMeasures"
# require "#{File.dirname(__FILE__)}/resources/OsLib_HelperMethods"
# require "#{File.dirname(__FILE__)}/resources/OsLib_HVAC"
# require "#{File.dirname(__FILE__)}/resources/OsLib_Schedules"

# Start the measure
class GroundSourceHeatPumpWithDOAS < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Ground Source Heat Pump With DOAS"
  end

  # Define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make an argument to apply/not apply this measure
    chs = OpenStudio::StringVector.new
    chs << "TRUE"
    chs << "FALSE"
    apply_measure = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('apply_measure', chs, true)
    apply_measure.setDisplayName("Apply Measure?")
    apply_measure.setDefaultValue("TRUE")
    args << apply_measure

    return args
  end #end the arguments method

  # Define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Assign the user inputs to variables
    apply_measure = runner.getStringArgumentValue("apply_measure",user_arguments)

    # This measure is not applicable if apply_measure is false
    if apply_measure == "FALSE"
      runner.registerAsNotApplicable("Not Applicable - User chose not to apply this measure via the apply_measure argument.")
      return true
    end    
    
    # Load some helper libraries
    require_relative 'resources/RemoveHVAC.Model'
    require_relative 'resources/OsLib_Schedules'
    
    # Extract an HVAC operation and ventilation schedule from
    # airloop serving the most zones in the current model
    air_loop_most_zones = nil
    max_zones = 0
    model.getAirLoopHVACs.each do |air_loop|
      num_zones = air_loop.thermalZones.size
      if num_zones > max_zones
        air_loop_most_zones = air_loop
        max_zones = num_zones
      end
    end
    building_HVAC_schedule = nil
    building_ventilation_schedule = nil
    if air_loop_most_zones
      building_HVAC_schedule = air_loop_most_zones.availabilitySchedule
      if air_loop_most_zones.airLoopHVACOutdoorAirSystem.is_initialized
        building_ventilation_schedule = air_loop_most_zones.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir.maximumFractionofOutdoorAirSchedule
        if building_ventilation_schedule.is_initialized
          building_ventilation_schedule = building_ventilation_schedule.get
        end
      end  
    end
    if building_HVAC_schedule.nil?
      building_HVAC_schedule = model.alwaysOnDiscreteSchedule
    end
    if building_ventilation_schedule.nil?
      building_ventilation_schedule = model.alwaysOnDiscreteSchedule
    end
   
    # Remove the existing HVAC equipment
    model.removeHVAC
    
    # Make the new schedules
    sch_ruleset_DOAS_setpoint = OsLib_Schedules.createComplexSchedule(model, {"name" => "AEDG DOAS Temperature Setpoint Schedule",
                                                                                "default_day" => ["All Days",[24,20.0]]})
    
    # Create a chilled water system to serve the DOAS
    chilled_water_plant = OpenStudio::Model::PlantLoop.new(model)
    chilled_water_plant.setName("Chilled Water Loop")
    chilled_water_plant.setMaximumLoopTemperature(98)
    chilled_water_plant.setMinimumLoopTemperature(1)
    loop_sizing = chilled_water_plant.sizingPlant
    loop_sizing.setLoopType("Cooling")
    loop_sizing.setDesignLoopExitTemperature(6.7)   
    loop_sizing.setLoopDesignTemperatureDifference(6.7)
    
    # Create a pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setRatedPumpHead(149453) #Pa
    pump.setMotorEfficiency(0.9)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
    
    # Create a chiller
    # Create clgCapFuncTempCurve
    clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
    clgCapFuncTempCurve.setCoefficient1Constant(1.05E+00)
    clgCapFuncTempCurve.setCoefficient2x(3.36E-02)
    clgCapFuncTempCurve.setCoefficient3xPOW2(2.15E-04)
    clgCapFuncTempCurve.setCoefficient4y(-5.18E-03)
    clgCapFuncTempCurve.setCoefficient5yPOW2(-4.42E-05)
    clgCapFuncTempCurve.setCoefficient6xTIMESY(-2.15E-04)
    clgCapFuncTempCurve.setMinimumValueofx(0)
    clgCapFuncTempCurve.setMaximumValueofx(20)
    clgCapFuncTempCurve.setMinimumValueofy(0)
    clgCapFuncTempCurve.setMaximumValueofy(50)
    
    # Create eirFuncTempCurve
    eirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
    eirFuncTempCurve.setCoefficient1Constant(5.83E-01)
    eirFuncTempCurve.setCoefficient2x(-4.04E-03)
    eirFuncTempCurve.setCoefficient3xPOW2(4.68E-04)
    eirFuncTempCurve.setCoefficient4y(-2.24E-04)
    eirFuncTempCurve.setCoefficient5yPOW2(4.81E-04)
    eirFuncTempCurve.setCoefficient6xTIMESY(-6.82E-04)
    eirFuncTempCurve.setMinimumValueofx(0)
    eirFuncTempCurve.setMaximumValueofx(20)
    eirFuncTempCurve.setMinimumValueofy(0)
    eirFuncTempCurve.setMaximumValueofy(50)
    
    # Create eirFuncPlrCurve
    eirFuncPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
    eirFuncPlrCurve.setCoefficient1Constant(4.19E-02)
    eirFuncPlrCurve.setCoefficient2x(6.25E-01)
    eirFuncPlrCurve.setCoefficient3xPOW2(3.23E-01)
    eirFuncPlrCurve.setMinimumValueofx(0)
    eirFuncPlrCurve.setMaximumValueofx(1.2)
    
    # Construct chiller
    chiller = OpenStudio::Model::ChillerElectricEIR.new(model,clgCapFuncTempCurve,eirFuncTempCurve,eirFuncPlrCurve)
    chiller.setReferenceCOP(2.93)
    chiller.setCondenserType("AirCooled")
    chiller.setChillerFlowMode("ConstantFlow")
    
    # Create a scheduled setpoint manager
    chilled_water_setpoint_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "AEDG CW-Loop-Temp-Schedule",
                                                                                     "default_day" => ["All Days",[24,6.7]]})
    setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model,chilled_water_setpoint_schedule)
    # Create a supply bypass pipe
    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a supply outlet pipe
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand bypass pipe
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand inlet pipe
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand outlet pipe
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    
    # Connect supply side components to plant loop
    chilled_water_plant.addSupplyBranchForComponent(chiller)
    chilled_water_plant.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(chilled_water_plant.supplyInletNode)
    pipe_supply_outlet.addToNode(chilled_water_plant.supplyOutletNode)
    setpoint_manager_scheduled.addToNode(chilled_water_plant.supplyOutletNode)
    
    # Connect demand side components to plant loop.
    # Water coils are added as they are added to airloops and ZoneHVAC.
    chilled_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(chilled_water_plant.demandInletNode)
    pipe_demand_outlet.addToNode(chilled_water_plant.demandOutletNode)

    
    
    # Create a hot water system to serve the DOAS
    hot_water_plant = OpenStudio::Model::PlantLoop.new(model)
    hot_water_plant.setName("Hot Water Loop")
    hot_water_plant.setMaximumLoopTemperature(100)
    hot_water_plant.setMinimumLoopTemperature(10)
    loop_sizing = hot_water_plant.sizingPlant
    loop_sizing.setLoopType("Heating")
    loop_sizing.setDesignLoopExitTemperature(82) 
    loop_sizing.setLoopDesignTemperatureDifference(11)
    
    # Create a pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setRatedPumpHead(119563) #Pa
    pump.setMotorEfficiency(0.9)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
    
    # Create a boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    boiler.setNominalThermalEfficiency(0.9)
    
    # Create a scheduled setpoint manager
    # Create a scheduled setpoint manager
    hot_water_setpoint_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "AEDG HW-Loop-Temp-Schedule",
                                                                               "default_day" => ["All Days",[24,67.0]]})
    setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model,hot_water_setpoint_schedule)
    
    # Create a supply bypass pipe
    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a supply outlet pipe
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand bypass pipe
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand inlet pipe
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand outlet pipe
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    
    # Connect supply side components to plant loop
    hot_water_plant.addSupplyBranchForComponent(boiler)
    hot_water_plant.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(hot_water_plant.supplyInletNode)
    pipe_supply_outlet.addToNode(hot_water_plant.supplyOutletNode)
    setpoint_manager_scheduled.addToNode(hot_water_plant.supplyOutletNode)
    
    # Connect demand side components to plant loop.
    # Water coils are added as they are added to airloops and ZoneHVAC.
    hot_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(hot_water_plant.demandInletNode)
    pipe_demand_outlet.addToNode(hot_water_plant.demandOutletNode)

    
    # Create a single DOAS system to serve all the zones
    doas_air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    doas_air_loop.setName("DOAS")
    
    # Modify system sizing properties
    sizing_system = doas_air_loop.sizingSystem
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(12.8)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(40)
    sizing_system.setTypeofLoadtoSizeOn("VentilationRequirement") #DOAS
    sizing_system.setAllOutdoorAirinCooling(true) #DOAS
    sizing_system.setAllOutdoorAirinHeating(true) #DOAS
    sizing_system.setMinimumSystemAirFlowRatio(0.3) #DCV
    
    # Set availability schedule
    doas_air_loop.setAvailabilitySchedule(building_HVAC_schedule)
    
    # Add each component to this array
    # to be attached to doas air loop later
    air_loop_comps = []
    
    # Create variable speed fan
    fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
    fan.setFanEfficiency(0.69)
    fan.setPressureRise(1125) #Pa
    fan.autosizeMaximumFlowRate()
    fan.setFanPowerMinimumFlowFraction(0.6)
    fan.setMotorEfficiency(0.9)
    fan.setMotorInAirstreamFraction(1.0)
    air_loop_comps << fan 
    
    # Create hot water heating coil
    heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
    air_loop_comps << heating_coil
    
    # Create chilled water cooling coil
    cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
    air_loop_comps << cooling_coil
    
    # Create controller outdoor air
    controller_OA = OpenStudio::Model::ControllerOutdoorAir.new(model)
    controller_OA.autosizeMinimumOutdoorAirFlowRate()
    controller_OA.autosizeMaximumOutdoorAirFlowRate()
    
    # Create ventilation schedules and assign to OA controller
    controller_OA.setMinimumFractionofOutdoorAirSchedule(model.alwaysOnDiscreteSchedule)
    controller_OA.setMaximumFractionofOutdoorAirSchedule(model.alwaysOnDiscreteSchedule)  
    controller_OA.setHeatRecoveryBypassControlType("BypassWhenOAFlowGreaterThanMinimum")
    
    # Create outdoor air system
    system_OA = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, controller_OA)
    air_loop_comps << system_OA
    
    # Create ERV
    heat_exchanger = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
    heat_exchanger.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    sensible_eff = 0.75
    latent_eff = 0.69
    heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(sensible_eff)
    heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(sensible_eff)
    heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(sensible_eff)
    heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(sensible_eff)
    heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(latent_eff)
    heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(latent_eff)
    heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(latent_eff)
    heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(latent_eff)
    heat_exchanger.setFrostControlType("ExhaustOnly")
    heat_exchanger.setThresholdTemperature(-12.2)
    heat_exchanger.setInitialDefrostTimeFraction(0.1670)
    heat_exchanger.setRateofDefrostTimeFractionIncrease(0.0240)
    heat_exchanger.setEconomizerLockout(false)
    heat_exchanger.addToNode(system_OA.outboardOANode.get)

    # Create scheduled setpoint manager for airloop
    primary_sat_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "AEDG Cold Deck Temperature Setpoint Schedule",
                                                                        "default_day" => ["All Days",[24,12.8]]})
    setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,primary_sat_schedule)
    
    
    # Connect components to airloop
    # find the supply inlet node of the airloop
    airloop_supply_inlet = doas_air_loop.supplyInletNode
    air_loop_comps.each do |comp|
      comp.addToNode(airloop_supply_inlet)
      if comp.to_CoilHeatingWater.is_initialized
        hot_water_plant.addDemandBranchForComponent(comp)
        comp.controllerWaterCoil.get.setMinimumActuatedFlow(0)
      elsif comp.to_CoilCoolingWater.is_initialized
        chilled_water_plant.addDemandBranchForComponent(comp)
        comp.controllerWaterCoil.get.setMinimumActuatedFlow(0)
      end
    end
    setpoint_manager.addToNode(doas_air_loop.supplyOutletNode)
   
    # Make an air terminal for the doas for each zone
    model.getThermalZones.each do |zone| # TODO more intelligent way to skip attics & plenums
      next if zone.name.get.include?("Attic")
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
      doas_air_loop.addBranchForZone(zone, air_terminal.to_StraightComponent)
    end
    
       
    # Create a condenser loop to serve the GSHPs
    gshp_loop = OpenStudio::Model::PlantLoop.new(model)
    gshp_loop.setName("AEDG Heat Pump Loop")
    gshp_loop.setMaximumLoopTemperature(80)
    gshp_loop.setMinimumLoopTemperature(1)
    loop_sizing = gshp_loop.sizingPlant
    loop_sizing.setLoopType("Condenser")
    loop_sizing.setDesignLoopExitTemperature(21)
    loop_sizing.setLoopDesignTemperatureDifference(5)  
    
    # Create a pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setRatedPumpHead(134508) #Pa
    pump.setMotorEfficiency(0.9)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
    
    # Create a supply bypass pipe
    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a supply outlet pipe
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand bypass pipe
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand inlet pipe
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # Create a demand outlet pipe
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    
    # Create setpoint managers
    hp_loop_cooling_sch = OsLib_Schedules.createComplexSchedule(model, {"name" => "AEDG HP-Loop-Clg-Temp-Schedule",
                                                                                     "default_day" => ["All Days",[24,21]]})
    hp_loop_heating_sch = OsLib_Schedules.createComplexSchedule(model, {"name" => "AEDG HP-Loop-Htg-Temp-Schedule",
                                                                    "default_day" => ["All Days",[24,5]]})
    setpoint_manager_scheduled_loop = OpenStudio::Model::SetpointManagerScheduled.new(model,hp_loop_cooling_sch)
    setpoint_manager_scheduled_cooling = OpenStudio::Model::SetpointManagerScheduled.new(model,hp_loop_cooling_sch)
    setpoint_manager_scheduled_heating = OpenStudio::Model::SetpointManagerScheduled.new(model,hp_loop_heating_sch)
    
    # Connect supply components to plant loop
    gshp_loop.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(gshp_loop.supplyInletNode)
    pipe_supply_outlet.addToNode(gshp_loop.supplyOutletNode)
    setpoint_manager_scheduled_loop.addToNode(gshp_loop.supplyOutletNode)
    
    # Connect demand components to plant loop
    gshp_loop.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(gshp_loop.demandInletNode)
    pipe_demand_outlet.addToNode(gshp_loop.demandOutletNode)
    # add additional components according to specific system type
    # add district cooling and heating to supply side
    district_cooling = OpenStudio::Model::DistrictCooling.new(model)
    district_cooling.setNominalCapacity(1000000000000) # large number; no autosizing
    gshp_loop.addSupplyBranchForComponent(district_cooling)
    setpoint_manager_scheduled_cooling.addToNode(district_cooling.outletModelObject.get.to_Node.get)
    district_heating = OpenStudio::Model::DistrictHeating.new(model)
    district_heating.setNominalCapacity(1000000000000) # large number; no autosizing
    district_heating.addToNode(district_cooling.outletModelObject.get.to_Node.get)
    setpoint_manager_scheduled_heating.addToNode(district_heating.outletModelObject.get.to_Node.get)

    # Create the WSHP for each zone
    model.getThermalZones.each do |zone|
      next if zone.name.get.include?("Attic") # TODO more intelligent way to skip attics & plenums
      # Create fan
      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan.setFanEfficiency(0.5)
      fan.setPressureRise(75) #Pa
      fan.autosizeMaximumFlowRate()
      fan.setMotorEfficiency(0.9)
      fan.setMotorInAirstreamFraction(1.0)
      
      # Create cooling coil and connect to heat pump loop
      cooling_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model)
      cooling_coil.setRatedCoolingCoefficientofPerformance(6.45)
      cooling_coil.setTotalCoolingCapacityCoefficient1(-9.149069561)
      cooling_coil.setTotalCoolingCapacityCoefficient2(10.87814026)
      cooling_coil.setTotalCoolingCapacityCoefficient3(-1.718780157)
      cooling_coil.setTotalCoolingCapacityCoefficient4(0.746414818)
      cooling_coil.setTotalCoolingCapacityCoefficient5(0.0)
      cooling_coil.setSensibleCoolingCapacityCoefficient1(-5.462690012)
      cooling_coil.setSensibleCoolingCapacityCoefficient2(17.95968138)
      cooling_coil.setSensibleCoolingCapacityCoefficient3(-11.87818402)
      cooling_coil.setSensibleCoolingCapacityCoefficient4(-0.980163419)
      cooling_coil.setSensibleCoolingCapacityCoefficient5(0.767285761)
      cooling_coil.setSensibleCoolingCapacityCoefficient6(0.0)
      cooling_coil.setCoolingPowerConsumptionCoefficient1(-3.205409884)
      cooling_coil.setCoolingPowerConsumptionCoefficient2(-0.976409399)
      cooling_coil.setCoolingPowerConsumptionCoefficient3(3.97892546)
      cooling_coil.setCoolingPowerConsumptionCoefficient4(0.938181818)
      cooling_coil.setCoolingPowerConsumptionCoefficient5(0.0)
      gshp_loop.addDemandBranchForComponent(cooling_coil)
      
      # Create heating coil and connect to heat pump loop
      heating_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)
      heating_coil.setRatedHeatingCoefficientofPerformance(4.0)
      heating_coil.setHeatingCapacityCoefficient1(-1.361311959)
      heating_coil.setHeatingCapacityCoefficient2(-2.471798046)
      heating_coil.setHeatingCapacityCoefficient3(4.173164514)
      heating_coil.setHeatingCapacityCoefficient4(0.640757401)
      heating_coil.setHeatingCapacityCoefficient5(0.0)
      heating_coil.setHeatingPowerConsumptionCoefficient1(-2.176941116)
      heating_coil.setHeatingPowerConsumptionCoefficient2(0.832114286)
      heating_coil.setHeatingPowerConsumptionCoefficient3(1.570743399)
      heating_coil.setHeatingPowerConsumptionCoefficient4(0.690793651)
      heating_coil.setHeatingPowerConsumptionCoefficient5(0.0)
      gshp_loop.addDemandBranchForComponent(heating_coil)
      
      # Create supplemental heating coil
      supplemental_heating_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      
      # Construct heat pump
      heat_pump = OpenStudio::Model::ZoneHVACWaterToAirHeatPump.new(model,
                                                                    model.alwaysOnDiscreteSchedule,
                                                                    fan,
                                                                    heating_coil,
                                                                    cooling_coil,
                                                                    supplemental_heating_coil)
      heat_pump.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(OpenStudio::OptionalDouble.new(0))
      heat_pump.setOutdoorAirFlowRateDuringCoolingOperation(OpenStudio::OptionalDouble.new(0))
      heat_pump.setOutdoorAirFlowRateDuringHeatingOperation(OpenStudio::OptionalDouble.new(0))
      heat_pump.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(OpenStudio::OptionalDouble.new(0))
      
      # Add heat pump to thermal zone
      heat_pump.addToThermalZone(zone)
    end
    
   
    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
GroundSourceHeatPumpWithDOAS.new.registerWithApplication