
class AddDaylightSensors < OpenStudio::Ruleset::ModelUserScript
  
  def check_applicability(model)

      # Information for debugging 
      measure_name = "AddDaylightSensors"
      measure_uid = "9cb0fb2d-d95d-400c-9833-3be2db6a75ec"
      measure_applicability = false

      # Store output messages
      @messages = []

      # Load a library that has the daylighting area calculations
      require_relative 'Standards.Space'

      # Open a channel to log info/warning/error messages
      @msg_log = OpenStudio::StringStreamLogSink.new
      @msg_log.setLogLevel(OpenStudio::Debug)
      
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
              @messages << msg.logMessage 
            elsif msg.logLevel == OpenStudio::Warn
              @messages << "[#{msg.logChannel}] #{msg.logMessage}"
            elsif msg.logLevel == OpenStudio::Error
              @messages << "[#{msg.logChannel}] #{msg.logMessage}"
            elsif msg.logLevel == OpenStudio::Debug && debug
              @messages << "DEBUG - [#{msg.logChannel}] #{msg.logMessage}"
            end
          end
        end
      end 
      
      # Loop through all spaces and attempt to add daylight sensors
      spaces_daylight_sensors_added = []
      spaces_affected = []
      changes = []
      model.getSpaces.sort.each do |space|

        added = space.addDaylightingControls('AssetScore', false, false)
        if added
          spaces_daylight_sensors_added << space
          spaces_affected << space.name.get.to_s
        end
      
      end

      # Log the messages
      log_msgs(false)    
  
      # If the model has no single zone air loops, flag as Not Applicable
      if spaces_daylight_sensors_added.size == 0
        measure_applicability = false
        @messages << "Not Applicable - The model has no spaces with daylight potential that need daylight controls."
        debug_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
        debug_hash["measure"]["uid"] = measure_uid
        debug_hash["measure"]["name"] = measure_name
        debug_hash["measure"]["applicable"] = measure_applicability
        debug_hash["measure"]["messages"] = @messages
        result_hash = nil
        return [result_hash,debug_hash] 
      end      
      
      # Report the applicability determination
      if spaces_daylight_sensors_added.size > 0
        measure_applicability = true
        result_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
        result_hash["measure"]["uid"] = measure_uid
        result_hash["measure"]["name"] = measure_name
        result_hash["measure"]["spaces"] = spaces_affected
        result_hash["measure"]["changes"] = changes
      else
        result_hash = nil
      end
      
      # Send the debugging output
      debug_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
      debug_hash["measure"]["uid"] = measure_uid
      debug_hash["measure"]["name"] = measure_name
      debug_hash["measure"]["applicable"] = measure_applicability
      debug_hash["measure"]["messages"] = @messages
      
      return [result_hash,debug_hash] 

    end #end check_applicability

end #AddVFDToSupplyFans