require_relative './fused_actor'
require_relative './fused_movie'
require_relative './tmdb_actor'
require_relative './tmdb_movie'
require_relative './imdb_query'
require 'pp'

class EntityResolution
  def self.pairwise_match_actor_ids actors_hash1, actors_hash2
    return nil if actors_hash1.class != Hash || actors_hash2.class != Hash
    actors1 = actors_hash1.values[0]
    actors2 = actors_hash2.values[0]
    db1 = actors_hash1.keys[0]
    db2 = actors_hash2.keys[0]
    matches = Array.new  # 2-D Array: [{db1 => actor1._id, db2 => actor2._id, ...}, ...]
    #(actors1.length).times do |i|
    100.times do |i|
      match = Hash.new
      (actors1.length).times do |j|
        if actors1[i].match? actors2[j]
          puts "#{i} match #{j}"
          match.merge!({db2 => actors2[j]._id.to_s})
          actors2.slice!(j)
          break
        end
      end
      match.merge!({db1 => actors1[i]._id.to_s})
      matches << match
      puts "Comparing #{i} ..." if i % 10 == 0
    end
    matches
  end

  def self.pairwise_match_actor_odm actors_hash1, actors_hash2
    return nil if actors_hash1.class != Hash || actors_hash2.class != Hash
    actors1 = actors_hash1.values[0]
    actors2 = actors_hash2.values[0]
    db1 = actors_hash1.keys[0]
    db2 = actors_hash2.keys[0]
    matches = Array.new  # 2-D Array: {index => [actor1._id, actor2._id, ...]}
    (actors1.length).times do |i|
    #100.times do |i|
      match = Hash.new
      (actors2.length).times do |j|
        if actors1[i].match? actors2[j]
          puts "#{i} match #{j}"
          match.merge!({db2 => actors2[j]})
          actors2.slice!(j)
          break
        end
      end
      match.merge!({db1 => actors1[i]})
      matches << match
      puts "Comparing #{i} ..." if i % 10 == 0
    end
    matches
  end

  # input : ({db1 => movies2}, {db2 => movies2})
  def self.pairwise_match_movie_odm movie_hash1, movie_hash2
    #return nil if movie_hash1.class != Hash || movie_hash2.class != Hash
    movies1 = movie_hash1.values[0]
    movies2 = movie_hash2.values[0]
    db1 = movie_hash1.keys[0]
    db2 = movie_hash2.keys[0]
    if movie_hash1.nil? && movie_hash2.nil?
      return nil
    elsif movie_hash1.values[0].nil?
      matches = []
      movie_hash2.values[0].each do |movie|
        matches << {db2 => movie}
      end
      return matches
    elsif movie_hash2.values[0].nil?
      matches = []
      movie_hash1.values[0].each do |movie|
        matches << {db1 => movie}
      end
      return matches
    else
      matches = Array.new  # Array: {index => {db =>movie1, db => movie2, ...}
      (movies1.length).times do |i|
        #100.times do |i|
        match = Hash.new
        (movies2.length).times do |j|
          if movies1[i].match? movies2[j]
            puts "#{i} match #{j}"
            match.merge!({db2 => movies2[j]})
            movies2.slice!(j)
            break
          end
        end
        match.merge!({db1 => movies1[i]})
        matches << match
        puts "Comparing Movie #{i} ..." if i % 10 == 0
      end
      movies2.length.times do |i|
        matches << {db2 => movies2[i]}
      end
      return matches
    end
  end

  def self.test_actor
    tmdb_actors_orignal = TmdbActor.all[200, 300]
    tmdb_actors = Array.new
    tmdb_actors_orignal.each do |actor|
      tmdb_actor = FusedActor.parse_tmdb_actor actor
      tmdb_actors << tmdb_actor
    end

    imdb_query = ImdbQuery.new
    imdb_ids = imdb_query.query_actordb_all
    imdb_actors = FusedActor.read_imdb_by_ids imdb_ids
