#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

require 'json'

#start the measure
class NaturalGasHeatPumps < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Natural Gas Heat Pumps"
  end

  # human readable description
  def description
    return "Natural gas driven heat pumps burn natural gas to drive a refrigerant-absorbent heating and cooling cycle.  These are currently available as large units that replace a boiler/chiller pair, providing hot and chilled water to a building.  These heat pumps can reduce peak demand by shifting from electricity to natural gas.  They may save heating energy since the heating COP of the heat pump is higher than direct combustion efficiency.  However, cooling energy may increase since cooling efficiency is lower than standard vapor-compression chillers."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure identifies buildings with boiler/chiller pairs providing hot/chilled water to hydronic systems in the building.  The boiler/chiller pair is replaced by a direct-fired absorption chiller heater.  The condenser type is air cooled or water cooled depending on the configuration of the original chiller."
  end  
  
  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
    
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end
    
    require 'json'
    
    # Get the last openstudio model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Could not load last OpenStudio model, cannot apply measure.")
      return false
    end
    model = model.get
    
    # Find the chiller
    chiller = nil
    chillers = workspace.getObjectsByType("Chiller:Electric:EIR".to_IddObjectType)
    if chillers.size == 00
      runner.registerAsNotApplicable("Not Applicable - this model does not contain any chillers that could be replaced by a natural gas heat pump.")
      return true
    elsif chillers.size > 1
      runner.registerAsNotApplicable("Not Applicable - this model has more than one chiller; cannot currently handle this configuration.")
      return true
    else
      chiller = chillers[0]
    end
    chiller_name = chiller.getString(0).get
    chiller.remove
    runner.registerInfo("Chiller #{chiller_name} will be replaced with a direct fired absorption chiller heater.")
    
    # Find the boiler
    boiler = nil
    boilers = workspace.getObjectsByType("Boiler:HotWater".to_IddObjectType)
    if boilers.size == 00
      runner.registerAsNotApplicable("Not Applicable - this model does not contain any boilers that could be replaced by a natural gas heat pump.")
      return true
    elsif boilers.size > 1
      runner.registerAsNotApplicable("Not Applicable - this model has more than one boiler; cannot currently handle this configuration.")
      return true
    else
      boiler = boilers[0]
    end
    boiler_name = boiler.getString(0).get
    boiler.remove
    runner.registerInfo("Boiler #{boiler_name} will be replaced with a direct fired absorption chiller heater.")
    
    # Get the names of the chilled water
    # amd condenser water nodes
    chw_inlet = chiller.getString(14)
    chw_outlet = chiller.getString(15)
    cw_inlet = chiller.getString(16)
    cw_outlet = chiller.getString(17)
    condenser_type = 'WaterCooled'
    if cw_inlet.get == '' || cw_outlet.get = ''
      condenser_type = 'AirCooled'
    end
    runner.registerInfo("The direct fired absorption chiller heater has an #{condenser_type} condenser.")
    
    # Get the names of the hot water nodes
    hw_inlet = boiler.getString(11)
    hw_outlet = boiler.getString(12)
    
    # puts "condenser_type = #{condenser_type}"
    # puts "chw_inlet = #{chw_inlet}"
    # puts "chw_outlet = #{chw_outlet}"
    # puts "cw_inlet = #{cw_inlet}"
    # puts "cw_outlet = #{cw_outlet}"
    # puts "hw_inlet = #{hw_inlet}"
    # puts "hw_outlet = #{hw_outlet}"
    
    # Make an absorption chiller heater
    # and associated performance curves
    idf_string = ""
    
    if condenser_type == 'AirCooled'
      cw_inlet = 'Absorption Chiller Heater Condenser Air Inlet Node'
      cw_outlet = 'Absorption Chiller Heater Condenser Air Outlet Node'
      idf_string << "
        OutdoorAir:Node,
          #{cw_inlet};  !- Name
          
        OutdoorAir:Node,
          #{cw_outlet};  !- Name"
    end
    
    # COP estimates from:
    # http://energy.gov/sites/prod/files/2014/03/f12/Non-Vapor%20Compression%20HVAC%20Report.pdf
    # Curves from E+ example file. Actual
    # manufacturer curves probably not flat
    heater_name = 'Absorption Chiller Heater'
    cop_cooling = 1.7
    cop_heating = 1.4
    parasitic_elec = 0.023
    
    runner.registerInfo("The direct fired absorption chiller heater has a cooling COP of #{cop_cooling.round(1)} and a heating COP of #{cop_heating.round(1)}.")

    idf_string << "
    Curve:Quadratic,
        GasAbsFlatQuad,          !- Name
        1.000000000,             !- Coefficient1 Constant
        0.000000000,             !- Coefficient2 x
        0.000000000,             !- Coefficient3 x**2
        0,                      !- Minimum Value of x
        50;                     !- Maximum Value of x

    Curve:Quadratic,
        GasAbsLinearQuad,        !- Name
        0.000000000,             !- Coefficient1 Constant
        1.000000000,             !- Coefficient2 x
        0.000000000,             !- Coefficient3 x**2
        0,                      !- Minimum Value of x
        50;                     !- Maximum Value of x

    Curve:Quadratic,
        GasAbsInvLinearQuad,     !- Name
        1.000000000,             !- Coefficient1 Constant
        -1.000000000,            !- Coefficient2 x
        0.000000000,             !- Coefficient3 x**2
        0,                      !- Minimum Value of x
        50;                     !- Maximum Value of x

    Curve:Biquadratic,
        GasAbsFlatBiQuad,        !- Name
        1.000000000,             !- Coefficient1 Constant
        0.000000000,             !- Coefficient2 x
        0.000000000,             !- Coefficient3 x**2
        0.000000000,             !- Coefficient4 y
        0.000000000,             !- Coefficient5 y**2
        0.000000000,             !- Coefficient6 x*y
        0,                      !- Minimum Value of x
        50,                     !- Maximum Value of x
        0,                      !- Minimum Value of y
        50;                     !- Maximum Value of y    
    
    ChillerHeater:Absorption:DirectFired,
        #{heater_name},             !- Name
        Autosize,                  !- Nominal Cooling Capacity {W}
        0.8,                     !- Heating to Cooling Capacity Ratio
        #{1/cop_cooling},        !- Fuel Input to Cooling Output Ratio
        #{1/cop_heating},        !- Fuel Input to Heating Output Ratio
        #{parasitic_elec},       !- Electric Input to Cooling Output Ratio
        #{parasitic_elec},       !- Electric Input to Heating Output Ratio
        #{chw_inlet},  !- Chilled Water Inlet Node Name
        #{chw_outlet}, !- Chilled Water Outlet Node Name
        #{cw_inlet},  !- Condenser Inlet Node Name
        #{cw_outlet},  !- Condenser Outlet Node Name
        #{hw_inlet},  !- Hot Water Inlet Node Name
        #{hw_outlet},  !- Hot Water Outlet Node Name
        0.000001,                !- Minimum Part Load Ratio
        1.0,                     !- Maximum Part Load Ratio
        0.6,                     !- Optimum Part Load Ratio
        29,                      !- Design Entering Condenser Water Temperature {C}
        7,                       !- Design Leaving Chilled Water Temperature {C}
        0.0011,                  !- Design Chilled Water Flow Rate {m3/s}
        0.0011,                  !- Design Condenser Water Flow Rate {m3/s}
        0.0043,                  !- Design Hot Water Flow Rate {m3/s}
        GasAbsFlatQuad,        !- Cooling Capacity Function of Temperature Curve Name
        GasAbsFlatQuad,        !- Fuel Input to Cooling Output Ratio Function of Temperature Curve Name
        GasAbsLinearQuad,        !- Fuel Input to Cooling Output Ratio Function of Part Load Ratio Curve Name
        GasAbsFlatQuad,        !- Electric Input to Cooling Output Ratio Function of Temperature Curve Name
        GasAbsFlatQuad,          !- Electric Input to Cooling Output Ratio Function of Part Load Ratio Curve Name
        GasAbsInvLinearQuad,     !- Heating Capacity Function of Cooling Capacity Curve Name
        GasAbsLinearQuad,        !- Fuel Input to Heat Output Ratio During Heating Only Operation Curve Name
        EnteringCondenser,       !- Temperature Curve Input Variable
        #{condenser_type},             !- Condenser Type
        2,                       !- Chilled Water Temperature Lower Limit {C}
        0,                       !- Fuel Higher Heating Value {kJ/kg}
        VariableFlow,            !- Chiller Flow Mode
        NaturalGas,              !- Fuel Type
        ;                        !- Sizing Factor"    
    
    # Fix up the branches
    workspace.getObjectsByType("Branch".to_IddObjectType).each do|branch|
      if branch.getString(4).get == chiller_name || branch.getString(4).get == boiler_name
        branch.setString(3, 'ChillerHeater:Absorption:DirectFired')
        branch.setString(4, heater_name)
      end
    end
    
    # Fix up the plant equipment lists
    workspace.getObjectsByType("PlantEquipmentList".to_IddObjectType).each do|list|
      if list.getString(2).get == chiller_name || list.getString(2).get == boiler_name
        list.setString(1, 'ChillerHeater:Absorption:DirectFired')
        list.setString(2, heater_name)
      end
    end

    # Debugging variables
    idf_string << "
    Output:Variable,*,Chiller Heater Heating Rate,hourly; !- Zone Average [C]
    Output:Variable,*,Chiller Heater Evaporator Cooling Rate,hourly; !- Zone Average [C]
    Output:Variable,*,Chiller Heater Gas Rate,hourly; !- Zone Average [C]
    Output:Variable,*,Chiller Heater Heating Gas Rate,hourly; !- Zone Average [C]
    Output:Variable,*,Chiller Heater Cooling Gas Rate,hourly; !- Zone Average []
    Output:Variable,*,Chiller Heater Cooling COP,hourly; !- Zone Average []
    Output:Variable,*,Chiller Heater Cooling Part Load Ratio,hourly; !- Zone Average []
    Output:Variable,*,Chiller Heater Heating Part Load Ratio,hourly; !- Zone Average []"
    
    idf_file = OpenStudio::IdfFile::load(idf_string, 'EnergyPlus'.to_IddFileType).get
    runner.registerInfo("Adding absorption chiller heater to workspace")
    workspace.addObjects(idf_file.objects)
    
    # if zones_applied.size == 0
      # runner.registerAsNotApplicable("Not Applicable.  Model contained no zones that have people in them, occupant feedback cannot be given wtihout occupants.")
      # return true
    # else
      # runner.registerFinalCondition("Applied Natural Gas Heat Pumps to #{zones_applied.size} zones.") 
    # end
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
NaturalGasHeatPumps.new.registerWithApplication