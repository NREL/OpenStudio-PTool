#start the measure
class ReplaceDesktopsWithThinClients < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Replace Desktops with Thin Clients"
  end

  # human readable description
  def description
    return "Laptop computers and thin clients are typically much more efficient than desktop computers, providing the same (or better) performance while using less energy.  As a result, switching from desktops to laptops or thin clients can save energy.  Typically, laptops use about 80% less electricity than desktops (1) and thin clients use (77%) less, assuming that servers and server cooling are handled on-site (2)."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Assume that each occupant in the building has a computer.  Assume that 53% of these are desktops, and 47% are laptops (1).  Assume that desktops draw 175W at peak, whereas laptops draw 40W and thin clients draw 45W (including data center cooling load).  Calculate the overall building installed electric equipment power in W, then calculate the reduction in W from switching from desktops.  Determine the percent power reduction for the overall building, and apply this percentage to all electric equipment in the building, because electric equipment is not typically identified in a granular fashion."
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

    # Define assumptions
    desktop_power_w = 175
    runner.registerInfo("Assume that each desktop uses #{desktop_power_w.round}W at peak.")
    frac_desktop = 0.53
    other_power_w = 45 # thin client
    runner.registerInfo("Assume that each thin client uses #{other_power_w.round}W at peak.")
    frac_other = 0.47
    
    # Get the total number of occupants in the building
    total_occ = model.getBuilding.numberOfPeople

    # Determine the total wattage of electric equipment
    # currently in the building.
    initial_equip_power_w = model.getBuilding.electricEquipmentPower
    
    # Calculate the number of desktops currently in the building
    num_desktops = total_occ * frac_desktop
    runner.registerInitialCondition("There are #{total_occ.round} people in this building.  Assuming #{frac_desktop} of them have desktops (and that the remainder have laptops already), there are currently #{num_desktops.round} desktops in the building.  There are currently #{initial_equip_power_w.round} W of electric equipment installed in the building.")
    
    # Determine the wattage reduction that would occur from
    # replacing the existing desktops with laptops.
    pwr_reduction_w = (desktop_power_w - other_power_w) * num_desktops
    
    # Determine the fraction that all equipment must be reduced by 
    # to represent the switch from desktops to another technology.
    # This reduction is spread over the entire building because
    # laptops aren't explicitly identified in the model.
    red_multiplier = 1 - (pwr_reduction_w / initial_equip_power_w)
    if pwr_reduction_w >= initial_equip_power_w
      runner.registerError("The amount of power reduction calculated is greater than the total installed electric equipment power in the building.  This likely means that not all occupants in the building were assumed to have computers, or that they are already assumed to have laptops, thin clients, or another similarly low power computer.")
      return false
    end
    
    # Loop through all electric equipment definitions in the building
    # and lower their power by the fraction calculated above.
    model.getElectricEquipmentDefinitions.each do |equipment|
      if equipment.designLevel.is_initialized
        new_electric_equipment_level = equipment.setDesignLevel(equipment.designLevel.get * red_multiplier)
      elsif equipment.wattsperSpaceFloorArea.is_initialized
        new_electric_equipment_per_area = equipment.setWattsperSpaceFloorArea(equipment.wattsperSpaceFloorArea.get * red_multiplier)
      elsif equipment.wattsperPerson.is_initialized
        new_electric_equipment_per_person = equipment.setWattsperPerson(equipment.wattsperPerson.get * red_multiplier)
      else
        runner.registerWarning("'#{equipment.name}' has no load values. Its performance was not altered.")
      end
    end

    # Determine the total wattage of electric equipment
    # now in the building.
    final_equip_power_w = model.getBuilding.electricEquipmentPower
    
    # Calculate the number of desktops currently in the building
    runner.registerFinalCondition("After replacing #{num_desktops.round} #{desktop_power_w.round}W desktops with #{other_power_w.round}W thin clients, there are now #{final_equip_power_w.round} W of electric equipment installed in the building.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
ReplaceDesktopsWithThinClients.new.registerWithApplication