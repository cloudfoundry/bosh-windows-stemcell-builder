require 'rspec'
RSpec::Matchers.define :include_provisioner do |expected_provisioner, after: []|

  def provisioner_is_after?(actual_provisioners, after, provisioner_index)
    after_index = actual_provisioners.find_index do |provisioner|
      after.matches? provisioner
    end
    if provisioner_index == nil
      @failure_message = "which does not exist"
    elsif after_index == nil
      @failure_message = "after: \n\t#{after.inspect}, which does not exist"
    elsif provisioner_index <= after_index
      @failure_message = "after:\n\t#{after.inspect}"
    end
    return provisioner_index != nil && after_index != nil && provisioner_index > after_index
  end

  def includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after)
    provisioner_index = actual_provisioners.find_index do |provisioner|
      expected_provisioner.matches? provisioner
    end

    provisioner_found = false
    if after.length == 0
      provisioner_found = provisioner_index != nil
    elsif provisioner_is_after?(actual_provisioners, after[0], provisioner_index)
      provisioner_found = includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after[1..-1])
    end

    return provisioner_found
  end

  match do |actual_provisioners|
    return includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after)
  end
  description do
    "include \n\t#{expected_provisioner.inspect} #{@failure_message}"
  end
end
