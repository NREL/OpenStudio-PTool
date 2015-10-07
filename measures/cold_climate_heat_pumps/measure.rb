# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class ColdClimateHeatPumps < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Cold Climate Heat Pumps"
  end

  # human readable description
  def description
    return  "This energy efficiency measure (EEM) adds cold-climate Air-Source Heat Pumps (ccASHP) to all air loops in a model having heat pump heating coils. The measure modifies all existing CoilHeatingDXSingleSpeed coils in a model by replacing performance curves with those representing the heating performance of a cold-climate Air-Source Heat Pumps (ccASHP).  ccASHP are defined as ducted or ductless, air-to-air, split system heat pumps serving either single-zone or multi-zone systems with capacities less than <65 kBtu/hour at 47F dry bulb), best suited to heat efficiently in cold climates (IECC climate zone 4 and higher). ccASHP DOES NOT include ground-source or air-to-water heat pump systems. This measure also sets the Min. OADB Temperature for ccASHP operation to -4F. The performance specifications for ccASHP have been derived from published performance data from the Northeast Energy Efficiency Partnership (NEEP) specification found here:   http://www.neep.org/sites/default/files/resources/NEEP%20cold%20climate%20Air-Source%20Heat%20Pump%20Specification.pdf"
  end
  # human readable description of modeling approach
  def modeler_description
    return "This measure replaces the coefficients for OS:PerformanceCurve objects associated with all OS:CoilHeatingDXSingleSpeed objects. These performance curve objects are modified: 
