### TCP SOCKET
require 'socket'
require 'json'

def with_sockets(ports)
  ports.each do |port|
    socket = TCPSocket.new('localhost', port)
    yield(socket)
    socket.close
  end
end

quorum_ports = []
5.times do |index|
  quorum_ports << 5000 + index
end
quorum_ports.map do |port|
  fork do
    server = TCPServer.new('localhost', port)
    promise_number = 0
    proposers_ids = []
    ## Store highest proposal(value, number)
    loop do
      client = server.accept
      request = client.gets
      data = JSON.parse(request)
      case data['action']
      when 'prepare'
        proposer_id = data['proposer_id']
        if proposer_id > promise_number 
          promise_number = proposer_id
          message = {accepted: true, promise_number: proposer_id}.to_json
          client.puts(message)
          proposers_ids << proposer_id
        else
          message = {accepted: false}.to_json
          client.puts(message)
        end
      end
      client.close
    end
  end
end

proposer_ports = []
2.times do |index|
  proposer_ports << 3000 + index
end

proposer_ports.map do |port|
  fork do
    server = TCPServer.new('localhost', port)
    proposer_id = 1
    ## Add async to proposer communication
    loop do
      client = server.accept
      request = client.gets
      data = JSON.parse(request)
      case data['action']
      when 'prepare'
        acceptors_responses = []
        proposer_id += 1
        message = { proposer_id: proposer_id, action: 'prepare' }.to_json
        with_sockets(quorum_ports) do |acceptor|
          acceptor.puts(message)
          response = acceptor.gets
          acceptors_responses << response
          acceptor.close
        end
      when 'create_message'
        quorum_ports.each do |quorum_port|
          quorum = TCPSocket.new('localhost', quorum_port)
          quorum.puts(request)
          quorum.gets
          quorum.close
        end
      end
    end
  end
end

message = { action: 'prepare' }.to_json
proposer_ports.each do |port|
  proposer = TCPSocket.new('localhost', port)
  proposer.puts(message)
  proposer.close
end
