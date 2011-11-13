class Song
  attr_accessor :name, :artist, :genre, :subgenre, :tags
  
  def initialize(name, artist, genre, subgenre, tags)
    @name, @artist, @genre = name, artist, genre
    @tags, @subgenre = tags, subgenre
  end
  
  def match_criteria?(criteria = {})
    criteria.all? { |k, v| check_criteria_pair(k, v) }
  end
  
  private
  
  def check_criteria_pair(key, value)
    case key
      when :name then @name == value
      when :artist then @artist == value
      when :genre then @genre == value
      when :subgenre then @subgenre == value
      when :tags then match_tags?(Array(value))
      when :filter then value.call(self)
    end
  end
  
  def match_tags?(tags)
    tags.all? do |tag|
      if tag.end_with?("!") 
        not @tags.include?(tag.chop)
      else
        @tags.include?(tag)
      end
    end
  end  
end

class Collection
  
  def initialize(songs_as_string, artist_tags)
    @songs = songs_as_string.lines.map do |line|
     parse_song(line, artist_tags)
    end
  end
  
  def find(criteria)
    @songs.select { |song| song.match_criteria?(criteria) }
  end
  
  private
  
  def parse_song(song_as_string, artist_tags)
    name, artist, genre_string, tags_string = 
      song_as_string.split('.').map(&:strip)
    genre, subgenre = genre_string.split(',').map(&:strip) 
    # Maybe I can use Null Object Pattern here ?
    tags_from_s = tags_string.split(',').map(&:strip) unless tags_string.nil?
    tags = [tags_from_s, genre, subgenre, artist_tags[artist]]
      .compact.flatten.map(&:downcase)
    Song.new(name, artist, genre, subgenre, tags)
  end
end