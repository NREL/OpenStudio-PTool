# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide
# Reference Document: "ISSUES ARISING FROM THE USE OF CHILLED BEAMS IN ENERGY MODELS"
# download here: http://www.researchgate.net/profile/Fred_Betz/publication/256375218_ISSUES_ARISING_FROM_THE_USE_OF_CHILLED_BEAMS_IN_ENERGY_MODELS/links/00b7d52264b1def7b8000000

# start the measure
class AddChilledBeam < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Add Chilled Beam"
  end

  # human readable description
  def description
    return "A chilled beam is a type of HVAC system designed to cool using convective forces. Chilled water (at a relatively high temperature of 60F – 65 F) is passed through a beam (a heat exchanger) either suspended a short distance from a ceiling or integrated into a standard suspended ceiling system. As the beam chills the air around it, the air becomes denser and falls to the floor. It is replaced by warmer air moving up from below, causing a constant flow of convection and this cooling the room. Chilled beams systems can be categorized as either ‘Active’ or ‘Passive’. Passive beams rely solely on radiant exchange and convection, offering quiet operation and a peak cooling capacity of 20 – 25 Btuh/linear foot of beam. Active beams force preconditioned air through engineered nozzles integrated within the beam to increase cooling capacity to 40 – 50 Btuh/linear foot of beam. When integrated with properly configured Dedicated Outdoor Air Systems (DOAS), adequately sized chilled beam systems can deliver cooling comfort at a very low operating cost. Chilled beam cooling systems are “sensible only” cooling systems, and unless used in arid climates, require additional dehumidification equipment (operating in parallel and/or series) to manage ventilation and space latent loads. Users should consider adding additional zone equipment (such as baseboard heaters) to handle zone heating loads."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure adds active or passive chilled beam units to selected conditioned thermal zones. In addition the user can select an existing air loop to serve active beams, or create a new Dual Wheel DOAS. Users can also select an existing chilled water loop to provide chilled water to beams, or create a new high temperature chiller water loop. Users are highly encouraged to review and modify the control strategies that this measure creates, such that it reflects their modeling scenario of interest."
  end

  # define the arguments that the user will input
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
  
    #Argument 1 Type of Chilled Beam System, required, choice, default Active
    beam_options = ["Active", "Passive"]
    cooled_beam_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("cooled_beam_type", beam_options,true)
    cooled_beam_type.setDisplayName('Select the Type of Chilled Beam to be added and indicate the Thermal Zones that Chilled Beams will be added to. NOTE: Users should confirm subsequent chilled beam model parameters. Defaulted coefficient values may not be representative of actual chilled beam performance')
    cooled_beam_type.setDefaultValue("Active")
    args << cooled_beam_type
  
    #Argument 3 Chilled Water Loop selection or creation 
    existing_plant_loops = model.getPlantLoops
    existing_chilled_loops = existing_plant_loops.select{ |pl| pl.sizingPlant.loopType() == "Cooling"}
    existing_plant_names = existing_chilled_loops.select{ |pl| not pl.name.empty?}.collect{ |pl| pl.name.get }
    existing_plant_names << "Create New"
    existing_plant_loop_name = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("existing_plant_loop_name", existing_plant_names, true)
    existing_plant_loop_name.setDisplayName('Chilled Water loop serving chilled beams. If "Create New" is selected a loop containing an air cooled chiller (COP=3.5) generating chilled water at 57 Deg F will be created. A constant speed pump (with user defined pressure rise) will be created.')
    existing_plant_loop_name.setDefaultValue ("Create New")
    args << existing_plant_loop_name
  
    #argument 4, new loop rated pump head type double, required, double, default 60 feet
    new_loop_rated_pump_head = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('new_loop_pump_head', true)
    new_loop_rated_pump_head.setDisplayName('The pump head (in feet of water) that will be assigned to the primary chilled water loop circulation pump. This argument will only be used if a new chilled water plant loop is created.')
    new_loop_rated_pump_head.setDefaultValue (60)
    args<< new_loop_rated_pump_head
    #must check interpretation of the 60 default value for pump head.  meant to be 60 feet.
  
    #argument 5. air_loop_name, required, double, default Create New
    air_loops_list = model.getAirLoopHVACs.collect { |l| l.name.get }
    air_loops_list << "Create New"
    air_loop_name = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('air_loop_name', air_loops_list, true)
    air_loop_name.setDisplayName('Air loop to serve selected zones by chilled beam units. This should be an air loop configured as a DOAS. If "Create New" is selected, an air loop containing a Dual Wheel DOAS system with a chilled water coil served by the user selected chiller plant loop will be created. The DOAS will be configured to deliver a constant temperature of 65 Deg F to connected zones.')
    air_loop_name.setDefaultValue ("Create New")
    args << air_loop_name
  
    #argument 5.5 (mislabeled in spec) new airloop fan pressure rise, required, double, default none
    new_airloop_fan_pressure_rise = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('new_airloop_fan_pressure_rise',true)
    new_airloop_fan_pressure_rise.setDisplayName('The pressure rise (inches of water) that will be assigned to the constant speed fans of a new air loop. This pressure rise, which includes the pressure across an energy wheel, will be split evenly between the new supply and exhaust fans.')
    new_airloop_fan_pressure_rise.setDefaultValue("5.00")
    args << new_airloop_fan_pressure_rise
    
    #argument 6  supply air vol flow rate, double, default to -1
    supply_air_vol_flow_rate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('supply_air_vol_flow_rate',true)
    supply_air_vol_flow_rate.setDisplayName('The combined air flow rate (cfm) of the supply air serving all chilled beams in a zone. Enter -1 to autosize (based on the zone ventilation requirement). If a value is entered, and multiple thermal zones are selected, this value will be hard coded to all selected zones.')
    supply_air_vol_flow_rate.setDefaultValue("-1")
    args << supply_air_vol_flow_rate
  
    #argument 7 max tot chw vol flow rate, required, double, default -1
    max_tot_chw_vol_flow_rate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('max_tot_chw_vol_flow_rate',true)
    max_tot_chw_vol_flow_rate.setDisplayName('Combined maximum chilled water flow rate (gpm) of all chilled beam units serving a zone. Enter -1 to autosize based on the zone design load. If a value is entered, and multiple thermal zones are selected, this value will be hard coded to all selected zones.')
    max_tot_chw_vol_flow_rate.setDefaultValue("-1")
    args << max_tot_chw_vol_flow_rate
  
    #arg 8 number of beams, required, double, default -1
    number_of_beams = OpenStudio::Ruleset::OSArgument::makeIntegerArgument('number_of_beams',true)
    number_of_beams.setDisplayName('The number of individual chilled beam units serving each zone. Enter -1 to autosize based on a value of 1.11 GPM per chilled beam unit.')
    number_of_beams.setDefaultValue("-1")
    args << number_of_beams
  
    #arg9 beam_length, required, double, defailt -1
    beam_length = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('beam_length',true)
    beam_length.setDisplayName('The length (ft) of an individual beam. Enter -1 to autosize based upon the # of beam units and the zone design sensible cooling load.')
    beam_length.setDefaultValue("-1")
    args << beam_length
  
    #arg10   design_inlet_water_temperature, requried, double, default 59
    design_inlet_water_temperature = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('design_inlet_water_temperature',true)
    design_inlet_water_temperature.setDisplayName('The design inlet water temperature (Deg F) of a beam unit.')
    design_inlet_water_temperature.setDefaultValue("59")
    args << design_inlet_water_temperature
  
    #arg11 design_outlet_water_temperature, required, double, default 62.6
    design_outlet_water_temperature = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('design_outlet_water_temperature',true)
    design_outlet_water_temperature.setDisplayName('The design outlet water temperature )Deg F) of the beam units.')
    design_outlet_water_temperature.setDefaultValue("62.6")
    args << design_outlet_water_temperature
  
    #arg12   coil_surface_area_per_coil_length, required, double, default 17.78
    coil_surface_area_per_coil_length = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coil_surface_area_per_coil_length',true)
    coil_surface_area_per_coil_length.setDisplayName('Surface area on the air side of the beam per unit beam length (ft^2/ft). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coil_surface_area_per_coil_length.setDefaultValue("17.78")
    args << coil_surface_area_per_coil_length
  
    #arg13  coefficient_alpha required, double, default 15.3
    coefficient_alpha = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coefficient_alpha',true)
    coefficient_alpha.setDisplayName('Model parameter alpha (unitless). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coefficient_alpha.setDefaultValue("15.3")
    args << coefficient_alpha
  
    #arg14  coefficient_n1, required, double, default 0
    coefficient_n1 = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coefficient_n1',true)
    coefficient_n1.setDisplayName('Model parameter n1 (unitless). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coefficient_n1.setDefaultValue("0")
    args << coefficient_n1
  
    #arg15 coefficient_n2,required, double, default .84)
    coefficient_n2 = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coefficient_n2',true)
    coefficient_n2.setDisplayName('Model parameter n2 (unitless). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coefficient_n2.setDefaultValue("0.84")
    args << coefficient_n2

    #arg16 coefficient_n3,required, double, default .84)
    coefficient_n3 = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coefficient_n3',true)
    coefficient_n3.setDisplayName('Model parameter n3 (unitless). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coefficient_n3.setDefaultValue(".12")
    args << coefficient_n3
  
    #arg17 coefficient_a0,required, double, default .5610)
    coefficient_a0 = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coefficient_a0',true)
    coefficient_a0.setDisplayName('Model parameter a0 (unitless). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coefficient_a0.setDefaultValue(".5610")
    args << coefficient_a0
  
    #arg18 coefficient_k1,required, double, default .00571)
    coefficient_k1 = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coefficient_k1',true)
    coefficient_k1.setDisplayName('Model parameter k1 (unitless). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coefficient_k1.setDefaultValue(".005710")
    args << coefficient_k1
  
    #arg19 coefficient_n,required, double, default .40)
    coefficient_n = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coefficient_n',true)
    coefficient_n.setDisplayName('Model parameter n (unitless). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coefficient_n.setDefaultValue(".400")
    args << coefficient_n
  
    #arg20 coefficient_kin,required, double, default 2.0)
    coefficient_kin = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('coefficient_kin',true)
    coefficient_kin.setDisplayName('Model parameter kin (unitless). This parameter is a unique value representing specific chilled beam products. See E+ Engineering Reference for equation details')
    coefficient_kin.setDefaultValue("2.0")
    args << coefficient_kin
  
    #argument 21 leaving_pipe_inside_dia, required, choice, default "1/2 type K"
    pipe_inside_dia_options = ["1/2 Type K", "1/2 Type L", "3/4 Type K", "3/4 Type L"]
    leaving_pipe_inside_dia = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("leaving_pipe_inside_dia", pipe_inside_dia_options,true)
    leaving_pipe_inside_dia.setDisplayName('Diameter (inches) of the chilled beam unit water inlet and outlet pipe connections.')
    leaving_pipe_inside_dia.setDefaultValue("1/2 Type K")
    args << leaving_pipe_inside_dia
    #note: [1/2 TypeK = .527  ]     [1/2 Type L = .545]    [3/4 type k = .745] [3/4 type l=.785]
  
    return args
  end

  
   # Parse user arguments into variables
  def parse_user_arguments(runner, user_arguments)
    apply_measure = runner.getStringArgumentValue("apply_measure",user_arguments)
    # This measure is not applicable if apply_measure is false
    if apply_measure == "FALSE"
      runner.registerAsNotApplicable("Not Applicable - User chose not to apply this measure via the apply_measure argument.")
      return true
    end
    
    @cooled_beam_type = runner.getStringArgumentValue("cooled_beam_type", user_arguments)
    @existing_plant_loop_name = runner.getStringArgumentValue("existing_plant_loop_name", user_arguments)
    @new_loop_pump_head = runner.getDoubleArgumentValue("new_loop_pump_head", user_arguments)
    @air_loop_name = runner.getStringArgumentValue("air_loop_name", user_arguments)
    @new_airloop_fan_pressure_rise = runner.getDoubleArgumentValue("new_airloop_fan_pressure_rise", user_arguments)
    @supply_air_vol_flow_rate = runner.getDoubleArgumentValue("supply_air_vol_flow_rate", user_arguments)
    @max_tot_chw_vol_flow_rate = runner.getDoubleArgumentValue("max_tot_chw_vol_flow_rate", user_arguments)
    @number_of_beams = runner.getIntegerArgumentValue("number_of_beams", user_arguments)
    @beam_length = runner.getDoubleArgumentValue("beam_length", user_arguments)
    @design_inlet_water_temperature = runner.getDoubleArgumentValue("design_inlet_water_temperature", user_arguments)
    @design_outlet_water_temperature = runner.getDoubleArgumentValue("design_outlet_water_temperature", user_arguments)
    @coil_surface_area_per_coil_length = runner.getDoubleArgumentValue("coil_surface_area_per_coil_length", user_arguments)
    @coefficient_alpha = runner.getDoubleArgumentValue("coefficient_alpha", user_arguments)
    @coefficient_n1 = runner.getDoubleArgumentValue("coefficient_n1", user_arguments)
    @coefficient_n2 = runner.getDoubleArgumentValue("coefficient_n2", user_arguments)
    @coefficient_n3 = runner.getDoubleArgumentValue("coefficient_n3", user_arguments)
    @coefficient_a0 = runner.getDoubleArgumentValue("coefficient_a0", user_arguments)
    @coefficient_k1 = runner.getDoubleArgumentValue("coefficient_k1", user_arguments)
    @coefficient_n = runner.getDoubleArgumentValue("coefficient_n", user_arguments)
    @coefficient_kin = runner.getDoubleArgumentValue("coefficient_kin", user_arguments)
    @leaving_pipe_inside_dia = runner.getStringArgumentValue("leaving_pipe_inside_dia", user_arguments)
  end

  def validate_arguments
    # Errors
    if @cooled_beam_type == "Passive" and @coefficient_kin != 0 then @runner.registerError("Value of coefficient of induction K1 of #{@coefficient_kin} not appropriate for passive chilled beam systems.  Use value of 0.") end
    if @cooled_beam_type == "Passive" and @coefficient_kin == 0 then @runner.registerError("Value of coefficient of induction K1 of #{@coefficient_kin} not appropriate for active chilled beam systems.") end
    #if @new_loop_pump_head <= 0 then @runner.registerError("Value of rated pump head of #{@new_loop_pump_head} ft of water must be greater than 0.") end
    if @new_airloop_fan_pressure_rise <= 0 then @runner.registerError("Value of airloop fan pressure rise of #{@new_airloop_fan_pressure_rise} inches must be greater than 0.") end
    if @supply_air_vol_flow_rate <= 0 and @supply_air_vol_flow_rate != -1 then @runner.registerError("Value of supply air volume flow rate of #{@supply_air_vol_flow_rate} cfm must be greater than 0.") end
    if @max_tot_chw_vol_flow_rate <= 0 and @max_tot_chw_vol_flow_rate != -1 then @runner.registerError("Value of max chilled water flow rate per unit of #{@max_tot_chw_vol_flow_rate} gpm must be greater than 0.") end
    if @number_of_beams <= 0 and @number_of_beams != -1 then @runner.registerError("Value for number of beams per zone of #{@number_of_beams} must be greater than 0.") end
    if @beam_length <= 0 and @beam_length != -1 then @runner.registerError("Value for beam length of #{@beam_length} ft must be greater than 0.") end
    if @design_inlet_water_temperature <= 52 then @runner.registerError("Value for design inlet water temperature of #{@design_inlet_water_temperature} deg F is too low to prevent condensation.  Value should be greater than 52 deg F.") end
    design_temp_diff = @design_outlet_water_temperature - @design_inlet_water_temperature
    if design_temp_diff < 3.0 then @runner.registerError("Value for water temperature difference of #{design_temp_diff} deg F is less than the recommended value of 3.0 deg F. Increase design outlet water temperature or decrease design inlet water temperature.") end
    if design_temp_diff > 8.0 then @runner.registerError("Value for water temperature difference of #{design_temp_diff} deg F is greater than the recommended value of 8.0 deg F. Decrease design outlet water temperature or increase design inlet water temperature.") end
    if @coil_surface_area_per_coil_length <= 0 then @runner.registerError("Value for coil surface area per length of #{@coil_surface_area_per_coil_length} ft must be greater than 0.") end
    if @coefficient_alpha <= 0 then @runner.registerError("Value for coefficient alpha of #{@coefficient_alpha} must be greater than 0.") end
    if @coefficient_n1 < 0 then @runner.registerError("Value for coefficient n1 of #{@coefficient_n1} must be greater than or equal to 0.") end
    if @coefficient_n2 < 0 then @runner.registerError("Value for coefficient n2 of #{@coefficient_n2} must be greater than or equal to 0.") end
    if @coefficient_n3 <= 0 then @runner.registerError("Value for coefficient n3 of #{@coefficient_n3} must be greater than 0.") end
    if @coefficient_a0 <= 0 then @runner.registerError("Value for coefficient a0 of #{@coefficient_a0} must be greater than 0.") end
    if @coefficient_k1 <= 0 then @runner.registerError("Value for coefficient K1 of #{@coefficient_k1} must be greater than 0.") end
    if @coefficient_n <= 0 then @runner.registerError("Value for coefficient n of #{@coefficient_n} must be greater than 0.") end
    if @coefficient_kin <= 0 then @runner.registerError("Value for coefficient Kin of #{@coefficient_kin} must be greater than 0.") end

    # Warnings
    if @new_airloop_fan_pressure_rise > 6 and @air_loop_name == "Create New" then @runner.registerWarning("Value for total airloop fan pressure rise for new supply and return fans of #{@new_airloop_fan_pressure_rise} inches appears high. Please check.") end
    if @new_airloop_fan_pressure_rise < 1.5 and @air_loop_name == "Create New" then @runner.registerWarning("Value for total airloop fan pressure rise for new supply and return fans of #{@new_airloop_fan_pressure_rise} inches appears low. Consider the pressure loss across the air loop energy recovery wheel. Please check.") end
    if @new_loop_pump_head > 60 then @runner.registerWarning("Value for new loop pump head of #{@new_loop_pump_head} ft seems high. Please check.") end
    if @max_tot_chw_vol_flow_rate < 0.16 and @max_tot_chw_vol_flow_rate != -1 then @runner.registerWarning("Value for maximum total chilled water flow rate of #{@max_tot_chw_vol_flow_rate} gpm appears low. Please check.") end
    if @beam_length > 8 then @runner.registerWarning("Value for beam length of #{@beam_length} ft appears high. Please check.") end
    if @beam_length < 2 and @beam_length != -1 then @runner.registerWarning("Value for beam length of #{@beam_length} ft appears low. Please check.") end
    if @design_inlet_water_temperature < 57 then @runner.registerWarning("Value design inlet water temperature of #{@design_inlet_water_temperature} def F is too low to prevent condensation.  Value should be between 57 and 64 deg F.") end
    if design_temp_diff < 3.2 then @runner.registerWarning("Value for water temperature difference of #{design_temp_diff} deg F is less than the recommended value of 3.2 deg F. Increase design outlet water temperature or decrease design inlet water temperature.") end
    if design_temp_diff > 7.6 then @runner.registerWarning("Value for water temperature difference of #{design_temp_diff} deg F is greater than the recommended value of 8.0 deg F. Decrease design outlet water temperature or increase design inlet water temperature.") end
    
    # Not Applicable
    if @model.getThermalZones.empty? then @runner.registerAsNotApplicable("Model has no thermal zones. Measure cannot be applied.") end

  end

    # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Load some helper libraries
    require_relative 'resources/RemoveHVAC.Model'    
    
    @runner = runner
    @model = model
  
    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
  
    parse_user_arguments(runner, user_arguments)
    #validate_arguments
    return false if @runner.result.errors.any?
    return true if @runner.result.value == OpenStudio::Ruleset::OSResultValue.new(-1) # Return true if the measure is Not Applicable

    # report initial condition of model
    num_cooled_beams = @model.numObjectsOfType(OpenStudio::Model::AirTerminalSingleDuctConstantVolumeCooledBeam.iddObjectType)
    air_loops = @model.getAirLoopHVACs
    plant_loops = @model.getPlantLoops
    runner.registerInitialCondition("Measure started with #{num_cooled_beams} Chilled Beam objects, #{air_loops.length} Air Loop objects and #{plant_loops.length} Plant Loop objects.")
  
    # Remove the existing HVAC equipment
    model.removeHVAC  
  
    # Find the plant loop that the user has chosen or create a new plant loop if the user has specified "Create New"
    if @existing_plant_loop_name == "Create New"
      @plant_loop = create_new_plant_loop
      @runner.registerInfo("Created a new chilled water plant loop named #{@plant_loop.name.get}.")
    else
      @plant_loop = @model.getPlantLoops.find { |l| !l.name.empty? and l.name.get == @existing_plant_loop_name}
      if !@plant_loop
        @runner.registerError("Plant Loop named #{@existing_plant_loop_name} was selected as the plant loop for added chilled beams but could not be found in the model")
        return false
      end
    end
  
    # Find the air loop that the user has chosen or create a new air loop if the user has specified "Create New"
    if @air_loop_name == "Create New"
      @air_loop, dehumidication_coil = create_new_air_loop
      @plant_loop.addDemandBranchForComponent(dehumidication_coil)
      @runner.registerInfo("Created a new air loop named #{@air_loop.name.get}")
    else
    @air_loop = @model.getAirLoopHVACs.find { |l| !l.name.empty? and l.name.get == @air_loop_name }
    if !@air_loop
      @runner.registerError("Air Loop HVAC named #{@air_loop_name} was selected as the air loop for added chilled beams but could not be found in the model")
      return false
    end
    # Get all demand components who's type name starts with AirTerminal and check for non-cooled beam terminals
    airTerminals = @air_loop.demandComponents.select { |c| /^OS_AirTerminal/ =~ c.iddObjectType.valueName  }
    if airTerminals.select { |c| c.iddObjectType != OpenStudio::Model::AirTerminalSingleDuctConstantVolumeCooledBeam.iddObjectType }.any?
      @runner.registerWarning("Selected air loop is currently serving non chilled beam equipment. The supply outlet conditions of this loop may not be appropriate for connecting chilled beam terminals to.")
    end
    # Find all the supply components and check for invalid fans
    constantFans = @air_loop.supplyComponents(OpenStudio::Model::FanConstantVolume.iddObjectType)
    variableFans = @air_loop.supplyComponents(OpenStudio::Model::FanVariableVolume.iddObjectType)

    # If there are no constant volume fans and there are no variable volume fans that are forced to constant volume the emit a warning
    if constantFans.empty? and variableFans.select { |f| f.to_FanVariableVolume.get.fanPowerMinimumFlowFraction == 1.0 }.empty?
      @runner.registerWarning("Selected air loop does not contain a fan configured to operate at constant volume conditions. Chilled Beam terminal units require constant volume airflow to operate properly. The measure will not be allowed to complete.")
    end
    end
    
    # For each thermal zone that the user selected, add a new air terminal to the air loop for that zone. Add
    # the cooling coil for that terminal to the plant loop selected by the user.
    # Also add an electric baseboard heater to meet heating load.
    model.getThermalZones.each do |zone|
      chilled_beam, cooling_coil = create_new_chilled_beam_terminal
      @air_loop.addBranchForZone(zone, chilled_beam)
      @plant_loop.addDemandBranchForComponent(cooling_coil)
      zone.sizingZone.setZoneCoolingDesignSupplyAirTemperature(OpenStudio::convert(60, "F", "C").get)
      zone.sizingZone.setZoneCoolingDesignSupplyAirHumidityRatio(0.004)
      @runner.registerInfo("Created a new AirTerminalSingleDuctConstantVolumeCooledBeam object and added it to air loop #{@air_loop.name.get} for zone #{zone.name.get}. The terminal's coil was added to plant loop #{@plant_loop.name.get}.")
      electric_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(@model)
      electric_baseboard.addToThermalZone(zone)
    end
    
    # report final condition of model
    num_cooled_beams = @model.numObjectsOfType(OpenStudio::Model::AirTerminalSingleDuctConstantVolumeCooledBeam.iddObjectType)
    air_loops = @model.getAirLoopHVACs
    plant_loops = @model.getPlantLoops
    runner.registerFinalCondition("Measure finished with #{num_cooled_beams} Chilled Beam objects, #{air_loops.length} Air Loop objects and #{plant_loops.length} Plant Loop objects.")

    return true
  end
  
  # Create a new AirTerminalSingleDuctConstantVolumeCooledBeam object using the alwaysOnDiscrete schedule
  # and with a new CoilCoolingCooledBeam.  The parameters of the new beam are set to the values entered by the user
  # in the measure arguments.
  # This method returns both the created air terminal and the cooled beam so that they can easily be added to the
  # appropriate loops by the caller
  def create_new_chilled_beam_terminal
    pipe_inside_diameters = { "1/2 Type K" => 0.527, "1/2 Type L" => 0.545, "3/4 Type K" => 0.745, "3/4 Type L" => 0.785 }
    
    cooling_coil = OpenStudio::Model::CoilCoolingCooledBeam.new(@model)
    cooling_coil.setCoilSurfaceAreaperCoilLength(OpenStudio::convert(@coil_surface_area_per_coil_length, "ft^2/ft", "m^2/m").get)
    cooling_coil.setModelParametera(@coefficient_alpha)
    cooling_coil.setModelParametern1(@coefficient_n1)
    cooling_coil.setModelParametern2(@coefficient_n2)
    cooling_coil.setModelParametern3(@coefficient_n3)
    cooling_coil.setModelParametera0(@coefficient_a0)
    cooling_coil.setModelParameterK1(@coefficient_k1)
    cooling_coil.setModelParametern(@coefficient_n)
    cooling_coil.setLeavingPipeInsideDiameter(OpenStudio::convert(pipe_inside_diameters[@leaving_pipe_inside_diameter].to_f, "in", "m").get)
    
    air_terminal = OpenStudio::Model::AirTerminalSingleDuctConstantVolumeCooledBeam.new(@model, @model.alwaysOnDiscreteSchedule(), cooling_coil)
    air_terminal.setCooledBeamType(@cooled_beam_type)
    if @supply_air_vol_flow_rate == -1
    air_terminal.autosizeSupplyAirVolumetricFlowRate
    else
    air_terminal.setSupplyAirVolumetricFlowRate(OpenStudio::convert(@supply_air_vol_flow_rate, "cfm", "m^3/s").get)
    end
    if @max_tot_chw_vol_flow_rate == -1
    air_terminal.autosizeMaximumTotalChilledWaterVolumetricFlowRate
    else
    air_terminal.setMaximumTotalChilledWaterVolumetricFlowRate(OpenStudio::convert(@max_tot_chw_vol_flow_rate, "gal/min", "m^3/s").get)
    end
    if @number_of_beams == -1
    air_terminal.autosizeNumberofBeams
    else
    air_terminal.setNumberofBeams(@number_of_beams)
    end
    if @beam_length == -1
    air_terminal.autosizeBeamLength
    else
    air_terminal.setBeamLength(OpenStudio::convert(@beam_length, "ft", "m").get)
    end
    air_terminal.setDesignInletWaterTemperature(OpenStudio::convert(@design_inlet_water_temperature, "F", "C").get)
    air_terminal.setDesignOutletWaterTemperature(OpenStudio::convert(@design_outlet_water_temperature, "F", "C").get)
    air_terminal.setCoefficientofInductionKin(@coefficient_kin)
    
    return air_terminal, cooling_coil
  end
  
# Create a new Air Loop for use with the added chilled beams.  
#  
#                            100 % OA Non recirculating DOAS Section View
#  
#               _________________________________________________________________________
#              |    E     |      |                          |   D   |                    |
#              |    x     |      |                          |   e   |                    |
#              |    h F   |      |                          |   h   |                    |
#   Exhaust    |(a) a a   | E    |          (b)             | P u   |        (c)         |   <- Return Air 
#     Air   <- |    u n   | n    |                          | a h   |                    |      From Conditioned
#              |    s     | t  W |                          | s i W |                    |      Zones
#              |____t_____|_h__h_|__________________________|_s_d_h |____________________|    
#              |          | a  e |              | C   |     | i i e |      S             | 
#   Outdoor    |          | l  e |              | o c |     | v f e |      u F           |       Supply Air
#    Air    -> |    (d)   | p  l |    (e)       | o o | (f) | e i l |      p a    (g)    |   ->  to Conditioned
#              |          | y    |              | l i |     |   n   |      p n           |       Zones
#              |          |      |              | i l |     |   g   |      l             |
#              |          |      |              | n   |     |       |      y             |
#              |_____ ____|______|______________|_g___|_____|_______|____________________|
#                                                | |
#                    Chilled Water Supply (h) ->-| |->-- (i) Chilled Water Return
#
#   The control setpoints and performance description of this unit will need to be set for each 
#   unique design scenario. For example, the setpoint for the leaving coil temperature, (f) will 
#   require a psychrometric analysis incorporating actual cooling coil capacity. The cooling coil
#   can be controlled to provide deep dehumidification, with dehumidification limits primarily dependent
#   on the chilled water supply temperature (h) and the number of rows (correlated to the coil airside
#   pressure drop). Users of this measure are encouraged to plot conditions (a)..(g) for their design 
#   cooling day on a psychrometric chart, then make a copy of this measure and reconfigure the hard coded
#   control setpoints, recovery wheel perfromance, cooling coil performance, fan powers and pressures, etc.   
#  

  def create_new_air_loop
    loop = OpenStudio::Model::AirLoopHVAC.new(@model)
    loop.setName("Chilled Beam DOAS")
    # modify system sizing properties
    sizing_system = loop.sizingSystem
    
    #These next two paramters configure the airloop to operate as a 100% Outside Air Unit
    sizing_system.setTypeofLoadtoSizeOn("VentilationRequirement")
    sizing_system.setMinimumSystemAirFlowRatio(1.0)  		
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(OpenStudio::convert(65, "F", "C").get)
    sizing_system.setAllOutdoorAirinCooling(true)
    sizing_system.setAllOutdoorAirinHeating(true)
    sizing_system.setCentralCoolingDesignSupplyAirHumidityRatio(0.004)
    sizing_system.setSystemOutdoorAirMethod("VentilationRateProcedure")
  
    
    # Add an outdoor air system to the loop
    outdoor_air_control = OpenStudio::Model::ControllerOutdoorAir.new(@model)
    outdoor_air_control.setName("100% OA Outdoor Air Controller - No Economizer")
    outdoor_air_control.setEconomizerControlType("NoEconomizer")
    outdoor_air_control.autosizeMinimumOutdoorAirFlowRate()   # This will set to AutoSize
    outdoor_air_control.autosizeMaximumOutdoorAirFlowRate()   # This will set to AutoSize
    outdoor_air_control.setMinimumFractionofOutdoorAirSchedule(@model.alwaysOnDiscreteSchedule())
    outdoor_air_control.setMaximumFractionofOutdoorAirSchedule(@model.alwaysOnDiscreteSchedule())
    
    # create outdoor air system
    system_OA = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(@model, outdoor_air_control)
    system_OA.setName("DOAS Outdoor Air Management System")
    system_OA.addToNode(loop.supplyInletNode)

    # Create an Air<->Air heat exchanger
    # Note that these settings for this rotary energy exchange device are reasonable but do not represent performance of a 
    # specific product and should be customized to reprsent specific modeling scenarios. 
  
    heat_exchanger = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(@model)
    heat_exchanger.setName("Aluminum Film Substrate Passive Dehumidification Wheel")
    heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.76)   
    heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.68)
    heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.76)
    heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.68)
    heat_exchanger.setNominalElectricPower(250)
    heat_exchanger.setHeatExchangerType("Rotary")
    heat_exchanger.setFrostControlType("None")
    heat_exchanger.addToNode(system_OA.outboardOANode.get)


    # Create a setpoint manager for the heat exchanger
    # This setpoint manager will attempt deliver 68F Air to the inlet of active chilled beam terminal units. 
    exchanger_setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(@model, make_constant_schedule("Passive Dehumidication Wheel LAT 68F Schedule", 68))
    exchanger_setpoint_manager.setName("Passive Dehumidification Wheel (Free reheat) Setpoint Manager")
    exchanger_setpoint_manager.addToNode(system_OA.outdoorAirModelObject.get.to_Node.get)
	
	# Create a cooling water coil
	# The purpose of this coil is to deeply cool the air to wring the maximum amount of moisture from the OA airstream
	# In many cases, this will overcool the 100% OA airstream, requiring either parasitic reheat or free reheat from a 
	# downstream sensible recovery wheel. 
	dehumidification_coil = OpenStudio::Model::CoilCoolingWater.new(@model, @model.alwaysOnDiscreteSchedule())
	dehumidification_coil.setName("Multirow Deep Dehumidification Coil")
	dehumidification_coil.setHeatExchangerConfiguration("Crossflow")
	dehumidification_coil.addToNode(system_OA.outboardOANode.get)
	
	# Create a setpoint manager for the cooling/dehumidification coil
	# The setpoint manager for this coil will operate to attempt to drive the coil temp to the specificed chilled beam
	# entering water temperature (user argument), since this temperature will likely set the temperature of most 
	# efficienct chilled water generation (without requiring mixing to serve the chilled beams a lower entering 
	# chilled water temperature.)
	
    dehumid_coil_setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(@model, make_constant_schedule("Dehumidication Coil Schedule", @design_inlet_water_temperature))
    dehumid_coil_setpoint_manager.setName("Setpoint Manager for Controlling Deep Dehumidification Coil Leaving Air Temp")
    dehumid_coil_setpoint_manager.addToNode(dehumidification_coil.airOutletModelObject.get.to_Node.get)
	
    # Create a second Air to Air Energy Exchange device representing a total energy wheel
    # Note that settings for this rotary energy exchange device are reasonable but do not represent performance of a 
    # specific product and should be customized to reprsent specific modeling scenarios. 
    # Frost control strategies (used for heating only) may need to be modified based on specific design winter conditions
    heat_exchanger2 = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(@model)
    heat_exchanger2.setName("Enthalpy Recovery Wheel")
    heat_exchanger2.setSensibleEffectivenessat100HeatingAirFlow(0.76)
    heat_exchanger2.setLatentEffectivenessat100HeatingAirFlow(0.68)
    heat_exchanger2.setSensibleEffectivenessat100CoolingAirFlow(0.76)
    heat_exchanger2.setLatentEffectivenessat100CoolingAirFlow(0.68)
    heat_exchanger2.setHeatExchangerType("Rotary")
    heat_exchanger2.setNominalElectricPower(250)
    heat_exchanger2.setFrostControlType("MinimumExhaustTemperature")
    heat_exchanger2.setThresholdTemperature(1.7)
    heat_exchanger2.addToNode(system_OA.outboardOANode.get)

    # Create a setpoint manager for the heat exchanger
    # This setpoint manager will attempt deliver 65F Air to the inlet of the downstream deep dehumidification coil. 
    exchanger2_setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(@model, make_constant_schedule("Enthalpy Wheel Leaving Air Temp Schedule", 65))
    exchanger2_setpoint_manager.setName("Enthalpy Wheel Leaving Supply Air Temperature Controller")
    exchanger2_setpoint_manager.addToNode(heat_exchanger2.primaryAirOutletModelObject.get.to_Node.get)

    # Create a variable volume SUPPLY fan - configured for constant volume
    supply_fan = OpenStudio::Model::FanVariableVolume.new(@model, @model.alwaysOnDiscreteSchedule())
    supply_fan.setName("Chilled Beam DOAS Supply Fan")
    inchesH2OtoPa = 1.0/0.00401463
    supply_fan.setPressureRise(@new_airloop_fan_pressure_rise / 2 * inchesH2OtoPa)
    supply_fan.autosizeMaximumFlowRate()
    supply_fan.setFanPowerMinimumFlowFraction(1.0)
    supply_fan.setFanPowerMinimumFlowRateInputMethod("Fraction")
    supply_fan.addToNode(loop.supplyOutletNode)
    
    # Create a variable volume EXHAUST fan - configured for constant flow
    exhaust_fan = OpenStudio::Model::FanVariableVolume.new(@model, @model.alwaysOnDiscreteSchedule())
    exhaust_fan.setName("Chilled Beam DOAS Exhaust Fan")
    exhaust_fan.setPressureRise(@new_airloop_fan_pressure_rise / 2 * inchesH2OtoPa)
    exhaust_fan.autosizeMaximumFlowRate()
    exhaust_fan.setFanPowerMinimumFlowFraction(1.0)
    exhaust_fan.setFanPowerMinimumFlowRateInputMethod("Fraction")
    exhaust_fan.addToNode(system_OA.outboardReliefNode.get)
    
    # make a constant 65F schedule and assign it to a setpoint manager for this loop
    loop_setpoint = OpenStudio::Model::SetpointManagerScheduled.new(@model, make_constant_schedule("Chilled Beam Air Loop Outlet Schedule", 65))
    loop_setpoint.setName("Constant 65 Degree Air Temp")
    loop_setpoint.addToNode(loop.supplyOutletNode)
    
    return loop, dehumidification_coil
  end
  
  # Create a new Plant Loop for use with the added chilled beams.  The created
  # plant loop has a fully populated supply side with a constant speed pump, an
  # Electric EIR Chiller and a constant 65F setpoint
  def create_new_plant_loop
    loop = OpenStudio::Model::PlantLoop.new(@model)
    loop.sizingPlant.setLoopType("Cooling")
    loop.setName("Chiller for Serving Chilled Beams - Plant Loop")
    
    pump = OpenStudio::Model::PumpConstantSpeed.new(@model)
    feetH2OtoPa = 12.0/0.00401463
    pump.setName("Chilled Water Loop - Primary Only Loop")
    pump.setRatedPumpHead(@new_loop_pump_head * feetH2OtoPa)
    pump.setPumpControlType("Intermittent")
    pump.addToNode(loop.supplyInletNode)
    
    # create electric chiller - curves and coefficients copied from OsLib_HVAC_20 used by NREL BCL measures
    clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(@model)
    clgCapFuncTempCurve.setCoefficient1Constant(1.07E+00)
    clgCapFuncTempCurve.setCoefficient2x(4.29E-02)
    clgCapFuncTempCurve.setCoefficient3xPOW2(4.17E-04)
    clgCapFuncTempCurve.setCoefficient4y(-8.10E-03)
    clgCapFuncTempCurve.setCoefficient5yPOW2(-4.02E-05)
    clgCapFuncTempCurve.setCoefficient6xTIMESY(-3.86E-04)
    clgCapFuncTempCurve.setMinimumValueofx(0)
    clgCapFuncTempCurve.setMaximumValueofx(20)
    clgCapFuncTempCurve.setMinimumValueofy(0)
    clgCapFuncTempCurve.setMaximumValueofy(50)
    # create eirFuncTempCurve
    eirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(@model)
    eirFuncTempCurve.setCoefficient1Constant(4.68E-01)
    eirFuncTempCurve.setCoefficient2x(-1.38E-02)
    eirFuncTempCurve.setCoefficient3xPOW2(6.98E-04)
    eirFuncTempCurve.setCoefficient4y(1.09E-02)
    eirFuncTempCurve.setCoefficient5yPOW2(4.62E-04)
    eirFuncTempCurve.setCoefficient6xTIMESY(-6.82E-04)
    eirFuncTempCurve.setMinimumValueofx(0)
    eirFuncTempCurve.setMaximumValueofx(20)
    eirFuncTempCurve.setMinimumValueofy(0)
    eirFuncTempCurve.setMaximumValueofy(50)
    # create eirFuncPlrCurve
    eirFuncPlrCurve = OpenStudio::Model::CurveQuadratic.new(@model)
    eirFuncPlrCurve.setCoefficient1Constant(1.41E-01)
    eirFuncPlrCurve.setCoefficient2x(6.55E-01)
    eirFuncPlrCurve.setCoefficient3xPOW2(2.03E-01)
    eirFuncPlrCurve.setMinimumValueofx(0)
    eirFuncPlrCurve.setMaximumValueofx(1.2)
    # construct chiller
    chiller = OpenStudio::Model::ChillerElectricEIR.new(@model,clgCapFuncTempCurve,eirFuncTempCurve,eirFuncPlrCurve)
    chiller.setName("Air Cooled Chiller for High Temp Chilled Water")
    chiller.setReferenceCOP(3.5)
    chiller.setChillerFlowMode("LeavingSetpointModulated")
    loop.addSupplyBranchForComponent(chiller)
    
    # make a constant schedule linked to design_inlet_water_temperature and assign it to a setpoint manager for this loop
    loop_setpoint = OpenStudio::Model::SetpointManagerScheduled.new(@model, make_constant_schedule("Chilled Beam Plant Loop Outlet Schedule", @design_inlet_water_temperature))
    loop_setpoint.setName("Setpoint Manager for High Temp Chilled Water")
    loop_setpoint.addToNode(loop.supplyOutletNode)
    
    return loop
  end
  
  # Creates a new ScheduleRuleset with the given name and a constant default day value.
  # The temperature supplied should be in deg F and will be converted to C
  def make_constant_schedule(name, temperature)
    s = OpenStudio::Model::ScheduleRuleset.new(@model)
    s.setName(name)
    s.defaultDaySchedule.addValue(OpenStudio::Time.new("24:00:00"), OpenStudio::convert(temperature, "F", "C").get)
	s
  end
  
end

# register the measure to be used by the application
AddChilledBeam.new.registerWithApplication
