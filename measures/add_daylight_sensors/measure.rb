#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

# Start the measure
class AddDaylightSensors < OpenStudio::Ruleset::ModelUserScript
  
  # Define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return "Add Daylight Sensors"
  end
  
  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end  
  
  # Define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
        
    return args
  end

  # Define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    # Use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Load a library that has the daylighting area calculations
    require_relative 'resources/Standards.Space'

    # Open a channel to log info/warning/error messages
    @msg_log = OpenStudio::StringStreamLogSink.new
    @msg_log.setLogLevel(OpenStudio::Debug)
    @runner = runner
    
    # Get all the log messages and put into output
    # for users to see.
    def log_msgs(debug = true)
      @msg_log.logMessages.each do |msg|
        # DLM: you can filter on log channel here for now
        if /openstudio.*/.match(msg.logChannel) #/openstudio\.model\..*/
          # Skip certain messages that are irrelevant/misleading
          next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
                  msg.logChannel.include?("runmanager") || # RunManager messages
                  msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
                  msg.logChannel.include?("Translator") # Forward translator and geometry translator
          # Report the message in the correct way
          if msg.logLevel == OpenStudio::Info
            @runner.registerInfo(msg.logMessage)  
          elsif msg.logLevel == OpenStudio::Warn
            @runner.registerWarning("[#{msg.logChannel}] #{msg.logMessage}")
          elsif msg.logLevel == OpenStudio::Error
            @runner.registerError("[#{msg.logChannel}] #{msg.logMessage}")
          elsif msg.logLevel == OpenStudio::Debug && debug
            @runner.registerInfo("DEBUG - [#{msg.logChannel}] #{msg.logMessage}")
          end
        end
      end
    end 
    
    # Loop through all spaces and attempt to add daylight sensors
    spaces_daylight_sensors_added = []
    spaces_affected = []
    model.getSpaces.sort.each do |space|

      added = space.addDaylightingControls('AssetScore', false, false)
      if added
        spaces_daylight_sensors_added << space
        spaces_affected << space.name.get.to_s
      end
    
    end

    # Log the messages
    log_msgs(false)    
    
    # Record the building's final condition
    if spaces_daylight_sensors_added.size == 0
      runner.registerAsNotApplicable("The building has no spaces with daylighting potential that need daylight controls, this measure is not applicable.")
      return true
    else
      runner.registerFinalCondition("#{spaces_daylight_sensors_added.size} spaces had daylight controls added. There names were spaces #{spaces_affected.join(", ")}.")  
    end    

    return true
    
  end # End the run method

end # End the measure

# This allows the measure to be use by the application
AddDaylightSensors.new.registerWithApplication