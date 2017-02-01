Bundler.require

require 'active_record'
require 'minitest/autorun'

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'

class Player < ActiveRecord::Base
  has_many :statistics

  connection.create_table table_name, :force => true do |t|
    t.string :name
  end
end

class Statistic < ActiveRecord::Base
  belongs_to :player
  belongs_to :participant

  connection.create_table table_name, :force => true do |t|
    t.integer :player_id
    t.integer :participant_id
    t.integer :points
    t.integer :time_played
  end
end

class Participant < ActiveRecord::Base
  has_one :statistic

  connection.create_table table_name, :force => true do |t|
    t.string :homeaway
  end
end

describe 'having query as arel' do
  before do
    [Statistic, Participant, Player].each { |ar| ar.delete_all }

    ActiveRecord::Base.logger = nil

    player = Player.create!(name: 'Hank Manning')

    part_a = Participant.create!(homeaway: 'H')
    part_b = Participant.create!(homeaway: 'H')

    @statistic = Statistic.create!(points: 10, time_played: 999, player: player, participant: part_a)
    @statistic = Statistic.create!(points: 14, time_played: 999, player: player, participant: part_b)

    ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  it 'sql' do
    sql = <<-_
      SELECT p.name, avg(s.points) as average
      FROM players p INNER JOIN statistics s 
        ON p.id = s.player_id INNER JOIN participants pa
        ON s.participant_id = pa.id
      WHERE pa.homeaway="H"
      GROUP BY p.name
      HAVING avg(s.time_played) > 900
      ORDER BY average DESC
    _
    result = Player.connection.execute(sql)
    result.length.must_equal 1
    row = result.first
    p row
    row['name'].must_equal 'Hank Manning'
    row['average'].must_equal 12
  end

  it 'arel' do
    result = Player.select('name, avg(points) as average')
               .joins(statistics: [:participant])
               .where(participants: {homeaway: 'H'})
               .group('players.name')
               .having('avg(statistics.time_played) > ?', 900)
               .order('average DESC') # .order(average: :desc) won't work

    result.length.must_equal 1
    row = result.first
    p row
    row.name.must_equal 'Hank Manning'
    row.average.must_equal 12
  end
end
