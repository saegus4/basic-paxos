require 'socket'
require 'json'

def with_sockets(ports)
  ports.each do |port|
    socket = TCPSocket.new('localhost', port)
    yield(socket)
    socket.close
  end
end

quorum_ports = (5000..5004).to_a
acceptor_pids = quorum_ports.map do |port|
  fork do
    server = TCPServer.new('localhost', port)
    at_exit { server.close }

    promise_number = 0
    highest_proposal = nil

    loop do
      client = server.accept
      request = client.gets
      data = JSON.parse(request)

      case data['action']
      when 'prepare'
        proposer_id = data['proposer_id']
        if proposer_id > promise_number
          highest_proposal = [proposer_id, data['value']] if data['value']
          promise_number = proposer_id
          response = {
            promise: true,
            promise_number: proposer_id,
            highest_proposal: highest_proposal
          }
        else
          response = { promise: false }
        end
        client.puts(response.to_json)
      else
        puts "#{data}"
      end

      client.close
    end
  end
end

proposer_ports = (3000..3001).to_a
proposer_pids = proposer_ports.map do |port|
  fork do
    server = TCPServer.new('localhost', port)
    at_exit { server.close }

    proposer_id = 1

    loop do
      client = server.accept
      request = client.gets
      data = JSON.parse(request)
      data_value = data['value']

      case data['action']
      when 'prepare'
        proposer_id += 1
        acceptors_responses = []

        message = { proposer_id: proposer_id, action: 'prepare' }.to_json
        with_sockets(quorum_ports) do |acceptor|
          begin
            acceptor.puts(message)
            response = acceptor.gets
            acceptors_responses << JSON.parse(response)
          rescue => e
            puts "Failed to contact acceptor: #{e.message}"
          end
        end

        quorum = acceptors_responses.select { |r| r['promise'] }
        highest = quorum.max_by { |r| r['promise_number'] || 0 }

        value = if highest && highest['highest_proposal']
                  highest['highest_proposal'][1]
                else
                  data_value
                end

        proposal_msg = { proposal_id: proposer_id, value: value }.to_json
        p 'Sending proposal:', proposal_msg

        with_sockets(quorum_ports) do |acceptor|
          begin
            acceptor.puts(proposal_msg)
          rescue => e
            puts "Failed to send proposal: #{e.message}"
          end
        end
      end

      client.close
    end
  end
end

message = { action: 'prepare', value: 50 }.to_json
proposer_ports.each do |port|
  proposer = TCPSocket.new('localhost', port)
  proposer.puts(message)
  proposer.close
end

Process.waitall

