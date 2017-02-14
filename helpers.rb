module Helpers
  def Helpers.pull_params(params, pull)
    res = {}
    pull.each { |keep|
      if params.has_key?(keep)
        res[keep.to_sym] = params[keep.to_s]
      else
        return false
      end
    }
    res
  end
end