1)	TotalHeatingCapacityFunctionofTemperature 
2)	TotalHeatingCapacityFunctionofFlowFraction 
3)	EnergyInputRatioFunctionofTemperature 
4)	EnergyInputRatioFunctionofFlowFraction 
5)	PartLoadFractionCorrelationCurve.
In addition, the setting for the MinimumOutdoorDryBulbTemperatureforCompressorOperation will be changed to -4F.
The replacement curves have been developed by regressing manufacturers published performance data for commercially available ccASHP from the NEEP website."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

	# initialize counter variables for ZoneHVACPackagedTerminalHeatPump objects at the global level
	zn_eqp_array = []
	heat_coil_array = []

	model.getObjectsByType(OpenStudio::Model::ZoneHVACPackagedTerminalHeatPump.iddObjectType).each do |zn_eqp| # getting ZoneHVACPackagedTerminalHeatPump objects 
		zn_eqp_array << zn_eqp 
		@heat_coil = zn_eqp.to_ZoneHVACPackagedTerminalHeatPump.get.heatingCoil.to_CoilHeatingDXSingleSpeed.get # getting heating coils: DX single speed 
		heat_coil_array << @heat_coil
		@heat_coil_name = @heat_coil.name
		@initial_cop = @heat_coil.ratedCOP # calling the existing COP
		@heat_coil.setName("#{@heat_coil_name}-modified") # new name for coil
		@heat_coil.setRatedCOP(4.07762)	# modified COP
		comp_t_initial = @heat_coil.minimumOutdoorDryBulbTemperatureforCompressorOperation
		@heat_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(-20) #temperature to -4F for compressor operation of coil
		runner.registerInfo ("MinimumOutdoorDryBulbTemperatureforCompressorOperation for OS:CoilHeatingDXSingleSpeed object = '#{@heat_coil_name}' has been changed from #{(((comp_t_initial)*1.8)+32)}F to -4F.")
		#Create a new Heating Capacity Function of Temperature Curve 
		#Curve:Biquadratic,
		#   HP_Heat-Cap-fT3,   !- Name
		#   0.9620542196000001,-0.00949277772,0.000109212948,0.0247078314,0.000034225092,-0.000125697744,   !- Coefficients (list)
		#   -100,              !- Minimum Value of x
		#   100,               !- Maximum Value of x
		#   -100,              !- Minimum Value of y
		#   100;               !- Maximum Value of y
		exist_hp_heat_cap_ft3_name = @heat_coil.totalHeatingCapacityFunctionofTemperatureCurve.name
		hp_heat_cap_ft3 = OpenStudio::Model::CurveBiquadratic.new(model)
		hp_heat_cap_ft3.setName("#{exist_hp_heat_cap_ft3_name}-modified")
		hp_heat_cap_ft3.setCoefficient1Constant(0.962054)
		hp_heat_cap_ft3.setCoefficient2x(-0.009493)
		hp_heat_cap_ft3.setCoefficient3xPOW2(0.0001092)
		hp_heat_cap_ft3.setCoefficient4y(0.024708)
		hp_heat_cap_ft3.setCoefficient5yPOW2(0.00003423)
		hp_heat_cap_ft3.setCoefficient6xTIMESY(-0.0001257)
		hp_heat_cap_ft3.setMinimumValueofx(-100)
		hp_heat_cap_ft3.setMaximumValueofx(100)
		hp_heat_cap_ft3.setMinimumValueofy(-100)
		hp_heat_cap_ft3.setMaximumValueofy(100)
		
		#Create a new EIR function of temperature curve
		#Curve:Biquadratic,
		#   hp_heat_eir_ft3,   !- Name
		#   0.5725180114,0.02289624912,0.000266018904,-0.0106675434,0.00049092156,-0.00068136876,   !- Coefficients (List)
		#   -100,              !- Minimum Value of x
		#   100,               !- Maximum Value of x
		#   -100,              !- Minimum Value of y
		#   100;               !- Maximum Value of y
		exist_hp_heat_eir_ft3_name = @heat_coil.energyInputRatioFunctionofTemperatureCurve.name
		hp_heat_eir_ft3 = OpenStudio::Model::CurveBiquadratic.new(model)
		hp_heat_eir_ft3.setName("#{exist_hp_heat_eir_ft3_name}-modified")
		hp_heat_eir_ft3.setCoefficient1Constant(0.57252)
		hp_heat_eir_ft3.setCoefficient2x(0.0229)
		hp_heat_eir_ft3.setCoefficient3xPOW2(0.00026602)
		hp_heat_eir_ft3.setCoefficient4y(-0.010668)
		hp_heat_eir_ft3.setCoefficient5yPOW2(0.000491)
		hp_heat_eir_ft3.setCoefficient6xTIMESY(-0.0006814)
		hp_heat_eir_ft3.setMinimumValueofx(-100)
		hp_heat_eir_ft3.setMaximumValueofx(100)
		hp_heat_eir_ft3.setMinimumValueofy(-100)
		hp_heat_eir_ft3.setMaximumValueofy(100)
						
		#Create a new part load function correlation curve
		#Curve:Quadratic,
		#   hp_heat_plf_fplr3,   !- Name
		#   0.76,0.24,0,         !- Coefficients (List)
		#   0,                   !- Minimum Value of x
		#   1,                   !- Maximum Value of x
		#   0.7,                 !- Minimum Value of y
		#   1;                   !- Maximum Value of y
		exist_hp_heat_plf_fplr3_name = @heat_coil.partLoadFractionCorrelationCurve.name
		hp_heat_plf_fplr3 = OpenStudio::Model::CurveQuadratic.new(model)
		hp_heat_plf_fplr3.setName("#{exist_hp_heat_plf_fplr3_name}-modified")
		hp_heat_plf_fplr3.setCoefficient1Constant(0.76)
		hp_heat_plf_fplr3.setCoefficient2x(0.24)
		hp_heat_plf_fplr3.setCoefficient3xPOW2(0.0)
		hp_heat_plf_fplr3.setMinimumValueofx(0)
		hp_heat_plf_fplr3.setMaximumValueofx(1)
	
		#Create a new heating capacity of flow fraction curve
		#Curve:Quadratic,
		#   hp_heat_cap_fff3,   !- Name
		#   1,0,0,              !- Coefficients (List)
		#   0,                  !- Minimum Value of x
		#   2,                  !- Maximum Value of x
		#   0,                  !- Minimum Value of y
		#   2;                  !- Maximum Value of y
		exist_hp_heat_cap_fff3_name = @heat_coil.totalHeatingCapacityFunctionofFlowFractionCurve.name
		hp_heat_cap_fff3 = OpenStudio::Model::CurveQuadratic.new(model)
		hp_heat_cap_fff3.setName("#{exist_hp_heat_cap_fff3_name}-modified")
		hp_heat_cap_fff3.setCoefficient1Constant(1)
		hp_heat_cap_fff3.setCoefficient2x(0.0)
		hp_heat_cap_fff3.setCoefficient3xPOW2(0.0)
		hp_heat_cap_fff3.setMinimumValueofx(0)
		hp_heat_cap_fff3.setMaximumValueofx(2)
						
		#Create a new EIR of flow fraction curve
		#Curve:Quadratic,
		#   hp_heat_eir_fff3,   !- Name
		#   1,0,0,              !- Coefficients (List)
		#   0,                  !- Minimum Value of x
		#   2,                  !- Maximum Value of x
		#   0,                  !- Minimum Value of y
		#   2;                  !- Maximum Value of y
		exist_hp_heat_eir_fff3_name = @heat_coil.energyInputRatioFunctionofFlowFractionCurve.name
		hp_heat_eir_fff3 = OpenStudio::Model::CurveQuadratic.new(model)
		hp_heat_eir_fff3.setName("#{exist_hp_heat_eir_fff3_name}-modified")
		hp_heat_eir_fff3.setCoefficient1Constant(1)
		hp_heat_eir_fff3.setCoefficient2x(0.0)
		hp_heat_eir_fff3.setCoefficient3xPOW2(0.0)
		hp_heat_eir_fff3.setMinimumValueofx(0)
		hp_heat_eir_fff3.setMaximumValueofx(2)
						
		#Assigning the existing curves with new ones
		@heat_coil.setTotalHeatingCapacityFunctionofTemperatureCurve(hp_heat_cap_ft3)
		@heat_coil.setTotalHeatingCapacityFunctionofFlowFractionCurve (hp_heat_cap_fff3)
		@heat_coil.setEnergyInputRatioFunctionofTemperatureCurve(hp_heat_eir_ft3)
		@heat_coil.setEnergyInputRatioFunctionofFlowFractionCurve(hp_heat_eir_fff3)
		@heat_coil.setPartLoadFractionCorrelationCurve (hp_heat_plf_fplr3)
		runner.registerInfo("Info about curve changes for OS:CoilHeatingDXSingleSpeed object = '#{@heat_coil_name}': 
		\n1. Heating Capacity Function of Temperature Curve from '#{exist_hp_heat_cap_ft3_name}' to '#{exist_hp_heat_cap_ft3_name}-modified',
		\n2. EIR function of temperature curve from '#{exist_hp_heat_eir_ft3_name}' to '#{exist_hp_heat_eir_ft3_name}-modified',
		\n3. Part load function correlation curve from '#{exist_hp_heat_plf_fplr3_name}' to '#{exist_hp_heat_plf_fplr3_name}-modified',
		\n4. Heating capacity of flow fraction curve from '#{exist_hp_heat_cap_fff3_name}' to '#{exist_hp_heat_cap_fff3_name}-modified',
		\n5. EIR of flow fraction curve from '#{exist_hp_heat_eir_fff3_name}' to '#{exist_hp_heat_eir_fff3_name}-modified'.")
		
	end #end the do loop
	
	# not applicable message if there is no valid heating coil
	if
		zn_eqp_array.length == 0
		runner.registerAsNotApplicable("The measure is not applicable due to absence of valid object 'OS:CoilHeatingDXSingleSpeed'.")
	return true
	end #end the not applicable if condition for heating plant loop
	
	
	
	
			
		# The modified dx heating coil object replacement object will follow the decriptions from page 19 (of 45) from here:
		# http://apps1.eere.energy.gov/buildings/publications/pdfs/building_america/minisplit_multifamily_retrofit.pdf
		# Because BEopt does not currently model MSHPs, the closest approximation (central variable-speed heat pump without ducts) was used 
		# on the advice of BEopt developers. The performance of the variable-speed heat pump was left unchanged: SEER 22 and HSPF 10
		#. These values are slightly conservative when compared to MSHP testing data from NREL (Winkler, 2011). Additional modeling 
		#assumptions are shown in Table 7 and Table 8...." We will use the 3rd stage performance for our measure.
		# Stage 3 from BeOpt item #11 from the space conditioning category, air source heat pump type,(SEER 22, HSPF 10), is the item we will mimic to represent 
		# a low temp MSHP
		
		#Here are snippets of the idf created by beopt v2.4.0.0 for the 3rd stage low temp MSHP
		
		#write info messages
		
		#write intitial and final conditions message
		
		#Curve Definitions			

		#Curve:Biquadratic,
		#   HP_Heat-Cap-fT3,   !- Name
		#   0.9620542196000001,-0.00949277772,0.000109212948,0.0247078314,0.000034225092,-0.000125697744,   !- Coefficients (list)
		#   -100,              !- Minimum Value of x
		#   100,               !- Maximum Value of x
		#   -100,              !- Minimum Value of y
		#   100;               !- Maximum Value of y

		#Curve:Biquadratic,
		#   HP_Heat-EIR-fT3,   !- Name
		#   0.5725180114,0.02289624912,0.000266018904,-0.0106675434,0.00049092156,-0.00068136876,   !- Coefficients (List)
		#   -100,              !- Minimum Value of x
		#   100,               !- Maximum Value of x
		#   -100,              !- Minimum Value of y
		#   100;               !- Maximum Value of y

		#Curve:Quadratic,
		#   HP_Heat-PLF-fPLR3,   !- Name
		#   0.76,0.24,0,         !- Coefficients (List)
		#   0,                   !- Minimum Value of x
		#   1,                   !- Maximum Value of x
		#   0.7,                 !- Minimum Value of y
		#   1;                   !- Maximum Value of y
		#
		#Curve:Quadratic,
		#   HP_Heat-Cap-fFF3,   !- Name
		#   1,0,0,              !- Coefficients (List)
		#   0,                  !- Minimum Value of x
		#   2,                  !- Maximum Value of x
		#   0,                  !- Minimum Value of y
		#   2;                  !- Maximum Value of y

		#Curve:Quadratic,
		#   HP_Heat-EIR-fFF3,   !- Name
		#   1,0,0,              !- Coefficients (List)
		#   0,                  !- Minimum Value of x
		#   2,                  !- Maximum Value of x
		#   0,                  !- Minimum Value of y
		#   2;                  !- Maximum Value of y

		#Curve:Biquadratic,
		#   DefrostEIR,         !- Name
		#   0.1528,0,0,0,0,0,   !- Coefficients (List)
		#   -100,               !- Minimum Value of x
		#   100,                !- Maximum Value of x
		#   -100,               !- Minimum Value of y
		#   100;                !- Maximum Value of y
					
	

	

	# change the minimum OA temp for compressor operation at equipment level
	zn_eqp_array.each do |comp_temp|
		if comp_temp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
			a_1 = comp_temp.to_ZoneHVACPackagedTerminalHeatPump.get
			initial_comp_temp_zone = a_1.minimumOutdoorDryBulbTemperatureforCompressorOperation
			a_1.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(-20) #changing the temp to -20C (-4F)
			runner.registerInfo("MinimumOutdoorDryBulbTemperatureforCompressorOperation for Zone equipment = '#{a_1.name}' has been changed from #{(((initial_comp_temp_zone)*1.8)+32)}F to -4F.")	
		end #end if statement
	end  # end the do loop
	
	@heat_coil_names = heat_coil_array.collect{ |l| l.name.to_s }.join(', ') # to get all the names of heatcoil array objects
	
    # report initial condition of model
    runner.registerInitialCondition("The initial model contains #{zn_eqp_array.length} applicable 'OS:CoilHeatingDXSingleSpeed' objects for which this measure is applicable.")

    # report final condition of model
    runner.registerFinalCondition("Performance curves representing 'ccASHP heating technology' has been applied to #{zn_eqp_array.length} 'OS:CoilHeatingDXSingleSpeed' objects in the model. \nName(s) of affected coil objects are: \n#{@heat_coil_names}")

    return true

  end
  
end

# register the measure to be used by the application
ColdClimateHeatPumps.new.registerWithApplication
