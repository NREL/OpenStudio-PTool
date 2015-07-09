#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class IntegratedWatersideEconomizer < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "IntegratedWatersideEconomizer"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    require 'json'
    results = {}
    
    def find_chiller_hookup_hx(model, plantLoop, results, runner)
      plantLoop.demandComponents.each do |comp|
        if comp.to_ChillerElectricEIR.is_initialized
          runner.registerInfo("Found Chiller: #{comp.name.to_s}")
          # Make the water to water heat exchanger (HX)
          runner.registerInfo("creating HeatExchanger")
          hx = OpenStudio::Model::HeatExchangerFluidToFluid.new(model)
          hx.setName("Integrated Waterside Economizer HX")
          hx.setHeatExchangeModelType("CounterFlow")
          hx.setControlType("CoolingDifferentialOnOff")
          hx.setMinimumTemperatureDifferencetoActivateHeatExchanger(5)
          hx.setHeatTransferMeteringEndUseType("FreeCooling")
          hx.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
          results[:hx_avail_schedule] = hx.availabilitySchedule.get.name.to_s
          # Add the HX to the supply side of the CHW loop
          # on the supply inlet node of the chiller, which is
          # typically on the suction side of the pump.
          # This puts the HX in series with the chiller(s).
          runner.registerInfo("hooking up chilled water side of HX")
          hx.addToNode(comp.to_ChillerElectricEIR.get.plantLoop.get.supplyInletNode)
          results[:chilled_loop_schedule] = comp.to_ChillerElectricEIR.get.plantLoop.get.loopTemperatureSetpointNode.setpointManagers[0].name.to_s
          results[:condenser_loop_schedule] = comp.to_ChillerElectricEIR.get.secondaryPlantLoop.get.loopTemperatureSetpointNode.setpointManagers[0].name.to_s
          # Add the HX to the demand side of the CW loop
          runner.registerInfo("hooking up condenser water side of HX")
          plantLoop.addDemandBranchForComponent(hx)
        end
      end
    end
    
    model.getPlantLoops.each_with_index do |plantLoop, index|
      if plantLoop.sizingPlant.loopType == 'Condenser' 
        skip = false
        plantLoop.supplyComponents.each do |comp|
          if comp.to_CoolingTowerVariableSpeed.is_initialized or comp.to_CoolingTowerSingleSpeed.is_initialized or comp.to_CoolingTowerTwoSpeed.is_initialized
            runner.registerInfo("cooling tower found on conderser loop #{plantLoop.name.to_s}")
            skip = true        
          end
          if skip == true
            plantLoop.setMinimumLoopTemperature(4)
            runner.registerInfo("setting Minimum loop temp to 4 on #{plantLoop.name.to_s}")
            runner.registerInfo("adding heat exchanger")
            find_chiller_hookup_hx(model, plantLoop, results, runner)
            break
          end
        end  
      else
         puts "No Condenser on plant loop #{plantLoop.name.to_s}"   
      end
    end

    #unique initial conditions based on
    #runner.registerInitialCondition("The building has #{results.length} constant air volume units for which this measure is applicable.")

    #reporting final condition of model
    #runner.registerFinalCondition("VSDs and associated controls were applied to  #{results.length} single-zone, constant air volume units in the model.  Airloops affected were #{airloop_name}")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
IntegratedWatersideEconomizer.new.registerWithApplication