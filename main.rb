require 'securerandom'
require 'objspace'

class Proposer
  attr_accessor :id, :last_message

  def initialize(id, last_message)
    @id = id
    @last_message = last_message
  end

  def self.find(id)
    proposers = ObjectSpace.each_object(self).to_a
    proposers.find { |proposer| proposer.id == id }
  end

  def next_message_id
    @last_message + 1
  end
end

class Prepare < Proposer
  attr_accessor :proposer_id, :id

  def initialize(proposer_id)
    @proposer_id = proposer_id
    @id = Proposer.find(proposer_id).next_message_id
  end
end

class Acceptor
  attr_accessor :minimum_n, :maximum_n

  def initialize(minimum_n)
    @minimum_n = minimum_n
    @maximum_n = 0
  end

  def accept?(prepare_n)
    return false unless prepare_n > minimum_n

    @maximum_n
  end
end
