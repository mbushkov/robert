ext :s3 do
  require 'right_aws'

  def s3(key = var[:s3,:access_key], secret = var[:s3,:secret_key])
    RightAws::S3.new(key, secret, :multi_thread => true)
  end
end

ext :s3_bucket do
  require 'set'

  var[:s3,:bucket] = lambda { conf_name.to_s.split(/:/)[1] }
  var[:s3,:acl] = lambda { "private" }

  def bucket
    @s3 ||= s3
    @bucket ||= @s3.bucket(var[:s3,:bucket])
  end

  def create
  end

  def put(key, data)
    bucket.put(key, data, {}, var[:s3,:acl])
  end

  def get(key)
    bucket.get(key)
  end

  def delete(key)
    bucket.delete(key)
  end

  module ComparableKey
    def eql?(ok)
      return false if ok.nil?
      name == ok.name
    end

    def hash
      name.hash
    end
  end

  def list
    bucket.keys.map { |k| k.dup.extend(ComparableKey) }.to_set
  end
end

defn s3.sync do
  body { |src_conf, dest_conf, src_key, dest_key|
    if src_key
      unless dest_key && src_key.e_tag == dest_key.e_tag
        logd "copying #{dest_key ? 'not synced' : 'brand new'} #{src_key.name} from #{src_conf.conf_name} to #{dest_conf.conf_name}"
        dest_conf.put((dest_key || src_key).name, src_conf.get(src_key))
      else
        logd "#{src_key.full_name} and #{dest_key.full_name} are synced"
      end
    elsif dest_key
      logd "deleting #{dest_key.full_name}"
      dest_conf.delete(dest_key)
    else
      raise ArgumentError, "both src and dest keys are nil"
    end
  }
end

conf :s3_bucket do
  use :sh, :log, :s3, :s3_bucket
end

conf :s3_synced_bucket do
  include :s3_bucket

  act[:sync] = sync.mirror(onfail.tryagain(s3.sync) { var[:pause] = lambda { 1 } }) {
    var[:dest] = lambda { self }
  }  
end