#imdb_actors = imdb_actors[0, 500]

    puts tmdb_actors.length
    puts imdb_actors.length

    matches_tmdb_imdb = EntityResolution.pairwise_match_actor_odm({tmdb: tmdb_actors}, {imdb: imdb_actors})
    puts matches_tmdb_imdb.length
    matches_tmdb_imdb.each do |match|
      if match.length > 1
        match.each_value do |value|
          puts "#{value.name}: #{value.birthday}"
          #puts value.birthday
        end
        puts
      end
    end
  end

  def self.test_movie
    puts "Reading from TMDB ..."
    tmdb_movies_orignal = TmdbMovie.all
    tmdb_movies = Array.new
    tmdb_movies_orignal.each do |movie|
      tmdb_movie = FusedMovie.parse_tmdb_movie movie
      tmdb_movies<< tmdb_movie
    end

    puts "Reading from IMDB ..."
    imdb_query = ImdbQuery.new
    imdb_ids = imdb_query.query_moviedb_all
    imdb_movies = FusedMovie.read_imdb_by_ids imdb_ids
#imdb_actors = imdb_actors[0, 500]

    puts "TMDB #: #{tmdb_movies.length}"
    puts "IMDB #: #{imdb_movies.length}"

    puts "Sorting ..."
    tmdb_movies.sort! { |a, b| a.title <=> b.title }
    imdb_movies.sort! { |a, b| a.title <=> b.title }

    # test group by
    puts "Grouping by first character of title ..."
    tmdb_movie_groups = FusedMovie.group_by_first_char tmdb_movies
    imdb_movie_groups = FusedMovie.group_by_first_char imdb_movies

    tmdb_count = 0
    imdb_count = 0

    tmdb_movie_groups.values.each do |array|
      tmdb_count += array.length
    end
    imdb_movie_groups.values.each do |array|
      imdb_count += array.length
    end
    puts "tmdb #: #{tmdb_count}"
    puts "imdb #: #{imdb_count}"

    puts tmdb_movie_groups.length
    puts imdb_movie_groups.length

    puts "Begin to pairwise match ..."
    movie_key_compared = []
    matches_tmdb_imdb = []
    tmdb_movie_groups.each_key do |key|
      puts "================ Matching in Group \"#{key}\" =================="
      movie_key_compared << key
      matches_tmdb_imdb.concat(pairwise_match_movie_odm({tmdb: tmdb_movie_groups[key]}, {imdb: imdb_movie_groups[key]}))
    end

    p movie_key_compared

    imdb_movie_groups.each_key do |key|
      unless movie_key_compared.include? key
        print "#{key}, "
        imdb_movie_groups[key].each do |movie|
          matches_tmdb_imdb << {imdb: movie}
        end
      end
    end

    #matches_tmdb_imdb = EntityResolution.pairwise_match_movie_odm({tmdb: tmdb_movies}, {imdb: imdb_movies})
    puts "Entities found: #{matches_tmdb_imdb.length}"
    pairwise_matches = 0
    matches_tmdb_imdb.each do |match|
      if match.length > 1
        pairwise_matches += 1
        match.each_value do |value|
          puts "#{value.title}: #{value.year}, #{value.directors}, #{value.main_casts}"
          #puts value.birthday
        end
        puts
      end
    end
    puts "Pairwise Matches = #{pairwise_matches}"
  end
end

EntityResolution.test_movie



#(actors_array_1.length).times do |i|
#  sim = []
#  (actors_array_1.length).times do |j|
#    unless i == j
#      if actors_array_1[i].match? actors_array_1[j]
##        puts "#{i} match #{j}"
#        break
#      end
#      #sim << (actors_array_1[i].similarity actors_array_1[j])
#    end
#  end
#  puts "#{i} false"
  #sim.sort! { |x, y| y <=> x}
  #puts sim.max
  #p sim[0]
# end