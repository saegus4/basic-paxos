### TCP SOCKET
require 'socket'

i = 1
ports = []
5.times do |index|
  ports << 5000 + index
end
p ports
ports.map do |port|
  fork do
    server = TCPServer.new('localhost', port)
    i += 1
    pid = Process.pid
    loop do
      p "Starting server at process #{pid}"
      client = server.accept
      response = "HTTP/1.1 200 OK\r\n" +
        "Content-Type: text/plain\r\n" +
        "Connection: close\r\n" +
        "\r\n" +
        "TU-TU-RU! from #{pid} port #{port}"

      client.puts(response)
      client.close
    end
  end
end

ports.each do |port|
  socket = TCPSocket.new('localhost', port)
  while line = socket.gets
    puts line
  end
  socket.close
end
