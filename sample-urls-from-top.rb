inn = ARGV[0]
sample = Integer(ARGV[1])
limit = Integer(ARGV[2])
outn = ARGV[3]

puts "sampling #{sample} out of the top #{limit} domains"

topdom = {}
File.open("top-1m.csv") do |f|
  f.each do |l|
    rank, dom = l.chomp.split(",", 2)
    rank = Integer(rank)
    break if rank > limit
    topdom[dom] = rank
  end
end


matchdom = []
otherdom = 0

File.open(inn) do |inf|
  inf.set_encoding("iso-8859-1")

  inf.each do |l|
    dom, deep = l.chomp.split(",", 2)
    if topdom.include? dom
      matchdom << [dom, deep]
    else
      otherdom += 1
    end
  end
end

puts "#{matchdom.size} links in top #{limit} doms, #{otherdom} not matching"

if matchdom.size < sample
  raise RuntimeError, "Not enough links to sample from"
end

sampledom = matchdom.sample(sample)
sampledom.sort_by!{|dom, deep| topdom[dom]}

File.open("#{outn}-dom.csv", 'w') do |domf|
  File.open("#{outn}-deep.csv", 'w') do |deepf|
    sampledom.each do |dom, deep|
      rank = topdom[dom]
      domf.puts "#{rank},#{dom}"
      deepf.puts "#{rank},#{deep}"
    end
  end
end
