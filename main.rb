### TCP SOCKET
require 'socket'
require 'json'

quorum_ports = []
5.times do |index|
  quorum_ports << 5000 + index
end
quorum_ports.map do |port|
  fork do
    server = TCPServer.new('localhost', port)
    loop do
      client = server.accept

      client.puts("Go with the message from port #{port}")
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
    loop do
      client = server.accept
      request = client.gets
      data = JSON.parse(request)
      case data['action']
      when 'create_message'
        quorum_ports.each do |quorum_port|
          quorum = TCPSocket.new('localhost', quorum_port)
          quorum.puts(request)
          line = quorum.gets
          quorum.close
        end
      end
    end
  end
end

message = {action: "create_message", body: "tu-tu-ru"}.to_json
proposer_ports.each do |port|
  proposer = TCPSocket.new('localhost', port)
  proposer.puts(message)
  proposer.close
end
