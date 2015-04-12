require 'rlp/wiki/database'

module Rlp
  module Wiki
    class Model < Rod::Model
      database_class Database
    end
  end
end

