class Array
  def to_hash
    Hash[*self.flatten(1)]
  end

  def index_by
	  map { |element| [yield(element), element] } .to_hash
  end

  def subarray_count array
    each_cons(array.length).count(array)
  end

  def occurences_count
    Hash.new(0).tap do |result|
      each { |element| result[element] += 1 }
    end
  end
end