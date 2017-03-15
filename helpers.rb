module Helpers
  def Helpers.pull_params(params, pull)
    res = {}
    pull.each { |keep|
      if params.has_key?(keep) && !params[keep].eql?('na')
        res[keep.to_sym] = params[keep.to_s]
      else
        return false
      end
    }
    res
  end
end
