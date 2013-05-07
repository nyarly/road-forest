

server = RoadForest::Server.new("http://example.com")

needs = server.credence_block do |start|
  start[:lc, "unsatisfied-needs"].all(:lc, "needs").each do |need|
    new_need = need.build_graph do |need|
      need[:lc, "path"]
      need[:lc, "file"]
    end
    #Either
    new_need[[:lc, "file"]] = files.find(new_need[:lc, "path"]).contents
    server.put(new_need)

    #OR

    file = new_need[:lc, "file"]
    server.raw_put(file, files.find(new_need[:lc, "path"])) #mime-type?
  end
end

server.credence_block do |start|
  new_need = start[:lc, "needs"].build_graph do |needs|
    needs[:lc, "need_form"].and_descendants(5) #for a depth stop
  end

  new_need[[:lc, "path"]] = "Manifest"
  server.post(new_need)
end
