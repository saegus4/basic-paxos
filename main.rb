### TCP SOCKET

proposer_to_acceptor_reader, proposer_to_acceptor_write = IO.pipe

acceptors_quorum = 5.times.map do
  fork do
    prepare = proposer_to_acceptor_reader.gets
    p prepare
      if prepare == 'TU-TU-RU'
        p 'TU-TU-RU'
      end
  end
end

proposer_to_acceptor_write.puts 'TU-TU-RU'



