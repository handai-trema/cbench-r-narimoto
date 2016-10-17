# A simple openflow controller for benchmarking.
class Cbench < Trema::Controller
  def start(_args)
    logger.info 'Cbench started.'
  end

  def packet_in(datapath_id, message)
    @flow_mod ||= create_flow_mod_binary(message)
    send_message datapath_id, @flow_mod
  end

  private

  def create_flow_mod_binary(message)
    options = {
      command: :add,
      priority: 0,
      transaction_id: 0,
      idle_timeout: 0,
      hard_timeout: 0,
      buffer_id: message.buffer_id,
      match: ExactMatch.new(message),
      actions: SendOutPort.new(message.in_port + 1)
    }
    FlowMod.new(options).to_binary.tap do |flow_mod|
      def flow_mod.to_binary
        self
      end
    end
  end
end
