DomRE = /^[^\/:]+:\/\/((?:[^:\/]+[.])?)([^\/:.]+[.](?:(?:co(?:m)?[.][^:\/.]{2})|(?:(?<![.]co[.])(?<![.]com[.])[^:\/.]+)))(?::\d+)?(?:\/|$)(.*)$/

doms = Hash.new{|h,k| h[k] = Hash.new(0)}

$stdin.set_encoding("iso-8859-1")

lc = 0
$stdin.each do |l|
  lc += 1
  if lc % 100000 == 0
    $stderr.puts lc
  end
  l.chomp!
  m = DomRE.match(l)
  if !m
    next
  end
  if m[3].empty? && (m[1].empty? || m[1].downcase == "www.")
    next
  end
  dom = m[2].downcase
  doms[dom][l] += 1
end

puts '"dom","sampleurl"'

doms.each do |dom, urls|
  su = urls.sort_by{|u| u[1]}
  sampleurl = su[-2] || su.last
  puts "\"#{dom}\",\"#{sampleurl.first.gsub('"', '""')}\""
end
