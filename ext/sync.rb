defn sync.mirror do
  body { |src = var[:src], dest = var[:dest]|
    src_keys = src.list
    dest_keys = dest.list

    src_keys.each do |skey|
      call_next(src, dest, skey, dest_keys.include?(skey) ? skey : nil)
    end
    (dest_keys - src_keys).each do |dkey|
      call_next(src, dest, nil, dkey)
    end
  }

  spec {
    it "copies everything when destination is empty" do
      src_mock = flexmock("src", :list => ["1000014.dat", "1000015.dat"])
      dest_mock = flexmock("dest", :list => [])

      @action.should_receive(:call_next).with(src_mock, dest_mock, "1000014.dat", nil)
      @action.should_receive(:call_next).with(src_mock, dest_mock, "1000015.dat", nil)

      @action.call(src_mock, dest_mock)
    end

    it "deletes everything when source is empty" do
      src_mock = flexmock("src", :list => [])
      dest_mock = flexmock("dest", :list => ["1000014.dat", "1000015.dat"])

      @action.should_receive(:call_next).with(src_mock, dest_mock, nil, "1000014.dat")
      @action.should_receive(:call_next).with(src_mock, dest_mock, nil, "1000015.dat")

      @action.call(src_mock, dest_mock)
    end

    it "syncs the key if it's already present" do
      src_mock = flexmock("src", :list => ["1000014.dat"])
      dest_mock = flexmock("dest", :list => ["1000014.dat"])

      @action.should_receive(:call_next).with(src_mock, dest_mock, "1000014.dat", "1000014.dat")

      @action.call(src_mock, dest_mock)
    end
  }
end

defn sync.rsync do
  var[:cmd] = lambda { "rsync" }
  var[:args] = lambda { "-auSx --delete --stats --temp-dir=/tmp -e 'ssh -i #{var[:public_key_path]}'" }
  var[:include] = lambda { nil }
  var[:exclude] = lambda { nil }

  body {
    role_host = var["role_#{var[:role]}".to_sym]

    syscmd("mkdir -p #{var[:to]}")
    syscmd("#{var[:cmd]} #{var[:args]} #{role_host}:#{var[:from]} #{var[:to]}")
  }
end