require 'socket'
require 'json'
require 'open3'

def with_sockets(ports)
  ports.each do |port|
    socket = TCPSocket.new('localhost', port)
    yield(socket)
    socket.close
  rescue Errno::ECONNREFUSED
    puts "Connection refused on port #{port}"
  end
end

quorum_ports = (5000..5004).to_a
pids = quorum_ports.map do |port|
  fork do
    server = TCPServer.new('localhost', port)
    at_exit { server.close }

    promise_number = 0
    highest_proposal = nil
    accepted_proposal = nil

    loop do
      client = server.accept
      request = client.gets
      data = JSON.parse(request)
      proposer_id = data['proposer_id']

      case data['action']
      when 'accept'
        if proposer_id >= promise_number
          accepted_proposal = [proposer_id, data['value']]
          highest_proposal = [proposer_id, data['value']]
          response = {
            accepted: true,
            accepted_proposal: accepted_proposal
          }
        else
          response = {
            accepted: false
          }
        end
      when 'prepare'
        if proposer_id >= promise_number
          promise_number = proposer_id
          response = {
            promise: true,
            promise_number: proposer_id,
            highest_proposal: highest_proposal
          }
        else
          response = { promise: false }
        end
      else
        puts "#{data}"
      end
      client.puts(response.to_json)

      client.close
    end
  end
end

proposer_ports = (3000..3001).to_a
proposer_ports.map do |port|
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
          acceptor.puts(message)
          response = acceptor.gets
          acceptors_responses << JSON.parse(response)
        rescue StandardError => e
          puts "Failed to contact acceptor: #{e.message}"
        end

        quorum = acceptors_responses.select { |r| r['promise'] }
        highest = quorum.max_by { |r| r['promise_number'] || 0 }

        value = if highest && highest['highest_proposal']
                  highest['highest_proposal'][1]
                else
                  data_value
                end

        proposal_msg = { proposer_id: proposer_id, value: value, action: 'accept' }.to_json

        accept_responses = []
        with_sockets(quorum_ports) do |acceptor|
          acceptor.puts(proposal_msg)
          response = acceptor.gets
          accept_responses << JSON.parse(response)
        rescue StandardError => e
          puts "Failed to send proposal: #{e.message}"
        end
        accepts = accept_responses.select { |r| r['accepted'] }
        if accepts.length > 3
          p "Message Accept with value #{accepts}"
        else
          p "Message not accept"
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

message = { action: 'prepare', value: 100 }.to_json
proposer_ports.each do |port|
  proposer = TCPSocket.new('localhost', port)
  proposer.puts(message)
  proposer.close
end

message = { action: 'prepare', value: 200 }.to_json
proposer_ports.each do |port|
  proposer = TCPSocket.new('localhost', port)
  proposer.puts(message)
  proposer.close
end

sleep(2.0)

pids.sample(4).each do |pid|
  puts "Killing PID #{pid}"
  Process.kill('KILL', pid)
end

message = { action: 'prepare', value: 300 }.to_json
proposer_ports.each do |port|
  proposer = TCPSocket.new('localhost', port)
  proposer.puts(message)
  proposer.close
end

Process.waitall
